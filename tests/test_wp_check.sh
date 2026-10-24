. "$(dirname "$0")/lib.sh"; SK=$PWD/skills/sdd-karazhan; W=$SK/scripts/wp-check.sh
R=$(fixture_repo padrao); cd $R; bash $SK/scripts/scaffold.sh 001-x >/dev/null
T=.claude/specs/current/001-x/tasks.md
printf '### WP-01 — coleta\n- Dono: eng-grom\n- Possui: pkg/coleta.py\n' > $T
printf 'def test_ok():\n    assert True\n' > tests/test_cli.py
printf '#!/bin/sh\n[ "$1" = --dry-run ] && exit 0\nexit 1\n' > run.sh
git commit -qam preparo
# feat/001-x no commit de preparo; a WP vive numa branch própria por cima dela
git branch feat/001-x; git checkout -qb feat/001-x-WP-01; echo "# coleta" >> pkg/coleta.py; git commit -qam coleta
out=$(bash $W WP-01 --tasks $T); code=$?
assert_eq 0 $code "tudo ok"
assert_contains "$out" "== dry-run" "dry-run rodou"; assert_contains "$out" "== resumo" "resumo"
assert_contains "$out" "dry-run: ok" "dry-run ok"
assert_contains "$out" "== diff (base feat/001-x)" "base padrão é feat/<slug>"
assert_contains "$out" "pkg/coleta.py" "diff só do commit da WP"
case "$out" in *"testes: ok"*|*"testes: ausente"*) ;; *) fail "testes deve ser ok ou ausente: $out" ;; esac
case "$out" in *"testes: falha"*|*"lint: falha"*) fail "etapa falhou: $out" ;; esac
case "$out" in *run.sh*|*test_cli.py*) fail "arquivos do preparo vazaram para a WP: $out" ;; esac
# --base explícito vence
out=$(bash $W WP-01 --tasks $T --base main)
assert_contains "$out" "== diff (base main)" "--base explícito"
# .claude/ é ignorado em fora-dos-paths
echo "- nota" >> $T; git add -f $T; git commit -qm orquestrador
out=$(bash $W WP-01 --tasks $T); code=$?
assert_eq 0 $code ".claude/ ignorado"
assert_contains "$out" "fora-dos-paths: ok" ".claude/ ignorado"
echo "# x" >> pkg/envio.py; git commit -qam fora
out=$(bash $W WP-01 --tasks $T || true)
assert_contains "$out" "pkg/envio.py" "fora dos paths listado"
assert_exit 1 bash $W WP-01 --tasks $T
assert_exit 2 bash $W WP-09 --tasks $T
[ "$(printf '%s\n' "$out" | sed -n '/== resumo/,$p' | wc -l)" -le 21 ] || fail "resumo > 20 linhas"
# tasks por padrão: único feature dir
assert_exit 1 bash $W WP-01
