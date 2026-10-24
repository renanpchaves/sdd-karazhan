#!/usr/bin/env bash
# Helpers de teste compartilhados. Uso: . "$(dirname "$0")/lib.sh"
set -eu

PWD_PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PWD_PLUGIN
cd "$PWD_PLUGIN"
TMP="$(mktemp -d)"
export TMP
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() { # <esperado> <obtido> <msg>
  [ "$1" = "$2" ] || fail "$3 (esperado '$1', obtido '$2')"
}

assert_contains() { # <texto> <trecho> <msg>
  case "$1" in
    *"$2"*) ;;
    *) fail "$3 (trecho '$2' ausente em '$1')" ;;
  esac
}

assert_exit() { # <código> <cmd...>
  local esperado="$1" rc=0
  shift
  "$@" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq "$esperado" ] || fail "exit $rc, esperado $esperado: $*"
}

# sed_i <expr> <arquivo>: edição in-place portátil (sem sed -i, que difere entre GNU e BSD).
sed_i() { sed "$1" "$2" > "$2.tmp" && mv "$2.tmp" "$2"; }

# fixture_repo [padrao|plano] -> cria repo git em $TMP, com commit inicial; imprime o caminho
fixture_repo() {
  local tipo="${1:-padrao}" dir
  dir="$(mktemp -d "$TMP/repo.XXXXXX")"
  (
    cd "$dir"
    git init -q -b main
    git config user.email "teste@example.com"
    git config user.name "Teste"
    git config core.autocrlf false
    # Commits de teste sem assinatura, mesmo com commit.gpgsign global.
    git config commit.gpgsign false
    case "$tipo" in
      padrao)
        mkdir -p pkg tests deploy config
        : > pkg/__init__.py
        for m in cli coleta envio relatorio; do
          printf 'def main():\n    return "%s"\n' "$m" > "pkg/$m.py"
        done
        printf 'from pkg import cli\n\n\ndef test_cli():\n    assert cli.main() == "cli"\n' > tests/test_cli.py
        printf '<?xml version="1.0"?>\n<plist version="1.0"><dict><key>Label</key><string>com.exemplo.x</string></dict></plist>\n' > deploy/com.exemplo.x.plist
        printf '#!/usr/bin/env bash\npython -m pkg.cli\n' > run.sh
        printf '#!/usr/bin/env bash\npip install -r requirements.txt\n' > setup.sh
        printf 'DEBUG = False\n' > config/settings.py
        chmod +x run.sh setup.sh
        ;;
      plano)
        printf 'print("ola")\n' > script.py
        printf '# Projeto plano\n' > README.md
        ;;
      *) echo "fixture_repo: tipo desconhecido '$tipo'" >&2; exit 2 ;;
    esac
    git add -A
    git -c commit.gpgsign=false commit -q -m "inicial"
  )
  echo "$dir"
}
