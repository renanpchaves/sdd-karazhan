#!/usr/bin/env bash
# inventario.sh
# Lista fatos do repo atual, em oito linhas fixas. Não lê o pedido nem decide time:
# quem decide é o Orchestrator, com estes fatos e a régua da skill. Exit 0 sempre que a saída sai.
# Fora de repo git, ou em repo sem código nem pacote, a primeira linha é "repo: novo".
. "$(dirname "$0")/../lib/common.sh"
. "$(dirname "$0")/../lib/tasks.sh"

AJUDA='uso: inventario.sh (sem argumentos), executado no diretório do projeto'
case "${1:-}" in
  -h|--help) usage "$AJUDA" ;;
  "") ;;
  *) die "$AJUDA" ;;
esac
need jq

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
cfg="$ROOT/config.json"
tmpd="$(mktemp -d)"
trap 'rm -rf "$tmpd"' EXIT

top=""
if command -v git >/dev/null 2>&1 && top="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  cd "$top"
else
  top=""
fi

kj=".claude/specs/karazhan.json"
if [ -f "$kj" ]; then jq empty "$kj" 2>/dev/null || die "karazhan.json inválido: $kj"; fi

# lista <itens por linha>: junta com ", "; "nenhum"/"nenhuma" (2º argumento) se vazio.
lista() {
  if [ -z "$1" ]; then echo "$2"; else printf '%s\n' "$1" | awk 'NR > 1 { printf ", " } { printf "%s", $0 }'; echo; fi
}

# --- código: módulos e áreas (alembic/ é a área migracoes, fora de módulos) ---
modulos=""
if [ -n "$top" ]; then
  modulos="$({ git -c core.quotepath=off ls-files '*.py' | tr -d '\r' | grep -vE '(^|/)(tests|alembic)/' || true; } |
    sed 's#.*/##; s/\.py$//' | grep -vE '^__.*__$' | tr '[:upper:]' '[:lower:]' | LC_ALL=C sort -u)"
fi
pacote=0
if compgen -G "*/__init__.py" >/dev/null; then pacote=1; fi
novo=0
if [ -z "$top" ] || { [ -z "$modulos" ] && [ "$pacote" -eq 0 ]; }; then novo=1; fi

areas=""
add_area() { areas="${areas:+$areas
}$1"; }
if [ "$novo" -eq 0 ]; then
  if [ "$pacote" -eq 1 ]; then add_area pacote; fi
  if [ -d deploy ] || [ -f run.sh ] || [ -f setup.sh ]; then add_area deploy; fi
  if [ -d config ]; then add_area config; fi
  if [ -d alembic ]; then add_area migracoes; fi
  if [ -d tests ]; then add_area tests; fi
fi

# --- specs: estado pelas lanes do tasks.md ---
specs=""
for d in .claude/specs/current/*/; do
  [ -d "$d" ] || continue
  slug="$(basename "$d")"
  tasks="$d/tasks.md"
  estado="vazia"
  if [ -f "$tasks" ]; then
    wps="$(wp_list "$tasks" || true)"
    if [ -n "$wps" ]; then
      estado="aprovada"
      for wp in $wps; do
        v=""
        wp_field "$tasks" "$wp" Lane 2>/dev/null >"$tmpd/lane" || true
        v="$(cat "$tmpd/lane")"
        case "$v" in aprovado|pronto) ;; *) estado="em curso"; break ;; esac
      done
    elif [ -n "$(wp_list "$d/tasks-done.md" 2>/dev/null || true)" ]; then
      # Pousada: as WPs já foram para tasks-done.md.
      estado="aprovada"
    fi
  fi
  specs="${specs:+$specs
}$slug ($estado)"
done

# --- mapa, esqueleto, testes, dry-run ---
mapa=""; esqueleto=""; testes=""; dry=""
if [ "$novo" -eq 1 ]; then
  mapa=ausente; esqueleto=nenhum; testes=não; dry=não
else
  linha_mapa="$(bash "$SCRIPTS/mapa-check.sh" 2>/dev/null || true)"
  mapa="$(printf '%s\n' "$linha_mapa" | sed -n 's/.*mapa=\([a-z-]*\).*/\1/p')"
  esqueleto="$(printf '%s\n' "$linha_mapa" | sed -n 's/.*esqueleto=\([a-z]*\).*/\1/p')"
  case "$mapa" in ok|ausente|vencido-idade|vencido-arvore) ;; *) mapa=ausente ;; esac
  [ -n "$esqueleto" ] || esqueleto=fora
  testes=não
  if [ -d tests ] || [ -f pytest.ini ] || { [ -f pyproject.toml ] && grep -qF '[tool.pytest' pyproject.toml; }; then
    testes=sim
  fi
  dry=não
  if [ -f run.sh ] && grep -rq -- '--dry-run' run.sh *.py */*.py 2>/dev/null; then dry=sim; fi
fi

# --- presets, codex, eng_max ---
eng_max="$(jqr '.eng_max' "$cfg")"
: > "$tmpd/presets"
if [ -f "$kj" ]; then
  over="$(jqr '.config.eng_max // empty' "$kj")"
  [ -z "$over" ] || eng_max="$over"
  jqr '(.presets // {}) | to_entries[] | "\(.key)\t\(.value.family)\t\(.value.tier)"' "$kj" > "$tmpd/presets"
fi
codex=não
if awk -F'\t' '$2 == "codex" { achou = 1 } END { exit !achou }' "$tmpd/presets" && command -v codex >/dev/null 2>&1; then
  codex=sim
fi
presets="$(awk -F'\t' '{ printf "%s%s=%s/%s", (NR > 1 ? " " : ""), $1, $2, $3 }' "$tmpd/presets")"

# --- conectados: nomes do roster (todos os pools) como palavra inteira, sem diferenciar maiúsculas ---
# Primeiro os de `maestri list` (terminal), depois os de equipe.md ainda não vistos. Saída: Nome (Papel, origem).
# nomes_em (stdin): palavras candidatas, em minúsculas. Token com hífen só vale no formato antigo
# prefixo-nome (eng-thrall → thrall); tasks-Gazlowe, digit-foo e Grommash não rendem nome.
nomes_em() {
  LC_ALL=C tr -c 'A-Za-z0-9_-' '\n' | LC_ALL=C tr 'A-Z' 'a-z' | awk '
    /-/ { if ($0 ~ /^(orch|arch|rec|eng|rev|git)-[a-z]+$/) print substr($0, index($0, "-") + 1); next }
    /^[a-z]+$/ { print }'
}
# so_agentes (stdin = maestri list): descarta as seções de notas e portais (cabeçalho sem recuo que cita
# note/nota/portal antes do ":"); ficam a linha You: e as dos agentes conectados.
so_agentes() {
  awk '/^[^ \t*-]/ { secao_nota = (tolower($0) ~ /^[^:]*(note|nota|portal)[^:]*:/) } !secao_nota'
}
jqr 'to_entries[] | .key as $p | .value[] | "\(ascii_downcase)\t\($p)"' "$ROOT/roster.json" > "$tmpd/roster"
: > "$tmpd/vistos"
if command -v maestri >/dev/null 2>&1; then
  maestri list 2>/dev/null | tr -d '\r' | so_agentes | nomes_em | awk '{ print "terminal\t" $0 }' >> "$tmpd/vistos" || true
fi
if [ -f .claude/specs/equipe.md ]; then
  tr -d '\r' < .claude/specs/equipe.md | nomes_em | awk '{ print "equipe.md\t" $0 }' >> "$tmpd/vistos"
fi
conectados="$(awk -F'\t' '
  BEGIN { papel["orch"] = "Orchestrator"; papel["arch"] = "Architect"; papel["rec"] = "Recon"
          papel["eng"] = "Engineer"; papel["rev"] = "Reviewer"; papel["git"] = "Git Manager" }
  NR == FNR { pool[$1] = $2; next }
  ($2 in pool) && !v[$2]++ { printf "%s%s (%s, %s)\n", toupper(substr($2, 1, 1)), substr($2, 2), papel[pool[$2]], $1 }
' "$tmpd/roster" "$tmpd/vistos")"

# --- saída ---
if [ "$novo" -eq 1 ]; then
  echo "repo: novo"
else
  echo "repo: $(basename "$top") · raiz: $top"
fi
echo "módulos: $(lista "$modulos" nenhum)"
echo "áreas: $(lista "$areas" nenhuma)"
echo "specs: $(lista "$specs" nenhuma)"
echo "mapa: $mapa · esqueleto: $esqueleto · testes: $testes · dry-run: $dry"
echo "presets: ${presets:-nenhum} · codex: $codex"
echo "conectados: $(lista "$conectados" nenhum)"
echo "eng_max: $eng_max"
