. "$(dirname "$0")/lib.sh"; SK=$PWD/skills/sdd-karazhan
# Worktrees dentro do repo: .worktrees/WP-NN e .worktrees/rev, escondidos pelo info/exclude comum.
R=$(fixture_repo padrao); cd "$R"
bash "$SK/scripts/scaffold.sh" 001-x >/dev/null
printf '### WP-01 — coleta\n- Dono: Grom\n- Possui: pkg/coleta.py\n' > .claude/specs/current/001-x/tasks.md
printf '#!/bin/sh\n[ "$1" = --dry-run ] && exit 0\nexit 1\n' > run.sh
git add -A; git commit -qm preparo; git branch feat/001-x
git worktree add -q .worktrees/WP-01 -b feat/001-x-WP-01 feat/001-x
git worktree add -q --detach .worktrees/rev feat/001-x
EXC="$(git rev-parse --git-path info/exclude)"

# guard-install garante .worktrees/ no exclude comum, uma só vez
assert_exit 0 bash "$SK/scripts/guard-install.sh" .worktrees/WP-01 bld WP-01 "pkg/coleta.py"
assert_exit 0 bash "$SK/scripts/guard-install.sh" .worktrees/WP-01 bld WP-01 "pkg/coleta.py"
assert_exit 0 bash "$SK/scripts/guard-install.sh" .worktrees/rev rev WP-01 ""
assert_eq 1 "$(grep -cxF '.worktrees/' "$EXC")" ".worktrees/ uma vez no exclude"
assert_eq 1 "$(grep -cxF '.sdd-role' "$EXC")" ".sdd-role uma vez no exclude"

# o worktree principal não vê .worktrees/
assert_eq "" "$(git status --porcelain)" "status limpo no principal"
git add -A
assert_eq "" "$(git diff --cached --name-only | grep '^\.worktrees/' || true)" "git add -A não pega .worktrees/"
git reset -q

# sem a linha no exclude, git add -A tentaria embutir o worktree (prova de que a linha é necessária)
R0=$(fixture_repo padrao); cd "$R0"
git worktree add -q .worktrees/WP-01 -b feat/y
echo "# w" >> .worktrees/WP-01/pkg/coleta.py
git add -A 2>/dev/null || true
[ -n "$(git status --porcelain | grep '\.worktrees' || true)" ] || fail "sem exclude, .worktrees/ deveria aparecer"
cd "$R"

# inventario, donos e mapa-check na raiz não enxergam arquivos de .worktrees/
echo "x = 1" > .worktrees/WP-01/pkg/novo_so_no_worktree.py
inv_com="$(bash "$SK/scripts/inventario.sh" | grep '^módulos:')"
case "$inv_com" in *novo_so_no_worktree*) fail "inventario enxergou .worktrees/: $inv_com" ;; esac
RS=$(fixture_repo padrao)
assert_eq "$(cd "$RS" && bash "$SK/scripts/inventario.sh" | grep '^módulos:')" "$inv_com" "módulos iguais com e sem worktree"
cat > .claude/specs/current/001-x/spec.md <<'EOS'
# Spec
## Dentro
- pkg/**
EOS
out=$(bash "$SK/scripts/donos.sh" 001-x || true)
case "$out" in *.worktrees*|*novo_so_no_worktree*) fail "donos enxergou .worktrees/: $out" ;; esac
bash "$SK/scripts/mapa-check.sh" --stamp >/dev/null
echo "y = 2" > .worktrees/WP-01/pkg/outro.py
bash "$SK/scripts/mapa-check.sh" >/dev/null 2>&1 || fail "mapa-check: árvore mudou com arquivo só no worktree"

# ferramentas: pytest e ruff na raiz ignoram .worktrees/
printf 'def test_so_no_worktree():\n    assert True\n' > .worktrees/WP-01/tests/test_so_no_worktree.py
if command -v pytest >/dev/null 2>&1; then
  out=$(pytest --collect-only -q 2>&1 || true)
  case "$out" in *test_so_no_worktree*|*.worktrees*) fail "pytest coletou .worktrees/: $out" ;; esac
  case "$out" in *test_cli*) ;; *) fail "pytest não coletou o teste da raiz: $out" ;; esac
fi
if command -v ruff >/dev/null 2>&1; then
  printf 'import os\n' > .worktrees/WP-01/pkg/lint_so_no_worktree.py
  out=$(ruff check . --no-cache 2>&1 || true)
  case "$out" in *lint_so_no_worktree*|*.worktrees*) fail "ruff listou .worktrees/: $out" ;; esac
  # dentro do worktree aninhado o exclude comum não esconde os arquivos dele mesmo
  out=$(cd "$R/.worktrees/WP-01" && ruff check . --no-cache 2>&1 || true)
  case "$out" in *lint_so_no_worktree*) ;; *) fail "ruff no worktree aninhado não lista os arquivos dele: $out" ;; esac
fi
if command -v pytest >/dev/null 2>&1; then
  out=$(cd "$R/.worktrees/WP-01" && pytest --collect-only -q 2>&1 || true)
  case "$out" in *test_so_no_worktree*) ;; *) fail "pytest no worktree aninhado não coletou o teste dele: $out" ;; esac
fi

# path-guard com cwd no worktree aninhado
H=$SK/hooks/path-guard.sh
WT="$R/.worktrees/WP-01"
jh() { jq -nc --arg t Edit --arg c "$WT" --arg f "$1" '{tool_name:$t,cwd:$c,tool_input:{file_path:$f}}' | bash "$H"; }
assert_exit 2 jh "$R/pkg/envio.py"                       # raiz do repo, fora do worktree aninhado
assert_exit 2 jh "$R/pkg/coleta.py"                      # nem os paths da WP valem fora do worktree
assert_exit 2 jh "../../pkg/envio.py"
assert_exit 0 jh "$WT/pkg/coleta.py"
assert_exit 0 jh "pkg/coleta.py"
assert_exit 2 jh "$WT/pkg/envio.py"
assert_exit 2 jh "$WT/.sdd-role"
# a raiz do repo não tem .sdd-role: livre
assert_exit 0 bash -c "jq -nc --arg c '$R' --arg f '$R/pkg/envio.py' '{tool_name:\"Edit\",cwd:\$c,tool_input:{file_path:\$f}}' | bash '$H'"

# pre-commit no worktree aninhado vale; no principal é no-op
cd "$WT"; echo "# w" >> pkg/envio.py; git add pkg/envio.py
assert_exit 1 env SDD_GIT_MANAGER=1 git commit -qm t
git reset -q pkg/envio.py; git checkout -q pkg/envio.py
echo "# w" >> pkg/coleta.py
assert_exit 0 env SDD_GIT_MANAGER=1 git commit -qam t

# wp-check dentro de .worktrees/WP-01: base feat/<slug>
out=$(bash "$SK/scripts/wp-check.sh" WP-01 --tasks "$R/.claude/specs/current/001-x/tasks.md" || true)
assert_contains "$out" "== diff (base feat/001-x)" "wp-check: base feat/<slug> no worktree aninhado"
assert_contains "$out" "pkg/coleta.py" "wp-check: diff da WP"
assert_contains "$out" "fora-dos-paths: ok" "wp-check: fora-dos-paths ok"

# pasta aninhada que não é worktree: guard-install recusa em vez de guardar o principal
R2=$(fixture_repo padrao); cd "$R2"
mkdir -p .worktrees/WP-02
assert_exit 2 bash "$SK/scripts/guard-install.sh" .worktrees/WP-02 bld WP-02 "pkg/coleta.py"
[ ! -e .sdd-role ] || fail "guard-install gravou .sdd-role no principal"

# exclude sem \n final: a linha nova não cola na última
R3=$(fixture_repo padrao); cd "$R3"
E3="$(git rev-parse --git-path info/exclude)"; mkdir -p "$(dirname "$E3")"; printf '*.log' > "$E3"
assert_exit 0 bash "$SK/scripts/guard-install.sh" . bld WP-01 "pkg/coleta.py"
assert_eq 1 "$(grep -cxF '*.log' "$E3")" "padrão do usuário preservado"
assert_eq 1 "$(grep -cxF '.sdd-role' "$E3")" ".sdd-role em linha própria"
