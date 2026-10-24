. "$(dirname "$0")/lib.sh"; S=$PWD/skills/sdd-karazhan/scripts/mapa-check.sh
R=$(fixture_repo padrao); cd $R; mkdir -p .claude/specs
out=$(bash $S || true); assert_contains "$out" "mapa=ausente esqueleto=padrao" "sem mapa"
assert_exit 0 bash $S --stamp
assert_exit 0 bash $S
echo "novo" > pkg/novo.py; git add -A; git commit -qm novo
assert_exit 1 bash $S; assert_contains "$(bash $S || true)" "vencido-arvore" "árvore mudou"
bash $S --stamp; sed -i 's/date=[0-9-]*/date=2020-01-01/' .claude/specs/mapa.md
assert_contains "$(bash $S || true)" "vencido-idade" "idade"
R2=$(fixture_repo plano); cd $R2; mkdir -p .claude/specs
assert_contains "$(bash $S || true)" "esqueleto=fora" "repo fora do padrão"
