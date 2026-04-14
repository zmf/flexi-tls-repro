#!/bin/sh
set -e

if [ "$MODE" = "online" ]; then
  exec ./run-repro-online.sh "$TOKEN" "$SID" "$DOMAIN"
else
  exec ./run-repro.sh
fi