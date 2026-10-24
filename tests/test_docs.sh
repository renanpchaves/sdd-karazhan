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
[ -f $SK/SKILL.md ] || fail "falta SKILL.md"
[ "$(sed '1,/^---$/d' $SK/SKILL.md | wc -w)" -le 400 ] || fail "SKILL.md > 400 palavras"
grep -q '^name: sdd-karazhan' $SK/SKILL.md || fail "frontmatter"
grep -qi 'maestri' $SK/SKILL.md || fail "gatilho"
C=$SK/references/convocacao.md
[ -f $C ] || fail "falta ref convocacao"
[ "$(wc -w < $C)" -le 900 ] || fail "convocacao.md > 900 palavras"
for p in Orchestrator Architect Recon Engineer Reviewer 'Git Manager' 'Nível 0' 'projeto novo' 'caracterização'; do
  grep -q "$p" $C || fail "convocacao.md sem '$p'"
done
! grep -rq 'convocar\.sh' skills README.md || fail "sobrou menção a convocar.sh"
for p in correção requisito observações; do grep -q "$p" $SK/agents/reviewer.md || fail "reviewer.md sem '$p'"; done
for p in 'Engineer novo' lição mergeável; do grep -q "$p" $SK/references/ciclo.md || fail "ciclo.md sem '$p'"; done
grep -q 'Engineer novo' $SK/agents/orchestrator.md || fail "orchestrator.md sem 'Engineer novo'"
grep -q 'lição' $C || fail "convocacao.md sem 'lição'"
grep -q 'plutil' $SK/mapa-padrao.md || fail "mapa-padrao sem plutil"
! grep -rq 'checkpoint da spec (passo 5)' $SK || fail "checkpoint da spec é o passo 3"
grep -q 'pelo Reviewer' $SK/agents/git-manager.md || fail "git-manager sem 'pelo Reviewer'"
! grep -q 'Mínimo é 3 terminais' README.md || fail "README ainda diz 3 terminais"
