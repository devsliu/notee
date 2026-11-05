package main

import (
	"bytes"
	"crypto/md5"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
)

// md5OfText / generateMd5Pass 复制自主程序, 供集成测试使用
func md5OfText(data string) string {
	h := md5.New()
	h.Write([]byte(data))
	return strings.ToUpper(hex.EncodeToString(h.Sum(nil)))
}
func generateMd5Pass(name, pass string) string {
	return md5OfText(fmt.Sprintf("%s_%s", name, pass))
}

var (
	baseURL      = "http://localhost:10001"
	testUserName = "okzdev"
	testPassword = "5D33B9D839FB5C1AFFEE78C45EBD38CC"
)

// randomString generates a random alphanumeric string of the given length.
func randomString(n int) string {
	const letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	for i := 0; i < n; i++ {
		b[i] = letters[int(b[i])%len(letters)]
	}
	return string(b)
}

// generateUUID generates a new UUID string.
func generateUUID() string {
	return uuid.New().String()
}

func TestAPIFlow(t *testing.T) {
	// 随机用户名, 避免重复运行时 "user exists"
	userName := "t_" + randomString(8)
	password := generateMd5Pass(userName, "123456")

	// ---- 1. 注册 ----
	regBody, _ := json.Marshal(map[string]string{
		"name":     userName,
		"password": password,
	})
	resp, err := http.Post(baseURL+"/user/register", "application/json", bytes.NewReader(regBody))
	if err != nil {
		t.Fatal("register error:", err)
	}
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("register failed: %s, body: %s", resp.Status, string(body))
	}
	resp.Body.Close()
	t.Log("1. register OK:", userName)

	// ---- 2. 登录 ----
	loginBody, _ := json.Marshal(map[string]string{
		"name":     userName,
		"password": password,
	})
	resp, err = http.Post(baseURL+"/user/login", "application/json", bytes.NewReader(loginBody))
	if err != nil {
		t.Fatal("login error:", err)
	}
	defer resp.Body.Close()
	var loginResp map[string]any
	json.NewDecoder(resp.Body).Decode(&loginResp)
	token := loginResp["token"].(string)
	userId := int64(loginResp["userId"].(float64))
	t.Logf("2. login OK: userId=%d", userId)

	// ---- 3. 创建 record ----
	recordUuid := generateUUID()
	recordName := "test_" + randomString(6) + ".txt"
	now := time.Now().UnixMilli()

	var buf bytes.Buffer
	writer := multipart.NewWriter(&buf)
	writer.WriteField("path", "/notes/")
	writer.WriteField("name", recordName)
	writer.WriteField("createAt", strconv.FormatInt(now, 10))
	writer.WriteField("editAt", strconv.FormatInt(now, 10))
	writer.WriteField("fileEditAt", strconv.FormatInt(now, 10))
	writer.WriteField("locked", "0")
	writer.WriteField("version", "0") // 新记录 baseVersion = 0
	fw, _ := writer.CreateFormFile("file", recordName)
	fw.Write([]byte("hello world from test"))
	writer.Close()

	req, _ := http.NewRequest("POST", baseURL+"/record/update?uuid="+recordUuid, &buf)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("X-User-Id", strconv.FormatInt(userId, 10))
	req.Header.Set("X-Token", token)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal("create record error:", err)
	}
	defer resp.Body.Close()
	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		t.Fatalf("decode record: %v", err)
	}
	t.Logf("3. create OK: uuid=%s, version=%v, md5=%v", record["uuid"], record["version"], record["md5"])
	if record["md5"] == nil || record["md5"] == "" {
		t.Error("record md5 should not be empty")
	}
	baseVersion := int64(record["version"].(float64))

	// ---- 4. 列出所有 record ----
	req, _ = http.NewRequest("GET", baseURL+"/record/list?version=0&limit=200", nil)
	req.Header.Set("X-User-Id", strconv.FormatInt(userId, 10))
	req.Header.Set("X-Token", token)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal("list records error:", err)
	}
	listBody, _ := io.ReadAll(resp.Body)
	var listResp map[string]any
	json.NewDecoder(bytes.NewReader(listBody)).Decode(&listResp)
	records := listResp["records"].([]any)
	t.Logf("4. list OK: %d records, purgedVersion=%v", len(records), listResp["purgedVersion"])
	resp.Body.Close()

	// ---- 5. 更新 record (带 baseVersion 做冲突检测) ----
	buf.Reset()
	writer = multipart.NewWriter(&buf)
	writer.WriteField("path", "/notes/")
	writer.WriteField("name", recordName)
	writer.WriteField("createAt", strconv.FormatInt(now, 10))
	writer.WriteField("editAt", strconv.FormatInt(now+1000, 10))
	writer.WriteField("fileEditAt", strconv.FormatInt(now+1000, 10))
	writer.WriteField("locked", "0")
	writer.WriteField("version", strconv.FormatInt(baseVersion, 10))
	fw, _ = writer.CreateFormFile("file", recordName)
	fw.Write([]byte("hello world UPDATED content"))
	writer.Close()

	req, _ = http.NewRequest("POST", baseURL+"/record/update?uuid="+recordUuid, &buf)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("X-User-Id", strconv.FormatInt(userId, 10))
	req.Header.Set("X-Token", token)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal("update record error:", err)
	}
	var updatedRecord map[string]any
	json.NewDecoder(resp.Body).Decode(&updatedRecord)
	t.Logf("5. update OK: version=%v, md5=%v", updatedRecord["version"], updatedRecord["md5"])
	newVersion := int64(updatedRecord["version"].(float64))
	if newVersion <= baseVersion {
		t.Errorf("version should increase after update: %d -> %d", baseVersion, newVersion)
	}
	resp.Body.Close()

	// ---- 6. 下载文件 + 校验 md5 ----
	req, _ = http.NewRequest("GET", baseURL+"/record/download?uuid="+recordUuid, nil)
	req.Header.Set("X-User-Id", strconv.FormatInt(userId, 10))
	req.Header.Set("X-Token", token)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal("download error:", err)
	}
	downloadBody, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	expectedMD5 := md5OfText(string(downloadBody))
	headerMD5 := resp.Header.Get("x-record-md5")
	t.Logf("6. download OK: size=%d, headerMD5=%s, computedMD5=%s", len(downloadBody), headerMD5, expectedMD5)
	if headerMD5 != expectedMD5 {
		t.Errorf("md5 mismatch: header=%s vs computed=%s", headerMD5, expectedMD5)
	}

	// ---- 7. 用过期 baseVersion 再更新, 应返回冲突 ----
	buf.Reset()
	writer = multipart.NewWriter(&buf)
	writer.WriteField("path", "/notes/")
	writer.WriteField("name", recordName)
	writer.WriteField("createAt", strconv.FormatInt(now, 10))
	writer.WriteField("editAt", strconv.FormatInt(now+2000, 10))
	writer.WriteField("fileEditAt", strconv.FormatInt(now+2000, 10))
	writer.WriteField("locked", "0")
	writer.WriteField("version", strconv.FormatInt(baseVersion, 10)) // 过期的 baseVersion
	fw, _ = writer.CreateFormFile("file", recordName)
	fw.Write([]byte("stale write should fail"))
	writer.Close()

	req, _ = http.NewRequest("POST", baseURL+"/record/update?uuid="+recordUuid, &buf)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("X-User-Id", strconv.FormatInt(userId, 10))
	req.Header.Set("X-Token", token)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal("conflict test request error:", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusOK {
		t.Error("expected conflict status, got 200 OK — baseVersion check may be broken")
	} else {
		t.Logf("7. conflict OK: got status %d as expected", resp.StatusCode)
	}

	// ---- 8. 删除 record (batch) ----
	deleteBody := bytes.NewBufferString(`[{"uuid":"` + recordUuid + `","version":0}]`)
	req, _ = http.NewRequest("POST", baseURL+"/record/deletes", deleteBody)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-User-Id", strconv.FormatInt(userId, 10))
	req.Header.Set("X-Token", token)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal("delete record error:", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("delete failed: %s, body: %s", resp.Status, string(body))
	}
	var delResults []map[string]any
	json.NewDecoder(resp.Body).Decode(&delResults)
	if len(delResults) != 1 || delResults[0]["code"].(float64) != 200 {
		t.Fatalf("delete batch unexpected result: %+v", delResults)
	}
	t.Log("8. delete OK")

	// ---- 9. 再次 list, 验证墓碑 ----
	req, _ = http.NewRequest("GET", baseURL+"/record/list?version=0&limit=200", nil)
	req.Header.Set("X-User-Id", strconv.FormatInt(userId, 10))
	req.Header.Set("X-Token", token)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal("list after delete error:", err)
	}
	defer resp.Body.Close()
	listBody2, _ := io.ReadAll(resp.Body)
	var listResp2 map[string]any
	json.NewDecoder(bytes.NewReader(listBody2)).Decode(&listResp2)
	records2 := listResp2["records"].([]any)
	tombstoneCount := 0
	for _, r := range records2 {
		rec := r.(map[string]any)
		if delAt, ok := rec["deleteAt"].(float64); ok && delAt > 0 {
			tombstoneCount++
		}
	}
	t.Logf("9. list after delete: %d total, %d tombstones", len(records2), tombstoneCount)
	if tombstoneCount == 0 {
		t.Error("expected at least one tombstone after delete")
	}

	// ---- 10. 还原场景: 对墓碑 upsert (baseVersion=0) 应复活记录而不是返回冲突 ----
	buf.Reset()
	writer = multipart.NewWriter(&buf)
	writer.WriteField("path", "/notes/")
	writer.WriteField("name", recordName)
	writer.WriteField("createAt", "0") // 还原后客户端不再持有原始 createAt, 传 0
	writer.WriteField("editAt", strconv.FormatInt(now+3000, 10))
	writer.WriteField("fileEditAt", strconv.FormatInt(now+3000, 10))
	writer.WriteField("locked", "0")
	writer.WriteField("version", "0")
	fw, _ = writer.CreateFormFile("file", recordName)
	fw.Write([]byte("restored content"))
	writer.Close()

	req, _ = http.NewRequest("POST", baseURL+"/record/update?uuid="+recordUuid, &buf)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("X-User-Id", strconv.FormatInt(userId, 10))
	req.Header.Set("X-Token", token)
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal("tombstone upsert error:", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("tombstone upsert should revive the record, got: %s, body: %s", resp.Status, string(body))
	}
	var reviveResp map[string]any
	json.NewDecoder(resp.Body).Decode(&reviveResp)
	if delAt, ok := reviveResp["deleteAt"].(float64); !ok || delAt != 0 {
		t.Errorf("expected deleteAt=0 after revive, got %v", reviveResp["deleteAt"])
	}
	if createAt, ok := reviveResp["createAt"].(float64); !ok || createAt != float64(now) {
		t.Errorf("expected original createAt=%d preserved, got %v", now, reviveResp["createAt"])
	}
	t.Log("10. tombstone revive OK: deleteAt=0, createAt preserved")

	t.Log("=== TestAPIFlow PASSED ===")
}

func TestBatchCreateRecords(t *testing.T) {
	// 登录
	loginBody, _ := json.Marshal(map[string]string{
		"name":     "test",
		"password": generateMd5Pass("test", "123"),
	})
	resp, err := http.Post(baseURL+"/user/login", "application/json", bytes.NewReader(loginBody))
	if err != nil {
		t.Fatal("login error:", err)
	}
	defer resp.Body.Close()
	var loginResp map[string]any
	json.NewDecoder(resp.Body).Decode(&loginResp)
	token := loginResp["token"].(string)
	userId := int64(loginResp["userId"].(float64))

	// 2. 清空笔记
	req, _ := http.NewRequest("POST", baseURL+"/record/clear", nil)
	req.Header.Set("X-User-Id", strconv.FormatInt(userId, 10))
	req.Header.Set("X-Token", token)
	resp2, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("clear records failed: %v", err)
	}
	defer resp2.Body.Close()
	if resp2.StatusCode != 200 {
		t.Fatalf("clear records failed, status: %d", resp2.StatusCode)
	}

	// 构造大内容
	bigContent := bytes.Repeat([]byte("内容很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长。\n"), 100)

	paths := []string{
		"/天空/",
		"/root1/",
		"/root1/child/",
		"/root2/child/grandchild/",
		"/",
	}
	exts := []string{"todo", "md", "txt"}

	now := time.Now().UnixMilli()
	for i := 0; i < 30; i++ {
		path := paths[i%len(paths)]
		suffix := exts[i%len(exts)]
		name := "record_" + strconv.Itoa(i) + "." + suffix
		recordUuid := generateUUID()
		var buf bytes.Buffer
		writer := multipart.NewWriter(&buf)
		writer.WriteField("path", path)
		writer.WriteField("name", name)
		writer.WriteField("createAt", strconv.FormatInt(now, 10))
		writer.WriteField("editAt", strconv.FormatInt(now, 10))
		writer.WriteField("fileEditAt", strconv.FormatInt(now, 10))
		writer.WriteField("locked", strconv.Itoa(0))
		fw, _ := writer.CreateFormFile("file", name)
		if suffix == "todo" {
			todoContent := "" // 标准todo格式
			for j := 0; j < 100; j++ {
				todoContent += "[ ] 任务" + strconv.Itoa(j) + "\n"
			}
			fw.Write([]byte(todoContent))
		} else {
			fw.Write(bigContent)
		}
		writer.Close()
		req, _ := http.NewRequest("POST", baseURL+"/record/update?uuid="+recordUuid, &buf)
		req.Header.Set("Content-Type", writer.FormDataContentType())
		req.Header.Set("X-User-Id", strconv.FormatInt(userId, 10))
		req.Header.Set("X-Token", token)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("create record error: %v", err)
		}
		if resp.StatusCode != 200 {
			body, _ := io.ReadAll(resp.Body)
			t.Fatalf("create record failed: %s, body: %s", resp.Status, string(body))
		}
		resp.Body.Close()
	}
	t.Log("批量创建笔记完成")
}
