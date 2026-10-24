. "$(dirname "$0")/lib.sh"; SK=skills/sdd-karazhan
for f in orchestrator architect recon engineer reviewer git-manager; do
  [ -f $SK/agents/$f.md ] || fail "falta $f"
  [ "$(wc -w < $SK/agents/$f.md)" -le 250 ] || fail "$f > 250 palavras"
  grep -q '^## Retorno' $SK/agents/$f.md || fail "$f sem Retorno"
done
grep -q 'Codex' $SK/agents/reviewer.md || fail "reviewer sem Codex"
grep -q 'SDD_GIT_MANAGER' $SK/agents/git-manager.md || fail "git-manager sem variável"
for f in ciclo recrutamento guardrails painel; do [ -f $SK/references/$f.md ] || fail "falta ref $f"; done
grep -qE 'hooks? de ferramenta|workspace-write' $SK/references/guardrails.md || fail "guardrails sem veredito Codex"
grep -q 'dry-run' $SK/mapa-padrao.md || fail "mapa-padrao sem dry-run"
