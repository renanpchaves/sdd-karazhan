. "$(dirname "$0")/lib.sh"; S=$PWD/skills/sdd-karazhan/scripts/scaffold.sh
R=$(fixture_repo plano); cd $R
assert_exit 2 bash $S "Login"
assert_exit 0 bash $S 001-login
for f in current/001-login/spec.md current/001-login/tasks.md bloqueios.md decisoes.md equipe.md karazhan.json; do [ -f .claude/specs/$f ] || fail "falta $f"; done
echo "x" >> .claude/specs/decisoes.md
out=$(bash $S 001-login); assert_contains "$out" "mantido: .claude/specs/decisoes.md" "idempotente"
assert_eq "x" "$(tail -n1 .claude/specs/decisoes.md)" "não sobrescreve"
assert_exit 0 jq -e '.brain_dir == null' .claude/specs/karazhan.json
