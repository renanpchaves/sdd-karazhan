#!/usr/bin/env bash
# Hook PreToolUse do Claude Code (Edit|Write|MultiEdit|NotebookEdit). Lê o JSON do stdin.
# Age só se existir .sdd-role na raiz do worktree do cwd. Bloquear = exit 2 com o motivo em stderr.
# Autocontido: usa ../lib/guard.sh e ../lib/tasks.sh a partir de si mesmo, sem depender do
# root= do .sdd-role. As regras ficam em lib/guard.sh, compartilhadas com o bash-guard.sh.
set -f  # os globs de paths nunca são expandidos pelo shell

lib="$(dirname "$0")/../lib"

if ! jq -n . >/dev/null 2>&1; then
  # Sem jq não dá para ler o JSON: bloqueia só se o cwd do processo estiver num worktree guardado.
  top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -f "$PWD/.sdd-role" ] || { [ -n "$top" ] && [ -f "$top/.sdd-role" ]; }; then
    echo "path-guard: jq ausente" >&2
    exit 2
  fi
  exit 0
fi

entrada="$(cat)"
campo_json() { printf '%s' "$entrada" | jq -r "$1 // empty" 2>/dev/null | tr -d '\r'; }

tool="$(campo_json .tool_name)"
case "$tool" in Edit|Write|MultiEdit|NotebookEdit) ;; *) exit 0 ;; esac

# Sem os helpers não dá para decidir: fail-closed onde houver .sdd-role.
falta=""
for f in tasks.sh guard.sh; do
  [ -f "$lib/$f" ] || { falta="lib/$f"; break; }
done
if [ -n "$falta" ]; then
  c="$(campo_json .cwd)"
  t="$(git -C "${c:-.}" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -f "$c/.sdd-role" ] || { [ -n "$t" ] && [ -f "$t/.sdd-role" ]; }; then
    echo "path-guard: $falta ausente" >&2
    exit 2
  fi
  exit 0
fi
. "$lib/guard.sh"
. "$lib/tasks.sh"

cwd="$(norm "$(campo_json .cwd)")"
[ -n "$cwd" ] || exit 0
top="$(guard_raiz "$cwd")"
role_file="$top/.sdd-role"
[ -f "$role_file" ] || exit 0

if [ "$(guard_role "$role_file")" = "rev" ]; then
  echo "Reviewer não edita arquivos" >&2
  exit 2
fi
wp="$(guard_campo "$role_file" wp)"

arq="$(campo_json .tool_input.file_path)"
# NotebookEdit traz o caminho em notebook_path.
[ -n "$arq" ] || arq="$(campo_json .tool_input.notebook_path)"
[ -n "$(norm "$arq")" ] || exit 0
rel="$(guard_rel "$(guard_abs "$cwd" "$arq")" "$top")"

rc=0
guard_regra_bld "$role_file" "$rel" || rc=$?
case "$rc" in
  0) exit 0 ;;
  1) echo "path-guard: .sdd-role é protegido" >&2 ;;
  2) echo "path-guard: $rel — tests/aceite é do Architect" >&2 ;;
  *) echo "fora dos paths da $wp: $rel" >&2 ;;
esac
exit 2
