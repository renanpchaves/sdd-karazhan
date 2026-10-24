#!/usr/bin/env bash
# convocar.sh "<pedido>" [grande] [papel ...]
# Lê sinais determinísticos do repo e imprime a folha de convocação (seis linhas + Presets:).
# Sem papéis: dimensiona pelo pedido. Com papéis (orch|arch|rec|eng|rev|git ou nome longo):
# monta exatamente esses, valida dependências (eng exige git; rev exige eng) e sai 2 se violadas.
# "grande" força o nível Grande. Exit 0 sempre que a folha sai. Executar na raiz do repo alvo.
. "$(dirname "$0")/../lib/common.sh"

AJUDA='uso: convocar.sh "<pedido>" [grande] [orch|arch|rec|eng|rev|git ...], executado na raiz do repo alvo'
case "${1:-}" in
  -h|--help) usage "$AJUDA" ;;
  "") die "$AJUDA" ;;
esac
need jq git
git rev-parse --show-toplevel >/dev/null 2>&1 || die "não é um repositório git"

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
pedido="$1"
shift

# --- argumentos nominais ---
grande=0
nominal=""
tem_papel() { case " $nominal " in *" $1 "*) return 0 ;; esac; return 1; }
for a in "$@"; do
  case "$(printf '%s' "$a" | tr '[:upper:]' '[:lower:]')" in
    grande) grande=1; continue ;;
    orch|orchestrator) p=orch ;;
    arch|architect) p=arch ;;
    rec|recon) p=rec ;;
    eng|engineer) p=eng ;;
    rev|reviewer) p=rev ;;
    git|git-manager) p=git ;;
    *) die "papel desconhecido: $a (use orch|arch|rec|eng|rev|git ou grande)" ;;
  esac
  tem_papel "$p" || nominal="$nominal $p"
done
if [ -n "$nominal" ]; then
  if tem_papel eng && ! tem_papel git; then die "Engineer exige Git Manager"; fi
  if tem_papel rev && ! tem_papel eng; then die "Reviewer exige Engineer"; fi
fi

tmpd="$(mktemp -d)"
trap 'rm -rf "$tmpd"' EXIT

# normalizar_fluxo (stdin): minúsculas, sem acento. sed cobre o português de forma determinística;
# iconv, se existir, translitera o resto (no macOS/Git Bash deixa marcas como ' e ~, removidas no tr).
normalizar_fluxo() {
  sed 's/á/a/g;s/à/a/g;s/â/a/g;s/ã/a/g;s/é/e/g;s/ê/e/g;s/í/i/g;s/ó/o/g;s/ô/o/g;s/õ/o/g;s/ú/u/g;s/ç/c/g;s/Á/A/g;s/À/A/g;s/Â/A/g;s/Ã/A/g;s/É/E/g;s/Ê/E/g;s/Í/I/g;s/Ó/O/g;s/Ô/O/g;s/Õ/O/g;s/Ú/U/g;s/Ç/C/g' |
    if command -v iconv >/dev/null 2>&1; then iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null || true; else cat; fi |
    tr -d "'\"\`^~" | tr '[:upper:]' '[:lower:]'
}
normalizar() { printf '%s' "$1" | normalizar_fluxo; }

# palavras <texto>: uma palavra normalizada por linha.
palavras() { normalizar "$1" | tr -c 'a-z0-9_' '\n' | grep -v '^$' || true; }

norm="$(normalizar "$pedido")"
palavras "$pedido" > "$tmpd/pedido"
tem_palavra() { grep -qxF "$1" "$tmpd/pedido"; }

cfg="$ROOT/config.json"
kj=".claude/specs/karazhan.json"

# --- sinais ---
# módulos: stems de *.py versionados fora de tests/, sem dunder, que aparecem como palavra no pedido.
{ git -c core.quotepath=off ls-files '*.py' | tr -d '\r' | grep -vE '(^|/)tests/' || true; } |
  sed 's#.*/##; s/\.py$//' | grep -vE '^__.*__$' | tr '[:upper:]' '[:lower:]' | awk '!v[$0]++' > "$tmpd/stems"
areas="$(grep -xF -f "$tmpd/pedido" "$tmpd/stems" || true)"
modulos="$areas"
deploy=0
if printf '%s' "$norm" | grep -qE 'deploy|plist|launchd|run\.sh|setup\.sh'; then
  deploy=1
  areas="$(printf '%s\n%s' "$areas" deploy | grep -v '^$')"
fi
n_areas="$(printf '%s\n' "$areas" | grep -c . || true)"

spec=não
for f in .claude/specs/current/*/spec.md; do
  [ -f "$f" ] || continue
  while IFS= read -r w; do
    if tem_palavra "$w"; then spec=sim; break 2; fi
  done < <(palavras "$(basename "$(dirname "$f")")" | grep -E '^[a-z0-9_]{4,}$' | grep '[a-z]' || true)
done

linha_mapa="$(bash "$SCRIPTS/mapa-check.sh" 2>/dev/null || true)"
mapa="$(printf '%s\n' "$linha_mapa" | sed -n 's/.*mapa=\([a-z-]*\).*/\1/p')"
esqueleto="$(printf '%s\n' "$linha_mapa" | sed -n 's/.*esqueleto=\([a-z]*\).*/\1/p')"
case "$mapa" in
  ok) ;;
  vencido*) mapa=vencido ;;
  *) mapa=ausente ;;
esac
[ -n "$esqueleto" ] || esqueleto=fora

testes=não
if [ -d tests ] || [ -f pytest.ini ] || { [ -f pyproject.toml ] && grep -qF '[tool.pytest' pyproject.toml; }; then
  testes=sim
fi

# tipo: correcao só quando há mais palavras de correção que de feature; padrão feature.
conta() { jqr ".palavras.$1[]" "$cfg" | normalizar_fluxo | grep -cxF -f "$tmpd/pedido" || true; }
tipo=feature
[ "$(conta correcao)" -le "$(conta feature)" ] || tipo=correcao

eng_max="$(jqr '.eng_max' "$cfg")"
: > "$tmpd/presets"
if [ -f "$kj" ]; then
  over="$(jqr '.config.eng_max // empty' "$kj")"
  [ -z "$over" ] || eng_max="$over"
  jqr '(.presets // {}) | to_entries[] | "\(.key)\t\(.value.family)\t\(.value.tier)"' "$kj" > "$tmpd/presets"
fi

codex=0
if awk -F'\t' '$2 == "codex" { achou = 1 } END { exit !achou }' "$tmpd/presets" && command -v codex >/dev/null 2>&1; then
  codex=1
fi

# --- dimensionamento ---
n_eng="$n_areas"
[ "$n_eng" -le "$eng_max" ] || n_eng="$eng_max"
[ "$n_eng" -ge 1 ] || n_eng=1
eng_tier=medio
[ "$deploy" -eq 0 ] || eng_tier=capaz
if printf '%s\n' "$modulos" | grep -qxE 'config|auth|db|database|crypto'; then eng_tier=capaz; fi

if [ -n "$nominal" ]; then
  tem_papel eng || n_eng=0
  [ "$n_eng" -le 1 ] || n_eng=1
fi
if [ "$grande" -eq 1 ] || { [ -z "$nominal" ] && [ "$n_areas" -gt "$eng_max" ]; }; then
  nivel=Grande
elif [ "$n_eng" -le 1 ]; then
  nivel=Pequena
else
  nivel=Média
fi

# --- nomes e presets ---
usados="$tmpd/usados"
: > "$usados"
equipe=".claude/specs/equipe.md"
# Roda em $(...), onde o bash limpa o set -e: as falhas saem explicitamente.
nome() {
  local n
  if [ -f "$equipe" ]; then
    n="$(bash "$SCRIPTS/pick-name.sh" "$1" --em-uso "$usados" --em-uso "$equipe")" || exit $?
  else
    n="$(bash "$SCRIPTS/pick-name.sh" "$1" --em-uso "$usados")" || exit $?
  fi
  echo "$n" >> "$usados"
  echo "$n"
}

# preset <família> <tier>: nome do preset da família no tier pedido ou no mais próximo; "?" se nenhum.
preset() {
  local ordem t p
  case "$2" in
    capaz) ordem="capaz medio barato" ;;
    medio) ordem="medio capaz barato" ;;
    *) ordem="barato medio capaz" ;;
  esac
  for t in $ordem; do
    p="$(awk -F'\t' -v f="$1" -v t="$t" '$2 == f && $3 == t { print $1; exit }' "$tmpd/presets")"
    if [ -n "$p" ]; then echo "$p"; return; fi
  done
  echo "?"
}

terminais=""
subagentes=""
presets=""
term() { terminais="${terminais:+$terminais · }$1"; }
sub() { subagentes="${subagentes:+$subagentes · }$1"; }
# convocar <prefixo> <família> <tier> <terminal|sub> [rótulo]: sorteia nome e registra o preset.
convocar() {
  local n
  n="$(nome "$1")" || exit $?
  presets="$presets $n=$(preset "$2" "$3")"
  if [ "$4" = terminal ]; then term "$n (${5:-$2/$3})"; elif [ -n "${5:-}" ]; then sub "$n ($5)"; else sub "$n"; fi
}
revisor() {
  if [ "$codex" -eq 1 ]; then convocar rev codex capaz terminal; else term "Reviewer: NÃO CONVOCADO (sem Codex)"; fi
}
git_onde=sub
[ "$nivel" != Grande ] || git_onde=terminal

if [ -n "$nominal" ]; then
  if tem_papel orch; then convocar orch claude capaz terminal; fi
  if tem_papel arch; then convocar arch claude capaz terminal; fi
  if tem_papel eng; then convocar eng claude "$eng_tier" terminal; fi
  if tem_papel rev; then revisor; fi
  if tem_papel rec; then convocar rec claude barato sub; fi
  if tem_papel git; then convocar git claude barato "$git_onde"; fi
  nao="(chamada nominal)"
else
  recon=0
  if [ "$mapa" != ok ] || [ "$esqueleto" = fora ]; then recon=1; fi
  arch_term=0
  # time mínimo: com 1 área (mesmo feature sem spec) o Architect é subagente de spec curta.
  if [ "$n_areas" -ge 2 ] || [ "$nivel" = Grande ]; then arch_term=1; fi

  [ "$recon" -eq 0 ] || convocar rec claude barato sub
  if [ "$arch_term" -eq 1 ]; then convocar arch claude capaz terminal; else convocar arch claude capaz sub "spec curta"; fi
  i=0
  while [ "$i" -lt "$n_eng" ]; do
    convocar eng claude "$eng_tier" terminal
    i=$((i + 1))
  done
  revisor
  convocar git claude barato "$git_onde"
  if [ "$recon" -eq 0 ]; then nao="recon (mapa válido, esqueleto padrão)"; else nao="—"; fi
fi

if [ "$n_areas" -eq 0 ]; then
  lista="nenhum módulo casou; dono dos paths será definido pelo Architect"
else
  lista="$(printf '%s\n' "$areas" | awk 'NR > 1 { printf ", " } { printf "%s", $0 }')"
fi

echo "Pedido: $pedido"
echo "Sinais: módulos=$n_areas ($lista) · spec=$spec · mapa=$mapa · testes=$testes · tipo=$tipo"
echo "Nível: $nivel"
echo "Terminais: ${terminais:-—}"
echo "Subagentes: ${subagentes:-—}"
echo "Não convocar: $nao"
echo "Presets:${presets:- —}"
