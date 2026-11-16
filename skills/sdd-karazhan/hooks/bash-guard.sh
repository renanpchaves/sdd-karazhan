#!/usr/bin/env bash
# Hook PreToolUse do Claude Code (Bash). Lê o JSON do stdin: {tool_name, cwd, tool_input:{command}}.
# Age só se existir .sdd-role na raiz do worktree do cwd. Acha, por heurística (não é um parser
# de shell), os alvos de escrita do comando e aplica as regras do path-guard.sh (lib/guard.sh).
# Bloquear = exit 2 com o motivo em stderr. Roda em bash 3.2 (o /bin/bash do macOS).
# Limite: escrita feita por dentro de um programa (python, node...) não é detectável;
# alvo em variável, eval, here-doc complexo e cd antes da escrita passam.
set -f  # nada de expansão de glob: alvos e paths são texto

lib="$(dirname "$0")/../lib"

if ! jq -n . >/dev/null 2>&1; then
  # Sem jq não dá para ler o JSON: bloqueia só se o cwd do processo estiver num worktree guardado.
  top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -f "$PWD/.sdd-role" ] || { [ -n "$top" ] && [ -f "$top/.sdd-role" ]; }; then
    echo "bash-guard: jq ausente" >&2
    exit 2
  fi
  exit 0
fi

entrada="$(cat)"
campo_json() { printf '%s' "$entrada" | jq -r "$1 // empty" 2>/dev/null | tr -d '\r'; }

[ "$(campo_json .tool_name)" = "Bash" ] || exit 0

# Sem os helpers não dá para decidir: fail-closed onde houver .sdd-role.
falta=""
for f in tasks.sh guard.sh; do
  [ -f "$lib/$f" ] || { falta="lib/$f"; break; }
done
if [ -n "$falta" ]; then
  c="$(campo_json .cwd)"
  t="$(git -C "${c:-.}" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -f "$c/.sdd-role" ] || { [ -n "$t" ] && [ -f "$t/.sdd-role" ]; }; then
    echo "bash-guard: $falta ausente" >&2
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
role="$(guard_role "$role_file")"
wp="$(guard_campo "$role_file" wp)"
comando_bash="$(campo_json .tool_input.command)"
[ -n "$comando_bash" ] || exit 0

# Tokenizador: lê o comando de ENVIRON["GUARD_CMD"] e imprime uma linha por token:
#   W<tab>palavra (aspas resolvidas)  R<tab>alvo de redirecionamento de saída  S (separador)
# Respeita aspas, \, $( ), ${ }, ` `, comentários e here-docs. Ignora >&N, N>&M e entradas (<).
read -r -d '' TOK <<'AWK'
function flush() {
  if (inw) {
    gsub(/\n/, ";", buf)
    if (pend == 1) printf "R\t%s\n", buf
    else if (pend == 3) { nh++; hd[nh] = buf; hdt[nh] = hdtab }
    else if (pend != 2) printf "W\t%s\n", buf
    pend = 0
  }
  buf = ""; inw = 0; bq = 0
}
function sep() { flush(); pend = 0; print "S" }
function heredocs(   k, j, linha) {
  for (k = 1; k <= nh; k++) {
    while (i <= n) {
      j = index(substr(s, i), "\n")
      if (j == 0) { linha = substr(s, i); i = n + 1 } else { linha = substr(s, i, j - 1); i += j }
      if (hdt[k]) sub(/^\t+/, "", linha)
      if (linha == hd[k]) break
    }
  }
  nh = 0
}
BEGIN {
  s = ENVIRON["GUARD_CMD"]; n = length(s); i = 1
  buf = ""; inw = 0; bq = 0; pend = 0; nh = 0
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "\\") {
      d = substr(s, i + 1, 1)
      if (d == "\n") { i += 2; continue }
      buf = buf d; inw = 1; bq = 1; i += 2; continue
    }
    if (c == "'") {
      j = index(substr(s, i + 1), "'")
      if (j == 0) { buf = buf substr(s, i + 1); inw = 1; bq = 1; i = n + 1; continue }
      buf = buf substr(s, i + 1, j - 1); inw = 1; bq = 1; i += j + 1; continue
    }
    if (c == "\"") {
      i++
      while (i <= n) {
        d = substr(s, i, 1)
        if (d == "\\") {
          e = substr(s, i + 1, 1)
          if (e == "\"" || e == "\\" || e == "$" || e == "`") { buf = buf e; i += 2; continue }
        }
        if (d == "\"") break
        buf = buf d; i++
      }
      i++; inw = 1; bq = 1; continue
    }
    if (c == "`") {
      j = index(substr(s, i + 1), "`")
      if (j == 0) j = n - i
      buf = buf substr(s, i, j + 1); inw = 1; i += j + 1; continue
    }
    if (c == "$" && (substr(s, i + 1, 1) == "(" || substr(s, i + 1, 1) == "{")) {
      o = substr(s, i + 1, 1); cl = (o == "(") ? ")" : "}"
      dep = 0; j = i + 1
      while (j <= n) {
        d = substr(s, j, 1)
        if (d == o) dep++
        else if (d == cl) { dep--; if (dep == 0) break }
        j++
      }
      buf = buf substr(s, i, j - i + 1); inw = 1; i = j + 1; continue
    }
    if (c == "#" && !inw) {
      j = index(substr(s, i), "\n")
      if (j == 0) i = n + 1; else i += j - 1
      continue
    }
    if (c == " " || c == "\t") { flush(); i++; continue }
    if (c == "\n") { sep(); i++; if (nh > 0) heredocs(); continue }
    if (c == ">") {
      if (inw && !bq && buf ~ /^[0-9]+$/) { buf = ""; inw = 0 } else flush()
      i++; d = substr(s, i, 1)
      if (d == ">" || d == "|") { i++; pend = 1; continue }
      if (d == "&") {
        i++
        if (substr(s, i, 1) ~ /[0-9-]/) { while (i <= n && substr(s, i, 1) ~ /[0-9-]/) i++; continue }
        pend = 1; continue
      }
      if (d == "(") continue
      pend = 1; continue
    }
    if (c == "<") {
      if (inw && !bq && buf ~ /^[0-9]+$/) { buf = ""; inw = 0 } else flush()
      i++; d = substr(s, i, 1)
      if (d == "<") {
        i++
        if (substr(s, i, 1) == "<") { i++; pend = 2; continue }
        hdtab = 0
        if (substr(s, i, 1) == "-") { i++; hdtab = 1 }
        pend = 3; continue
      }
      if (d == "&") { i++; while (i <= n && substr(s, i, 1) ~ /[0-9-]/) i++; continue }
      if (d == ">") { i++; pend = 1; continue }
      if (d == "(") continue
      pend = 2; continue
    }
    if (c == "&" && substr(s, i + 1, 1) == ">") {
      flush(); i += 2
      if (substr(s, i, 1) == ">") i++
      pend = 1; continue
    }
    if (c == ";" || c == "&" || c == "|" || c == "(" || c == ")" || c == "{" && !inw || c == "}" && !inw) {
      sep(); i++; continue
    }
    buf = buf c; inw = 1; i++
  }
  flush()
}
AWK

ALVOS=""
TAB="$(printf '\t')"
NL='
'
RE_ATRIB='^[A-Za-z_][A-Za-z0-9_]*='

alvo() { ALVOS="$ALVOS$1$NL"; }

# nao_opcoes "<opções com valor>" args...: põe em NO os argumentos que não são opção.
nao_opcoes() {
  local vals=" $1 " fim=0
  shift
  NO=()
  while [ $# -gt 0 ]; do
    if [ "$fim" -eq 0 ]; then
      case "$1" in
        --) fim=1; shift; continue ;;
        --*) shift; continue ;;
        -?*)
          case "$vals" in *" $1 "*) shift ;; esac
          shift; continue
          ;;
      esac
    fi
    NO[${#NO[@]}]="$1"
    shift
  done
}

# todos_alvos: cada elemento de NO, a partir do índice $1, é alvo.
todos_alvos() {
  local k="${1:-0}"
  while [ "$k" -lt "${#NO[@]}" ]; do alvo "${NO[$k]}"; k=$((k + 1)); done
}

c_sed() {
  local a b k ch inplace=0 script=0 fim=0
  NO=()
  while [ $# -gt 0 ]; do
    a="$1"; shift
    if [ "$fim" -eq 0 ]; then
      case "$a" in
        --) fim=1; continue ;;
        --in-place*) inplace=1; continue ;;
        --expression=*|--file=*) script=1; continue ;;
        --expression|--file|-e|-f) script=1; shift; continue ;;
        --*) continue ;;
        -?*)
          # Agrupadas e com valor colado (-ni, -i.bak, -es/a/b/, -fscript.sed, -E -i):
          # i leva o resto como sufixo; e/f levam o resto como script (ou o próximo argumento).
          b="${a#-}"; k=0
          while [ "$k" -lt "${#b}" ]; do
            ch="${b:$k:1}"
            case "$ch" in
              i)
                inplace=1
                # BSD: -i '' (sufixo vazio separado).
                if [ "$((k + 1))" -eq "${#b}" ] && [ $# -gt 0 ] && [ -z "$1" ]; then shift; fi
                break
                ;;
              e|f)
                script=1
                [ "$((k + 1))" -lt "${#b}" ] || shift
                break
                ;;
              l) [ "$((k + 1))" -lt "${#b}" ] || shift; break ;;
            esac
            k=$((k + 1))
          done
          continue
          ;;
      esac
    fi
    NO[${#NO[@]}]="$a"
  done
  [ "$inplace" -eq 1 ] || return 0
  # Sem -e/-f, o primeiro argumento é o script; os arquivos vêm depois.
  if [ "$script" -eq 1 ]; then todos_alvos 0; else todos_alvos 1; fi
}

c_perl() {
  local a b k ch inplace=0 code=0 fim=0
  NO=()
  while [ $# -gt 0 ]; do
    a="$1"; shift
    if [ "$fim" -eq 0 ]; then
      case "$a" in
        --) fim=1; continue ;;
        -?*)
          b="${a#-}"; k=0
          # Agrupadas (-pi, -pe, -i.bak, -e's/a/b/'): i leva o resto como sufixo; e/E leva o
          # resto como código, ou o próximo argumento se nada vier colado. M, m, I, l, 0, x, C, d e D
          # levam o resto como valor (-Mstrict não é -i).
          while [ "$k" -lt "${#b}" ]; do
            ch="${b:$k:1}"
            case "$ch" in
              i) inplace=1; break ;;
              e|E) code=1; [ "$((k + 1))" -lt "${#b}" ] || shift; break ;;
              M|m|I|l|0|x|C|d|D) break ;;
            esac
            k=$((k + 1))
          done
          continue
          ;;
      esac
    fi
    NO[${#NO[@]}]="$a"
  done
  [ "$inplace" -eq 1 ] || return 0
  if [ "$code" -eq 1 ]; then todos_alvos 0; else todos_alvos 1; fi
}

# cp, mv, install e ln: o destino (último argumento, ou -t DIR); install -d cria todos; mv também a origem.
c_destino() {
  local nome="$1" a dir=0 t=0 ant=""
  shift
  for a in "$@"; do
    case "$ant" in -t) alvo "$a"; t=1 ;; esac
    case "$a" in
      --target-directory=*) alvo "${a#--target-directory=}"; t=1 ;;
      --directory) dir=1 ;;
      --*) ;;
      -*d*) [ "$nome" = "install" ] && dir=1 ;;
    esac
    ant="$a"
  done
  nao_opcoes "-t -m -o -g -S" "$@"
  if [ "$dir" -eq 1 ]; then todos_alvos 0; return 0; fi
  # mv: a origem também é escrita (sai do lugar). Com -t, todos são origem; sem, todos menos o último.
  if [ "$nome" = "mv" ]; then
    local k=0 fim="${#NO[@]}"
    [ "$t" -eq 1 ] || fim=$((fim - 1))
    while [ "$k" -lt "$fim" ]; do alvo "${NO[$k]}"; k=$((k + 1)); done
  fi
  [ "$t" -eq 0 ] || return 0
  [ "${#NO[@]}" -ge 2 ] && alvo "${NO[$((${#NO[@]} - 1))]}"
  return 0
}

# comando <prof> palavras...: um comando simples, já separado de &&, ||, ;, |.
comando() {
  local prof="$1" nome a ant=""
  shift
  while [ $# -gt 0 ]; do
    if [[ "$1" =~ $RE_ATRIB ]]; then shift; continue; fi
    case "$1" in
      sudo|env|command|builtin|exec|nohup|time|nice|caffeinate|timeout|stdbuf)
        shift
        while [ $# -gt 0 ]; do
          case "$1" in
            -*|[0-9]*) shift ;;
            *) [[ "$1" =~ $RE_ATRIB ]] && shift || break ;;
          esac
        done
        ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || return 0
  nome="${1##*/}"
  shift
  case "$nome" in
    tee|rm) nao_opcoes "" "$@"; todos_alvos 0 ;;
    touch) nao_opcoes "-r -t -d" "$@"; todos_alvos 0 ;;
    truncate) nao_opcoes "-s -r" "$@"; todos_alvos 0 ;;
    cp|mv|install|ln) c_destino "$nome" "$@" ;;
    dd) for a in "$@"; do case "$a" in of=*) alvo "${a#of=}" ;; esac; done ;;
    sed|gsed) c_sed "$@" ;;
    perl) c_perl "$@" ;;
    bash|sh|zsh|dash|ksh)
      # bash -c '...' (também -lc, -ec): analisa o script do -c.
      for a in "$@"; do
        case "$ant" in -*c) analisa "$a" $((prof + 1)); return 0 ;; esac
        case "$a" in
          --) return 0 ;;
          -*) ;;
          *) return 0 ;;
        esac
        ant="$a"
      done
      ;;
  esac
  return 0
}

# analisa <comando> <prof>: junta em ALVOS os alvos de escrita do comando.
analisa() {
  local prof="${2:-0}" linha tipo val
  local -a ws
  ws=()
  [ "$prof" -le 4 ] || return 0
  while IFS= read -r linha; do
    tipo="${linha%%"$TAB"*}"
    val="${linha#*"$TAB"}"
    case "$tipo" in
      W) ws[${#ws[@]}]="$val" ;;
      R) alvo "$val" ;;
      S) [ "${#ws[@]}" -eq 0 ] || comando "$prof" "${ws[@]}"; ws=() ;;
    esac
  done <<EOT
$(GUARD_CMD="$1" awk "$TOK" </dev/null)
EOT
  [ "${#ws[@]}" -eq 0 ] || comando "$prof" "${ws[@]}"
  return 0
}

# temporario <abs>: sob /tmp, /private/tmp ou $TMPDIR.
temporario() {
  local d
  for d in /tmp /private/tmp "$(norm "${TMPDIR:-}")"; do
    [ -n "$d" ] && [ "$d" != "/" ] || continue
    case "$1" in "$d"/*) return 0 ;; esac
    case "$d" in /var/*) case "$1" in "/private$d"/*) return 0 ;; esac ;; esac
  done
  return 1
}

# verifica <alvo>: sai 2 com o motivo se o alvo não pode ser escrito.
verifica() {
  local a="$1" abs rel rc=3
  # 1. Literal com $, ` ou ~: não dá para saber o alvo; ignora.
  case "$a" in ""|-|*'$'*|*'`'*|*'~'*) return 0 ;; esac
  # 2. Descartes e saídas padrão.
  case "$a" in /dev/null|/dev/std*) return 0 ;; esac
  # 3. Relativo resolve a partir do cwd.
  abs="$(guard_abs "$cwd" "$a")"
  rel="$(guard_rel "$abs" "$top")"
  if [ "$rel" = "$abs" ]; then
    # 5. Fora da raiz, sem "..", em temporário: permite. 6. Resto: fora do worktree.
    case "/$abs/" in */../*) ;; *) if temporario "$abs"; then return 0; fi ;; esac
  elif [ "$role" != "rev" ]; then
    # 4. Dentro da raiz: regras do Builder (temporário não isenta: o worktree pode estar sob $TMPDIR).
    rc=0
    guard_regra_bld "$role_file" "$rel" || rc=$?
  fi
  if [ "$role" = "rev" ]; then
    echo "bash-guard: Reviewer não edita arquivos: $rel" >&2
    exit 2
  fi
  case "$rc" in
    0) return 0 ;;
    1) echo "bash-guard: .sdd-role é protegido" >&2 ;;
    2) echo "bash-guard: $rel — tests/aceite é do Architect" >&2 ;;
    *) echo "bash-guard: fora dos paths da $wp: $rel" >&2 ;;
  esac
  exit 2
}

analisa "$comando_bash" 0
while IFS= read -r a; do
  [ -n "$a" ] || continue
  verifica "$a"
done <<EOT
$ALVOS
EOT
exit 0
