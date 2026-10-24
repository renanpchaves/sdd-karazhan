# Ciclo

Sete passos, sempre nesta ordem. Os scripts ficam em `scripts/` da skill: o Orchestrator resolve a raiz do plugin (`${CLAUDE_PLUGIN_ROOT}/skills/sdd-karazhan`, ou o diretório base informado ao carregar a skill) e passa **caminhos absolutos** a todo agente, inclusive ao Reviewer no Codex. Scripts rodam na raiz do repo alvo, salvo indicação.

## 1. Inventariar

```bash
maestri list                     # responde → modo Maestri; comando ausente → modo subagente
maestri preset list              # presets do workspace (só no modo Maestri)
scripts/mapa-check.sh            # mapa=ok|ausente|vencido-idade|vencido-arvore esqueleto=padrao|fora
scripts/pick-name.sh orch        # nome com que o Orchestrator assina
```

- Preset sem entrada em `.claude/specs/karazhan.json`: faça a pergunta única (`references/recrutamento.md`) antes de convocar.
- `git-*` já conectado em `maestri list` é reaproveitado pela folha.

## 2. Convocar

```bash
scripts/convocar.sh "<pedido>"                  # dimensiona
scripts/convocar.sh "<pedido>" grande           # força Grande
scripts/convocar.sh "<pedido>" arch eng rev git # chamada nominal: só valida, nunca adiciona papel
```

- Mostre a folha (seis linhas + `Presets:`) e espere uma palavra do usuário antes de recrutar.
- `Reviewer: NÃO CONVOCADO (sem Codex)`: pergunte ao usuário se segue sem Reviewer ou se configura um preset Codex. Não siga em silêncio.
- Registre em `decisoes.md` cada papel convocado e o sinal que o justificou.
- Folha com Recon: rode-o como subagente com `agents/recon.md` antes do passo 3. Sem Recon, o Architect usa `mapa-padrao.md`.

## 3. Contratar

```bash
scripts/scaffold.sh NNN-slug     # NNN = próximo número livre em current/ e archive/
```

- Architect terminal (2+ módulos, chamada nominal ou Grande): conduz a descoberta e escreve `spec.md` e `plan.md`.
- Architect subagente (demais casos): escreve a spec curta com o que o Orchestrator passar.
- Checkpoint: o usuário aprova a spec. O Orchestrator nunca escreve spec.

## 4. Particionar

- Escreva uma WP por bloco em `tasks.md`, no formato do template do `scaffold.sh` (`### WP-NN — título`, `- Lane:`, `- Dono:`, `- Possui:`, `- Fora de escopo:`, `- Objetivo:`, `- Aceite:`, `- Evidência:`, `- Depende de:`).
- Um dono por path. `deploy/**`, `run.sh` e `setup.sh` têm dono explícito quando tocados.
- Ondas pelo campo `Depende de`.

```bash
scripts/donos.sh NNN-slug        # precisa sair 0: orfaos: 0 e duplicados: 0
```

Lanes: `planejado` → `fazendo` → `revisão` → `aprovado` → `pronto` (integrada).

## 5. Recrutar

- Git Manager primeiro: branch `feat/NNN-slug`, worktrees da onda e guarda (`agents/git-manager.md`):

```bash
scripts/guard-install.sh <worktree> eng WP-NN <paths-csv>
scripts/guard-install.sh <worktree-rev> rev WP-NN <paths-csv>
```

- Depois Engineers e Reviewer, com os comandos de `references/recrutamento.md`. Registre cada um em `equipe.md`.

## 6. Delegar

- Mensagem de quatro linhas: objetivo, WP, fronteira, formato de retorno (o bloco fixo do role).
- A nota `tasks-<nome>` traz o bloco da WP e o comando exato de evidência:

```bash
scripts/wp-check.sh WP-NN --tasks <abs>/.claude/specs/current/NNN-slug/tasks.md
```

  Base padrão `feat/NNN-slug`; arquivos em `.claude/` são ignorados. Antes do commit o diff sai vazio: lint, testes e dry-run valem; o diff vale na rodada do Reviewer.
- Sequência por WP: Engineer `ok` → Git Manager commita (`SDD_GIT_MANAGER=1`) → Reviewer roda `wp-check.sh` e lê o diff → `aprovado` ou volta ao Engineer.
- Reprovada duas vezes ou Engineer `bloqueado`: registre em `bloqueios.md` (formato em `references/painel.md`) e acione o dono da decisão (Architect para ambiguidade de contrato, usuário para regra de negócio).
- Atualize a lane em `tasks.md` a cada passagem.

## 7. Integrar

- Git Manager faz merge das WPs `aprovado` em `feat/NNN-slug` e roda a suíte de testes do projeto ali.
- Lane `pronto`.
- Fim da onda: `scripts/painel.sh NNN-slug --publicar` e checkpoint com o usuário (`references/painel.md`).
- Push e PR só com autorização explícita do usuário.
- Pouso do andar: mova as WPs `pronto` para `tasks-done.md` e libere os nomes em `equipe.md`. Remover worktree ou dispensar terminal só com autorização.
