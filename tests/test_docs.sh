. "$(dirname "$0")/lib.sh"; SK=skills/sdd-karazhan
for f in orchestrator architect recon builder reviewer git-manager; do
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
[ "$(wc -w < $C)" -le 1050 ] || fail "convocacao.md > 1050 palavras"
for p in Orchestrator Architect Recon Builder Reviewer 'Git Manager' 'Nível 0' 'projeto novo' 'caracterização'; do
  grep -q "$p" $C || fail "convocacao.md sem '$p'"
done
! grep -rq 'convocar\.sh' skills README.md || fail "sobrou menção a convocar.sh"
for p in correção requisito observações; do grep -q "$p" $SK/agents/reviewer.md || fail "reviewer.md sem '$p'"; done
for p in 'Builder novo' lição mergeável; do grep -q "$p" $SK/references/ciclo.md || fail "ciclo.md sem '$p'"; done
grep -q 'Builder novo' $SK/agents/orchestrator.md || fail "orchestrator.md sem 'Builder novo'"
grep -q 'lição' $C || fail "convocacao.md sem 'lição'"
grep -q 'plutil' $SK/mapa-padrao.md || fail "mapa-padrao sem plutil"
! grep -rq 'checkpoint da spec (passo 5)' $SK || fail "checkpoint da spec é o passo 3"
grep -q 'pelo Reviewer' $SK/agents/git-manager.md || fail "git-manager sem 'pelo Reviewer'"
! grep -q 'Mínimo é 3 terminais' README.md || fail "README ainda diz 3 terminais"
# v0.1.1: nome = personagem, badge = papel; tudo do agente vai na nota tasks-<Nome>
for f in $SK/agents/*.md; do
  ! grep -qE '<(WP|PATHS|NOTA|ORCH|GIT)>' $f || fail "$f ainda tem placeholder de agente"
done
grep -qF -- '--role "Builder"' $SK/references/recrutamento.md || fail "recrutamento.md sem --role \"Builder\""
grep -qF -- '--scope global' $SK/references/recrutamento.md || fail "recrutamento.md sem --scope global"
! grep -rqE 'eng-grom|rev-uther|arch-ysera|git-gazlowe|orch-antonidas' skills README.md || fail "sobrou nome no formato antigo"
# papel Engineer vira Builder (chave bld)
[ -f $SK/agents/builder.md ] || fail "falta agents/builder.md"
[ ! -e $SK/agents/engineer.md ] || fail "agents/engineer.md deveria ter virado builder.md"
! grep -rniE 'engineer' skills README.md .claude-plugin | grep -v 'references/recrutamento.md' | grep -q . || fail "sobrou Engineer fora da linha de compat do recrutamento.md"
[ "$(grep -ci 'engineer' $SK/references/recrutamento.md)" -le 1 ] || fail "recrutamento.md cita Engineer em mais de uma linha"
! grep -rw 'eng' --include='*.md' skills README.md | grep -v 'role=eng' | grep -q . || fail "sobrou a chave eng na prosa (agora bld)"
! grep -rqE 'pick-name\.sh eng|guard-install\.sh .* eng( |$)' skills README.md || fail "sobrou comando com eng"
# Maestri atual: arrange, ícone/cor por papel, role delete com ok do usuário, bld_max
R=$SK/references/recrutamento.md
for p in 'maestri arrange' '--icon' '--color' 'role delete' 'pencil.and.ruler' hammer 'shield.checkered' gearshape; do
  grep -qF -- "$p" $R || fail "recrutamento.md sem '$p'"
done
grep -q 'arrange' $SK/agents/orchestrator.md || grep -q 'arrange' $SK/references/ciclo.md || fail "nem orchestrator.md nem ciclo.md citam arrange"
! grep -rqiE 'renomeie o terminal|renomear o próprio terminal|não renomeia o próprio terminal' skills README.md || fail "ainda pede ao usuário para renomear o terminal"
grep -q 'role delete' README.md || fail "README sem role delete"
! grep -rq 'eng_max' skills README.md --exclude=inventario.sh || fail "sobrou eng_max fora do compat do inventario.sh"
grep -q 'bld_max' $SK/config.json || fail "config.json sem bld_max"
# recruta antes da nota (nome final pode virar "#2"); pedido do role Orchestrator registrado em equipe.md
rl=$(grep -n '^maestri recruit' $R | head -n 1 | cut -d: -f1); nl=$(grep -n '^maestri note create' $R | head -n 1 | cut -d: -f1)
[ -n "$rl" ] && [ -n "$nl" ] && [ "$rl" -lt "$nl" ] || fail "recrutamento.md: recruit deve vir antes de note create"
grep -qF 'role Orchestrator: atribuído' $R || fail "recrutamento.md sem a linha de registro do role em equipe.md"
grep -qF 'role Orchestrator: atribuído' $SK/references/ciclo.md || fail "ciclo.md sem a linha de registro do role"
grep -qF 'role Orchestrator: recusado' $R || fail "recrutamento.md sem o registro de recusa do role"
grep -qF 'atribuído|recusado' $SK/references/ciclo.md || fail "ciclo.md sem o registro de recusa"
gr=$(grep -n '^maestri recruit "Grom"' $R | head -n 1 | cut -d: -f1); gn=$(grep -n '^maestri note create --name "tasks-Grom"' $R | head -n 1 | cut -d: -f1)
[ -n "$gr" ] && [ -n "$gn" ] && [ "$gr" -lt "$gn" ] || fail "recrutamento.md: recruit Grom deve vir antes da nota tasks-Grom"
grep -qF 'Nome | Papel' $R && grep -qF 'role Orchestrator: atribuído' $R || fail "recrutamento.md sem o conteúdo de equipe.md criado pelo Orchestrator"
grep -q 'Carregue no passo 1' $R || fail "recrutamento.md deve ser carregado também no passo 1"
# v0.1.2: worktrees dentro do repo, em .worktrees/ (info/exclude); nada de pastas irmãs
for p in '.worktrees/WP-NN' '.worktrees/rev'; do
  grep -qF -- "$p" $SK/references/ciclo.md || fail "ciclo.md sem '$p'"
done
grep -qF -- '.worktrees/rev' $SK/agents/git-manager.md || fail "git-manager.md sem .worktrees/rev"
grep -qF '.worktrees/' $SK/agents/git-manager.md || fail "git-manager.md sem .worktrees/"
grep -qF 'info/exclude' $SK/agents/git-manager.md || fail "git-manager.md sem info/exclude"
! grep -rnE '<repo>-(WP|rev)' skills README.md | grep -v 'references/ciclo.md:.*Migração' | grep -q . || fail "sobrou worktree irmão (<repo>-WP/-rev) fora da nota de migração"
[ "$(grep -c '^- Migração' $SK/references/ciclo.md)" -eq 1 ] || fail "ciclo.md sem a nota de migração"
# v0.1.2: arquivos versionados com papel, não personagem (nomes só em equipe.md, que é local)
! grep -rqE 'Dono: *(Grom|Uther|Ysera|Gazlowe|Antonidas|Jaina|<Nome>)' skills README.md || fail "Dono com nome de personagem"
! grep -rqE '## [0-9<][^`]* · (Grom|Uther|Ysera|Gazlowe|Antonidas|Jaina|<orch>) · (decisão|lição|Reviewer)' skills README.md || fail "decisoes.md com nome de personagem como autor"
grep -qF 'Dono:' $SK/references/ciclo.md && grep -qE 'Dono:.*papel|papel.*Dono' $SK/references/ciclo.md || fail "ciclo.md sem Dono = papel"
grep -qF '.claude/specs/.gitignore' $SK/references/ciclo.md || fail "ciclo.md sem .claude/specs/.gitignore"
