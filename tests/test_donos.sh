. "$(dirname "$0")/lib.sh"; S=$PWD/skills/sdd-karazhan/scripts/donos.sh
R=$(fixture_repo padrao); cd $R; bash $PWD_PLUGIN/skills/sdd-karazhan/scripts/scaffold.sh 001-x >/dev/null
cat > .claude/specs/current/001-x/spec.md <<'EOS'
# Spec
## Dentro
- pkg/**
- run.sh
- deploy/**
EOS
cat > .claude/specs/current/001-x/tasks.md <<'EOS'
### WP-01 — coleta
- Dono: eng-grom
- Possui: pkg/coleta.py, pkg/cli.py
### WP-02 — deploy
- Dono: eng-cairne
- Possui: deploy/**
EOS
out=$(bash $S 001-x || true)
assert_contains "$out" "orfaos: 4" "init, envio, relatorio, run.sh sem dono"
assert_contains "$out" "run.sh" "run.sh órfão"
assert_exit 1 bash $S 001-x
sed_i 's|pkg/coleta.py, pkg/cli.py|pkg/**, run.sh|' .claude/specs/current/001-x/tasks.md
assert_exit 0 bash $S 001-x
printf '### WP-03 — dup\n- Dono: eng-baine\n- Possui: pkg/cli.py\n' >> .claude/specs/current/001-x/tasks.md
assert_contains "$(bash $S 001-x || true)" "duplicados: 1" "dois donos"
assert_contains "$(bash $S 001-x || true)" "pkg/cli.py (WP-01, WP-03)" "dono duplicado nomeado"
printf '### WP-04 — quebrada\n- Dono: eng-magni\n' >> .claude/specs/current/001-x/tasks.md
assert_exit 2 bash $S 001-x
assert_contains "$(bash $S 001-x 2>&1 || true)" "WP-04 sem campo Possui" "mensagem nomeia a WP"

# lib/tasks.sh: glob_match e parsing (ignora comentário HTML do template)
. "$PWD_PLUGIN/skills/sdd-karazhan/lib/tasks.sh"
assert_exit 0 glob_match 'pkg/**' pkg/a.py
assert_exit 0 glob_match 'pkg/**' pkg/sub/b.py
assert_exit 1 glob_match 'pkg/**' tests/a.py
assert_exit 1 glob_match 'pkg/**' pkgx/a.py
assert_exit 0 glob_match 'deploy/*.plist' deploy/x.plist
assert_exit 1 glob_match 'deploy/*.plist' deploy/sub/x.plist
assert_exit 0 glob_match 'run.sh' run.sh
assert_exit 1 glob_match 'run.sh' runxsh
assert_exit 0 glob_match '**/x.py' x.py
assert_exit 0 glob_match '**/x.py' a/b/x.py
assert_exit 0 glob_match 'a?.py' ab.py
assert_exit 1 glob_match 'a?.py' a/.py
bash $PWD_PLUGIN/skills/sdd-karazhan/scripts/scaffold.sh 002-y >/dev/null
assert_eq "" "$(wp_list .claude/specs/current/002-y/tasks.md)" "template comentado não gera WP fantasma"
assert_eq "WP-01 WP-02 WP-03 WP-04" "$(wp_list .claude/specs/current/001-x/tasks.md | tr '\n' ' ' | sed 's/ $//')" "wp_list"
assert_eq "eng-baine" "$(wp_field .claude/specs/current/001-x/tasks.md WP-03 Dono)" "wp_field"
assert_eq "pkg/**|run.sh" "$(wp_paths .claude/specs/current/001-x/tasks.md WP-01 | tr '\n' '|' | sed 's/|$//')" "wp_paths"

# glob_match: normalização de barras
assert_exit 0 glob_match 'pkg/' pkg/a.py
assert_exit 0 glob_match './pkg/**' pkg/a.py
assert_exit 0 glob_match '/pkg/**' ./pkg/a.py
assert_exit 1 glob_match 'pkg/' tests/a.py

# wp_paths ignora crases
printf '### WP-09 — crase\n- Possui: `pkg/**`, `run.sh`\n' > $TMP/crase.md
assert_eq "pkg/**|run.sh" "$(wp_paths $TMP/crase.md WP-09 | tr '\n' '|' | sed 's/|$//')" "wp_paths sem crases"

# Dentro vazio (template do scaffold, só comentário) -> exit 2
T=.claude/specs/current/002-y
printf '### WP-01 — a\n- Possui: pkg/**\n' > $T/tasks.md
assert_exit 2 bash $S 002-y
assert_contains "$(bash $S 002-y 2>&1 || true)" "spec sem itens em ## Dentro" "mensagem de Dentro vazio"

# Arquivo planejado (sem metacaractere, fora do git) vira órfão; glob sem casamento só avisa
D=.claude/specs/current/001-x
printf '### WP-01 — tudo\n- Possui: pkg/**, run.sh, deploy/**\n' > $D/tasks.md
printf '## Dentro\n- pkg/**\n- run.sh\n- deploy/**\n- nada/**\n' > $D/spec.md
assert_exit 0 bash $S 001-x
assert_contains "$(bash $S 001-x 2>&1 >/dev/null || true)" "aviso: nenhum arquivo casa nada/**" "aviso de glob sem casamento"
printf '## Dentro\n- pkg/**\n- pkg/novo.py\n' > $D/spec.md
printf '### WP-01 — pkg\n- Possui: pkg/cli.py\n' > $D/tasks.md
out=$(bash $S 001-x || true)
assert_contains "$out" "  pkg/novo.py" "arquivo planejado aparece como órfão"
printf '### WP-01 — pkg\n- Possui: pkg/**\n' > $D/tasks.md
assert_exit 0 bash $S 001-x
printf '### WP-01 — pkg\n- Possui: pkg/**\n### WP-02 — novo\n- Possui: pkg/novo.py\n' > $D/tasks.md
assert_contains "$(bash $S 001-x || true)" "pkg/novo.py (WP-01, WP-02)" "planejado com dois donos"

# Nomes acentuados saem literais (core.quotepath=off)
mkdir -p docs && printf 'x\n' > "docs/relatório.md"
git add -A && git -c commit.gpgsign=false commit -q -m acento
printf '## Dentro\n- docs/**\n' > $D/spec.md
printf '### WP-01 — x\n- Possui: pkg/**\n' > $D/tasks.md
out=$(bash $S 001-x || true)
assert_contains "$out" "  docs/relatório.md" "acento literal na lista de órfãos"

# subdiretório: mesma saída que na raiz
assert_eq "$out" "$(cd pkg && bash $S 001-x || true)" "subdiretório usa a raiz"
