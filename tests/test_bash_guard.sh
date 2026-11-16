. "$(dirname "$0")/lib.sh"; SK=$PWD/skills/sdd-karazhan
H=$SK/hooks/bash-guard.sh
R=$(fixture_repo padrao); cd "$R"
bash "$SK/scripts/guard-install.sh" . bld WP-01 "pkg/coleta.py,deploy/**,tests/**" >/dev/null

jb() { jq -nc --arg t "$1" --arg c "$2" --arg x "$3" '{tool_name:$t,cwd:$c,tool_input:{command:$x}}'; }
hook() { jb Bash "$R" "$1" | bash "$H"; }
bloq() { assert_exit 2 hook "$1"; }
livre() { assert_exit 0 hook "$1"; }
msg() { hook "$1" 2>&1 || true; }

# escrita fora dos paths
bloq "sed -i '' 's/a/b/' pkg/envio.py"
bloq "sed -i 's/a/b/' pkg/envio.py"
bloq "sed -i.bak 's/a/b/' pkg/envio.py"
bloq "sed -i -e 's/a/b/' pkg/envio.py"
bloq "sed -E -i '' -e 's/a/b/' pkg/envio.py"
bloq "echo x > pkg/envio.py"
bloq "echo x >> pkg/envio.py"
bloq "ls &> pkg/x.log"
bloq "ls 2> pkg/err.log"
bloq "printf x>pkg/envio.py"
bloq "echo x >| pkg/envio.py"
bloq "echo x | tee pkg/envio.py"
bloq "echo x | tee -a deploy/a pkg/envio.py"
bloq "cp pkg/coleta.py pkg/novo.py"
bloq "mv pkg/coleta.py pkg/novo.py"
bloq "install -m 644 pkg/coleta.py pkg/novo.py"
bloq "cp -t pkg pkg/coleta.py"
# mv: a origem sai do lugar, então também é alvo
bloq "mv pkg/envio.py pkg/coleta.py"
bloq "mv pkg/envio.py deploy/envio.py"
bloq "mv -f pkg/envio.py deploy/"
bloq "mv -t deploy pkg/envio.py"
bloq "mv deploy/a pkg/envio.py deploy/"
assert_contains "$(msg "mv pkg/envio.py deploy/envio.py")" "fora dos paths da WP-01: pkg/envio.py" "mensagem origem do mv"
livre "mv deploy/a deploy/b"
livre "mv -t deploy deploy/sub/a pkg/coleta.py"
livre "mv /tmp/x.py deploy/x.py"
livre "cp pkg/envio.py deploy/envio.py"
bloq "install -d pkg/sub"
bloq "rm pkg/envio.py"
bloq "rm -rf pkg"
bloq "touch pkg/novo.py"
bloq "truncate -s 0 pkg/envio.py"
bloq "ln -s pkg/coleta.py pkg/link.py"
bloq "dd if=/dev/zero of=pkg/envio.py count=1"
bloq "perl -pi -e 's/a/b/' pkg/envio.py"
bloq "perl -i -pe 's/a/b/' pkg/envio.py"
bloq "/usr/bin/sed -i '' 's/a/b/' pkg/envio.py"
# script/código colado à opção (-eSCRIPT, -fFILE, --expression=) não engole o arquivo
bloq "sed -i \"\" -e\"s/a/b/\" .sdd-role"
bloq "sed -i '' -es/a/b/ pkg/envio.py"
bloq "sed -i -e's/a/b/' pkg/envio.py"
bloq "sed -i '' -fscript.sed pkg/envio.py"
bloq "sed -i '' --expression=s/a/b/ pkg/envio.py"
bloq "sed -i '' --expression s/a/b/ pkg/envio.py"
bloq "sed -n -i '' -e s/a/b/ pkg/envio.py"
bloq "sed -ni '' 's/a/b/' pkg/envio.py"
bloq "perl -i -e's/a/b/' pkg/envio.py"
bloq "perl -pi -e's/a/b/' pkg/envio.py"
bloq "perl -i -pes/a/b/ pkg/envio.py"
bloq "perl -Mstrict -pi -e 's/a/b/' pkg/envio.py"
livre "sed -i '' -e's/a/b/' pkg/coleta.py"
livre "sed -e's/a/b/' pkg/envio.py"
livre "perl -Mstrict -e 'print 1' pkg/envio.py"
assert_contains "$(msg "sed -i '' 's/a/b/' pkg/envio.py")" "bash-guard: fora dos paths da WP-01: pkg/envio.py" "mensagem fora dos paths"
# comando composto e bash -c
bloq "true && echo x > pkg/envio.py"
bloq "false || touch pkg/novo.py"
bloq "ls; touch pkg/novo.py"
bloq "cat pkg/coleta.py | tee pkg/envio.py"
bloq "bash -c 'echo x > pkg/envio.py'"
bloq "sh -lc \"rm pkg/envio.py\""
bloq "echo ok > pkg/coleta.py && sed -i '' 's/a/b/' pkg/envio.py"
bloq "FOO=1 caffeinate -i sed -i '' 's/a/b/' pkg/envio.py"
bloq "(cd . && rm pkg/envio.py)"
bloq "echo x
rm pkg/envio.py"
# tests/aceite e .sdd-role
bloq "echo x > tests/aceite/test_wp01_x.py"
bloq "cp pkg/coleta.py tests/aceite/x.py"
bloq "sed -i '' 's/a/b/' tests//aceite/x.py"
assert_contains "$(msg "echo x > tests/aceite/x.py")" "tests/aceite é do Architect" "mensagem aceite"
livre "echo x > tests/test_outro.py"
bloq "echo role=rev > .sdd-role"
bloq "echo 'paths=**' >> ./.sdd-role"
bloq "sed -i '' 's/bld/rev/' .sdd-role"
assert_contains "$(msg "echo role=rev > .sdd-role")" "bash-guard: .sdd-role é protegido" "mensagem .sdd-role"
# fora do worktree
bloq "echo x > /opt/sdd-karazhan-fora/x.txt"
bloq "echo x > ../fora.txt"
bloq "touch pkg/../../fora.txt"
bloq "echo x > /tmp/../etc/x"
# dentro dos paths
livre "echo x > pkg/coleta.py"
livre "echo x >> deploy/novo.txt"
livre "sed -i '' 's/a/b/' pkg/coleta.py"
livre "sed -n 's/a/b/p' pkg/envio.py"
livre "echo x | tee pkg/coleta.py"
livre "cp pkg/envio.py deploy/x"
livre "rm deploy/com.exemplo.x.plist"
livre "echo x > $R/pkg/coleta.py"
assert_exit 0 bash -c "$(declare -f jb); jb Bash '$R/pkg' 'echo x > coleta.py' | bash '$H'"
assert_exit 2 bash -c "$(declare -f jb); jb Bash '$R/pkg' 'echo x > envio.py' | bash '$H'"
# descartes e temporários
livre "grep a pkg/envio.py > /dev/null 2>&1"
livre "ls 2>/dev/null"
livre "echo erro > /dev/stderr"
livre "echo x > /tmp/sdd-guarda.txt"
livre "echo x > /private/tmp/sdd-guarda.txt"
livre "cp pkg/envio.py /tmp/x.py"
T="${TMPDIR:-/tmp}"; livre "echo x > ${T%/}/sdd-guarda.txt"
# leitura e falsos positivos
livre "git status"
livre "ls -la"
livre "bash tests/run.sh 2>&1 | tail -5"
livre "echo erro >&2"
livre "python3 script.py"
livre "echo 'a > pkg/envio.py'"
livre "grep -rn 'rm pkg/envio.py' pkg | head"
livre "echo x # > pkg/envio.py"
livre "echo x > \"\$OUT\""
livre "echo x > ~/x.txt"
livre "cat > pkg/coleta.py <<'EOF'
rm pkg/envio.py
echo y > pkg/envio.py
EOF"
livre "find pkg -name '*.py' | xargs grep a"
# ferramenta que não é Bash e worktree sem .sdd-role
assert_exit 0 bash -c "$(declare -f jb); jb Read '$R' 'echo x > pkg/envio.py' | bash '$H'"
L=$(fixture_repo plano)
assert_exit 0 bash -c "$(declare -f jb); jb Bash '$L' 'echo x > /opt/fora.txt' | bash '$H'"
# jq ausente: bloqueia onde há .sdd-role, libera onde não há
mkdir -p "$TMP/bin"; printf '#!/bin/sh\nexit 127\n' > "$TMP/bin/jq"; chmod +x "$TMP/bin/jq"
assert_exit 2 bash -c "cd '$R' && echo '{}' | PATH='$TMP/bin':\"\$PATH\" bash '$H'"
assert_contains "$(cd "$R" && echo '{}' | PATH="$TMP/bin:$PATH" bash "$H" 2>&1 || true)" "bash-guard: jq ausente" "msg jq"
assert_exit 0 bash -c "cd '$L' && echo '{}' | PATH='$TMP/bin':\"\$PATH\" bash '$H'"
# fail-closed sem lib/ (cópia isolada do hook)
mkdir -p "$TMP/iso/hooks"; cp "$H" "$TMP/iso/hooks/bash-guard.sh"
assert_exit 2 bash -c "$(declare -f jb); jb Bash '$R' 'ls' | bash '$TMP/iso/hooks/bash-guard.sh'"
# Reviewer: nada de escrita, leitura e descarte livres
bash "$SK/scripts/guard-install.sh" . rev WP-01 "" >/dev/null
bloq "echo x > pkg/coleta.py"
bloq "touch pkg/novo.py"
bloq "cp pkg/envio.py pkg/x.py"
bloq "echo x > /opt/fora.txt"
assert_contains "$(msg "echo x > pkg/coleta.py")" "Reviewer não edita arquivos" "mensagem reviewer"
livre "git status"
livre "grep -r a pkg > /dev/null 2>&1"
livre "echo x > /tmp/rev.txt"
# hooks.json: path-guard continua em [0], bash-guard registrado para Bash
assert_exit 0 jq -e '.hooks.PreToolUse[0].matcher == "Edit|Write|MultiEdit|NotebookEdit"' "$PWD_PLUGIN/hooks/hooks.json"
assert_exit 0 jq -e '.hooks.PreToolUse[1].matcher == "Bash" and (.hooks.PreToolUse[1].hooks[0].command | startswith("bash ") and contains("bash-guard.sh"))' "$PWD_PLUGIN/hooks/hooks.json"
