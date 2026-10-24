#!/usr/bin/env bash
# pick-name.sh <prefixo> [--em-uso <arquivo>]...
# Sorteia um nome livre do pool <prefixo> do roster.json e imprime o personagem com inicial maiúscula (Grom).
# Nomes em uso: saída de `maestri list` (se existir) + cada --em-uso (padrão: .claude/specs/equipe.md).
# Um nome está em uso se aparece como palavra inteira, sem diferenciar maiúsculas; o formato antigo
# (prefixo-nome, da v0.1.0) também conta. SDD_SEED definido => primeiro nome livre na ordem do roster (determinístico).
. "$(dirname "$0")/../lib/common.sh"

AJUDA="uso: pick-name.sh <orch|arch|rec|eng|rev|git> [--em-uso <arquivo>]..."
case "${1:-}" in -h|--help) usage "$AJUDA" ;; esac

need jq
prefixo="${1:-}"
[ -n "$prefixo" ] || die "$AJUDA" 2
shift
case "$prefixo" in
  orch|arch|rec|eng|rev|git) ;;
  *) die "prefixo inválido: $prefixo (use orch|arch|rec|eng|rev|git)" 2 ;;
esac

fontes=()
while [ $# -gt 0 ]; do
  case "$1" in
    --em-uso) [ $# -ge 2 ] || die "--em-uso exige um arquivo" 2; fontes+=("$2"); shift 2 ;;
    *) die "argumento desconhecido: $1" 2 ;;
  esac
done
[ ${#fontes[@]} -gt 0 ] || fontes=(".claude/specs/equipe.md")

em_uso=""
if command -v maestri >/dev/null 2>&1; then
  em_uso="$(maestri list 2>/dev/null | palavras)"
fi
for f in "${fontes[@]}"; do
  [ -f "$f" ] || [ -c "$f" ] || continue
  em_uso="$em_uso"$'\n'"$(palavras < "$f")"
done

livres=()
while IFS= read -r nome; do
  [ -n "$nome" ] || continue
  printf '%s\n' "$em_uso" | grep -qxF "$nome" || livres+=("$nome")
done < <(jqr ".$prefixo[] | ascii_downcase" "$ROOT/roster.json")

[ ${#livres[@]} -gt 0 ] || die "pool $prefixo esgotado; amplie roster.json" 1

if [ -n "${SDD_SEED:-}" ]; then
  idx=0
else
  idx=$((RANDOM % ${#livres[@]}))
fi
printf '%s\n' "${livres[$idx]}" | capitalizar
