#!/usr/bin/env bash
# Hook PreToolUse do Claude Code (Edit|Write|MultiEdit). Lê o JSON do stdin.
# Só age se existir <cwd>/.sdd-role. Bloquear = exit 2 com o motivo em stderr.
if ! command -v jq >/dev/null 2>&1; then
  echo "path-guard: jq ausente" >&2
  exit 0
fi
entrada="$(cat)"
campo_json() { printf '%s' "$entrada" | jq -r "$1 // empty" 2>/dev/null | tr -d '\r'; }

tool="$(campo_json .tool_name)"
case "$tool" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

# norm <path>: barras normais, sem "/" final.
norm() {
  local p
  p="$(printf '%s' "$1" | tr '\134' '/')"
  while [ "${#p}" -gt 1 ] && [ "${p%/}" != "$p" ]; do p="${p%/}"; done
  printf '%s' "$p"
}
cwd="$(norm "$(campo_json .cwd)")"
[ -n "$cwd" ] && [ -f "$cwd/.sdd-role" ] || exit 0
role_file="$cwd/.sdd-role"

campo() { grep "^$1=" "$role_file" | head -n 1 | cut -d= -f2- | tr -d '\r'; }
role="$(campo role)"

if [ "$role" = "rev" ]; then
  echo "Reviewer não edita arquivos" >&2
  exit 2
fi

wp="$(campo wp)"
paths="$(campo paths)"
root="$(campo root)"
if [ ! -f "$root/lib/tasks.sh" ]; then
  echo "path-guard: lib/tasks.sh não encontrado em root=$root (.sdd-role)" >&2
  exit 0
fi
. "$root/lib/tasks.sh"

arq="$(norm "$(campo_json .tool_input.file_path)")"
[ -n "$arq" ] || exit 0
rel="$arq"
# Remove o prefixo do cwd; letra de drive ignora maiúsculas (C:/ vs c:/).
case "$arq" in
  "$cwd"/*) rel="${arq#"$cwd"/}" ;;
  [A-Za-z]:/*)
    if [ "$(printf '%s' "${arq:0:${#cwd}}" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$cwd" | tr 'A-Z' 'a-z')" ] && [ "${arq:${#cwd}:1}" = "/" ]; then
      rel="${arq:$((${#cwd} + 1))}"
    fi
    ;;
esac

# Absoluto restante (fora do worktree) ou com ".." não é confiável: bloqueia.
permitido=1
case "$rel" in
  /*|[A-Za-z]:/*|..|../*|*/..|*/../*) ;;
  *)
    globs="$(printf '%s\n' "$paths" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' || true)"
    while IFS= read -r g; do
      [ -n "$g" ] || continue
      if glob_match "$g" "$rel"; then permitido=0; break; fi
    done <<EOT
$globs
EOT
    ;;
esac
if [ "$permitido" -ne 0 ]; then
  echo "fora dos paths da $wp: $rel" >&2
  exit 2
fi
exit 0
