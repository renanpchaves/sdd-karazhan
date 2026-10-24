#!/usr/bin/env bash
# Roda cada tests/test_*.sh a partir da raiz do plugin.
set -u
cd "$(dirname "$0")/.."
total=0
falhas=0
for t in tests/test_*.sh; do
  [ -e "$t" ] || continue
  nome="$(basename "$t" .sh)"
  total=$((total + 1))
  if (bash "$t"); then
    echo "PASS $nome"
  else
    echo "FAIL $nome"
    falhas=$((falhas + 1))
  fi
done
echo "$((total - falhas))/$total passaram"
[ "$falhas" -eq 0 ]
