#!/usr/bin/env bash
# donos.sh NNN-slug
# Confere que cada arquivo da seção "## Dentro" do spec tem exatamente uma WP dona (campo Possui).
# Saída: "orfaos: N" + um path por linha; "duplicados: N" + "path (WP-01, WP-02)" por linha.
# Exit 0 se ambos zero, 1 caso contrário, 2 se spec/tasks ausentes ou uma WP sem Possui.
# Executar na raiz do repo alvo.
. "$(dirname "$0")/../lib/common.sh"
. "$ROOT/lib/tasks.sh"
need git
git rev-parse --show-toplevel >/dev/null 2>&1 || die "não é um repositório git"

AJUDA="uso: donos.sh NNN-slug, executado na raiz do repo alvo"
case "${1:-}" in
  -h|--help) usage "$AJUDA" ;;
  "") die "$AJUDA" ;;
esac
slug="$1"
dir=".claude/specs/current/$slug"
spec="$dir/spec.md"
tasks="$dir/tasks.md"
[ -f "$spec" ] || die "spec não encontrado: $spec"
[ -f "$tasks" ] || die "tasks não encontrado: $tasks"

# Seção "## Dentro": itens "- path" até o próximo "## ", sem comentários HTML.
dentro="$(tasks_sem_comentarios "$spec" | awk '
  /^## / { em = ($0 ~ /^## Dentro[ \t]*$/); next }
  em && /^- / {
    v = substr($0, 3)
    gsub(/^[ \t`]+|[ \t`]+$/, "", v)
    if (v != "") print v
  }')"

# WPs e seus globs (arrays paralelos; bash 3.2).
ids=()
globs=()
while IFS= read -r wp; do
  [ -n "$wp" ] || continue
  g="$(wp_paths "$tasks" "$wp")" || exit 2
  ids+=("$wp")
  globs+=("$g")
done <<EOT
$(wp_list "$tasks")
EOT
[ "${#ids[@]}" -gt 0 ] || die "nenhuma WP em $tasks"

orfaos=""
n_orf=0
dups=""
n_dup=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  dentro_ok=0
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    if glob_match "$e" "$f"; then dentro_ok=1; break; fi
  done <<EOT
$dentro
EOT
  [ "$dentro_ok" -eq 1 ] || continue
  donos=""
  n=0
  i=0
  while [ "$i" -lt "${#ids[@]}" ]; do
    while IFS= read -r g; do
      if glob_match "$g" "$f"; then
        donos="${donos:+$donos, }${ids[$i]}"
        n=$((n + 1))
        break
      fi
    done <<EOT
${globs[$i]}
EOT
    i=$((i + 1))
  done
  if [ "$n" -eq 0 ]; then
    orfaos="$orfaos  $f
"
    n_orf=$((n_orf + 1))
  elif [ "$n" -gt 1 ]; then
    dups="$dups  $f ($donos)
"
    n_dup=$((n_dup + 1))
  fi
done <<EOT
$(git ls-files)
EOT

echo "orfaos: $n_orf"
printf '%s' "$orfaos"
echo "duplicados: $n_dup"
printf '%s' "$dups"
[ "$n_orf" -eq 0 ] && [ "$n_dup" -eq 0 ]
