#!/usr/bin/env bash
# Hook PreToolUse do Claude Code (Edit|Write|MultiEdit|NotebookEdit). Lê o JSON do stdin.
# Age só se existir .sdd-role na raiz do worktree do cwd. Bloquear = exit 2 com o motivo em stderr.
# Autocontido: usa ../lib/tasks.sh a partir de si mesmo, sem depender do root= do .sdd-role.

# canon <path>: colapsa "//", remove segmentos "." e "./" inicial, até estabilizar.
canon() {
  local p="$1" n
  while :; do
    n="$(printf '%s' "$p" | sed 's|//*|/|g; s|/\./|/|g; s|^\./||; s|/\.$||')"
    [ "$n" != "$p" ] || break
    p="$n"
  done
  printf '%s' "$p"
}

# norm <path>: barras normais, sem "/" final.
norm() {
  local p
  p="$(printf '%s' "$1" | tr '\134' '/')"
  while [ "${#p}" -gt 1 ] && [ "${p%/}" != "$p" ]; do p="${p%/}"; done
  printf '%s' "$p"
}

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

cwd="$(norm "$(campo_json .cwd)")"
[ -n "$cwd" ] || exit 0
# Raiz do worktree na mesma grafia do cwd: cwd sem o prefixo (subdiretório) devolvido pelo git.
prefixo="$(git -C "$cwd" rev-parse --show-prefix 2>/dev/null || true)"
prefixo="${prefixo%/}"
top="$cwd"
if [ -n "$prefixo" ] && [ "${cwd%"/$prefixo"}" != "$cwd" ]; then
  top="${cwd%"/$prefixo"}"
fi
role_file="$top/.sdd-role"
[ -f "$role_file" ] || exit 0

campo() { grep "^$1=" "$role_file" | head -n 1 | cut -d= -f2- | tr -d '\r'; }
role="$(campo role)"
# role=bld (ou o legado role=eng): qualquer role que não seja rev segue as regras do Builder.

if [ "$role" = "rev" ]; then
  echo "Reviewer não edita arquivos" >&2
  exit 2
fi

lib="$(dirname "$0")/../lib/tasks.sh"
if [ ! -f "$lib" ]; then
  echo "path-guard: lib/tasks.sh ausente" >&2
  exit 2
fi
. "$lib"
wp="$(campo wp)"
paths="$(campo paths)"

arq="$(campo_json .tool_input.file_path)"
# NotebookEdit traz o caminho em notebook_path.
[ -n "$arq" ] || arq="$(campo_json .tool_input.notebook_path)"
arq="$(norm "$arq")"
[ -n "$arq" ] || exit 0
# Relativo vale a partir do cwd.
case "$arq" in
  /*|[A-Za-z]:/*) ;;
  *) arq="$cwd/$arq" ;;
esac
arq="$(canon "$arq")"
rel="$arq"
# Remove o prefixo da raiz; letra de drive ignora maiúsculas (C:/ vs c:/).
case "$arq" in
  "$top"/*) rel="${arq#"$top"/}" ;;
  [A-Za-z]:/*)
    if [ "$(printf '%s' "${arq:0:${#top}}" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$top" | tr 'A-Z' 'a-z')" ] && [ "${arq:${#top}:1}" = "/" ]; then
      rel="${arq:$((${#top} + 1))}"
    fi
    ;;
esac
rel="$(canon "$rel")"

if [ "$rel" = ".sdd-role" ]; then
  echo "path-guard: .sdd-role é protegido" >&2
  exit 2
fi

# tests/aceite é do Architect: o Builder não escreve ali, mesmo que paths case.
aceite="$(campo aceite)"
if [ -n "$aceite" ] && glob_match "$(printf '%s' "$aceite" | tr 'A-Z' 'a-z')" "$(printf '%s' "$rel" | tr 'A-Z' 'a-z')"; then
  echo "path-guard: $rel — tests/aceite é do Architect" >&2
  exit 2
fi

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
