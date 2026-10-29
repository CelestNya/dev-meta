#!/usr/bin/env bash
# Probe CommandCode API reachability and auth from a GitHub Actions runner.
#
# Stage 1  GET  {base}/health          — informational; any HTTP response
#                                        proves DNS + TLS + egress reachability.
# Stage 2  POST {base}/alpha/generate  — with the full official CLI header set
#                                        (CC inspects these and rejects
#                                        non-CLI-looking clients) and a minimal
#                                        valid body.
#
# The CLI version is resolved live from the npm registry, mirroring ccproxy's
# cli_version.rs behaviour, so the probe keeps working as CC bumps minVersion.
#
# The API key is read from $CMD_API_KEY and never printed.
set -u

BASE="${CC_API_BASE:-https://api.commandcode.ai}"
KEY="${CMD_API_KEY:-}"
FALLBACK_VERSION="${CC_CLI_VERSION:-1.54.1}"

fail() { echo "::error::$1"; exit 1; }

[ -n "$KEY" ] || fail "CMD_API_KEY is empty — did you set the repo secret?"

# --- resolve the current CC CLI version from npm (2 attempts, like ccproxy) ---
CC_VERSION=""
for _ in 1 2; do
  CC_VERSION=$(curl -sS --max-time 10 "https://registry.npmjs.org/command-code/latest" \
    | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("version",""))
except Exception: pass' 2>/dev/null) && [ -n "$CC_VERSION" ] && break
  CC_VERSION=""
  sleep 2
done
CC_VERSION="${CC_VERSION:-$FALLBACK_VERSION}"
echo "CLI version: ${CC_VERSION} (npm latest or fallback)"

THREAD_ID=$(python3 -c 'import uuid;print(uuid.uuid4())')
TRACE_ID=$(python3 -c 'import uuid;print(uuid.uuid4().hex)')
SPAN_ID=$(python3 -c 'import uuid;print(uuid.uuid4().hex[:16])')
TRACEPARENT="00-${TRACE_ID}-${SPAN_ID}-01"
SLUG="ghactions-probe"

echo
echo "=== Stage 1: GET ${BASE}/health (informational) ==="
curl -sS --max-time 15 -o /dev/null -w 'http=%{http_code} dns=%{time_namelookup}s connect=%{time_connect}s tls=%{time_appconnect}s total=%{time_total}s\n' \
  "${BASE}/health" \
  || echo "WARNING: health path unreachable (will rely on stage 2 for a verdict)"

echo
echo "=== Stage 2: POST ${BASE}/alpha/generate (full CLI headers) ==="
BODY=$(cat <<EOF
{
  "config": {
    "workingDir": "/home/runner/dev-meta",
    "date": "$(date -u +%F)",
    "environment": "linux-x64, Node.js v24.16.0",
    "structure": [],
    "isGitRepo": true,
    "currentBranch": "main",
    "mainBranch": "main",
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
  "threadId": "${THREAD_ID}"
}
EOF
)

HTTP_CODE=$(curl -sS --max-time 90 -o /tmp/cc-resp.json -w '%{http_code}' \
  -X POST "${BASE}/alpha/generate" \
  -H "Accept: application/json, */*" \
  -H "Accept-Language: en-US,en;q=0.9" \
  -H "User-Agent: commandcode-cli/${CC_VERSION} Node.js/v24.16.0" \
  -H "Authorization: Bearer ${KEY}" \
  -H "x-cli-environment: production" \
  -H "x-command-code-version: ${CC_VERSION}" \
  -H "x-session-id: ${THREAD_ID}" \
  -H "x-co-flag: false" \
  -H "x-taste-learning: false" \
  -H "x-project-slug: ${SLUG}" \
  -H "traceparent: ${TRACEPARENT}" \
  -H "Content-Type: application/json" \
  --data "$BODY") || fail "generate request failed at transport level"

echo "http=${HTTP_CODE}"
if [ "$HTTP_CODE" != "200" ]; then
  echo "--- response body (first 500 bytes) ---"
  head -c 500 /tmp/cc-resp.json; echo
  fail "generate returned HTTP ${HTTP_CODE}"
fi

echo "--- response head (first 400 bytes) ---"
head -c 400 /tmp/cc-resp.json; echo
SIZE=$(wc -c < /tmp/cc-resp.json)
echo
echo "OK: CC connectivity verified — generate returned 200 with ${SIZE} bytes"
