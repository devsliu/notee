# Notee

> 自托管笔记同步 — Go + SQLite（**零基础设施**）+ Flutter 客户端。
> 跨平台：Windows · Linux · macOS · Android · iOS。
> 版本控制、冲突解决、墓碑清理。
> 适合个人和小团队部署使用。

[English](README.md)

---

## 为什么选 Notee？

三个设计选择保持 Notee 轻量简洁：

- **Go 单二进制** — 服务端编译出来就是一个文件，没有运行时，没有解释器，冷启动毫秒级
- **嵌入式 SQLite** — 没有数据库进程，没有连接池调优，数据就是一个 `.db` 文件
- **零解释型语言** — 没有 JS、没有 Electron、没有 Node、没有 WebView、没有 HTML，全编译型代码

核心设计：

- **文件级版本控制** — `fileVersion` + MD5 完整性校验
- **增量同步版本向量** — 只拉取上次同步后有变化的部分
- **自动墓碑清理** — 清理 `purgedVersion` 之前的远端条目，防止删除记录无限堆积
- **TOCTOU 防护** — baseVersion 在 HTTP handler 和 DB 事务内双重校验
- **单笔记加密** — 每条笔记可选 AES-256 加密，密钥零存储，忘记密码即无法解密

---

## 体积与占用

| 产物 | 大小 | 备注 |
|---|---|---|
| 服务端二进制 (Linux) | **~9.4 MB** | Go 单二进制 |
| Docker 容器内存 | **~12 MB** | |
| Windows 客户端 | **~15 MB** | Release + 混淆 + AppBundle |
| Linux 客户端 | **~13 MB** | |
| macOS 客户端 (silicon) | **~26 MB** | |
| Android APK (arm64-v8a) | **~25 MB** | Release + 混淆 + NDK llvm-strip + 仅 arm64 |

---

## 特性

### 服务端 (Go)

| 特性 | 说明 |
|---|---|
| 存储 | 单个 SQLite 文件，按用户分表 |
| 鉴权 | 随机 token（32 字节 hex），30 天 TTL，内存缓存 |
| 多设备 | 同账号最多保留 N 个活跃 token（默认 3），超出踢最老 |
| Token 失效 | 401 + X-Auth-Reason 头区分"过期"和"无效"，客户端自动 relogin |
| 同步协议 | 版本向量 (version + purgedVersion)，增量拉取，purge 时全量重拉 |
| 冲突检测 | baseVersion 乐观锁，HTTP handler 预检 + DB 事务内再检 |
| 资源保护 | MaxBytesReader (100MB)，UUID 校验防路径穿越 |
| 管理界面 | 内置 HTML，Session Cookie + SameSite=Strict — `http://host:7000/admin` |
| HTTPS | 服务端纯 HTTP，如需 HTTPS 可自行部署 Nginx / Caddy 反代 |

### 客户端 (Flutter)

| 特性 | 说明 |
|---|---|
| 平台 | Windows, macOS, Linux, Android, iOS（一套代码），响应式布局 |
| 编辑器 | AppFlowy Editor（自定义 fork）— 块级富文本：段落、标题、列表、代码块（自动识别语言）、待办、链接、图片 |
| Markdown 导入 / 导出 | 批量导入或导出 `.md` / `.txt` — 标题、列表、链接、代码围栏（语言识别）与原生块互转 |
| 全文搜索 | SQLite FTS5 — 中文逐字索引，bm25 相关性排序，结果 snippet 关键字高亮，本地搜索历史 |
| 大纲导航 | 编辑器大纲侧栏 — 按标题层级生成，点击跳转，跟随光标 / 滚动高亮当前位置 |
| 离线可用 | 本地优先 — 完整 Drift (SQLite) 缓存，无网络可读写，重连自动同步 |
| 标签 | 每条笔记独立标签；虚拟标签文件夹视图；按标签过滤；标签编辑器；标签改动自动同步 |
| 提醒 | 一次性 / 每周 / 每月 / 每年四种重复模式，支持农历日期；日历视图；今日未完成数量徽章 |
| 回收站 | 软删除 → 恢复 → 彻底清空；删除时自动捕获回收站条目，恢复保留原 uuid |
| 冲突 UI | 自动检测，Diff 视图，手动解决（保留本地 / 保留远端） |
| 加密 | 按笔记 AES-256 加密 — 可选，零密钥存储，丢密码即丢数据 |
| 分享 | 生成带过期时间的公开链接分享笔记（Markdown 快照）。桌面端复制链接到剪贴板，移动端调用系统分享面板。链接采用 AES-GCM token，密钥取自所有者的密码哈希 — 修改密码会吊销该用户的所有分享链接 |
| 国际化 | 中文 / 英文 |

---

## 快速开始

### 源码构建

**服务端:**
```bash
cd server_go/src
go mod download
go run .
```

**客户端:**
```bash
cd client_flutter
flutter pub get
flutter run
```

### 本地服务配置文件

```ini
[NOTE]
NOTE_PORT = 10001
NOTE_DATA_DIR = D://test/
NOTE_VERSION_DIR = D://test/version
NOTE_ADMIN_USER = admin
NOTE_ADMIN_PASS = admin
NOTE_MAX_DEVICES = 5
NOTE_MAX_FILE_SIZE = 100
```

**参数说明:**
- `NOTE_ADMIN_USER` / `NOTE_ADMIN_PASS`: 管理界面登录凭据
- `NOTE_PORT`: HTTP 监听端口（默认 10001）
- `NOTE_DATA_DIR`: 数据目录，存放 SQLite 和上传文件
- `NOTE_VERSION_DIR`: 客户端升级包根目录，存放所有版本子目录 + `version.ini`（默认 `./version`）
- `NOTE_MAX_DEVICES`: 同账号最多保留的活跃 token 数，超出后自动踢掉最老的 token
- `NOTE_MAX_FILE_SIZE`: 单条目最大上传文件大小，单位 MB（默认 100）
- 同名环境变量优先于 config.ini（以设置了 `NOTE_ADMIN_USER` 为准）

### Docker 服务配置文件

```yaml
version: "3"
services:
  server:
    image: notee:1.0.0
    user: "0:0"
    ports:
      - "7000:10001"
    environment:
      - NOTE_PORT=10001
      - NOTE_DATA_DIR=/app/data
      - NOTE_VERSION_DIR=/app/version
      - NOTE_ADMIN_USER=admin
      - NOTE_ADMIN_PASS=admin
      - NOTE_MAX_DEVICES=5
      - NOTE_MAX_FILE_SIZE=100
    volumes:
      - ./notee:/app/data
      - ./version:/app/version
    restart: always
```

### 首次使用

1. 启动服务端，浏览器打开 `http://host:port/admin`
2. 用上面配置的 admin 账号登录
3. 在管理界面创建用户账号（用户名 + 密码）
4. 打开 Notee 客户端 → **设置** → 填入服务端地址（如 `http://your-server:10001`）和刚才创建的用户名密码
5. 登录成功，多端同步笔记

---

## 客户端版本升级部署

客户端在 **设置 → 版本** 中通过服务端检查和下载更新，升级文件统一放在 `NOTE_VERSION_DIR` 指向的目录（Docker 部署即挂载的 `./version`）。

### 检查与下载接口

- `GET /upgrade/check?platform=android` — 查询指定平台的最新版本（无需鉴权），返回完整下载 URL
- `GET /upgrade/download/{version}/{file}` — 下载安装包（无需鉴权，静态文件服务）

`platform` 取值：`windows`、`linux`、`macos`、`android`、`ios`。

### 目录结构

每个版本独立子目录。服务端先读根目录 `version.ini` 取最新版本名，再进 `{version}/` 读各平台元数据。

```
version/
├── version.ini                                    # latest=1.1.2
├── 1.1.2/
│   ├── version.json                               # 各平台 md5 + 文件名
│   ├── changelog.txt                              # 纯文本发布说明
│   ├── notee-client-windows-x64.zip
│   ├── notee-client-macos-silicon.zip
│   ├── notee-client-linux-x64.tar.gz
│   └── notee-android-arm64-v8a.apk
└── 1.1.1/
    └── ...
```

- `version.ini` — 一行 `latest=X.Y.Z`，服务端首先读它决定最新版本
- `{version}/version.json` — 各平台 `{md5, file}` 条目，带顶层 `updatedAt`
- `{version}/changelog.txt` — 可选纯文本更新说明，check 接口原样返回
- 版本子目录内的安装包文件名**不带版本号**，版本由目录名决定
- macOS 平台键是 `macos`，和其它平台一样走同一套流程
- iOS 平台键被接受但构建脚本不会产出 iOS 安装包

### version.ini 和 version.json 格式

**version.ini** — 一行：
```ini
latest=1.1.2
```

**版本子目录内的 version.json：**
```json
{
  "updatedAt": "2026-10-12T21:49:26Z",
  "windows": {
    "md5": "0AB9CC48BB1777B9657F245D67ECA0AF",
    "file": "notee-client-windows-x64.zip"
  },
  "linux": {
    "md5": "476123BE55F4B5C9E2B8E47FED54A6B5",
    "file": "notee-client-linux-x64.tar.gz"
  },
  "android": {
    "md5": "7CFD9EF9F65F301AA20DED96EDD72BE3",
    "file": "notee-android-arm64-v8a.apk"
  },
  "macos": {
    "md5": "EC4492A621F29E00CA04138F3CC1E4FE",
    "file": "notee-client-macos-silicon.zip"
  }
}
```

字段说明：
- `md5`：安装包大写 MD5，客户端完整性校验用
- `file`：版本子目录下的文件名，也是 check 接口构造下载 URL 的依据
- `updatedAt`：服务端不消费，仅作记录

---

## 分享

笔记可以通过**带过期时间的公开链接**分享。客户端把当前笔记转为 Markdown，上传快照到服务端，然后把返回的链接交给系统分享面板（桌面端则直接复制到剪贴板）。

### 存储结构

分享文件存放在 `{recordsFolder}/user_{id}/share/` 下，文件名：

```
{uuid}.{random16}.{unixTime}.{lifeSeconds}
```

- `uuid` — 记录 id，删除记录时可一并清理该记录的所有分享文件
- `random16` — 8 字节随机数（hex），同一笔记多次分享会生成不可猜测的不同链接
- `unixTime` + `lifeSeconds` — 编码过期时间；过期文件在该用户每次新建分享时惰性清理

### 链接格式

```
http://host:port/note/d/{userId}/{title}.md?token={base64}
```

- `{userId}` — 标识所有者，服务端据此选取正确的解密密钥
- `{title}` — 仅作展示（笔记标题，已对 URL 不安全字符做清洗）；真实文件名从 token 解密得到
- `{token}` — `Base64URL( AES-256-GCM(内部文件名) )`，密钥为 `SHA256(所有者库存密码哈希)`

路径段只用于展示；服务端解密 token 得到磁盘上的真实文件名，校验过期后返回文件。用户修改密码会使其所有分享链接失效。

### 下载模式

- 默认（无参数）：返回 HTML 预览页，显示笔记标题，并提供"下载 .md"按钮
- `?raw=1`：以附件形式返回原始 Markdown 文件（`Content-Disposition: attachment`）

### 加密笔记

分享加密笔记时会先弹密码框解密，用解密后的明文转 Markdown 再分享（不会把密文分享出去）。

---

## API

需要鉴权的接口必须带请求头: `X-User-Id` + `X-Token`.

| 方法 | 路径 | 说明 | 鉴权 |
|---|---|---|---|
| POST | `/user/register` | 注册用户 | 否 |
| POST | `/user/login` | 登录, 获取 token | 否 |
| POST | `/record/update` | 创建或更新条目 (baseVersion 做冲突检测) | 是 |
| POST | `/record/updates` | 批量更新无文件条目 (仅元数据, version 做冲突检测) | 是 |
| POST | `/record/deletes` | 批量删除条目 (version 做冲突检测) | 是 |
| GET | `/record/list` | 查询条目 (按版本增量拉取) | 是 |
| GET | `/record/download` | 下载条目文件 | 是 |
| POST | `/record/clear` | 清空当前用户所有条目 | 是 |
| POST | `/note/upload` | 上传 Markdown 快照，返回带过期时间的公开下载链接（`?uuid=`，表单：`file`、`life` 秒数、`title`） | 是 |
| GET | `/note/d/{userId}/{title}.md?token=...` | 查看/下载分享的笔记（无需鉴权）。加 `?raw=1` 以附件形式返回原始 `.md` | 否 |
| GET | `/api_stat/list` | 查询 API 调用统计 | 是 |
| GET | `/upgrade/check` | 检查客户端更新（参数 `platform`） | 否 |
| GET | `/upgrade/download/{version}/{file}` | 下载安装包（静态文件） | 否 |
| POST | `/admin/login` | 管理端登录 | 否 |
| GET | `/admin` | 管理界面 | 否 (session cookie) |

---

## License

[PolyForm Noncommercial License 1.0.0](LICENSE) — 个人和非营利组织免费使用，商业用途需事先书面授权。协议原文见 <https://polyformproject.org/licenses/noncommercial/1.0.0>。
