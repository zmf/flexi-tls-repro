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

echo "[repro] Publishing Fastly Service..."
cd "${ROOT_DIR}"
npx fastly compute publish --service-id=$SID --token=$TOKEN --debug-mode > "${LOG_FILE}" 2>&1 &
SERVER_PID=$!

# Wait for service to deploy, start with 60s
sleep 60

cases=(
  "strict-valid-google"
  "flexi-valid-google"
  "strict-expired-badssl"
  "flexi-expired-badssl"
)

for c in "${cases[@]}"; do
  echo
  echo "=== CASE: ${c} ${DOMAIN} ==="
  before_lines=$(wc -l < "${LOG_FILE}" 2>/dev/null || echo 0)
  curl -sS "https://${DOMAIN}/case/${c}" | tee "/tmp/${c}.json"
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
