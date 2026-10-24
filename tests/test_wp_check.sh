. "$(dirname "$0")/lib.sh"; SK=$PWD/skills/sdd-karazhan; W=$SK/scripts/wp-check.sh
R=$(fixture_repo padrao); cd $R; bash $SK/scripts/scaffold.sh 001-x >/dev/null
printf '### WP-01 — coleta\n- Dono: eng-grom\n- Possui: pkg/coleta.py\n' > .claude/specs/current/001-x/tasks.md
printf 'def test_ok():\n    assert True\n' > tests/test_cli.py
printf '#!/bin/sh\n[ "$1" = --dry-run ] && exit 0\nexit 1\n' > run.sh
git commit -qam preparo
git checkout -qb feat/001-x; echo "# coleta" >> pkg/coleta.py; git commit -qam coleta
out=$(bash $W WP-01 --tasks .claude/specs/current/001-x/tasks.md); code=$?
assert_eq 0 $code "tudo ok"
assert_contains "$out" "== dry-run" "dry-run rodou"; assert_contains "$out" "== resumo" "resumo"
assert_contains "$out" "dry-run: ok" "dry-run ok"
case "$out" in *"testes: ok"*|*"testes: ausente"*) ;; *) fail "testes deve ser ok ou ausente: $out" ;; esac
case "$out" in *"testes: falha"*|*"lint: falha"*) fail "etapa falhou: $out" ;; esac
echo "# x" >> pkg/envio.py; git commit -qam fora
out=$(bash $W WP-01 --tasks .claude/specs/current/001-x/tasks.md || true)
assert_contains "$out" "pkg/envio.py" "fora dos paths listado"
assert_exit 1 bash $W WP-01 --tasks .claude/specs/current/001-x/tasks.md
assert_exit 2 bash $W WP-09 --tasks .claude/specs/current/001-x/tasks.md
[ "$(printf '%s\n' "$out" | sed -n '/== resumo/,$p' | wc -l)" -le 21 ] || fail "resumo > 20 linhas"
# tasks por padrão: único feature dir
assert_exit 1 bash $W WP-01
