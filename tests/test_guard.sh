. "$(dirname "$0")/lib.sh"; SK=$PWD/skills/sdd-karazhan
R=$(fixture_repo padrao); cd "$R"
assert_exit 0 bash "$SK/scripts/guard-install.sh" . eng WP-01 "pkg/coleta.py,deploy/**"
assert_contains "$(cat .sdd-role)" "paths=pkg/coleta.py,deploy/**" "sdd-role paths"
assert_contains "$(cat .sdd-role)" "root=$SK" "sdd-role root"
assert_contains "$(cat "$(git rev-parse --git-path info/exclude)")" ".sdd-role" "exclude"
assert_eq "" "$(git status --porcelain)" ".sdd-role fora do status"
echo "# ok" >> pkg/coleta.py; git add pkg/coleta.py
assert_exit 1 git commit -qm t                          # sem SDD_GIT_MANAGER
assert_contains "$(git commit -qm t 2>&1 || true)" "commit só pelo Git Manager" "mensagem sem manager"
SDD_GIT_MANAGER=1 git commit -qm t; assert_eq 0 $? "git manager commita"
echo "# x" >> pkg/envio.py; git add pkg/envio.py
assert_exit 1 env SDD_GIT_MANAGER=1 git commit -qm t    # fora dos paths
assert_contains "$(SDD_GIT_MANAGER=1 git commit -qm t 2>&1 || true)" "bloqueado: pkg/envio.py fora dos paths da WP-01" "mensagem fora dos paths"
git reset -q pkg/envio.py; git checkout -q pkg/envio.py
# hook compartilhado e sem .sdd-role: no-op
rm .sdd-role
echo "# y" >> pkg/envio.py; git add pkg/envio.py
assert_exit 0 git commit -qm t
bash "$SK/scripts/guard-install.sh" . eng WP-01 "pkg/coleta.py,deploy/**" >/dev/null

# path-guard
H=$SK/hooks/path-guard.sh
j() { jq -nc --arg t "$1" --arg c "$R" --arg f "$2" '{tool_name:$t,cwd:$c,tool_input:{file_path:$f}}'; }
hook() { j "$@" | bash "$H"; }
assert_exit 0 hook Edit "$R/pkg/coleta.py"
assert_exit 0 hook Edit "pkg/coleta.py"
assert_exit 0 hook MultiEdit "$R/deploy/sub/x.plist"
assert_exit 0 hook Edit "$R\pkg\coleta.py"
assert_exit 2 hook Edit "$R/pkg/envio.py"
assert_exit 2 hook Write "pkg/envio.py"
assert_exit 2 hook Edit "pkg/../pkg/coleta.py"
assert_exit 2 hook Edit "/pkg/coleta.py"
assert_exit 0 hook Read "$R/pkg/envio.py"
assert_contains "$(hook Edit "$R/pkg/envio.py" 2>&1 || true)" "fora dos paths da WP-01: pkg/envio.py" "mensagem path-guard"
if command -v cygpath >/dev/null 2>&1; then
  W=$(cygpath -w "$R")
  assert_exit 0 bash -c "jq -nc --arg c '$W' --arg f '$W\pkg\coleta.py' '{tool_name:\"Edit\",cwd:\$c,tool_input:{file_path:\$f}}' | bash '$H'"
  assert_exit 2 bash -c "jq -nc --arg c '$W' --arg f '$W\pkg\envio.py' '{tool_name:\"Edit\",cwd:\$c,tool_input:{file_path:\$f}}' | bash '$H'"
fi
(cd "$TMP" && assert_exit 0 bash -c "echo '{\"tool_name\":\"Edit\",\"cwd\":\"$TMP\",\"tool_input\":{\"file_path\":\"x\"}}' | bash '$H'")  # sem .sdd-role
bash "$SK/scripts/guard-install.sh" . rev WP-01 "" >/dev/null
assert_exit 2 hook Write "$R/pkg/coleta.py"
assert_contains "$(hook Write "$R/pkg/coleta.py" 2>&1 || true)" "Reviewer não edita arquivos" "mensagem reviewer"
echo "# z" >> pkg/coleta.py; git add pkg/coleta.py
assert_exit 1 env SDD_GIT_MANAGER=1 git commit -qm t    # reviewer não commita
git reset -q pkg/coleta.py; git checkout -q pkg/coleta.py

# hooksPath existente
R2=$(fixture_repo plano); cd "$R2"; git config core.hooksPath .husky
assert_exit 2 bash "$SK/scripts/guard-install.sh" . eng WP-01 "script.py"
assert_contains "$(bash "$SK/scripts/guard-install.sh" . eng WP-01 script.py 2>&1 || true)" "core.hooksPath já definido em .husky" "hooksPath msg"
assert_eq 0 "$(ls -A .git/hooks | grep -c '^pre-commit$' || true)" "nada instalado"
assert_exit 0 jq -e '.hooks.PreToolUse[0].matcher == "Edit|Write|MultiEdit"' "$PWD_PLUGIN/hooks/hooks.json"
