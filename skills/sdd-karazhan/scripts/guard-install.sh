#!/usr/bin/env bash
# guard-install.sh <worktree> <eng|rev> <WP-NN> <paths-csv>
# Grava <worktree>/.sdd-role, instala o hook pre-commit e esconde .sdd-role no info/exclude.
# O hook vai para o hooks/ comum do repo (worktrees compartilham): instalar uma vez vale para
# todos, e é no-op onde não há .sdd-role. Exit 2 se core.hooksPath já estiver definido.
. "$(dirname "$0")/../lib/common.sh"

AJUDA="uso: guard-install.sh <worktree> <eng|rev> <WP-NN> <paths-csv>"
case "${1:-}" in
  -h|--help) usage "$AJUDA" ;;
esac
need git
[ "$#" -eq 4 ] || die "$AJUDA"
worktree="$1"
role="$2"
wp="$3"
paths="$4"
case "$role" in eng|rev) ;; *) die "role inválido: $role (use eng ou rev)" ;; esac
[ -d "$worktree" ] || die "worktree não encontrado: $worktree"
worktree="$(cd "$worktree" && pwd)"
top="$(git -C "$worktree" rev-parse --show-toplevel 2>/dev/null)" || die "não é um repositório git: $worktree"
worktree="$top"

fonte="$ROOT/hooks/pre-commit"
[ -f "$fonte" ] || die "hook não encontrado: $fonte"

hp="$(git -C "$worktree" config --get core.hooksPath || true)"
[ -z "$hp" ] || die "core.hooksPath já definido em $hp; encadeie manualmente chamando $fonte"

# git-path_abs <path>: --git-path pode devolver caminho relativo ao worktree.
git_path() {
  local p
  p="$(git -C "$worktree" rev-parse --git-path "$1")"
  case "$p" in
    /*|?:*) printf '%s\n' "$p" ;;
    *) printf '%s/%s\n' "$worktree" "$p" ;;
  esac
}

hooks_dir="$(git_path hooks)"
destino="$hooks_dir/pre-commit"
if [ -e "$destino" ] && ! grep -q "^# sdd-karazhan pre-commit" "$destino"; then
  die "já existe um pre-commit que não é do sdd-karazhan em $destino; encadeie manualmente chamando $fonte"
fi
mkdir -p "$hooks_dir"
cp "$fonte" "$destino"
chmod +x "$destino"

printf 'role=%s\nwp=%s\npaths=%s\nroot=%s\n' "$role" "$wp" "$paths" "$ROOT" > "$worktree/.sdd-role"

exclude="$(git_path info/exclude)"
mkdir -p "$(dirname "$exclude")"
grep -qxF '.sdd-role' "$exclude" 2>/dev/null || echo '.sdd-role' >> "$exclude"

echo "guarda instalada: $role $wp em $worktree"
