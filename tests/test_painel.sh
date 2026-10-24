. "$(dirname "$0")/lib.sh"; SK=$PWD/skills/sdd-karazhan; P=$SK/scripts/painel.sh
R=$(fixture_repo padrao); cd $R; bash $SK/scripts/scaffold.sh 001-x >/dev/null
printf '### WP-02 — b\n- Lane: revisão\n- Dono: Cairne\n- Possui: deploy/**\n### WP-10 — c\n- Dono: eng-x\n### WP-01 — a\n- Lane: aprovado\n- Dono: Grom\n- Possui: pkg/**\n' > .claude/specs/current/001-x/tasks.md
printf '## 2026-10-23 · Grom · campo ambíguo\n- Escopo: WP-01\n## 2026-10-22 · eng-x · resolvido antigo\n- Resolução: decidido\n## 2026-10-21 · eng-y · outro resolvido\nResolução: feito\n' >> .claude/specs/bloqueios.md
out=$(bash $P 001-x)
assert_contains "$out" "# Painel — 001-x" "título"
assert_contains "$out" "| WP | Lane | Dono | Possui |" "cabeçalho"
assert_contains "$out" "| WP-01 | aprovado | Grom | pkg/** |" "linha wp"
assert_contains "$out" "| WP-10 | — | eng-x | — |" "campos ausentes viram traço"
[ "$(printf '%s\n' "$out" | grep -n 'WP-01' | head -1 | cut -d: -f1)" -lt "$(printf '%s\n' "$out" | grep -n 'WP-02' | head -1 | cut -d: -f1)" ] || fail "ordem"
[ "$(printf '%s\n' "$out" | grep -n 'WP-02' | head -1 | cut -d: -f1)" -lt "$(printf '%s\n' "$out" | grep -n 'WP-10' | head -1 | cut -d: -f1)" ] || fail "ordem numérica"
assert_contains "$out" "## Bloqueios abertos" "seção bloqueios"
assert_contains "$out" "- 2026-10-23 · Grom · campo ambíguo" "bloqueio aberto"
case "$out" in *"resolvido antigo"*|*"outro resolvido"*) fail "bloqueio resolvido listado: $out" ;; esac
assert_contains "$out" "## Equipe" "seção equipe"
assert_contains "$out" "sem equipe registrada" "equipe sem linhas"
printf '| Grom | Eng | exec | pkg/** | 2 |\n' >> .claude/specs/equipe.md
out=$(bash $P 001-x)
assert_contains "$out" "| Grom | Eng | exec | pkg/** | 2 |" "equipe copiada"
# registro do Orchestrator acima da tabela: todas as linhas de agente aparecem; cabeçalho e separador não
printf '# Equipe\n\nOrchestrator: Antonidas — role Orchestrator: atribuído (usuário, 2026-10-24)\n\nUma linha por agente.\n\n| Nome | Papel | Preset | Possui | Andar |\n|---|---|---|---|---|\n| Grom | Builder | cc | pkg/** | 1 |\n| Uther | Reviewer | cx | — | 1 |\n' > .claude/specs/equipe.md
out=$(bash $P 001-x)
assert_contains "$out" "| Grom | Builder | cc | pkg/** | 1 |" "registro acima: primeira linha de agente"
assert_contains "$out" "| Uther | Reviewer | cx | — | 1 |" "registro acima: segunda linha de agente"
case "$out" in *"| Nome | Papel"*|*"|---|---|---|---|---|"*|*"Antonidas"*) fail "cabeçalho, separador ou registro vazaram: $out" ;; esac
# equipe.md sem cabeçalho: as linhas de agente continuam aparecendo
printf 'Orchestrator: Antonidas — role Orchestrator: recusado (usuário, 2026-10-24)\n| Grom | Builder | cc | pkg/** | 1 |\n| Uther | Reviewer | cx | — | 1 |\n' > .claude/specs/equipe.md
out=$(bash $P 001-x)
assert_contains "$out" "| Grom | Builder | cc | pkg/** | 1 |" "sem cabeçalho: primeira linha"
assert_contains "$out" "| Uther | Reviewer | cx | — | 1 |" "sem cabeçalho: segunda linha"
# sem bloqueios abertos -> nenhum
printf '# Bloqueios\n' > .claude/specs/bloqueios.md
out=$(bash $P 001-x)
assert_contains "$out" "nenhum" "sem bloqueios"
rm .claude/specs/bloqueios.md
out=$(bash $P 001-x)
assert_contains "$out" "nenhum" "bloqueios.md ausente"
assert_exit 2 bash $P 009-nao
# --publicar sem maestri: grava .claude/specs/painel.md
PATH_SEM=$(mktemp -d "$TMP/bin.XXXXXX")
for c in bash cat awk sed grep tr cut head tail sort git dirname date rm mkdir printf; do
  p=$(command -v $c 2>/dev/null) || continue
  { echo "#!/bin/sh"; echo "exec \"$p\" \"\$@\""; } > "$PATH_SEM/$c"; chmod +x "$PATH_SEM/$c"
done
if PATH="$PATH_SEM" command -v maestri >/dev/null 2>&1; then :; else
  out=$(PATH="$PATH_SEM" bash $P 001-x --publicar)
  assert_contains "$out" "publicado em .claude/specs/painel.md" "publicar sem maestri"
  grep -q "# Painel — 001-x" .claude/specs/painel.md || fail "painel.md sem conteúdo"
fi
# --publicar com maestri stub
STUB=$(mktemp -d "$TMP/stub.XXXXXX"); LOG=$STUB/log; : > $LOG
cat > $STUB/maestri <<'EOS'
#!/usr/bin/env bash
if [ "$1" = list ]; then cat "$(dirname "$0")/lista" 2>/dev/null; exit 0; fi
printf '%s\n' "$*" >> "$(dirname "$0")/log"
EOS
chmod +x $STUB/maestri
: > $STUB/lista
PATH="$STUB:$PATH" bash $P 001-x --publicar >/dev/null
assert_contains "$(cat $LOG)" "note create --name painel-001-x # Painel — 001-x" "cria nota na primeira vez"
: > $LOG; echo "painel-001-x" > $STUB/lista
PATH="$STUB:$PATH" bash $P 001-x --publicar >/dev/null
assert_contains "$(cat $LOG)" "note write painel-001-x # Painel — 001-x" "reescreve nota existente"
case "$(cat $LOG)" in *"note create"*) fail "não deve criar de novo" ;; esac
