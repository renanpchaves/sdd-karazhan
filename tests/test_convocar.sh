. "$(dirname "$0")/lib.sh"; SK=$PWD/skills/sdd-karazhan; C=$SK/scripts/convocar.sh
# PATH sem um codex real da máquina: só o stub em $TMP/bin decide se há Codex. Diretórios com
# codex saem do PATH; as ferramentas necessárias que moravam neles ganham wrapper em $TMP/ferr.
mkdir -p "$TMP/bin" "$TMP/ferr"
P=""; set -f; IFS=:
for d in $PATH; do [ -x "$d/codex" ] || P="$P:$d"; done
unset IFS; set +f
for c in bash jq git sed awk grep tr iconv mktemp sha1sum shasum cut head tail date cat basename dirname sort; do
  p="$(command -v "$c" 2>/dev/null)" || continue
  case "$p" in /*) ;; *) continue ;; esac
  [ -x "${p%/*}/codex" ] || continue
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$p" > "$TMP/ferr/$c"; chmod +x "$TMP/ferr/$c"
done
export PATH="$TMP/bin:$TMP/ferr$P"
R=$(fixture_repo padrao); cd $R; bash $SK/scripts/scaffold.sh 001-x >/dev/null
jq '.presets={"cc":{"family":"claude","tier":"capaz"},"cc-mini":{"family":"claude","tier":"barato"},"cx":{"family":"codex","tier":"capaz"}}' .claude/specs/karazhan.json > k && mv k .claude/specs/karazhan.json
printf '#!/bin/sh\nexit 0\n' > $TMP/bin/codex; chmod +x $TMP/bin/codex
bash $SK/scripts/mapa-check.sh --stamp >/dev/null
out=$(SDD_SEED=1 bash $C "adicionar filtro por empresa no relatorio")
assert_contains "$out" "Nível: Pequena" "1 módulo"
assert_contains "$out" "Sinais: módulos=1 (relatorio)" "módulo casado"
assert_contains "$out" "eng-grom (claude/medio)" "engineer"
assert_contains "$out" "rev-uther (codex/capaz)" "reviewer codex"
assert_contains "$out" "spec=não" "feature sem spec"
assert_contains "$out" "Subagentes: arch-alexstrasza (spec curta) · git-gazlowe" "subagentes: 1 área => architect subagente mesmo sem spec"
assert_contains "$out" "Não convocar: recon (mapa válido, esqueleto padrão)" "recon fora"
assert_contains "$out" "Presets: " "linha de presets"
assert_contains "$out" "eng-grom=cc " "preset do engineer (fallback medio->capaz)"
assert_contains "$out" "rev-uther=cx" "preset do reviewer"
out=$(SDD_SEED=1 bash $C "nova coleta e envio com plist no launchd")
assert_contains "$out" "módulos=3 (coleta, envio, deploy)" "deploy como área"
assert_contains "$out" "Nível: Média" "3 áreas"
assert_contains "$out" "Terminais: arch-alexstrasza (claude/capaz)" "architect terminal com 2+ áreas"
assert_contains "$out" "eng-grom (claude/capaz) · eng-saurfang (claude/capaz) · eng-durotan (claude/capaz)" "3 engineers sem nome repetido, tier capaz por deploy"
out=$(bash $C "melhorar performance"); assert_contains "$out" "módulos=0" "sem módulo"; assert_contains "$out" "nenhum módulo casou" "aviso"
out=$(bash $C "Ajuste no RELATÓRIO"); assert_contains "$out" "módulos=1 (relatorio)" "acento e caixa normalizados"
out=$(bash $C "adicionar relatório de coleta, envio e cli"); assert_contains "$out" "Nível: Grande" "4 áreas > eng_max"
out=$(SDD_SEED=1 bash $C "adicionar filtro no relatorio" grande); assert_contains "$out" "Nível: Grande" "grande nominal"
assert_contains "$out" "git-gazlowe (claude/barato)" "git manager terminal na Grande"
assert_contains "$out" "Terminais: arch-alexstrasza (claude/capaz)" "architect terminal na Grande mesmo com 1 área"
rm $TMP/bin/codex
assert_contains "$(bash $C "ajuste no relatorio")" "Reviewer: NÃO CONVOCADO (sem Codex)" "sem codex"
printf '#!/bin/sh\nexit 0\n' > $TMP/bin/codex; chmod +x $TMP/bin/codex
out=$(SDD_SEED=1 bash $C "qualquer" arch eng git); assert_contains "$out" "Terminais: arch-" "nominal"; assert_contains "$out" "Não convocar: (chamada nominal)" "nominal não adiciona"
case "$out" in *rev-*|*rec-*) fail "nominal adicionou papel: $out" ;; esac
assert_exit 2 bash $C "qualquer" eng
assert_exit 2 bash $C "qualquer" rev git
assert_exit 2 bash $C "qualquer" papelinventado
R2=$(fixture_repo plano); cd $R2; bash $SK/scripts/scaffold.sh 001-y >/dev/null
assert_contains "$(bash $C "corrigir bug no script")" "Subagentes: rec-" "recon em repo fora do padrão"
# módulo deploy.py + área deploy contam uma vez; rodar de subdiretório usa a raiz do repo
R3=$(fixture_repo padrao); cd $R3; printf 'x = 1\n' > pkg/deploy.py; git add -A; git commit -qm deploy
bash $SK/scripts/scaffold.sh 001-z >/dev/null
out=$(bash $C "ajustar deploy"); assert_contains "$out" "módulos=1 (deploy)" "deploy sem duplicar"; assert_contains "$out" "Nível: Pequena" "deploy é 1 área"
cd pkg; assert_contains "$(bash $C "ajuste no relatorio")" "módulos=1 (relatorio)" "subdiretório usa a raiz"; cd ..
echo '{quebrado' > .claude/specs/karazhan.json; assert_exit 2 bash $C "ajuste no relatorio"
