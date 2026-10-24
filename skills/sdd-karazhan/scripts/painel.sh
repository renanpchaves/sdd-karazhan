#!/usr/bin/env bash
# painel.sh NNN-slug [--publicar]
# Imprime o painel (markdown) da feature: tabela de WPs (de tasks.md), bloqueios abertos
# (.claude/specs/bloqueios.md) e equipe (.claude/specs/equipe.md).
# --publicar: com maestri no PATH escreve na nota "painel-NNN-slug" (cria se não existir);
# sem maestri grava em .claude/specs/painel.md.
# Exit 2 se current/NNN-slug/tasks.md não existe ou os argumentos são inválidos.
. "$(dirname "$0")/../lib/common.sh"
. "$ROOT/lib/tasks.sh"

AJUDA="uso: painel.sh NNN-slug [--publicar]"
case "${1:-}" in -h|--help) usage "$AJUDA" ;; esac
need git
slug=""
publicar=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage "$AJUDA" ;;
    --publicar) publicar=1; shift ;;
    -*) die "opção desconhecida: $1
$AJUDA" ;;
    *) [ -z "$slug" ] || die "$AJUDA"; slug="$1"; shift ;;
  esac
done
[ -n "$slug" ] || die "$AJUDA"

top="$(git rev-parse --show-toplevel 2>/dev/null)" || die "não é um repositório git"
cd "$top"

tasks=".claude/specs/current/$slug/tasks.md"
[ -f "$tasks" ] || die "tasks não encontrado: $tasks"

vazio() { [ -n "$1" ] && printf '%s' "$1" || printf '—'; }

# WPs ordenadas pelo número do id (WP-02 -> 2).
ids="$(wp_list "$tasks" | awk '{ n = $1; sub(/^WP-/, "", n); print n + 0, $1 }' | sort -n -k1,1 | cut -d' ' -f2)"

linhas=""
while IFS= read -r id; do
  [ -n "$id" ] || continue
  lane="$(wp_field "$tasks" "$id" Lane 2>/dev/null)" || lane=""
  dono="$(wp_field "$tasks" "$id" Dono 2>/dev/null)" || dono=""
  possui="$(wp_field "$tasks" "$id" Possui 2>/dev/null)" || possui=""
  linhas="$linhas| $id | $(vazio "$lane") | $(vazio "$dono") | $(vazio "$possui") |
"
done <<EOT
$ids
EOT

# Bloqueios abertos: blocos "## ..." sem linha "Resolução:" (com ou sem "- ").
bloqueios=""
if [ -f .claude/specs/bloqueios.md ]; then
  bloqueios="$(tr -d '\r' < .claude/specs/bloqueios.md | awk '
    function fecha() { if (cab != "" && !res) print "- " cab }
    /^## / { fecha(); cab = substr($0, 4); res = 0; next }
    /^(- )?Resolução:/ { res = 1 }
    END { fecha() }')"
fi

# Equipe: linhas de tabela depois do cabeçalho e do separador.
equipe=""
if [ -f .claude/specs/equipe.md ]; then
  equipe="$(tr -d '\r' < .claude/specs/equipe.md | grep '^|' | awk 'NR > 2' || true)"
fi

painel="# Painel — $slug

| WP | Lane | Dono | Possui |
|---|---|---|---|
$linhas
## Bloqueios abertos

${bloqueios:-nenhum}

## Equipe

${equipe:-sem equipe registrada}"

printf '%s\n' "$painel"

if [ "$publicar" -eq 1 ]; then
  if command -v maestri >/dev/null 2>&1; then
    nota="painel-$slug"
    if maestri list 2>/dev/null | grep -qF "$nota"; then
      maestri note write "$nota" "$painel"
    else
      maestri note create --name "$nota" "$painel"
    fi
  else
    printf '%s\n' "$painel" > .claude/specs/painel.md
    echo "publicado em .claude/specs/painel.md"
  fi
fi
