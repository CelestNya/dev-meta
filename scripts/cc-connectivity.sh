#!/usr/bin/env bash
# Probe CommandCode API reachability and auth from a GitHub Actions runner.
#
# Two stages:
#   1. GET  {base}/health          — no auth; proves network + DNS + TLS
#   2. POST {base}/alpha/generate  — Bearer auth; proves the key is valid and
#                                    the request shape is accepted
#
# The API key is read from $CMD_API_KEY and never printed.
set -u

BASE="${CC_API_BASE:-https://api.commandcode.ai}"
KEY="${CMD_API_KEY:-}"

fail() { echo "::error::$1"; exit 1; }

[ -n "$KEY" ] || fail "CMD_API_KEY is empty — did you set the repo secret?"

echo "=== Stage 1: GET ${BASE}/health (no auth) ==="
curl -sS --max-time 15 -o /dev/null -w 'http=%{http_code} dns=%{time_namelookup}s connect=%{time_connect}s tls=%{time_appconnect}s total=%{time_total}s\n' \
  "${BASE}/health" || fail "health probe failed (network unreachable from runner)"

echo
echo "=== Stage 2: POST ${BASE}/alpha/generate (Bearer auth, minimal body) ==="
BODY=$(cat <<'EOF'
{
  "config": {
    "workingDir": "/tmp",
    "date": "__DATE__",
    "environment": "linux-x64, Node.js v24.16.0",
    "structure": [],
    "isGitRepo": false,
    "currentBranch": "",
    "mainBranch": "",
    "gitStatus": "",
    "recentCommits": []
  },
  "memory": "",
  "taste": "",
  "skills": "",
  "permissionMode": "standard",
  "params": {
    "model": "deepseek-v4.1-flash",
    "messages": [{"role": "user", "content": "Reply with exactly: OK"}],
    "stream": false,
    "max_tokens": 8
  },
  "threadId": "__UUID__"
}
EOF
)
BODY=${BODY/__DATE__/$(date -u +%F)}
BODY=${BODY/__UUID__/$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c 'import uuid;print(uuid.uuid4())')}

HTTP_CODE=$(curl -sS --max-time 60 -o /tmp/cc-resp.json -w '%{http_code}' \
  -X POST "${BASE}/alpha/generate" \
  -H "Authorization: Bearer ${KEY}" \
  -H "Content-Type: application/json" \
  --data "$BODY") || fail "generate request failed at transport level"

echo "http=${HTTP_CODE} total_elapsed see timing above"
if [ "$HTTP_CODE" != "200" ]; then
  echo "--- response body (first 500 bytes) ---"
  head -c 500 /tmp/cc-resp.json; echo
  fail "generate returned HTTP ${HTTP_CODE} (auth or request-shape problem)"
fi

echo "--- response head (first 400 bytes) ---"
head -c 400 /tmp/cc-resp.json; echo
SIZE=$(wc -c < /tmp/cc-resp.json)
echo
echo "✅ CC connectivity OK — health probe passed, generate returned 200 with ${SIZE} bytes"
