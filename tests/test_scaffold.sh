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

# --- .claude/specs/.gitignore próprio: estado local fora do git, ledger versionado ---
LOCAIS="equipe.md painel.md karazhan.json mapa.md bloqueios.md"
R3=$(fixture_repo padrao); cd "$R3"
printf '.venv/\n' > .gitignore; git add .gitignore; git commit -qm gi
GI=.claude/specs/.gitignore
out=$(bash $S 001-x); assert_contains "$out" "criado: $GI" "cria .gitignore dos specs"
for f in $LOCAIS; do assert_eq 1 "$(grep -cxF "$f" $GI)" "$f uma vez em $GI"; done
assert_eq 5 "$(grep -c . $GI)" "só as 5 linhas"
bash $S 001-x >/dev/null
for f in $LOCAIS; do assert_eq 1 "$(grep -cxF "$f" $GI)" "$f não duplica"; done
assert_eq ".venv/" "$(cat .gitignore)" ".gitignore da raiz intocado"
echo "# estado" > .claude/specs/painel.md; echo "# m" > .claude/specs/mapa.md
echo "## d" >> .claude/specs/decisoes.md
status="$(git status --porcelain -uall)"
for f in $LOCAIS; do case "$status" in *".claude/specs/$f"*) fail "$f aparece no git status: $status" ;; esac; done
for f in .claude/specs/.gitignore .claude/specs/current/001-x/spec.md .claude/specs/current/001-x/tasks.md .claude/specs/decisoes.md; do
  assert_contains "$status" "$f" "$f versionável"
done
# .gitignore pré-existente com linhas próprias (sem newline final) é preservado; só faltantes entram
R4=$(fixture_repo plano); cd "$R4"; mkdir -p .claude/specs
printf 'meu-arquivo.txt\nequipe.md' > $GI
bash $S 001-x >/dev/null
assert_eq 1 "$(grep -cxF 'meu-arquivo.txt' $GI)" "linha própria preservada"
for f in $LOCAIS; do assert_eq 1 "$(grep -cxF "$f" $GI)" "$f uma vez (pré-existente)"; done
assert_eq 6 "$(grep -c . $GI)" "própria + 5"
# o ledger não carrega nome de personagem: template com papel, decisoes com autor = papel
tasks="$(cat .claude/specs/current/001-x/tasks.md)"
assert_contains "$tasks" "- Dono: Builder" "template com papel"
case "$tasks" in *"Dono: <Nome>"*) fail "template ainda pede nome" ;; esac
assert_contains "$(cat .claude/specs/decisoes.md)" "data · papel · decisão" "decisoes com papel como autor"
