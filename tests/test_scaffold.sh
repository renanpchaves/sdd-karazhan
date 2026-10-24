. "$(dirname "$0")/lib.sh"; S=$PWD/skills/sdd-karazhan/scripts/scaffold.sh
R=$(fixture_repo plano); cd $R
assert_exit 2 bash $S "Login"
assert_exit 0 bash $S 001-login
for f in current/001-login/spec.md current/001-login/tasks.md bloqueios.md decisoes.md equipe.md karazhan.json; do [ -f .claude/specs/$f ] || fail "falta $f"; done
echo "x" >> .claude/specs/decisoes.md
out=$(bash $S 001-login); assert_contains "$out" "mantido: .claude/specs/decisoes.md" "idempotente"
assert_eq "x" "$(tail -n1 .claude/specs/decisoes.md)" "não sobrescreve"
assert_exit 0 jq -e '.brain_dir == null' .claude/specs/karazhan.json
# subdiretório: cria na raiz e imprime caminhos relativos à raiz
R2=$(fixture_repo padrao); cd $R2/pkg
out=$(bash $S 002-sub)
assert_contains "$out" "criado: .claude/specs/current/002-sub/spec.md" "caminho relativo à raiz"
[ -f $R2/.claude/specs/current/002-sub/spec.md ] || fail "scaffold de subdiretório não criou na raiz"
[ ! -e $R2/pkg/.claude ] || fail "scaffold de subdiretório criou em pkg/"
assert_exit 2 bash -c "cd '$TMP' && bash '$S' 003-x"
