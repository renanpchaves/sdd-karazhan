#!/usr/bin/env bash
# donos.sh NNN-slug
# Confere que cada arquivo da seção "## Dentro" do spec tem exatamente uma WP dona (campo Possui).
# Saída: "orfaos: N" + um path por linha; "duplicados: N" + "path (WP-01, WP-02)" por linha.
# Exit 0 se ambos zero, 1 caso contrário, 2 se spec/tasks ausentes ou uma WP sem Possui.
# Executar na raiz do repo alvo.
. "$(dirname "$0")/../lib/common.sh"
. "$ROOT/lib/tasks.sh"

AJUDA="uso: donos.sh NNN-slug, executado na raiz do repo alvo"
case "${1:-}" in
  -h|--help) usage "$AJUDA" ;;
  "") die "$AJUDA" ;;
esac
need git
git rev-parse --show-toplevel >/dev/null 2>&1 || die "não é um repositório git"
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

[ -n "$dentro" ] || die "spec sem itens em ## Dentro: $spec"

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

# Candidatos: arquivos versionados que casam com cada entrada de Dentro. Entrada sem
# metacaractere que não existe no git é arquivo planejado (entra na checagem e aparece
# como órfão se nenhuma WP o possuir); com metacaractere e sem casamento, só avisa.
todos="$(git -c core.quotepath=off ls-files)"
cand=""
while IFS= read -r e; do
  [ -n "$e" ] || continue
  e="${e#./}"
  e="${e#/}"
  case "$e" in */) e="$e**" ;; esac
  achou=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if glob_match "$e" "$f"; then
      cand="$cand$f
"
      achou=1
    fi
  done <<EOT
$todos
EOT
  if [ "$achou" -eq 0 ]; then
    case "$e" in
      *[*?]*) echo "aviso: nenhum arquivo casa $e" >&2 ;;
      *) cand="$cand$e
" ;;
    esac
  fi
done <<EOT
$dentro
EOT
cand="$(printf '%s' "$cand" | sort -u)"

orfaos=""
n_orf=0
dups=""
n_dup=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
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
$cand
EOT

echo "orfaos: $n_orf"
printf '%s' "$orfaos"
echo "duplicados: $n_dup"
printf '%s' "$dups"
[ "$n_orf" -eq 0 ] && [ "$n_dup" -eq 0 ]
