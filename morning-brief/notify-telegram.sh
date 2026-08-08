#!/bin/bash
# 早報 Telegram 通知
#
# 由 push-brief.sh 在推送結束後呼叫。
# 設定檔 .telegram.env 沒建立或沒填完整時會安靜跳過，不影響推送本身。
#
# 用法：
#   ./notify-telegram.sh            推送成功
#   ./notify-telegram.sh --failed   推送失敗

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH"

BASE="$HOME/lanyliu.github.io/morning-brief"
ENV_FILE="$BASE/.telegram.env"
NOTE_FILE="$BASE/notify-note.txt"
STAMP="$(date '+%F %T')  telegram:"

if [ ! -f "$ENV_FILE" ]; then
  echo "$STAMP 找不到 .telegram.env，跳過通知"
  exit 0
fi

# shellcheck disable=SC1090
. "$ENV_FILE"

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
  echo "$STAMP .telegram.env 缺 token 或 chat id，跳過通知"
  exit 0
fi

TODAY="$(date '+%Y-%m-%d')"
URL="https://lanyliu.github.io/morning-brief/"

# 提醒文字由早報任務寫入 notify-note.txt
# 第一行是日期，第二行起是內容。日期對不上就不用，避免發到昨天的提醒。
NOTE=""
if [ -f "$NOTE_FILE" ]; then
  NOTE_DATE="$(head -n 1 "$NOTE_FILE" | tr -d '[:space:]')"
  if [ "$NOTE_DATE" = "$TODAY" ]; then
    NOTE="$(tail -n +2 "$NOTE_FILE")"
  else
    echo "$STAMP 提醒是 ${NOTE_DATE} 的，今天是 ${TODAY}，只發連結"
  fi
fi

if [ "$1" = "--failed" ]; then
  TEXT="⚠️ ${TODAY} 早報推送失敗

網頁上的內容可能還是昨天的。到 Terminal 執行 morning-brief/push-brief.sh 可以看錯誤訊息。"
elif [ -n "$NOTE" ]; then
  TEXT="☀️ ${TODAY} 早報好了

${NOTE}

${URL}"
else
  TEXT="☀️ ${TODAY} 早報好了

${URL}"
fi

RESP=$(curl -s -m 15 -X POST \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${TEXT}")

if echo "$RESP" | grep -q '"ok":true'; then
  echo "$STAMP 已送出"
else
  echo "$STAMP 送出失敗 → $RESP"
fi
