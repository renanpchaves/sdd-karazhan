#!/usr/bin/env bash
# scaffold.sh NNN-slug
# Cria .claude/specs/current/NNN-slug/{spec,plan,tasks,tasks-done}.md e, se faltarem,
# .claude/specs/{bloqueios,decisoes,equipe}.md e karazhan.json. Nunca sobrescreve.
# Também garante .claude/specs/.gitignore com o estado local (equipe, painel, karazhan.json,
# mapa, bloqueios): só acrescenta as linhas que faltam; o .gitignore da raiz não é tocado.
# Executar na raiz do repo alvo.
. "$(dirname "$0")/../lib/common.sh"

AJUDA="uso: scaffold.sh NNN-slug  (ex.: 001-login), executado na raiz do repo alvo"
case "${1:-}" in -h|--help) usage "$AJUDA" ;; esac
[ $# -eq 1 ] || die "$AJUDA"
slug="$1"
[[ "$slug" =~ ^[0-9]{3}-[a-z0-9-]+$ ]] || die "slug inválido: $slug (use NNN-slug, ex.: 001-login)"
need git
git rev-parse --show-toplevel >/dev/null 2>&1 || die "não é um repositório git"
cd "$(git rev-parse --show-toplevel)"

# criar <arquivo> <conteúdo>: grava só se o arquivo não existe; imprime criado: / mantido:
criar() {
  if [ -e "$1" ]; then
    echo "mantido: $1"
    return 0
  fi
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" > "$1"
  echo "criado: $1"
}

dir=".claude/specs/current/$slug"

criar "$dir/spec.md" "# Spec — $slug

## Objetivo

## Dentro
<!-- um path ou glob por linha, iniciando com \`- \` (ex.: - src/auth/**) -->

## Fora
<!-- paths de outros donos, mesmo formato -->

## Aceite
"

criar "$dir/plan.md" "# Plan — $slug"

criar "$dir/tasks.md" "# Tasks — $slug

<!--
### WP-01 — <título>
- Lane: planejado
- Dono: Builder
- Possui: <path/**, outro/arquivo.py>
- Fora de escopo: <paths de outros donos>
- Objetivo: <resultado, não receita>
- Aceite: <critério binário>
- Evidência: <o que volta como prova>
- Depende de: <WP-NN ou nenhuma>
-->"

criar "$dir/tasks-done.md" "# Tasks done — $slug"

criar ".claude/specs/bloqueios.md" "# Bloqueios

Entrada: \`## data · agente · bloqueio\`, com campos escopo, dono da decisão e resolução (sem resolução = aberto)."

criar ".claude/specs/decisoes.md" "# Decisões

Entrada: \`## data · papel · decisão\` (papel, não o nome do agente: este arquivo é versionado), com racional, alternativas, custo de reverter e escopo."

criar ".claude/specs/equipe.md" "# Equipe

Uma linha por agente: nome, papel, preset, paths possuídos e andar.

| Nome | Papel | Preset | Possui | Andar |
|---|---|---|---|---|"

criar ".claude/specs/karazhan.json" '{"presets":{},"config":{},"brain_dir":null}'

# .claude/specs/.gitignore: estado local fora do git; spec, plan, tasks, decisoes e aceite continuam versionados.
gi=".claude/specs/.gitignore"
novo=0
[ -e "$gi" ] || novo=1
mkdir -p "$(dirname "$gi")"
touch "$gi"
[ -z "$(tail -c1 "$gi")" ] || echo >> "$gi"
add=0
for linha in equipe.md painel.md karazhan.json mapa.md bloqueios.md; do
  grep -qxF "$linha" "$gi" || { echo "$linha" >> "$gi"; add=1; }
done
if [ "$novo" -eq 1 ]; then echo "criado: $gi"
elif [ "$add" -eq 1 ]; then echo "atualizado: $gi"
else echo "mantido: $gi"; fi
