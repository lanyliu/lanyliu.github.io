#!/bin/bash
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH"
cd "$HOME/lanyliu.github.io" || exit 1
sleep 5
rm -f .git/index.lock .git/HEAD.lock .git/refs/heads/*.lock 2>/dev/null
rm -f .git/objects/*/tmp_obj_* 2>/dev/null
git add morning-brief/index.html
if git diff --cached --quiet; then
  echo "$(date '+%F %T')  no change, skipping"
  exit 0
fi
NOTIFY="$HOME/lanyliu.github.io/morning-brief/notify-telegram.sh"

if git commit -m "morning brief $(date +%Y-%m-%d)" && git push origin master; then
  echo "$(date '+%F %T')  pushed OK"
  [ -x "$NOTIFY" ] && "$NOTIFY"
else
  echo "$(date '+%F %T')  PUSH FAILED"
  [ -x "$NOTIFY" ] && "$NOTIFY" --failed
fi
