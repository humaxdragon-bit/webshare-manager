#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/checks
swiftc -parse-as-library Sources/Webshare/API.swift Sources/Webshare/UploadedFile.swift Sources/Webshare/PublicSearch.swift Sources/Webshare/Transfers.swift Sources/Webshare/DownloadOperation.swift Tests/WebshareTests/WebshareTests.swift -o .build/checks/WebshareChecks
PORT_FILE="$(mktemp)"
python3 Tests/download_fixture.py "$PORT_FILE" &
FIXTURE_PID=$!
trap 'kill "$FIXTURE_PID" 2>/dev/null || true; rm -f "$PORT_FILE"' EXIT
for attempt in {1..50}; do
    [[ -s "$PORT_FILE" ]] && break
    sleep 0.1
done
WEBSHARE_TEST_ENDPOINT="http://127.0.0.1:$(cat "$PORT_FILE")/sample" .build/checks/WebshareChecks
