. "$(dirname "$0")/lib.sh"; S=$PWD/skills/sdd-karazhan/scripts/mapa-check.sh
R=$(fixture_repo padrao); cd $R; mkdir -p .claude/specs
out=$(bash $S || true); assert_contains "$out" "mapa=ausente esqueleto=padrao" "sem mapa"
assert_exit 0 bash $S --stamp
assert_exit 0 bash $S
echo "novo" > pkg/novo.py; git add -A; git commit -qm novo
assert_exit 1 bash $S; assert_contains "$(bash $S || true)" "vencido-arvore" "árvore mudou"
bash $S --stamp >/dev/null; sed_i 's/date=[0-9-]*/date=2020-01-01/' .claude/specs/mapa.md
assert_contains "$(bash $S || true)" "vencido-idade" "idade"
R2=$(fixture_repo plano); cd $R2; mkdir -p .claude/specs
assert_contains "$(bash $S || true)" "esqueleto=fora" "repo fora do padrão"
# fingerprint ignora .claude/: versionar o mapa e arquivos de specs não invalida
R3=$(fixture_repo padrao); cd $R3; mkdir -p .claude/specs
bash $S --stamp >/dev/null; git add -A; git commit -qm mapa
assert_contains "$(bash $S || true)" "mapa=ok" "mapa versionado segue ok"
echo "x" > .claude/specs/decisoes.md; git add -A; git commit -qm specs
assert_exit 0 bash $S
echo "novo" > pkg/novo.py; git add -A; git commit -qm novo
assert_contains "$(bash $S || true)" "vencido-arvore" "arquivo fora de .claude/ invalida"
# brain_dir: mapa vai para <brain_dir>/repos/<nome>.md
R4=$(fixture_repo padrao); cd $R4; mkdir -p .claude/specs
printf '{"presets":{},"config":{},"brain_dir":"%s"}\n' "$TMP/brain" > .claude/specs/karazhan.json
bash $S --stamp >/dev/null
M="$TMP/brain/repos/$(basename "$R4").md"
[ -f "$M" ] || fail "mapa do brain_dir não criado: $M"
assert_contains "$(head -n1 "$M")" "<!-- karazhan fingerprint=" "primeira linha do mapa no brain"
assert_exit 0 bash $S
# subdiretório: usa a raiz do repo (carimbo e saída iguais aos da raiz)
R5=$(fixture_repo padrao); cd $R5; mkdir -p .claude/specs
(cd pkg && bash $S --stamp >/dev/null)
[ -f .claude/specs/mapa.md ] || fail "--stamp de subdiretório não gravou na raiz"
[ ! -e pkg/.claude ] || fail "--stamp de subdiretório gravou em pkg/"
assert_contains "$(cd pkg && bash $S)" "mapa=ok esqueleto=padrao" "subdiretório ok"
assert_eq "$(bash $S)" "$(cd pkg && bash $S)" "subdiretório igual à raiz"
# fora de repo git: exit 2
assert_exit 2 bash -c "cd '$TMP' && bash '$S'"
