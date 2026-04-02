#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${ROOT_DIR}/repro.log"
SERVER_PID=""

cleanup() {
  if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
    kill "${SERVER_PID}" || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "[repro] Starting fastly compute serve..."
cd "${ROOT_DIR}"
npx fastly compute serve --debug-mode > "${LOG_FILE}" 2>&1 &
SERVER_PID=$!

# Wait for server port with guard: fail fast if process exits.
for _ in {1..120}; do
  if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
    echo "[repro] fastly compute serve exited before opening port."
    echo "[repro] Last log lines:"
    tail -n 80 "${LOG_FILE}" || true
    exit 1
  fi
  if curl -sS "http://127.0.0.1:7676/" >/dev/null 2>&1; then
    echo "[repro] Local server is up on :7676"
    break
  fi
  sleep 0.5
done

if ! curl -sS "http://127.0.0.1:7676/" >/dev/null 2>&1; then
  echo "[repro] Timed out waiting for server port 7676."
  echo "[repro] Last log lines:"
  tail -n 80 "${LOG_FILE}" || true
  exit 1
fi

cases=(
  "strict-valid-google"
  "flexi-valid-google"
  "strict-expired-badssl"
  "flexi-expired-badssl"
)

for c in "${cases[@]}"; do
  echo
  echo "=== CASE: ${c} ==="
  before_lines=$(wc -l < "${LOG_FILE}" 2>/dev/null || echo 0)
  curl -sS "http://127.0.0.1:7676/case/${c}" | tee "/tmp/${c}.json"
  echo
  after_lines=$(wc -l < "${LOG_FILE}" 2>/dev/null || echo 0)
  if [[ "${after_lines}" -gt "${before_lines}" ]]; then
    case_slice=$(sed -n "$((before_lines + 1)),${after_lines}p" "${LOG_FILE}")
    case_hyper_error=$(printf "%s\n" "${case_slice}" | grep -E "Error: hyper::Error" | tail -n 1 || true)
    case_fallback_error=$(printf "%s\n" "${case_slice}" | grep -E "Case .* failed|InvalidCertificate" | tail -n 1 || true)
    if [[ -n "${case_hyper_error}" ]]; then
      echo "CASE_LOG_ERROR:${c}:${case_hyper_error}"
    elif [[ -n "${case_fallback_error}" ]]; then
      echo "CASE_LOG_ERROR:${c}:${case_fallback_error}"
    else
      echo "CASE_LOG_ERROR:${c}:<none>"
    fi
  else
    echo "CASE_LOG_ERROR:${c}:<none>"
  fi
done

echo
echo "[repro] Relevant runtime errors from ${LOG_FILE}:"
grep -E "hyper::Error|InvalidCertificate|Case .* failed" "${LOG_FILE}" || true

echo
echo "[repro] Done. Full server log: ${LOG_FILE}"
