#!/bin/bash
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH"
cd ~/lanyliu.github.io
rm -f .git/index.lock
git add morning-brief.html
git commit -m "Update morning brief – 2026-07-28"
git push origin master
echo ""
echo "=== DONE ==="
echo "Visit: https://lanyliu.github.io/morning-brief.html"
