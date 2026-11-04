# 发布脚本: 推送 tag -> 等待 CI 构建 -> 下载产物到 pack/build/{version}/ -> 生成 version.json/changelog.txt/version.ini -> 复制到服务端
# 用法: powershell -ExecutionPolicy Bypass -File pack\publish_release.ps1 -Version 1.0.10
# 注意: 不要手动修改 client_flutter/pubspec.yaml 里的 version 字段。
#       GitHub Release workflow 会在构建时自动将 version 改为 "<tag>+<GITHUB_RUN_NUMBER>"。
#       本脚本只需推送正确的 tag，CI 会处理版本号。
param(
    [Parameter(Mandatory=$true)]
    [string]$Version,            # e.g. 1.0.5 (no 'v'), tag will be v$Version
    [string]$ServerVersionDir = 'Y:\notee\version'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$tag = "v$Version"

Set-Location $ProjectRoot

# 1. 推送 tag 触发 CI (tag 已存在则跳过, 直接复用已有 CI 构建)
$tagExists = git tag --list $tag
if ($tagExists) {
    Write-Host "Tag $tag already exists, skip tagging."
} else {
    git tag -a $tag -m "Release $tag"
    git push origin $tag
    if ($LASTEXITCODE -ne 0) { throw "push tag failed" }
}

# 2. 等待 CI run 出现并构建完成
$runId = $null
for ($i = 0; $i -lt 30; $i++) {
    $runs = gh run list --branch $tag --limit 1 --json databaseId,status,conclusion | ConvertFrom-Json
    if ($runs.Count -gt 0) {
        $runId = $runs[0].databaseId
        # 如果已经完成, 直接跳过 watch
        if ($runs[0].status -eq 'completed') {
            Write-Host "CI run $runId already completed ($($runs[0].conclusion))."
            if ($runs[0].conclusion -ne 'success') { throw "CI build failed ($($runs[0].conclusion)), see: gh run view $runId" }
            break
        }
        break
    }
    Start-Sleep -Seconds 5
}
if (-not $runId) { throw "CI run for $tag not found" }
if (-not $runs -or $runs[0].status -ne 'completed') {
    Write-Host "Watching CI run $runId ..."
    gh run watch $runId --exit-status --interval 60
    if ($LASTEXITCODE -ne 0) { throw "CI build failed, see: gh run view $runId" }
}

# 3. 下载 Release 产物到本地 build 目录
$artDir = Join-Path $PSScriptRoot "build\$Version"
if (Test-Path $artDir) { Remove-Item $artDir -Recurse -Force }
New-Item -ItemType Directory -Path $artDir | Out-Null
gh release download $tag --dir $artDir --clobber
if ($LASTEXITCODE -ne 0) { throw "release download failed" }

# 3.5 重命名产物, 去掉文件名中的版本号 (服务端版本目录中的固件/apk/zip 不带版本名)
Get-ChildItem $artDir -File | Where-Object { $_.Name -like "*-v$Version.*" } | ForEach-Object {
    $newName = $_.Name -replace "-v$([regex]::Escape($Version))", ""
    Rename-Item -LiteralPath $_.FullName -NewName $newName -Force
    Write-Host "  renamed: $($_.Name) -> $newName"
}

# 4. 生成版本元数据 (version.json / changelog.txt / version.ini)

chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Map platform → filename (文件名已去掉版本号, docker 不进 version.json)
$map = @{
    'windows' = "notee-client-windows-x64.zip"
    'android' = "notee-android-arm64-v8a.apk"
    'macos'   = "notee-client-macos-silicon.zip"
    'linux'   = (Get-ChildItem "$artDir\notee-client-linux-x64*.tar.gz" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Name)
}

# Changelog: 直接从 GitHub Release 的 body 获取
try {
    $changelog = (gh release view $tag --json body --jq '.body' 2>$null)
    if (-not $changelog) { $changelog = '' }
} catch { $changelog = '' }
if (-not $changelog) { $changelog = 'init release' }

$updatedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')

# version.json (只含 updatedAt + 各平台 md5/file)
$data = [PSCustomObject]@{ updatedAt = $updatedAt }

foreach ($plat in $map.Keys) {
    $fname = $map[$plat]
    if (-not $fname) { continue }
    $fpath = Join-Path $artDir $fname
    if (-not (Test-Path $fpath)) { continue }

    $md5 = (Get-FileHash $fpath -Algorithm MD5).Hash.ToUpper()
    $entry = [PSCustomObject]@{ md5 = $md5; file = $fname }
    Add-Member -InputObject $data -NotePropertyName $plat -NotePropertyValue $entry -Force
    Write-Host "  [$plat] $Version md5=$md5"
}

# 生成格式化 JSON 并还原 unicode 转义
$json = $data | ConvertTo-Json -Depth 10
$matches = [regex]::Matches($json, '\\u([0-9a-fA-F]{4})')
for ($i = $matches.Count - 1; $i -ge 0; $i--) {
    $m = $matches[$i]
    $code = [Convert]::ToInt32($m.Groups[1].Value, 16)
    $char = [char]$code
    $json = $json.Substring(0, $m.Index) + $char + $json.Substring($m.Index + $m.Length)
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$jsonPath = Join-Path $artDir 'version.json'
[IO.File]::WriteAllText($jsonPath, $json, $utf8NoBom)
Write-Host "version.json saved: $jsonPath"

$changelogPath = Join-Path $artDir 'changelog.txt'
[IO.File]::WriteAllText($changelogPath, $changelog, $utf8NoBom)
Write-Host "changelog.txt saved: $changelogPath"

# 根目录 versions.json 已废弃, 删除
$oldJson = Join-Path $ServerVersionDir 'versions.json'
if (Test-Path $oldJson) { Remove-Item $oldJson -Force }

# 根目录 version.ini (最新版本名)
$iniPath = Join-Path $ServerVersionDir 'version.ini'
[IO.File]::WriteAllText($iniPath, "latest=$Version`n", $utf8NoBom)
Write-Host "version.ini saved: $iniPath (latest=$Version)"

# 5. 复制本地 build 目录到服务端
$serverArtDir = Join-Path $ServerVersionDir $Version
if (Test-Path $serverArtDir) { Remove-Item $serverArtDir -Recurse -Force }
Copy-Item $artDir $serverArtDir -Recurse -Force
Write-Host "Copied $artDir -> $serverArtDir"

Write-Host "Publish $tag done -> $ServerVersionDir"
