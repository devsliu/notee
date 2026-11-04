//go:build ignore
// +build ignore

// 并发压测 notee Go 后端.
// 用法: go run stress_test.go
//
// 流程:
//  1. 登录拿 token (默认 test/test)
//  2. 并发 N 个 goroutine 循环 M 次写 /record/update (同一个 uuid, 测 OCC 冲突重试)
//  3. 并发读 /record/list
//  4. 打印 QPS / 错误率 / 延迟分布

package main

import (
	"bytes"
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"runtime"
	"sync"
	"sync/atomic"
	"time"
)

const (
	baseURL    = "http://liuhaoge.cn:7000"
	userName   = "stress_test_user"
	userPass   = "stress123"
	workers    = 50                                     // 并发 goroutine 数
	iterations = 100                                    // 每个 goroutine 循环次数
	testUUID   = "a1b2c3d4-e5f6-7890-abcd-ef1234567890" // 标准 UUID 格式, 通过服务端校验
)

var httpClient = &http.Client{
	Timeout: 10 * time.Second,
	Transport: &http.Transport{
		MaxIdleConns:        100,
		MaxIdleConnsPerHost: 100,
		IdleConnTimeout:     30 * time.Second,
	},
}

func passMd5() string {
	h := md5.Sum([]byte(userName + "_" + userPass))
	return hex.EncodeToString(h[:])
}

func ensureUser() {
	body, _ := json.Marshal(map[string]string{
		"name":     userName,
		"password": passMd5(), // admin 注册: md5(name_password)
	})
	resp, err := httpClient.Post(baseURL+"/user/register", "application/json", bytes.NewReader(body))
	if err != nil {
		fmt.Printf("⚠️ 注册请求失败: %v\n", err)
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode == 200 {
		fmt.Println("✅ 注册成功 (新用户)")
	} else {
		fmt.Printf("ℹ️ 注册跳过 (HTTP %d, 可能已存在)\n", resp.StatusCode)
	}
}

func main() {
	fmt.Println("=== Notee 并发压测 ===")
	fmt.Printf("目标: %s\n", baseURL)
	fmt.Printf("CPU: %d, Workers: %d, 每轮: %d\n\n", runtime.NumCPU(), workers, iterations)

	// 0. 确保用户存在 (不存在就注册)
	ensureUser()

	// 1. 登录
	token, userId := login()
	fmt.Printf("✅ 登录成功: userId=%d, token=%s...%s\n\n",
		userId, token[:8], token[len(token)-4:])

	// 2. 先写一条, 让 update 有东西可 merge
	fmt.Println("📝 预热写入一条 record...")
	warmup(token, userId)

	// 3. 并发压测: update (测 OCC 冲突)
	fmt.Printf("\n🔥 并发写压测: %d workers × %d iters /record/update (同一 uuid)\n", workers, iterations)
	runStress("update", workers, iterations, func() bool {
		return updateRecord(token, userId)
	})

	// 4. 并发压测: list (测读并发)
	fmt.Printf("\n📖 并发读压测: %d workers × %d iters /record/list\n", workers, iterations)
	runStress("list", workers, iterations, func() bool {
		return listRecords(token, userId)
	})
}

func login() (string, int64) {
	// 兼容两种协议: admin 注册存 md5(name_password), Flutter 客户端注册存明文
	// 统一用 md5 试 (test 多半是 admin 创建的)
	body, _ := json.Marshal(map[string]string{
		"name":     userName,
		"password": passMd5(),
	})
	resp, err := httpClient.Post(baseURL+"/user/login", "application/json", bytes.NewReader(body))
	if err != nil {
		fatal("登录失败: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		b, _ := io.ReadAll(resp.Body)
		fatal("登录 HTTP %d: %s", resp.StatusCode, string(b))
	}
	var r struct {
		UserId int64  `json:"userId"`
		Token  string `json:"token"`
	}
	json.NewDecoder(resp.Body).Decode(&r)
	return r.Token, r.UserId
}

func warmup(token string, userId int64) {
	if updateRecord(token, userId) {
		fmt.Println("   ✅ 预热写入完成")
	} else {
		fmt.Println("   ⚠️ 预热写入失败, 继续压测...")
	}
	listRecords(token, userId) // 顺便拉一次最新 version
}

func runStress(name string, workers, iters int, fn func() bool) {
	var success, fail int64
	var totalLatency int64
	var minLatency, maxLatency int64 = 1 << 62, 0
	var mu sync.Mutex

	start := time.Now()
	var wg sync.WaitGroup
	wg.Add(workers)

	for w := 0; w < workers; w++ {
		go func() {
			defer wg.Done()
			for i := 0; i < iters; i++ {
				t0 := time.Now()
				ok := fn()
				lat := time.Since(t0).Milliseconds()

				if ok {
					atomic.AddInt64(&success, 1)
				} else {
					atomic.AddInt64(&fail, 1)
				}
				mu.Lock()
				totalLatency += lat
				if lat < minLatency {
					minLatency = lat
				}
				if lat > maxLatency {
					maxLatency = lat
				}
				mu.Unlock()
			}
		}()
	}
	wg.Wait()
	elapsed := time.Since(start)

	total := int64(workers * iters)
	qps := float64(success) / elapsed.Seconds()
	avgLat := float64(totalLatency) / float64(total)

	fmt.Printf("📊 [%s] 结果:\n", name)
	fmt.Printf("   耗时: %.2fs | QPS: %.1f\n", elapsed.Seconds(), qps)
	fmt.Printf("   成功: %d | 失败: %d (%.2f%%)\n",
		success, fail, float64(fail)/float64(total)*100)
	fmt.Printf("   延迟: min=%dms avg=%.1fms max=%dms\n\n", minLatency, avgLat, maxLatency)
}

func updateRecord(token string, userId int64) bool {
	// multipart: uuid query + 文件 + 表单字段
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)

	// 表单字段 (服务端用 r.FormValue / getFormInt64 读)
	now := time.Now().UnixMilli()
	w.WriteField("createAt", fmt.Sprintf("%d", now))
	w.WriteField("editAt", fmt.Sprintf("%d", now))
	w.WriteField("fileEditAt", fmt.Sprintf("%d", now))
	w.WriteField("version", "0") // baseVersion, 新建传 0
	w.WriteField("path", "/stress/")
	w.WriteField("name", "stress-test.md")
	w.WriteField("locked", "0")
	w.WriteField("md5sum", "")

	// 文件
	part, _ := w.CreateFormFile("file", "stress.md")
	content := fmt.Sprintf("# Stress Test\n写入时间: %s\n", time.Now().Format(time.RFC3339Nano))
	part.Write([]byte(content))
	w.Close()

	req, _ := http.NewRequest("POST",
		fmt.Sprintf("%s/record/update?uuid=%s", baseURL, testUUID),
		&buf)
	req.Header.Set("Content-Type", w.FormDataContentType())
	req.Header.Set("X-User-Id", fmt.Sprintf("%d", userId))
	req.Header.Set("X-Token", token)

	resp, err := httpClient.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		b, _ := io.ReadAll(resp.Body)
		fmt.Printf("  update 失败: HTTP %d: %s\n", resp.StatusCode, string(b))
		return false
	}
	return true
}

func listRecords(token string, userId int64) bool {
	req, _ := http.NewRequest("GET",
		fmt.Sprintf("%s/record/list?version=0&limit=1000", baseURL), nil)
	req.Header.Set("X-User-Id", fmt.Sprintf("%d", userId))
	req.Header.Set("X-Token", token)

	resp, err := httpClient.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		b, _ := io.ReadAll(resp.Body)
		fmt.Printf("  list 失败: HTTP %d: %s\n", resp.StatusCode, string(b))
		return false
	}
	return true
}

func fatal(format string, args ...interface{}) {
	fmt.Printf("❌ "+format+"\n", args...)
	os.Exit(1)
}
