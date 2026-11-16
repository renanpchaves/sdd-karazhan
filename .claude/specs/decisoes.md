# Decisões

Entrada: `## data · papel · decisão` (papel, não o nome do agente: este arquivo é versionado), com racional, alternativas, custo de reverter e escopo.

## 2026-11-15 · Orchestrator · folha da 001-guarda-bash
- Pedido: o usuário pediu um time pequeno para fechar a lacuna da guarda (Builder editando arquivo pelo shell), com o Reviewer aprovando antes de atualizar o plugin.
- Tamanho Pequena, nível 1: 1 área (guarda de hooks: hooks.json + hooks/*.sh + tests/ + manifests de versão); sem banco, integração ou auth.
- Architect subagente (Pequena), Git Manager subagente (Pequena), Builder terminal claude/capaz (guarda é segurança: tier capaz), Reviewer terminal Codex.
- Recon não convocado: repo pequeno e conhecido; o Architect lê hooks/, tests/test_guard.sh e lib/ direto.
- Desvio: o inventário diz `repo: novo` e `testes: não` porque só reconhece Python; o repo é bash com suíte em tests/run.sh. Tratado como brownfield com testes.
- Desvio: o repo não tem setup.sh nem pytest. O oráculo de aceite fica em tests/aceite/test_wp01_*.py (pytest chamando bash) e o Git Manager cria um .venv com pytest em cada worktree (excluído pelo info/exclude), no lugar do setup.sh. A suíte do plugin (tests/run.sh) é evidência obrigatória a mais.
- Desvio: presets Antigravity, OpenCode e Shell continuam fora do karazhan.json (mesmo desvio da feature anterior).
- Commit: o commit pré-revisão fica na branch da WP (local); nada entra em main antes do `aprovado` do Reviewer, como o usuário pediu. Push só com o ok do usuário.
- Ajuste do usuário (2026-11-15): Git Manager vira terminal no canvas (Mekkatorque), em vez de subagente; o Architect da spec segue subagente porque já estava escrevendo.

## 2026-11-15 · Orchestrator · bloqueio do Architect: run.sh já falha no HEAD
- O oráculo exige `bash tests/run.sh` com 0, mas no HEAD 1cdd92b falham test_docs (agents/orchestrator.md com 253 palavras, limite 250) e test_wp_check (wp-check.sh:98, `case` dentro de `$( )`, não parseia no /bin/bash 3.2 do macOS).
- Decisão: entram no Possui da WP-01 como correção mínima: enxugar orchestrator.md e só a sintaxe da linha 98 do wp-check.sh, sem mudar comportamento. Alternativa (relaxar o critério) rejeitada: o Reviewer roda o wp-check em HEAD desanexado, justamente o caminho quebrado no macOS. Custo de reverter: baixo. Escopo: só esta WP.
- path-guard.sh e tests/test_manifests.sh entraram no Possui (helper comum em lib/ e versão 0.1.3); docs/** e tests/run.sh saíram (não precisam mudar).
