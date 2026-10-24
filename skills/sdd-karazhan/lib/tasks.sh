#!/usr/bin/env bash
# Parser de tasks.md e casamento de globs. Uso: . "<skill>/lib/tasks.sh"
# Pode ser carregado sozinho (hook, scripts): não executa nada ao carregar e não
# depende de common.sh. Erros vão para stderr com código de retorno, sem exit.

# tasks_sem_comentarios <arquivo>: imprime o arquivo sem blocos <!-- ... --> (multi-linha
# ou na mesma linha) e sem CR. O template do scaffold traz uma WP de exemplo comentada.
tasks_sem_comentarios() {
  [ -f "${1:-}" ] || { echo "arquivo não encontrado: ${1:-}" >&2; return 2; }
  awk '
    {
      sub(/\r$/, "")
      l = $0; out = ""
      while (1) {
        if (em) {
          i = index(l, "-->")
          if (!i) break
          l = substr(l, i + 3); em = 0
        } else {
          i = index(l, "<!--")
          if (!i) { out = out l; break }
          out = out substr(l, 1, i - 1); l = substr(l, i + 4); em = 1
        }
      }
      print out
    }' "$1"
}

# wp_list <tasks.md>: ids das WPs (WP-01...), um por linha, na ordem do arquivo.
wp_list() {
  tasks_sem_comentarios "$1" | awk '$1 == "###" && $2 ~ /^WP-[0-9]+$/ { print $2 }'
}

# wp_field <tasks.md> <WP-NN> <Campo>: valor (sem espaços nas pontas) da linha "- Campo: valor"
# dentro da WP. Campo ausente: "WP-NN sem campo <Campo>" em stderr e retorno 2.
wp_field() {
  local out
  out="$(tasks_sem_comentarios "$1" | awk -v id="$2" -v campo="$3" '
    $1 == "###" { em = ($2 == id); next }
    em {
      p = "- " campo ":"
      if (substr($0, 1, length(p)) == p) {
        v = substr($0, length(p) + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", v)
        print v
        achou = 1
        exit
      }
    }
    END { exit achou ? 0 : 3 }')" || { echo "$2 sem campo $3" >&2; return 2; }
  printf '%s\n' "$out"
}

# wp_paths <tasks.md> <WP-NN>: globs do campo Possui, um por linha (split por vírgula, trim).
# Campo ausente ou vazio: "WP-NN sem campo Possui" em stderr e retorno 2.
wp_paths() {
  local val paths
  val="$(wp_field "$1" "$2" Possui)" || return 2
  paths="$(printf '%s\n' "$val" | tr ',' '\n' | tr -d '`' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' || true)"
  [ -n "$paths" ] || { echo "$2 sem campo Possui" >&2; return 2; }
  printf '%s\n' "$paths"
}

# glob_match <glob> <path>: exit 0 se casa, 1 se não. Relativo à raiz do repo.
# "**" casa qualquer profundidade (inclusive zero): "pkg/**" casa pkg/a.py e pkg/s/b.py;
# "**/x" casa x e a/b/x. "*" e "?" não atravessam "/".
# "./" ou "/" iniciais são ignorados no glob e no path; glob terminado em "/" vale "<glob>/**".
glob_match() {
  local g="$1" p="$2" re="^" i=0 n c
  g="${g#./}"; g="${g#/}"; p="${p#./}"; p="${p#/}"
  case "$g" in */) g="$g**" ;; esac
  n=${#g}
  while [ "$i" -lt "$n" ]; do
    c="${g:$i:1}"
    case "$c" in
      '*')
        if [ "${g:$((i + 1)):1}" = '*' ]; then
          if [ "${g:$((i + 2)):1}" = '/' ]; then
            re="$re(.*/)?"
            i=$((i + 2))
          else
            re="$re.*"
            i=$((i + 1))
          fi
        else
          re="$re[^/]*"
        fi
        ;;
      '/')
        if [ "${g:$i}" = '/**' ]; then
          re="$re(/.*)?"
          i=$n
        else
          re="$re/"
        fi
        ;;
      '?') re="$re[^/]" ;;
      '^') re="$re\^" ;;
      '.'|'+'|'('|')'|'['|']'|'{'|'}'|'|'|'$'|'\') re="$re[$c]" ;;
      *) re="$re$c" ;;
    esac
    i=$((i + 1))
  done
  re="$re\$"
  [[ "$p" =~ $re ]]
}
