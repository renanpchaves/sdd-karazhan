#!/usr/bin/env bash
# Funções comuns dos scripts do sdd-karazhan. Uso: . "$(dirname "$0")/lib/common.sh"
set -eu

# Diretório da skill (pai de lib/), independente do cwd.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT

# die <msg> [código=2]: mensagem em stderr e sai.
die() {
  echo "${1:-erro}" >&2
  exit "${2:-2}"
}

# usage <texto>: imprime o texto e sai 0. Chamar quando o argumento for --help:
#   case "${1:-}" in -h|--help) usage "uso: x.sh <arg>" ;; esac
usage() {
  echo "$1"
  exit 0
}

# need <cmd...>: sai 2 nomeando o primeiro comando ausente.
need() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "comando obrigatório ausente: $c" 2
  done
}

# jqr <args>: jq -r sem CR (no Windows o jq emite CRLF). Usar para ler strings de JSON.
jqr() { jq -r "$@" | tr -d '\r'; }
