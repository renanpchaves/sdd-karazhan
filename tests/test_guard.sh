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
# NotebookEdit: caminho em tool_input.notebook_path
nb() { jq -nc --arg c "$R" --arg f "$1" '{tool_name:"NotebookEdit",cwd:$c,tool_input:{notebook_path:$f}}' | bash "$H"; }
assert_exit 0 nb "$R/deploy/n.ipynb"
assert_exit 2 nb "$R/pkg/n.ipynb"
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
assert_exit 0 jq -e '.hooks.PreToolUse[0].matcher == "Edit|Write|MultiEdit|NotebookEdit"' "$PWD_PLUGIN/hooks/hooks.json"
assert_exit 0 jq -e '.hooks.PreToolUse[0].hooks[0].command | startswith("bash ")' "$PWD_PLUGIN/hooks/hooks.json"

# --- correções da revisão ---
cd "$R"
bash "$SK/scripts/guard-install.sh" . eng WP-01 "deploy/**,pkg/coleta.py" >/dev/null
# rename de fora dos paths para dentro não passa
git mv pkg/envio.py deploy/envio.py
assert_exit 1 env SDD_GIT_MANAGER=1 git commit -qm t
assert_contains "$(SDD_GIT_MANAGER=1 git commit -qm t 2>&1 || true)" "bloqueado: pkg/envio.py" "rename bypass"
git reset -q --hard
# cwd em subdiretório do worktree: .sdd-role pela raiz
jc() { jq -nc --arg t "$1" --arg c "$2" --arg f "$3" '{tool_name:$t,cwd:$c,tool_input:{file_path:$f}}'; }
assert_exit 2 bash -c "$(declare -f jc); jc Edit '$R/pkg' '$R/pkg/envio.py' | bash '$H'"
assert_exit 0 bash -c "$(declare -f jc); jc Edit '$R/pkg' '$R/pkg/coleta.py' | bash '$H'"
assert_exit 0 bash -c "$(declare -f jc); jc Edit '$R/pkg' 'coleta.py' | bash '$H'"
assert_exit 2 bash -c "$(declare -f jc); jc Edit '$R/pkg' 'envio.py' | bash '$H'"
# .sdd-role é intocável
assert_exit 2 hook Edit "$R/.sdd-role"
assert_exit 2 hook Write ".sdd-role"
assert_exit 2 hook Edit "./.sdd-role"
assert_contains "$(hook Edit "./.sdd-role" 2>&1 || true)" "path-guard: .sdd-role é protegido" "./.sdd-role protegido"
# jq ausente: bloqueia onde há .sdd-role, libera onde não há
mkdir -p "$TMP/bin"; printf '#!/bin/sh\nexit 127\n' > "$TMP/bin/jq"; chmod +x "$TMP/bin/jq"
assert_exit 2 bash -c "cd '$R' && echo '{}' | PATH='$TMP/bin':\"\$PATH\" bash '$H'"
assert_contains "$(cd "$R" && echo '{}' | PATH="$TMP/bin:$PATH" bash "$H" 2>&1 || true)" "path-guard: jq ausente" "msg jq"
assert_exit 0 bash -c "cd '$TMP' && echo '{}' | PATH='$TMP/bin':\"\$PATH\" bash '$H'"
# path-guard não depende do root= do .sdd-role
sed_i 's|^root=.*|root=/nao/existe|' "$R/.sdd-role"
assert_exit 0 hook Edit "$R/pkg/coleta.py"
assert_exit 2 hook Edit "$R/pkg/envio.py"
# pre-commit com root inválido: bloqueia e orienta
echo "# r" >> pkg/coleta.py; git add pkg/coleta.py
assert_contains "$(SDD_GIT_MANAGER=1 git commit -qm t 2>&1 || true)" "rode guard-install.sh novamente" "root inválido"
git reset -q --hard
# path-guard fail-closed sem lib/tasks.sh (cópia isolada do hook)
mkdir -p "$TMP/iso/hooks"; cp "$H" "$TMP/iso/hooks/path-guard.sh"
assert_exit 2 bash -c "$(declare -f jc); jc Edit '$R' '$R/pkg/coleta.py' | bash '$TMP/iso/hooks/path-guard.sh'"
assert_contains "$(jc Edit "$R" "$R/pkg/coleta.py" | bash "$TMP/iso/hooks/path-guard.sh" 2>&1 || true)" "path-guard: lib/tasks.sh ausente" "msg lib ausente"
bash "$SK/scripts/guard-install.sh" . eng WP-01 "deploy/**,pkg/coleta.py" >/dev/null   # restaura root

# marcador: sobrescreve pre-commit nosso, recusa o de terceiros
bash "$SK/scripts/guard-install.sh" . eng WP-01 "pkg/coleta.py" >/dev/null
assert_exit 0 bash "$SK/scripts/guard-install.sh" . eng WP-01 "pkg/coleta.py"
HK=$(git rev-parse --git-path hooks)/pre-commit
printf '#!/bin/sh\necho outro\n' > "$HK"
assert_exit 2 bash "$SK/scripts/guard-install.sh" . eng WP-01 "pkg/coleta.py"
assert_contains "$(cat "$HK")" "echo outro" "hook de terceiros preservado"
rm -f "$HK"

# worktree vinculado: hook comum, .sdd-role só no worktree guardado
R3=$(fixture_repo padrao); cd "$R3"
git worktree add -q "$TMP/wt" -b feat/x
assert_exit 0 bash "$SK/scripts/guard-install.sh" "$TMP/wt" eng WP-01 "pkg/coleta.py"
cd "$TMP/wt"
echo "# w" >> pkg/coleta.py; git add pkg/coleta.py
assert_exit 1 git commit -qm t
assert_exit 0 env SDD_GIT_MANAGER=1 git commit -qm t
cd "$R3"
echo "# m" >> pkg/envio.py; git add pkg/envio.py
assert_exit 0 git commit -qm t   # sem .sdd-role no worktree principal: no-op

# --- tests/aceite é oráculo do Architect: o Engineer não toca, mesmo com paths=tests/** ---
cd "$R"
bash "$SK/scripts/guard-install.sh" . eng WP-01 "tests/**" >/dev/null
assert_contains "$(cat .sdd-role)" "aceite=tests/aceite/**" "sdd-role aceite"
assert_exit 2 hook Edit "$R/tests/aceite/x.py"
assert_exit 2 hook Write "tests/aceite/sub/y.py"
assert_exit 2 hook MultiEdit "$R/tests/aceite/x.py"
assert_contains "$(hook Edit "$R/tests/aceite/x.py" 2>&1 || true)" "tests/aceite é do Architect" "mensagem hook aceite"
assert_exit 0 hook Edit "$R/tests/test_cli.py"
mkdir -p tests/aceite; echo "# a" > tests/aceite/x.py; git add tests/aceite/x.py
assert_exit 1 env SDD_GIT_MANAGER=1 git commit -qm t
assert_contains "$(SDD_GIT_MANAGER=1 git commit -qm t 2>&1 || true)" "bloqueado: tests/aceite/x.py — tests/aceite é do Architect" "mensagem pre-commit aceite"
git reset -q tests/aceite/x.py; rm -rf tests/aceite
echo "# t" >> tests/test_cli.py; git add tests/test_cli.py
assert_exit 0 env SDD_GIT_MANAGER=1 git commit -qm t
# caminhos não canônicos não contornam o oráculo
cd "$R"
assert_exit 2 hook Edit "$R/tests//aceite/x.py"
assert_exit 2 hook Edit "$R/tests/./aceite/x.py"
assert_exit 2 hook Edit "tests/./aceite//x.py"
assert_exit 2 hook Edit "$R/tests/ACEITE/x.py"
assert_exit 2 hook Write "tests/Aceite/x.py"
assert_contains "$(hook Edit "$R/tests//aceite/x.py" 2>&1 || true)" "tests/aceite é do Architect" "mensagem tests//aceite"
assert_exit 2 nb "$R/tests/aceite/n.ipynb"
assert_exit 0 hook Edit "$R/tests/./test_cli.py"
