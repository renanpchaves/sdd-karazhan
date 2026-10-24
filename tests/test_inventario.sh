. "$(dirname "$0")/lib.sh"; SK=$PWD/skills/sdd-karazhan; I=$SK/scripts/inventario.sh
# PATH sem um codex real da máquina: só o stub em $TMP/bin decide se há Codex. Diretórios com
# codex saem do PATH; as ferramentas necessárias que moravam neles ganham wrapper em $TMP/ferr.
mkdir -p "$TMP/bin" "$TMP/ferr"
P=""; set -f; IFS=:
for d in $PATH; do [ -x "$d/codex" ] || [ -x "$d/maestri" ] || P="$P:$d"; done
unset IFS; set +f
for c in bash jq git sed awk grep tr iconv mktemp sha1sum shasum cut head tail date cat basename dirname sort; do
  p="$(command -v "$c" 2>/dev/null)" || continue
  case "$p" in /*) ;; *) continue ;; esac
  { [ -x "${p%/*}/codex" ] || [ -x "${p%/*}/maestri" ]; } || continue
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$p" > "$TMP/ferr/$c"; chmod +x "$TMP/ferr/$c"
done
export PATH="$TMP/bin:$TMP/ferr$P"
linha() { printf '%s\n' "$1" | grep "^$2:" || true; } # <saída> <chave>: a linha que começa com a chave

# --- fixture padrão com scaffold, presets e mapa carimbado ---
R=$(fixture_repo padrao); cd $R; bash $SK/scripts/scaffold.sh 001-x >/dev/null
jq '.presets={"cc":{"family":"claude","tier":"capaz"},"cc-mini":{"family":"claude","tier":"barato"},"cx":{"family":"codex","tier":"capaz"}}' .claude/specs/karazhan.json > k && mv k .claude/specs/karazhan.json
bash $SK/scripts/mapa-check.sh --stamp >/dev/null
out=$(bash $I); code=$?
assert_eq 0 $code "exit 0"
assert_eq 8 "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "oito linhas"
assert_eq "repo: $(basename "$R") · raiz: $(git rev-parse --show-toplevel)" "$(printf '%s\n' "$out" | sed -n 1p)" "linha repo"
assert_eq "módulos: cli, coleta, envio, relatorio, settings" "$(linha "$out" módulos)" "módulos ordenados, sem tests nem dunder"
assert_eq "áreas: pacote, deploy, config, tests" "$(linha "$out" áreas)" "áreas"
assert_eq "specs: 001-x (vazia)" "$(linha "$out" specs)" "spec sem WP é vazia"
assert_eq "mapa: ok · esqueleto: padrao · testes: sim · dry-run: não" "$(linha "$out" mapa)" "linha do mapa"
assert_eq "presets: cc=claude/capaz cc-mini=claude/barato cx=codex/capaz · codex: não" "$(linha "$out" presets)" "presets sem codex no PATH"
assert_eq "conectados: nenhum" "$(linha "$out" conectados)" "sem conectados"
assert_eq "eng_max: 3" "$(linha "$out" eng_max)" "eng_max do plugin"
# a ordem das linhas é fixa
assert_eq "repo módulos áreas specs mapa presets conectados eng_max" "$(printf '%s\n' "$out" | sed 's/:.*//' | tr '\n' ' ' | sed 's/ $//')" "ordem das linhas"

# --- codex: preset codex E binário ---
printf '#!/bin/sh\nexit 0\n' > $TMP/bin/codex; chmod +x $TMP/bin/codex
assert_contains "$(bash $I)" "· codex: sim" "codex com preset e binário"
jq '.presets={"cc":{"family":"claude","tier":"capaz"}}' .claude/specs/karazhan.json > k && mv k .claude/specs/karazhan.json
assert_contains "$(bash $I)" "presets: cc=claude/capaz · codex: não" "binário sem preset codex"
rm $TMP/bin/codex

# --- eng_max do karazhan.json vence o do plugin ---
jq '.config.eng_max=2' .claude/specs/karazhan.json > k && mv k .claude/specs/karazhan.json
assert_contains "$(bash $I)" "eng_max: 2" "eng_max sobrescrito"
jq 'del(.config.eng_max) | .presets={}' .claude/specs/karazhan.json > k && mv k .claude/specs/karazhan.json
assert_contains "$(bash $I)" "presets: nenhum · codex: não" "sem presets"

# --- specs: aprovada, em curso, vazia ---
for s in 002-y 003-z 004-w 005-v; do bash $SK/scripts/scaffold.sh $s >/dev/null; done
printf '### WP-01 — a\n- Lane: aprovado\n### WP-02 — b\n- Lane: pronto\n' > .claude/specs/current/001-x/tasks.md
printf '### WP-01 — a
- Lane: aprovado
### WP-02 — b
- Lane: em andamento
' > .claude/specs/current/002-y/tasks.md
# WP sem Lane lida de fato: depois de uma WP aprovada, e como primeira WP
printf '### WP-01 — a
- Lane: aprovado
### WP-02 — sem lane
- Dono: x
' > .claude/specs/current/004-w/tasks.md
printf '### WP-01 — sem lane
- Dono: x
' > .claude/specs/current/005-v/tasks.md
assert_eq "specs: 001-x (aprovada), 002-y (em curso), 003-z (vazia), 004-w (em curso), 005-v (em curso)" "$(linha "$(bash $I)" specs)" "estados das specs, WP sem Lane lida"

# --- conectados: equipe.md e maestri ---
printf '| eng-grom | Engineer | cc | pkg/** | 1 |\n| rev-uther | Reviewer | cx | - | 1 |\n| git-gazlowe | Git | cc | - | 1 |\n| eng-grom | de novo | | | |\n' >> .claude/specs/equipe.md
printf '| digit-foo | Armadilha |
' >> .claude/specs/equipe.md
assert_eq "conectados: eng-grom (equipe.md), rev-uther (equipe.md), git-gazlowe (equipe.md)" "$(linha "$(bash $I)" conectados)" "conectados via equipe.md, sem repetir"
case "$(bash $I)" in *git-foo*) fail "digit-foo casou como git-foo" ;; esac
printf '#!/bin/sh\n[ "$1" = list ] && printf "arch-alexstrasza\neng-saurfang  claude\n"\nexit 0\n' > $TMP/bin/maestri; chmod +x $TMP/bin/maestri
assert_eq "conectados: arch-alexstrasza (terminal), eng-saurfang (terminal)" "$(linha "$(bash $I)" conectados)" "maestri list tem precedência"
rm $TMP/bin/maestri

# --- dry-run ---
printf 'import argparse\np = argparse.ArgumentParser()\np.add_argument("--dry-run")\n' > pkg/cli.py
assert_contains "$(bash $I)" "dry-run: sim" "--dry-run em *.py de pacote com run.sh"
rm run.sh
assert_contains "$(bash $I)" "dry-run: não" "sem run.sh"

# --- mapa vencido pela árvore ---
printf 'x = 1\n' > pkg/novo.py; git add -A; git commit -qm novo
out=$(bash $I); assert_contains "$out" "mapa: vencido-arvore" "mapa vencido"
assert_contains "$out" "novo" "módulo novo listado"

# --- subdiretório usa a raiz do repo ---
cd pkg; assert_contains "$(bash $I)" "áreas: pacote, deploy, config, tests" "subdiretório usa a raiz"; cd ..

# --- deploy: run.sh ou setup.sh sem deploy/ também formam a área ---
R4=$(fixture_repo padrao); cd $R4; rm -rf deploy; git add -A
assert_contains "$(bash $I)" "áreas: pacote, deploy, config, tests" "run.sh e setup.sh sem deploy/ valem deploy"
rm setup.sh; git add -A
assert_contains "$(bash $I)" "áreas: pacote, deploy, config, tests" "run.sh sem deploy/ vale deploy"
rm run.sh; printf '#!/usr/bin/env bash\n' > setup.sh; git add -A
assert_contains "$(bash $I)" "áreas: pacote, deploy, config, tests" "setup.sh sem deploy/ vale deploy"
rm setup.sh; git add -A
assert_contains "$(bash $I)" "áreas: pacote, config, tests" "sem deploy/, run.sh nem setup.sh"

# --- plano: esqueleto fora ---
R2=$(fixture_repo plano); cd $R2
out=$(bash $I)
assert_contains "$out" "esqueleto: fora" "plano fora do esqueleto"
assert_eq "módulos: script" "$(linha "$out" módulos)" "módulo do plano"
assert_eq "áreas: nenhuma" "$(linha "$out" áreas)" "plano sem áreas"
assert_eq "specs: nenhuma" "$(linha "$out" specs)" "plano sem specs"
assert_contains "$out" "mapa: ausente" "plano sem mapa"
assert_contains "$out" "testes: não" "plano sem testes"

# --- fora de repo git: repo novo, exit 0, presets ainda lidos ---
N=$(mktemp -d "$TMP/novo.XXXXXX"); cd $N
out=$(bash $I); code=$?
assert_eq 0 $code "exit 0 fora de git"
assert_eq "repo: novo" "$(printf '%s\n' "$out" | sed -n 1p)" "repo novo na primeira linha"
assert_eq "módulos: nenhum" "$(linha "$out" módulos)" "novo sem módulos"
assert_contains "$out" "mapa: ausente · esqueleto: nenhum · testes: não · dry-run: não" "novo: linha do mapa"
assert_contains "$out" "presets: nenhum · codex: não" "novo sem presets"
assert_contains "$out" "eng_max: 3" "novo com eng_max"
mkdir -p .claude/specs; echo '{"presets":{"cx":{"family":"codex","tier":"capaz"}},"config":{"eng_max":1}}' > .claude/specs/karazhan.json
printf '| arch-alexstrasza | Architect |\n' > .claude/specs/equipe.md
out=$(bash $I)
assert_contains "$out" "presets: cx=codex/capaz · codex: não" "novo lê presets"
assert_contains "$out" "conectados: arch-alexstrasza" "novo lê equipe.md"
assert_contains "$out" "eng_max: 1" "novo lê eng_max"

# --- repo git sem código nem pacote: também novo ---
G=$(mktemp -d "$TMP/vazio.XXXXXX"); cd $G; git init -q -b main; printf '# x\n' > README.md; git add -A; git -c commit.gpgsign=false -c user.email=t@e -c user.name=T commit -qm i
out=$(bash $I); code=$?
assert_eq 0 $code "exit 0 repo sem código"
assert_eq "repo: novo" "$(printf '%s\n' "$out" | sed -n 1p)" "repo sem código é novo"

# --- argumentos e erros ---
assert_exit 0 bash $I --help
assert_exit 2 bash $I "pedido qualquer"
cd $R; echo '{quebrado' > .claude/specs/karazhan.json; assert_exit 2 bash $I
