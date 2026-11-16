# Spec — 001-guarda-bash

## Objetivo

Fechar o atalho do shell na guarda do Builder. Hook `PreToolUse` para `Bash` (`skills/sdd-karazhan/hooks/bash-guard.sh`) que acha, por heurística, os alvos de escrita do comando e aplica as mesmas regras do `path-guard.sh`. Assim `sed -i`, `>`, `tee`, `cp` e afins deixam de escapar fora dos paths da WP.

## Dentro
- skills/sdd-karazhan/hooks/bash-guard.sh
- skills/sdd-karazhan/hooks/path-guard.sh
- hooks/hooks.json
- skills/sdd-karazhan/lib/**
- tests/test_bash_guard.sh
- tests/test_manifests.sh
- .claude-plugin/**
- CHANGELOG.md
- README.md
- skills/sdd-karazhan/references/guardrails.md
- skills/sdd-karazhan/scripts/wp-check.sh
- skills/sdd-karazhan/agents/orchestrator.md

## Fora
- skills/sdd-karazhan/hooks/pre-commit
- skills/sdd-karazhan/scripts/guard-install.sh
- tests/aceite/**

## Interface

- Entrada: JSON do hook no stdin, `{tool_name, cwd, tool_input:{command}}`. Se `tool_name` não for `Bash`, sai 0.
- Ativação: igual ao path-guard. Raiz do worktree = `cwd` sem o `--show-prefix` do git. Sem `.sdd-role` nessa raiz, sai 0. Sem jq, faz como o path-guard: bloqueia só se houver `.sdd-role`.
- Bloquear: exit 2, com o motivo em stderr citando o alvo relativo. Para o Reviewer, a mensagem contém `Reviewer não edita arquivos`. Para o Builder, usa as mensagens do path-guard com prefixo `bash-guard:`: `fora dos paths da WP-NN: <rel>`, `.sdd-role é protegido` e `tests/aceite é do Architect`.
- Alvos detectados, também dentro de `&&`, `||`, `;`, `|` e de um `bash -c '...'` simples:
  - redirecionamento `>`, `>>`, `&>` e `N>`, ignorando `>&N`;
  - `tee` e `tee -a`;
  - `sed -i` (GNU, BSD `-i ''`, `-i.bak`), nos arquivos depois do script;
  - `perl -i`, `-pi` e `-i.bak`;
  - o destino de `cp`, `mv`, `install` e `ln`;
  - `rm`, `touch` e `truncate`;
  - `dd of=`.
- Ordem por alvo:
  1. Alvo literal com `$`, `` ` `` ou `~`: ignora.
  2. `/dev/null` e `/dev/std*`: permite.
  3. Alvo relativo: resolve a partir do `cwd` e passa por `canon`/`norm`.
  4. Alvo dentro da raiz do worktree: regras do role. Temporários não isentam aqui, porque o worktree pode estar sob `$TMPDIR`.
  5. Alvo fora da raiz, sem `..` e sob `/tmp`, `/private/tmp` ou `$TMPDIR`: permite.
  6. Qualquer outro alvo, incluindo os com `..`, conta como fora do worktree.
- `role=rev`: bloqueia todo alvo que chegue aos passos 4 ou 6. Os passos 2 e 5 também valem para o Reviewer.
- `role=bld`: segue a ordem do path-guard. Primeiro bloqueia `.sdd-role`, depois `aceite=` e por fim o que estiver fora dos paths ou fora do worktree.
- Reuso: `canon`, `norm`, a raiz do worktree e a leitura do `.sdd-role` saem do path-guard para um helper em `lib/` usado pelos dois hooks. O path-guard não muda de comportamento: `tests/test_guard.sh` continua verde.
- Roda em bash 3.2, o `/bin/bash` do macOS. Fica sem `mapfile`, sem `${x,,}` e sem array associativo. Use `set -f` antes de expandir os globs de `paths`.
- `hooks/hooks.json` ganha uma entrada nova depois da atual: `{"matcher":"Bash","hooks":[{"type":"command","command":"bash \"${CLAUDE_PLUGIN_ROOT}/skills/sdd-karazhan/hooks/bash-guard.sh\"","timeout":10}]}`. `PreToolUse[0]` continua sendo o path-guard, como o `test_guard.sh` confere.

## Limites (documentar em guardrails.md)

- Escrita feita por dentro de um programa (`python script.py`, `node`, `npx remotion render`) não é detectável. Para esses casos valem o role, o `pre-commit` e o `wp-check.sh`.
- É heurística, não um parser de shell. Alvo em variável, `eval`, here-doc complexo e `cd` antes da escrita passam.
- Em modo subagente não se aplica, como o path-guard.

## Fora de escopo
- Mudar o que o `wp-check.sh` confere. A única exceção é a correção de sintaxe pré-existente do WP-01.
- Guarda para Builder em Codex.
- Push e publicação.

## Aceite

- `python3 -m pytest tests/aceite/test_wp01_guarda_bash.py` sai com 0. Precisa de pytest e jq.
- `bash tests/run.sh` sai com 0.

## WP-01 — bash-guard: hook PreToolUse para Bash

- Objetivo:
  - Criar `bash-guard.sh` e o helper comum, e registrar o hook.
  - Criar `tests/test_bash_guard.sh` no estilo de `test_guard.sh`. O glob do `run.sh` já o coleta.
  - Subir para 0.1.3: manifests, `test_manifests.sh` e `## 0.1.3` no CHANGELOG.
  - Atualizar a prosa. Em `guardrails.md`, o "Não cobre Bash" vira uma seção do bash-guard com os limites. A linha 162 do README passa a citar os dois hooks.
- Pré-existente: em HEAD `1cdd92b`, `bash tests/run.sh` já falha com o `/bin/bash` 3.2 em dois testes.
  - `test_wp_check`: o `case ... )` dentro de `$( )` em `wp-check.sh:98` não parseia no bash 3.2. Corrigir só a sintaxe, sem mudar a lógica.
  - `test_docs`: `agents/orchestrator.md` tem 253 palavras, acima do limite de 250. Enxugar sem mudar regra.
- Possui:
  - `skills/sdd-karazhan/hooks/bash-guard.sh`
  - `skills/sdd-karazhan/hooks/path-guard.sh`
  - `hooks/hooks.json`
  - `skills/sdd-karazhan/lib/**`
  - `tests/test_bash_guard.sh`
  - `tests/test_manifests.sh`
  - `.claude-plugin/**`
  - `CHANGELOG.md`
  - `README.md`
  - `skills/sdd-karazhan/references/guardrails.md`
  - `skills/sdd-karazhan/scripts/wp-check.sh`
  - `skills/sdd-karazhan/agents/orchestrator.md`
- Aceite: `tests/aceite/test_wp01_guarda_bash.py` verde, com os critérios abaixo, um teste para cada.
  - bloqueia `sed -i` fora dos paths
  - bloqueia redirecionamento fora dos paths
  - bloqueia `tee`
  - bloqueia `cp`, `mv` e `install` com destino fora
  - bloqueia `rm`, `touch`, `truncate`, `ln`, `dd` e `perl -i`
  - bloqueia escrita em comando composto
  - bloqueia `tests/aceite`
  - bloqueia `.sdd-role`
  - bloqueia escrita fora do worktree
  - bloqueia o Reviewer escrevendo
  - permite escrita dentro dos paths
  - permite `/dev/null` e os temporários
  - permite comandos de leitura
  - não bloqueia alvo com variável
  - não faz nada sem `.sdd-role`
  - `hooks.json` registra o hook
  - a suíte inclui o teste
  - versão 0.1.3
  - `guardrails.md` atualizado
  - `run.sh` sai com 0
- Evidência:
  - saída do pytest do oráculo;
  - linhas finais de `bash tests/run.sh`.
- Depende de: nenhuma.
