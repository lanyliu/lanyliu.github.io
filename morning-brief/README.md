# 早報系統

每天早上自動產生一份早報，寫成 `index.html`，由背景程序偵測到檔案更新後自動 push 上 GitHub Pages。

線上位置：https://lanyliu.github.io/morning-brief/

## 組成

| 檔案 | 角色 |
|---|---|
| 排程任務 `morning-brief` | 每天 08:10 觸發，產生內容並寫入 `index.html` |
| `sources.md` | 追蹤來源清單。要加減來源改這裡，不用動排程任務 |
| `index.html` | 產出的早報。每天被覆寫 |
| `push-brief.sh` | 偵測到 `index.html` 更新後執行 commit + push |
| `notify-telegram.sh` | 推送結束後發 Telegram 通知 |
| `.telegram.env` | Telegram 憑證。不進 git |
| `notify-note.txt` | 當天的提醒文字，由早報任務寫入。不進 git |
| `covered-topics.md` | 職涯區塊的已涵蓋紀錄，用來擋重複內容 |

排程任務的 prompt 存在 `~/Claude/Scheduled/morning-brief/SKILL.md`。

## 流程

```
08:10  排程任務啟動
   ↓   讀 sources.md，決定要抓哪些來源
   ↓   抓行事曆、連結器、網路資料
   ↓   寫入 morning-brief/index.html
   ↓
launchd 偵測到 index.html 變更
   ↓   執行 push-brief.sh
   ↓   git add morning-brief/index.html
   ↓   有變更才 commit，沒變更就跳過
   ↓   git push origin master
   ↓
GitHub Pages 更新
   ↓
notify-telegram.sh 發通知到手機
```

## 自動推送機制

`~/Library/LaunchAgents/com.lany.morningbrief.push.plist`

用 WatchPaths 綁定 `morning-brief/index.html`，檔案一被寫入就執行 `push-brief.sh`。

**這是唯一負責 git 的地方。** 排程任務本身不執行任何 git 指令，只負責把檔案寫到正確位置。這樣拆開的原因：

- sandbox 環境沒有 SSH key，在裡面跑 `git push` 一定失敗
- 推送邏輯集中在一個地方，好排查
- 排程任務只要專心產內容

### 為什麼路徑不能改

`push-brief.sh` 和 plist 的 WatchPaths 都寫死 `morning-brief/index.html`。早報如果寫到別的檔名，watcher 不會被觸發，推送就不會發生，而且不會有任何錯誤訊息，只是安靜地沒動作。

2026-08-08 就踩過這個坑：排程 prompt 還留著搬家前的根目錄路徑 `morning-brief.html`，早報產出正常但沒有上線。改路徑的話這三個地方要一起改：

1. 排程任務 prompt 的 OUTPUT PATH 段落
2. `push-brief.sh` 的 `git add` 那行
3. plist 的 WatchPaths

### 檢查機制是否正常

```bash
# 最近的推送紀錄
cat ~/lanyliu.github.io/.git/logs/refs/remotes/origin/master | tail -5

# 確認 launchd job 有載入
launchctl list | grep morningbrief

# 本地有沒有還沒推上去的 commit
cd ~/lanyliu.github.io && git status -sb
```

推送紀錄每行結尾是 `update by push`，時間戳記應該對得上早報產出的時間。

## Telegram 通知

推送結束後由 `push-brief.sh` 呼叫 `notify-telegram.sh`。成功發連結，失敗發警告，這樣機制壞掉的時候不會安靜地沒聲音。

憑證放在 `.telegram.env`，已加進 `.gitignore`。檔案不存在或值沒填完，通知會安靜跳過，不影響推送。

### 設定步驟

1. Telegram 裡找 `@BotFather`，送 `/newbot`，取名之後拿到 bot token
2. 跟你新建的機器人講一句話（隨便什麼都行，機器人要先收到訊息才知道你的 chat id）
3. 瀏覽器開 `https://api.telegram.org/bot<TOKEN>/getUpdates`，在 JSON 裡找 `"chat":{"id":123456789`
4. 建設定檔：

```bash
cd ~/lanyliu.github.io/morning-brief
cat > .telegram.env <<'EOF'
TELEGRAM_BOT_TOKEN=貼上你的token
TELEGRAM_CHAT_ID=貼上你的chatid
EOF
chmod 600 .telegram.env
```

5. 測試：

```bash
./notify-telegram.sh
```

手機收到訊息就完成了。

### 訊息內容

推送成功的訊息長這樣：

```
☀️ 2026-08-08 早報好了

上午四個行程連著跑到十點半，九點的 Jerry 會議和萬物論錄音
重疊半小時，出門前先決定退掉哪一場。

https://lanyliu.github.io/morning-brief/
```

中間那段提醒由早報任務寫進 `notify-note.txt`，格式是第一行日期、第二行起內容，100 字以內。取材自當天實際抓到的資料，通常是「需要你處理」的第一則、行事曆上的衝突或硬起床時間、或是有時效的機會。

`notify-telegram.sh` 會比對檔案第一行的日期，對不上就只發連結。這是為了避免早報當天沒跑成功、推送卻被其他變更觸發時，發出昨天的提醒。

`--failed` 的警告文字也寫在 `notify-telegram.sh` 裡，想改直接改。

## sources.md 怎麼用

表格裡「啟用」填 `否` 就跳過該來源，不用刪整行。「抓取方式」決定用瀏覽器還是搜尋，Threads 和 YouTube 這類前端渲染的站用 `Chrome→搜尋`，這樣 Chrome 擴充套件沒連線時還能退回搜尋。

詳細規則寫在 `sources.md` 檔案本身。

這個檔案沒有納入 git 追蹤，只留在本機。

## 職涯區塊的防重複機制

「AI 職涯階梯」和「資料分析師 / 資料科學家職涯」是常青主題，同一批職涯指南天天佔據搜尋結果前段。這兩個區塊維持每天出現，但每天要重新賺到版面。

排程任務寫頁面之前會先讀 `covered-topics.md`，每則新內容要同時滿足三個條件：

- 角度跟最近 14 天的紀錄都不同
- 來源網域在同一區塊最近 7 天沒用過
- 有明確時間錨點（新發布的報告、更新的數字、政策或公司制度異動、104 新數據）

找不到就整個區塊當天不出現，不允許把舊東西換句話說。頁面寫完後任務會自己往 `covered-topics.md` 追加一筆，並裁到最近 30 筆。

想讓某個主題重新可用，把 `covered-topics.md` 裡對應那行刪掉。

## 已知待辦

目前沒有。
