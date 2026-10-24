#!/usr/bin/env bash
# mapa-check.sh [--stamp] [--mapa <arquivo>]
# Valida o mapa do repo por idade e impressão digital da árvore (git ls-files).
# Saída: mapa=ok|ausente|vencido-idade|vencido-arvore esqueleto=padrao|fora fingerprint=<hex>
# Exit 0 para ok, 1 para os demais. --stamp grava/atualiza a 1ª linha do mapa e sai 0.
# Executar na raiz do repo alvo.
. "$(dirname "$0")/../lib/common.sh"

AJUDA="uso: mapa-check.sh [--stamp] [--mapa <arquivo>], executado na raiz do repo alvo"
case "${1:-}" in -h|--help) usage "$AJUDA" ;; esac
need jq git
git rev-parse --show-toplevel >/dev/null 2>&1 || die "não é um repositório git"
stamp=0
mapa=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage "$AJUDA" ;;
    --stamp) stamp=1 ;;
    --mapa)
      [ $# -ge 2 ] || die "$AJUDA"
      mapa="$2"
      shift
      ;;
    *) die "$AJUDA" ;;
  esac
  shift
done
# --mapa relativo vale a partir do cwd de origem; resolver antes do cd para a raiz.
if [ -n "$mapa" ]; then
  case "$mapa" in /*|[A-Za-z]:*) ;; *) mapa="$PWD/$mapa" ;; esac
fi
cd "$(git rev-parse --show-toplevel)"

cfg="$ROOT/config.json"
kj=".claude/specs/karazhan.json"

max_dias="$(jqr '.mapa_max_dias' "$cfg")"
brain_dir=""
if [ -f "$kj" ]; then
  over="$(jqr '.config.mapa_max_dias // empty' "$kj")"
  [ -z "$over" ] || max_dias="$over"
  brain_dir="$(jqr '.brain_dir // empty' "$kj")"
fi

if [ -z "$mapa" ]; then
  if [ -n "$brain_dir" ]; then
    mapa="$brain_dir/repos/$(basename "$(git rev-parse --show-toplevel)").md"
  else
    mapa=".claude/specs/mapa.md"
  fi
fi

# Impressão digital: 12 primeiros hex do sha1 da lista de arquivos versionados, ignorando .claude/
# (o próprio mapa vive lá; senão o carimbo se invalidaria ao ser versionado).
if command -v sha1sum >/dev/null 2>&1; then
  hash=sha1sum
else
  hash="shasum"
fi
fp="$({ git ls-files | grep -v '^\.claude/' || true; } | $hash | cut -c1-12)"

if [ "$stamp" -eq 1 ]; then
  linha="<!-- karazhan fingerprint=$fp date=$(date +%Y-%m-%d) -->"
  mkdir -p "$(dirname "$mapa")"
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  if [ -f "$mapa" ]; then
    if head -n1 "$mapa" | grep -q '^<!-- karazhan '; then
      { echo "$linha"; tail -n +2 "$mapa"; } > "$tmp"
    else
      { echo "$linha"; cat "$mapa"; } > "$tmp"
    fi
  else
    { echo "$linha"; echo "# Mapa — $(basename "$(git rev-parse --show-toplevel)")"; } > "$tmp"
  fi
  cat "$tmp" > "$mapa"
  echo "carimbado: $mapa fingerprint=$fp"
  exit 0
fi

# Esqueleto padrão: plist, diretório de testes e ao menos um pacote (*/__init__.py) na raiz.
plist="$(jqr '.esqueleto.plist' "$cfg")"
testes="$(jqr '.esqueleto.tests' "$cfg")"
esq=fora
if compgen -G "$plist" >/dev/null && [ -d "$testes" ] && compgen -G "*/__init__.py" >/dev/null; then
  esq=padrao
fi

estado=ok
if [ ! -f "$mapa" ]; then
  estado=ausente
else
  cabec="$(head -n1 "$mapa" | tr -d '\r')"
  fp_mapa=""
  data_mapa=""
  case "$cabec" in
    "<!-- karazhan "*)
      fp_mapa="$(printf '%s\n' "$cabec" | sed -n 's/.*fingerprint=\([0-9a-f]*\).*/\1/p')"
      data_mapa="$(printf '%s\n' "$cabec" | sed -n 's/.*date=\([0-9-]*\).*/\1/p')"
      ;;
  esac
  if [ -n "$data_mapa" ] && idade="$(dias_desde "$data_mapa")" && [ "$idade" -gt "$max_dias" ]; then
    estado=vencido-idade
  elif [ "$fp_mapa" != "$fp" ]; then
    estado=vencido-arvore
  fi
fi

echo "mapa=$estado esqueleto=$esq fingerprint=$fp"
[ "$estado" = ok ]
