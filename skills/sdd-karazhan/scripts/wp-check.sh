#!/usr/bin/env bash
# wp-check.sh WP-NN [--base <ref>] [--tasks <arquivo>] [--tudo]
# Base padrão: feat/<NNN-slug> (slug tirado do caminho do tasks.md) se existir, senão main,
# senão o primeiro commit. Arquivos em .claude/ são ignorados em fora-dos-paths.
# Reúne evidência de uma WP para o Reviewer. Etapas: lint, testes, aceite, dry-run, diff, fora-dos-paths, aceite-intacto.
# aceite roda tests/aceite/test_wp<NN>_*.py da WP (sem eles, tests/aceite inteiro); --tudo força o inteiro (pouso).
# ruff e pytest vêm do .venv do repo, se existir; senão do PATH.
# Cada etapa imprime "== <etapa>", a saída (últimas 30 linhas) e "<etapa>: ok|falha|ausente";
# o rodapé "== resumo" repete uma linha por etapa.
# Exit 0 se nenhuma etapa falhou e nada está fora dos paths, 1 caso contrário,
# 2 se a WP não existe, não tem Possui ou os argumentos são inválidos.
# Executar no worktree da feature (a raiz do git é usada).
. "$(dirname "$0")/../lib/common.sh"
. "$ROOT/lib/tasks.sh"

AJUDA="uso: wp-check.sh WP-NN [--base <ref>] [--tasks <arquivo>] [--tudo]"
case "${1:-}" in -h|--help) usage "$AJUDA" ;; esac
need git
wp=""
base=""
tasks=""
tudo=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage "$AJUDA" ;;
    --base) [ $# -ge 2 ] || die "$AJUDA"; base="$2"; shift 2 ;;
    --tasks) [ $# -ge 2 ] || die "$AJUDA"; tasks="$2"; shift 2 ;;
    --tudo) tudo=1; shift ;;
    -*) die "opção desconhecida: $1
$AJUDA" ;;
    *) [ -z "$wp" ] || die "$AJUDA"; wp="$1"; shift ;;
  esac
done
[ -n "$wp" ] || die "$AJUDA"

top="$(git rev-parse --show-toplevel 2>/dev/null)" || die "não é um repositório git"
# --tasks relativo vale a partir do cwd de origem; resolver antes do cd.
# Barras invertidas (caminho Windows) viram "/" para o slug sair do caminho.
if [ -n "$tasks" ]; then
  tasks="$(printf '%s' "$tasks" | tr '\\' '/')"
  case "$tasks" in /*|[A-Za-z]:*) ;; *) tasks="$PWD/$tasks" ;; esac
fi
cd "$top"

if [ -z "$tasks" ]; then
  achados=""
  n=0
  for f in .claude/specs/current/*/tasks.md; do
    [ -f "$f" ] || continue
    achados="$f"
    n=$((n + 1))
  done
  [ "$n" -eq 1 ] || die "informe --tasks: $n tasks.md em .claude/specs/current/ (esperado exatamente 1)"
  tasks="$achados"
fi
[ -f "$tasks" ] || die "tasks não encontrado: $tasks"

wp_list "$tasks" | grep -qx "$wp" || die "$wp não existe em $tasks"
globs="$(wp_paths "$tasks" "$wp")" || exit 2

# Globs -> pathspecs do git (:(glob), com "dir/" virando "dir/**").
specs=()
while IFS= read -r g; do
  [ -n "$g" ] || continue
  g="${g#./}"
  g="${g#/}"
  case "$g" in */) g="$g**" ;; esac
  specs+=(":(glob)$g")
done <<EOT
$globs
EOT

# Base: --base; senão feat/<slug> (slug do caminho do tasks.md) se existir; senão main;
# se o ref não existir, o primeiro commit.
if [ -z "$base" ]; then
  slug=""
  case "/$tasks" in
    */.claude/specs/current/*/tasks.md)
      slug="/$tasks"
      slug="${slug#*/.claude/specs/current/}"
      slug="${slug%/tasks.md}"
      ;;
  esac
  case "$slug" in */*) slug="" ;; esac
  if [ -n "$slug" ] && git rev-parse --verify -q "feat/$slug^{commit}" >/dev/null 2>&1; then
    base="feat/$slug"
  else
    base="main"
  fi
fi
base_nota=" (base $base)"
if ! git rev-parse --verify -q "$base^{commit}" >/dev/null 2>&1; then
  primeiro="$(git rev-list --max-parents=0 HEAD | tail -1)"
  [ -n "$primeiro" ] || die "repositório sem commits"
  base_nota=" (base $base ausente; usando o primeiro commit ${primeiro:0:7})"
  base="$primeiro"
fi

resumo=""
falhou=0

# etapa <nome> <status> <saída>: imprime cabeçalho, saída e linha de status.
etapa() {
  local nome="$1" status="$2" saida="${3:-}" cab="${4:-}"
  echo "== $nome$cab"
  [ -z "$saida" ] || printf '%s\n' "$saida" | tail -n 30
  echo "$nome: $status"
  resumo="$resumo$nome: $status
"
  [ "$status" != falha ] || falhou=1
  return 0
}

# roda <cmd...>: executa, captura saída e define $saida e $rc (sem abortar com set -e).
roda() {
  rc=0
  saida="$("$@" 2>&1)" || rc=$?
}

# ferramenta <nome>: a do .venv do repo, se existir; senão a do PATH; vazio se nenhuma.
ferramenta() {
  if [ -x ".venv/bin/$1" ]; then
    echo ".venv/bin/$1"
  elif [ -x ".venv/Scripts/$1.exe" ]; then
    echo ".venv/Scripts/$1.exe"
  elif command -v "$1" >/dev/null 2>&1; then
    echo "$1"
  fi
}
ruff_bin="$(ferramenta ruff)"
pytest_bin="$(ferramenta pytest)"

# lint
if [ -n "$ruff_bin" ]; then
  roda "$ruff_bin" check .
  etapa lint "$([ "$rc" -eq 0 ] && echo ok || echo falha)" "$saida"
else
  etapa lint ausente "ruff não encontrado"
fi

# testes
if [ -d tests ] && [ -n "$pytest_bin" ]; then
  # tests/aceite tem etapa própria, filtrada por WP.
  roda "$pytest_bin" -q --ignore=tests/aceite
  # exit 5 = nenhum teste coletado: não há evidência, não é falha.
  case "$rc" in 0) st=ok ;; 5) st=ausente ;; *) st=falha ;; esac
  etapa testes "$st" "$saida"
elif [ -d tests ]; then
  etapa testes ausente "tests/ existe, mas pytest não foi encontrado"
elif [ -f package.json ] && command -v npm >/dev/null 2>&1 \
  && [ "$(jq -r '.scripts.test // empty' package.json 2>/dev/null | tr -d '\r')" != "" ]; then
  roda npm test --silent
  etapa testes "$([ "$rc" -eq 0 ] && echo ok || echo falha)" "$saida"
else
  etapa testes ausente "sem tests/ nem script test em package.json"
fi

# aceite: o oráculo precisa rodar de verdade; skip, xfail ou nada coletado é falha.
# Skip e xfail só contam na linha de resumo do pytest (-rsx), não num caminho com "xfail".
if [ -d tests/aceite ] && [ -n "$pytest_bin" ]; then
  # Arquivos da WP: tests/aceite/test_wp<nn>_*.py (nn = dois dígitos de WP-NN).
  nn="${wp#[Ww][Pp]-}"
  case "$nn" in [0-9][0-9]) ;; *) nn="" ;; esac
  alvo=()
  if [ "$tudo" -eq 0 ] && [ -n "$nn" ]; then
    for f in tests/aceite/test_wp"$nn"_*.py; do
      if [ -f "$f" ]; then alvo+=("$f"); fi
    done
  fi
  if [ "${#alvo[@]}" -gt 0 ]; then
    cab=""
  else
    alvo=(tests/aceite)
    if [ "$tudo" -eq 1 ]; then cab=" (--tudo: tests/aceite inteiro)"; else cab=" (sem arquivo da WP: rodando tests/aceite inteiro)"; fi
  fi
  roda "$pytest_bin" "${alvo[@]}" -rsx -p no:cacheprovider
  st=ok
  [ "$rc" -eq 0 ] || st=falha
  if printf '%s\n' "$saida" | grep -Eq '^(SKIPPED|XFAIL)( |\[)'; then st=falha; fi
  etapa aceite "$st" "$saida" "$cab"
elif [ -d tests/aceite ]; then
  etapa aceite ausente "tests/aceite existe, mas pytest não foi encontrado"
elif grep -q 'tests/aceite' "$(dirname "$tasks")/spec.md" 2>/dev/null; then
  etapa aceite falha "oráculo declarado na spec mas ausente"
else
  etapa aceite ausente "sem tests/aceite"
fi

# dry-run
if [ -f run.sh ] && grep -rq -- '--dry-run' run.sh *.py */*.py 2>/dev/null; then
  # timeout (GNU), gtimeout (coreutils no macOS) ou sem limite, avisado no cabeçalho.
  cab=""
  if command -v timeout >/dev/null 2>&1; then
    roda timeout 120 ./run.sh --dry-run
  elif command -v gtimeout >/dev/null 2>&1; then
    roda gtimeout 120 ./run.sh --dry-run
  else
    roda ./run.sh --dry-run
    cab=" (sem timeout)"
  fi
  etapa dry-run "$([ "$rc" -eq 0 ] && echo ok || echo falha)" "${saida:+$saida
}exit=$rc" "$cab"
else
  etapa dry-run ausente "sem run.sh com --dry-run"
fi

# diff
roda git -c core.quotepath=off diff --stat "$base...HEAD" -- "${specs[@]}"
etapa diff "$([ "$rc" -eq 0 ] && echo ok || echo falha)" "$saida" "$base_nota"

# fora-dos-paths
fora=""
rc=0
saida="$(git -c core.quotepath=off diff --name-only --no-renames "$base...HEAD" 2>/dev/null)" || rc=$?
if [ "$rc" -ne 0 ]; then
  etapa fora-dos-paths falha "$saida"
else
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in .claude/*) continue ;; esac
    dentro=0
    while IFS= read -r g; do
      [ -n "$g" ] || continue
      if glob_match "$g" "$f"; then dentro=1; break; fi
    done <<EOT
$globs
EOT
    [ "$dentro" -eq 1 ] || fora="${fora:+$fora
}$f"
  done <<EOT
$saida
EOT
  if [ -z "$fora" ]; then
    etapa fora-dos-paths ok ""
  else
    etapa fora-dos-paths falha "$fora"
  fi
fi

# aceite-intacto: tests/aceite é do Architect; qualquer mudança na WP reprova.
# Config do pytest também: conftest e arquivos de config poderiam neutralizar o oráculo.
rc=0
saida="$(git -c core.quotepath=off diff --name-only --no-renames "$base...HEAD" -- tests/aceite tests/conftest.py conftest.py pytest.ini pytest.toml .pytest.toml pyproject.toml setup.cfg tox.ini 2>&1)" || rc=$?
if [ "$rc" -eq 0 ] && [ -z "$saida" ]; then
  etapa aceite-intacto ok ""
else
  etapa aceite-intacto falha "$saida"
fi

echo "== resumo"
printf '%s' "$resumo"
exit "$falhou"
