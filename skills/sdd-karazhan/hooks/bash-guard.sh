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
    # "{ " abre grupo; "{" colado (tee {a,b}) é expansão de chaves.
    if (c == "{" && !inw && (i == n || substr(s, i + 1, 1) ~ /[ \t\n]/)) { sep(); i++; continue }
    if (c == ";" || c == "&" || c == "|" || c == "(" || c == ")" || c == "}" && !inw) {
      sep(); i++; continue
    }
    # Fora de aspas, * ? [ ] { } , viram marcadores (\016-\024): o shell expande esses,
    # e o bash-guard precisa saber quais vieram sem aspas.
    if (c == "*") c = "\016"; else if (c == "?") c = "\017"; else if (c == "[") c = "\020"
    else if (c == "]") c = "\021"; else if (c == "{") c = "\022"; else if (c == "}") c = "\023"
    else if (c == ",") c = "\024"
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
          # resto como código, ou o próximo argumento se nada vier colado. M, m, I, x, C, d e D
          # levam o resto como valor (-Mstrict não é -i); 0 e l levam só dígitos e a leitura
          # segue (-0pi e -lpi são -i).
          while [ "$k" -lt "${#b}" ]; do
            ch="${b:$k:1}"
            case "$ch" in
              i) inplace=1; break ;;
              e|E) code=1; [ "$((k + 1))" -lt "${#b}" ] || shift; break ;;
              0)
                # -0[octal] ou -0x[hex].
                k=$((k + 1))
                if [ "${b:$k:1}" = "x" ]; then
                  k=$((k + 1))
                  while [ "$k" -lt "${#b}" ]; do
                    case "${b:$k:1}" in [0-9a-fA-F]) k=$((k + 1)) ;; *) break ;; esac
                  done
                else
                  while [ "$k" -lt "${#b}" ]; do
                    case "${b:$k:1}" in [0-7]) k=$((k + 1)) ;; *) break ;; esac
                  done
                fi
                continue
                ;;
              l)
                k=$((k + 1))
                while [ "$k" -lt "${#b}" ]; do
                  case "${b:$k:1}" in [0-7]) k=$((k + 1)) ;; *) break ;; esac
                done
                continue
                ;;
              M|m|I|x|C|d|D) break ;;
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

# Marcadores do tokenizador para * ? [ ] { } , sem aspas (\001 e \177 ficam de fora: o bash 3.2
# os usa internamente).
MG_E="$(printf '\016')"; MG_Q="$(printf '\017')"; MG_C="$(printf '\020')"; MG_F="$(printf '\021')"
MB_A="$(printf '\022')"; MB_F="$(printf '\023')"; MB_V="$(printf '\024')"

# literal <alvo>: troca os marcadores pelos caracteres originais.
literal() { printf '%s' "$1" | tr '\016\017\020\021\022\023\024' '*?[]{},'; }

# expandir <alvo>: expansão de chaves sem aspas ({a,b}, aninhadas), como o shell faz. Junta
# as alternativas em EXP. Chave sem vírgula de topo ou sem fechamento fica literal.
expandir() {
  local s="$1" pre resto n i c dep corpo pos alt virg
  [ "${#EXP[@]}" -le 256 ] || return 0
  case "$s" in *"$MB_A"*) ;; *) EXP[${#EXP[@]}]="$s"; return 0 ;; esac
  pre="${s%%"$MB_A"*}"; resto="${s#*"$MB_A"}"
  n=${#resto}; i=0; dep=0; virg=0
  while [ "$i" -lt "$n" ]; do
    c="${resto:$i:1}"
    if [ "$c" = "$MB_A" ]; then dep=$((dep + 1))
    elif [ "$c" = "$MB_F" ]; then [ "$dep" -gt 0 ] || break; dep=$((dep - 1))
    elif [ "$c" = "$MB_V" ] && [ "$dep" -eq 0 ]; then virg=1
    fi
    i=$((i + 1))
  done
  if [ "$i" -ge "$n" ] || [ "$virg" -eq 0 ]; then
    expandir "$pre{$resto"
    return 0
  fi
  corpo="${resto:0:$i}"; pos="${resto:$((i + 1))}"
  # Separa o corpo nas vírgulas de topo.
  n=${#corpo}; i=0; dep=0; alt=""
  while [ "$i" -lt "$n" ]; do
    c="${corpo:$i:1}"
    if [ "$c" = "$MB_V" ] && [ "$dep" -eq 0 ]; then
      expandir "$pre$alt$pos"; alt=""
    else
      [ "$c" = "$MB_A" ] && dep=$((dep + 1))
      [ "$c" = "$MB_F" ] && dep=$((dep - 1))
      alt="$alt$c"
    fi
    i=$((i + 1))
  done
  expandir "$pre$alt$pos"
}

# tem_glob <texto marcado>: 0 se tem * ? ou [ sem aspas.
tem_glob() { case "$1" in *"$MG_E"*|*"$MG_Q"*|*"$MG_C"*) return 0 ;; esac; return 1; }

# padrao <segmento marcado>: o segmento como padrão do [[ == ]]; o que veio entre aspas é escapado.
padrao() {
  local s="$1" i=0 c out=""
  while [ "$i" -lt "${#s}" ]; do
    c="${s:$i:1}"
    case "$c" in
      "$MG_E") out="$out*" ;;
      "$MG_Q") out="$out?" ;;
      "$MG_C") out="$out[" ;;
      "$MG_F") out="$out]" ;;
      '*'|'?'|'['|']'|'\') out="$out\\$c" ;;
      *) out="$out$c" ;;
    esac
    i=$((i + 1))
  done
  printf '%s' "$out"
}

# casa_seg <nome> <segmento marcado>: 0 se o segmento pode casar com o nome. Como no shell,
# glob só casa nome com "." inicial se o próprio segmento começar com "." literal.
casa_seg() {
  local p
  if tem_glob "$2"; then
    case "$1" in .*) case "$2" in .*) ;; *) return 1 ;; esac ;; esac
    p="$(padrao "$2")"
    [[ "$1" == $p ]]
  else
    [ "$1" = "$(literal "$2")" ]
  fi
}

# segs <caminho>: põe em SG os segmentos do caminho.
segs() { SG=(); IFS=/ read -r -a SG <<EOT
$1
EOT
}

# prefixo_literal: segmentos de SG antes do primeiro com glob, juntados por "/".
prefixo_literal() {
  local k=0 p=""
  while [ "$k" -lt "${#SG[@]}" ]; do
    tem_glob "${SG[$k]}" && break
    if [ -z "$p" ]; then p="${SG[$k]}"; else p="$p/${SG[$k]}"; fi
    k=$((k + 1))
  done
  printf '%s' "$p"
}

# sobe_dir: 0 se algum segmento de SG é ".." ou é glob que casa "..".
sobe_dir() {
  local k=0
  while [ "$k" -lt "${#SG[@]}" ]; do
    [ "${SG[$k]}" != ".." ] || return 0
    if tem_glob "${SG[$k]}" && casa_seg ".." "${SG[$k]}"; then return 0; fi
    k=$((k + 1))
  done
  return 1
}

# regra_glob_bld <rel marcado>: como guard_regra_bld, para um padrão. Bloqueia se o padrão
# puder casar com .sdd-role, com o aceite ou com algo fora dos paths. Retorna 0, 1, 2 ou 3.
regra_glob_bld() {
  local rel="$1" m aceite k lim pre g base
  local -a R A
  segs "$rel"; R=("${SG[@]}"); m=${#R[@]}
  sobe_dir && return 3
  if [ "$m" -eq 1 ] && casa_seg ".sdd-role" "${R[0]}"; then return 1; fi
  # Aceite: o padrão casa com o prefixo literal do glob do aceite (comparação em minúsculas).
  aceite="$(guard_campo "$role_file" aceite | tr 'A-Z' 'a-z')"
  aceite="${aceite#./}"; aceite="${aceite#/}"
  if [ -n "$aceite" ]; then
    segs "$aceite"; A=()
    k=0
    while [ "$k" -lt "${#SG[@]}" ]; do
      case "${SG[$k]}" in *'*'*|*'?'*|*'['*) break ;; esac
      A[${#A[@]}]="${SG[$k]}"; k=$((k + 1))
    done
    [ "${#A[@]}" -gt 0 ] || return 2
    segs "$(printf '%s' "$rel" | tr 'A-Z' 'a-z')"
    lim=${#A[@]}; [ "$m" -ge "$lim" ] || lim=$m
    k=0
    while [ "$k" -lt "$lim" ] && casa_seg "${A[$k]}" "${SG[$k]}"; do k=$((k + 1)); done
    [ "$k" -lt "$lim" ] || return 2
  fi
  # Paths: o prefixo literal do padrão precisa estar sob um glob "<dir>/**" (ou "**") dos paths.
  segs "$rel"; pre="$(literal "$(prefixo_literal)")"
  while IFS= read -r g; do
    g="$(printf '%s' "$g" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    g="${g#./}"; g="${g#/}"
    case "$g" in */) g="$g**" ;; esac
    [ "$g" != "**" ] || return 0
    case "$g" in
      */\*\*)
        base="${g%/\*\*}"
        case "$base" in *'*'*|*'?'*|*'['*) continue ;; esac
        if [ "$pre" = "$base" ]; then return 0; fi
        case "$pre" in "$base"/*) return 0 ;; esac
        ;;
    esac
  done <<EOT
$(guard_campo "$role_file" paths | tr ',' '\n')
EOT
  return 3
}

# bloqueia <rc> <rel>: mensagem do role e exit 2 (rc 0 volta).
bloqueia() {
  if [ "$role" = "rev" ]; then
    echo "bash-guard: Reviewer não edita arquivos: $2" >&2
    exit 2
  fi
  case "$1" in
    0) return 0 ;;
    1) echo "bash-guard: .sdd-role é protegido" >&2 ;;
    2) echo "bash-guard: $2 — tests/aceite é do Architect" >&2 ;;
    *) echo "bash-guard: fora dos paths da $wp: $2" >&2 ;;
  esac
  exit 2
}

# verifica_glob <alvo marcado>: alvo com * ? [ sem aspas, que o shell expande.
verifica_glob() {
  local abs rel rc=0 pre
  abs="$(guard_abs "$cwd" "$1")"
  rel="$(guard_rel "$abs" "$top")"
  if [ "$rel" = "$abs" ]; then
    segs "${abs#/}"; pre="/$(literal "$(prefixo_literal)")"
    if ! sobe_dir && temporario "$pre/"; then return 0; fi
    bloqueia 3 "$(literal "$rel")"
  fi
  [ "$role" = "rev" ] && bloqueia 3 "$(literal "$rel")"
  regra_glob_bld "$rel" || rc=$?
  [ "$rc" -eq 0 ] && return 0
  bloqueia "$rc" "$(literal "$rel")"
}

# verifica <alvo>: expande chaves sem aspas e checa cada alternativa.
verifica() {
  local k=0
  local -a lista
  case "$1" in ""|-|*'$'*|*'`'*|*'~'*) return 0 ;; esac
  case "$1" in *"$MB_A"*) ;; *) verifica_um "$1"; return 0 ;; esac
  EXP=()
  expandir "$1"
  if [ "${#EXP[@]}" -gt 256 ]; then
    echo "bash-guard: expansão de chaves grande demais: $(literal "$1")" >&2
    exit 2
  fi
  lista=("${EXP[@]}")
  while [ "$k" -lt "${#lista[@]}" ]; do verifica_um "${lista[$k]}"; k=$((k + 1)); done
}

# verifica_um <alvo>: sai 2 com o motivo se o alvo não pode ser escrito.
verifica_um() {
  local a abs rel rc=3
  # Chave ou vírgula que sobrou da expansão é literal.
  a="$(printf '%s' "$1" | tr '\022\023\024' '{},')"
  if tem_glob "$a"; then verifica_glob "$a"; return 0; fi
  a="$(literal "$a")"
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
  bloqueia "$rc" "$rel"
}

analisa "$comando_bash" 0
while IFS= read -r a; do
  [ -n "$a" ] || continue
  verifica "$a"
done <<EOT
$ALVOS
EOT
exit 0
