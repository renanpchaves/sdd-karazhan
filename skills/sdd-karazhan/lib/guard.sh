#!/usr/bin/env bash
# Funções comuns dos hooks de guarda (path-guard.sh e bash-guard.sh). Uso: . "<skill>/lib/guard.sh"
# Pode ser carregado sozinho: não executa nada ao carregar e não depende de common.sh.
# guard_regra_bld usa glob_match de lib/tasks.sh, que o hook carrega antes. Roda em bash 3.2.

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

# guard_raiz <cwd normalizado>: raiz do worktree na mesma grafia do cwd
# (cwd sem o prefixo de subdiretório devolvido pelo git).
guard_raiz() {
  local cwd="$1" prefixo top
  prefixo="$(git -C "$cwd" rev-parse --show-prefix 2>/dev/null || true)"
  prefixo="${prefixo%/}"
  top="$cwd"
  if [ -n "$prefixo" ] && [ "${cwd%"/$prefixo"}" != "$cwd" ]; then
    top="${cwd%"/$prefixo"}"
  fi
  printf '%s' "$top"
}

# guard_sem_jq <nome>: sem jq não dá para ler o JSON. Bloqueia (exit 2) só se o cwd do
# processo estiver num worktree guardado; senão sai 0. Sempre encerra o hook.
guard_sem_jq() {
  local top
  top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -f "$PWD/.sdd-role" ] || { [ -n "$top" ] && [ -f "$top/.sdd-role" ]; }; then
    echo "$1: jq ausente" >&2
    exit 2
  fi
  exit 0
}

# guard_campo <role_file> <chave>: valor da primeira linha "chave=", sem CR.
guard_campo() { grep "^$2=" "$1" | head -n 1 | cut -d= -f2- | tr -d '\r'; }

# guard_role <role_file>: role sem espaços/CR, em minúsculas. Qualquer role que não seja
# rev (bld ou o legado eng) segue as regras do Builder.
guard_role() { guard_campo "$1" role | tr -d '[:space:]' | tr 'A-Z' 'a-z'; }

# guard_abs <cwd> <alvo>: alvo normalizado, absoluto (relativo vale a partir do cwd) e canônico.
guard_abs() {
  local a
  a="$(norm "$2")"
  case "$a" in
    /*|[A-Za-z]:/*) ;;
    *) a="$1/$a" ;;
  esac
  canon "$a"
}

# guard_rel <abs> <top>: caminho relativo à raiz; fora dela, devolve o próprio abs.
# Letra de drive ignora maiúsculas (C:/ vs c:/).
guard_rel() {
  local arq="$1" top="$2" rel="$1"
  case "$arq" in
    "$top"/*) rel="${arq#"$top"/}" ;;
    [A-Za-z]:/*)
      if [ "$(printf '%s' "${arq:0:${#top}}" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$top" | tr 'A-Z' 'a-z')" ] && [ "${arq:${#top}:1}" = "/" ]; then
        rel="${arq:$((${#top} + 1))}"
      fi
      ;;
  esac
  canon "$rel"
}

# guard_dentro <rel>: 0 se rel está dentro do worktree (relativo e sem "..").
guard_dentro() {
  case "$1" in
    /*|[A-Za-z]:/*|..|../*|*/..|*/../*) return 1 ;;
  esac
  return 0
}

# guard_regra_bld <role_file> <rel>: regras do Builder, na ordem do path-guard.
# Retorna 0 (permitido), 1 (.sdd-role), 2 (tests/aceite) ou 3 (fora dos paths/worktree).
guard_regra_bld() {
  local rf="$1" rel="$2" aceite paths globs g
  [ "$rel" != ".sdd-role" ] || return 1
  # tests/aceite é do Architect: o Builder não escreve ali, mesmo que paths case.
  aceite="$(guard_campo "$rf" aceite)"
  if [ -n "$aceite" ] && glob_match "$(printf '%s' "$aceite" | tr 'A-Z' 'a-z')" "$(printf '%s' "$rel" | tr 'A-Z' 'a-z')"; then
    return 2
  fi
  # Absoluto restante (fora do worktree) ou com ".." não é confiável.
  guard_dentro "$rel" || return 3
  paths="$(guard_campo "$rf" paths)"
  globs="$(printf '%s\n' "$paths" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' || true)"
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    if glob_match "$g" "$rel"; then return 0; fi
  done <<EOT
$globs
EOT
  return 3
}
