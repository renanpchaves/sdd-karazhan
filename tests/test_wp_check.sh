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
# --tasks com barras invertidas (caminho Windows) ainda dá base feat/<slug>
if command -v cygpath >/dev/null 2>&1; then TW=$(cygpath -w "$R/$T"); else TW=$(printf '%s' "$R/$T" | tr '/' '\\'); fi
case "$TW" in *'\'*) ;; *) fail "caminho de teste sem barra invertida: $TW" ;; esac
assert_contains "$(bash $W WP-01 --tasks "$TW" || true)" "== diff (base feat/001-x)" "--tasks Windows"
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
# ruff e pytest do .venv do repo vencem os do PATH
mkdir -p .venv/bin
printf '#!/bin/sh\necho ruff-do-venv\n' > .venv/bin/ruff
printf '#!/bin/sh\necho pytest-do-venv\n' > .venv/bin/pytest
chmod +x .venv/bin/ruff .venv/bin/pytest
out=$(bash $W WP-01 --tasks $T || true)
assert_contains "$out" "ruff-do-venv" "ruff do .venv"; assert_contains "$out" "lint: ok" "lint pelo .venv"
assert_contains "$out" "pytest-do-venv" "pytest do .venv"; assert_contains "$out" "testes: ok" "testes pelo .venv"
rm -rf .venv
# sem timeout nem gtimeout: dry-run sem limite, avisado no cabeçalho; gtimeout entra se existir
mkdir -p "$TMP/semto"
for c in git dirname tr tail head grep awk sed cat; do
  p=$(command -v $c); printf '#!/bin/sh\nexec "%s" "$@"\n' "$p" > "$TMP/semto/$c"; chmod +x "$TMP/semto/$c"
done
out=$(PATH="$TMP/semto" "$BASH" $W WP-01 --tasks $T || true)
assert_contains "$out" "== dry-run (sem timeout)" "sem timeout avisado"
assert_contains "$out" "dry-run: ok" "dry-run sem timeout roda"
printf '#!/bin/sh\necho via-gtimeout\nshift\nexec "$@"\n' > "$TMP/semto/gtimeout"; chmod +x "$TMP/semto/gtimeout"
out=$(PATH="$TMP/semto" "$BASH" $W WP-01 --tasks $T || true)
assert_contains "$out" "via-gtimeout" "gtimeout usado"
case "$out" in *"(sem timeout)"*) fail "gtimeout presente, mas cabeçalho diz sem timeout" ;; esac

# --- aceite-intacto ---
git checkout -q feat/001-x-WP-01 2>/dev/null || true
git checkout -qb feat/001-x-WP-02 feat/001-x
printf '### WP-01 — coleta\n- Dono: eng-grom\n- Possui: pkg/coleta.py, tests/**\n' > $T
git add -f $T; git commit -qm tasks2
git branch -f feat/001-x
echo "# c2" >> pkg/coleta.py; git commit -qam coleta2
out=$(bash $W WP-01 --tasks $T); code=$?
assert_eq 0 $code "aceite intacto: exit 0"
assert_contains "$out" "aceite-intacto: ok" "aceite-intacto ok"
assert_eq 7 "$(printf '%s\n' "$out" | sed -n '/== resumo/,$p' | tail -n +2 | wc -l | tr -d ' ')" "resumo com 7 linhas"
assert_contains "$out" "aceite: ausente" "sem tests/aceite: ausente"
mkdir -p tests/aceite; printf 'def test_x():\n    assert True\n' > tests/aceite/test_x.py
git add tests/aceite/test_x.py; git commit -qm aceite
out=$(bash $W WP-01 --tasks $T || true)
assert_contains "$out" "aceite-intacto: falha" "aceite-intacto falha"
if command -v pytest >/dev/null 2>&1; then assert_contains "$out" "aceite: ok" "oráculo roda e passa"; fi
assert_contains "$out" "tests/aceite/test_x.py" "arquivo de aceite listado"
assert_exit 1 bash $W WP-01 --tasks $T
# config do pytest vigiada
git checkout -qb feat/001-x-WP-03 feat/001-x
printf '# conftest\n' > tests/conftest.py; git add tests/conftest.py; git commit -qm conftest
out=$(bash $W WP-01 --tasks $T || true)
assert_contains "$out" "aceite-intacto: falha" "conftest vigiado"
assert_contains "$out" "tests/conftest.py" "conftest listado"
assert_exit 1 bash $W WP-01 --tasks $T
for cfg in pytest.toml .pytest.toml; do
  git checkout -qb "feat/001-x-cfg$cfg" feat/001-x
  printf '[pytest]\n' > $cfg; git add -f $cfg; git commit -qm "$cfg"
  out=$(bash $W WP-01 --tasks $T || true)
  assert_contains "$out" "aceite-intacto: falha" "$cfg vigiado"
  assert_contains "$out" "$cfg" "$cfg listado"
done
# oráculo com skip não vale
if command -v pytest >/dev/null 2>&1; then
  git checkout -qb feat/001-x-WP-04 feat/001-x
  mkdir -p tests/aceite
  printf 'import pytest\n\n\n@pytest.mark.skip(reason="x")\ndef test_a():\n    assert False\n' > tests/aceite/test_a.py
  git add tests/aceite/test_a.py; git commit -qm skip
  out=$(bash $W WP-01 --tasks $T || true)
  assert_contains "$out" "aceite: falha" "skip no oráculo é falha"
  assert_exit 1 bash $W WP-01 --tasks $T
  # sem nenhum teste coletado também é falha
  git checkout -qb feat/001-x-WP-05 feat/001-x
  mkdir -p tests/aceite; printf '# vazio\n' > tests/aceite/helper.py
  git add tests/aceite/helper.py; git commit -qm vazio
  out=$(bash $W WP-01 --tasks $T || true)
  assert_contains "$out" "aceite: falha" "nada coletado é falha"
  # "xfail" no caminho não é xfail: só a linha de resumo do pytest conta
  git checkout -qb feat/001-x-WP-06 feat/001-x
  mkdir -p tests/aceite; printf 'def test_regra():\n    assert True\n' > tests/aceite/test_xfail_regra.py
  git add tests/aceite/test_xfail_regra.py; git commit -qm xfail-no-nome
  out=$(bash $W WP-01 --tasks $T || true)
  assert_contains "$out" "aceite: ok" "xfail no caminho não é falha"
  # xfail de verdade continua falha
  git checkout -qb feat/001-x-WP-07 feat/001-x
  mkdir -p tests/aceite
  printf 'import pytest\n\n\n@pytest.mark.xfail(reason="x")\ndef test_b():\n    assert False\n' > tests/aceite/test_b.py
  git add tests/aceite/test_b.py; git commit -qm xfail
  out=$(bash $W WP-01 --tasks $T || true)
  assert_contains "$out" "aceite: falha" "xfail no oráculo é falha"
fi
# spec cita tests/aceite, mas o diretório não existe: falha, não ausente
git checkout -qb feat/001-x-WP-08 feat/001-x
rm -rf tests/aceite  # sobras não rastreadas (__pycache__) dos ramos anteriores
printf '\nAceite em `tests/aceite/test_001_x.py`.\n' >>.claude/specs/current/001-x/spec.md
out=$(bash $W WP-01 --tasks $T || true)
assert_contains "$out" "aceite: falha" "oráculo da spec ausente é falha"
assert_contains "$out" "oráculo declarado na spec mas ausente" "motivo da falha"
assert_exit 1 bash $W WP-01 --tasks $T
