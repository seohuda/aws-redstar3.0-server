#!/usr/bin/env bash
set -euo pipefail

# Helper script to generate Red Star OS 3.0 Server license activation key from Machine ID
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 1 ]; then
  echo "사용법: $0 <기계코드>"
  echo "예시:   $0 RSS3123456789012"
  exit 1
fi

MACHINE_ID="$1"
# Remove hyphens and spaces if any
MACHINE_ID="${MACHINE_ID//-/}"
MACHINE_ID="${MACHINE_ID// /}"

if [ ! -f "${SCRIPT_DIR}/dprkeygen" ]; then
  if [ -f "/tmp/dprkeygen/dprkeygen" ]; then
    cp "/tmp/dprkeygen/dprkeygen" "${SCRIPT_DIR}/dprkeygen"
  fi
fi

if [ -f "${SCRIPT_DIR}/dprkeygen" ]; then
  "${SCRIPT_DIR}/dprkeygen" "${MACHINE_ID}"
else
  echo "ERROR: dprkeygen binary not found."
  exit 1
fi
