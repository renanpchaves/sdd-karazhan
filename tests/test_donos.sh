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
sed -i 's|pkg/coleta.py, pkg/cli.py|pkg/**, run.sh|' .claude/specs/current/001-x/tasks.md
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
