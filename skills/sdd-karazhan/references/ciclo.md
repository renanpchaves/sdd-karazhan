# Ciclo

Sete passos, sempre nesta ordem. Os scripts ficam em `scripts/` da skill: o Orchestrator resolve a raiz do plugin (`${CLAUDE_PLUGIN_ROOT}/skills/sdd-karazhan`, ou o diretório base informado ao carregar a skill) e passa **caminhos absolutos** a todo agente, inclusive ao Reviewer no Codex. Nos roles essa raiz é o placeholder `<SK>`, preenchido junto com os demais (`references/recrutamento.md`). Scripts rodam na raiz do repo alvo, salvo indicação.

## 1. Inventariar

```bash
maestri list                     # responde → modo Maestri; comando ausente → modo subagente
maestri preset list              # presets do workspace (só no modo Maestri)
scripts/inventario.sh            # oito linhas de fatos: repo, módulos, áreas, specs, mapa, presets, conectados, eng_max
scripts/pick-name.sh orch        # nome com que o Orchestrator assina
```

- Preset sem entrada em `.claude/specs/karazhan.json`: faça a pergunta única (`references/recrutamento.md`) antes de convocar.
- O script só coleta fatos. Não lê o pedido nem decide o time.

## 2. Decidir

- Com o pedido e o inventário, aplique `references/convocacao.md`: nível de contrato (0/1/2), tamanho do time, papéis, tiers, presets e nomes (`pick-name.sh <prefixo>` por papel; `git-*` em `conectados` é reaproveitado).
- Nível 0: o Orchestrator diz ao usuário que não vai usar a skill e para; o usuário faz direto.
- Mostre a folha (sete linhas, porquê inline; a linha `Tamanho:` diz Pequena, Média ou Grande). Pequena: siga sem esperar; os terminais só nascem depois do checkpoint da spec (passo 5), e o usuário responde `para` para ajustar o time. Média e Grande: espere uma palavra.
- Chamada nominal (`arch eng rev git`): só os papéis pedidos; `arch` nominal é terminal. `eng` sem `git` ou `rev` sem `eng`: mostre o motivo e pergunte de novo. Não complete a lista por conta própria. `grande` sozinho não é chamada nominal: só força o tamanho Grande.
- `Reviewer: NÃO CONVOCADO (sem Codex)` na linha `Terminais:`: pergunte ao usuário se segue sem Reviewer ou se configura um preset Codex. Não siga em silêncio.
- Registre em `decisoes.md` cada papel convocado e o sinal que o justificou; desvio da rubrica, com o motivo.
- `repo: novo`: duas folhas. Folha 1 (git + arch) sempre espera uma palavra; o Git Manager subagente faz `git init -b main`, `.gitignore` e commit vazio, e o Architect escreve `spec.md` e `plan.md`. Folha 2 sai depois do `plan.md`, com uma área por fronteira de arquivo, e segue as regras normais.
- Folha com Recon: rode-o como subagente com `agents/recon.md` antes do Architect (passo 3). Sem Recon, o Architect lê o mapa válido existente (`.claude/specs/mapa.md` ou `<brain_dir>/repos/<repo>.md`) mais o `mapa-padrao.md`.

## 3. Contratar

```bash
scripts/scaffold.sh NNN-slug     # NNN = próximo número livre em current/ e archive/
```

- Spec existente (`spec=sim`): siga a regra da rubrica; continuar ou reusar slug dispensa o `scaffold.sh`.
- Architect terminal (2+ áreas, chamada nominal `arch` ou Grande): conduz a descoberta e escreve `spec.md` e `plan.md`.
- Architect subagente (demais casos): escreve a spec curta com o que o Orchestrator passar. Na Pequena, a conversa de descoberta com o usuário é do Orchestrator, que entrega as respostas ao subagente; o Architect só escreve.
- Nível 1: spec de 1 página com comandos de aceitação; `plan.md` opcional. Nível 2: spec curta, testes de contrato e fixtures aprovados pelo usuário antes das WPs de implementação, `plan.md` obrigatório. Pequena + Nível 2: spec curta + lista dos testes de contrato exigidos; `plan.md` só com mais de uma WP.
- Brownfield: o Architect confere `tests/test_<mod>*` dos módulos que mudam. Sem teste, a WP-01 é o teste de caracterização (fixture gravada em `tests/fixtures/`, teste em `tests/`), escrita pelo Engineer e revisada antes das outras WPs.
- Projeto novo: onda 1 é o esqueleto, em série, por um Engineer seguindo `mapa-padrao.md`; depois, paralelo.
- Architect escreve `tests/aceite/test_<slug>.py` (um teste por critério de aceite; Nível 2 também contrato e fixtures) antes das WPs começarem: oráculo que o Engineer não edita (`references/guardrails.md`).
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

- Depois do checkpoint da spec e antes do `worktree add` das WPs, o Git Manager commita `tests/aceite/**` (e `.claude/specs/**`) em `feat/NNN-slug` no worktree principal (hook no-op), com `SDD_GIT_MANAGER=1`. Sem isso as WPs nascem sem o oráculo.
- Git Manager primeiro: branch `feat/NNN-slug`, um worktree por WP da onda (com `setup.sh` rodado nele, se existir) e um único worktree do Reviewer no andar, desanexado, com guarda (`agents/git-manager.md`):

```bash
git worktree add ../<repo>-WP-NN -b feat/NNN-slug-WP-NN feat/NNN-slug
scripts/guard-install.sh ../<repo>-WP-NN eng WP-NN <paths-csv>
git worktree add --detach ../<repo>-rev feat/NNN-slug        # uma vez por andar
scripts/guard-install.sh ../<repo>-rev rev WP-NN <paths-csv> # para rev, WP e paths não restringem: todo commit é bloqueado
```

- Uma WP por Engineer por andar: nova WP é novo role, novo worktree, novo `.sdd-role`.
- Depois Engineers e Reviewer, com os comandos de `references/recrutamento.md`. Registre cada um em `equipe.md`.

## 6. Delegar

- Mensagem de quatro linhas: objetivo, WP, fronteira, formato de retorno (o bloco fixo do role).
- A nota `tasks-<nome>` traz o bloco da WP e o comando exato de evidência:

```bash
scripts/wp-check.sh WP-NN --tasks <abs>/.claude/specs/current/NNN-slug/tasks.md
```

  Base padrão `feat/NNN-slug`; arquivos em `.claude/` são ignorados. Antes do commit o diff sai vazio: lint, testes e dry-run valem; o diff vale na rodada do Reviewer.
- Sequência por WP: Engineer `ok` → Git Manager commita no worktree da WP (`git add -A`, `SDD_GIT_MANAGER=1`), antes da revisão → Git Manager posiciona o worktree do Reviewer (`git -C ../<repo>-rev checkout --detach feat/NNN-slug-WP-NN`) → Reviewer roda `wp-check.sh` e lê o diff (`aceite-intacto: falha` reprova) → `aprovado` ou volta ao Engineer.
- Revisões em série: o worktree `../<repo>-rev` é único, então o Reviewer revisa uma WP por vez. O Orchestrator enfileira os pedidos de revisão e só manda o próximo depois do retorno do anterior.
- `pre-commit` bloqueou por arquivo fora dos paths: se for artefato gerado conhecido (`__pycache__/`, `.pytest_cache/`, `.ruff_cache/`, `*.pyc`, `.claude/settings.local.json`), o Git Manager tira do stage só esses artefatos (`git -C <worktree> rm -r --cached <artefato>`), acrescenta o padrão a `$(git -C <worktree> rev-parse --git-path info/exclude)` (num worktree ligado `.git` é arquivo, não diretório) e repete o commit uma vez. O hook para no primeiro arquivo barrado: liste todos os artefatos em stage com `git -C <worktree> diff --cached --name-only` antes de tirar. Nenhum outro arquivo sai do stage. Qualquer outro arquivo: o Git Manager devolve `bloqueado` com a lista, e o Orchestrator manda ao Engineer como `falha`. O Engineer remove ou move o que gerou (pode apagar arquivo não rastreado que criou pelo shell) e reporta de novo.
- Reprovada duas vezes ou Engineer `bloqueado`: registre em `bloqueios.md` (formato em `references/painel.md`) e acione o dono da decisão (Architect para ambiguidade de contrato, usuário para regra de negócio).
- Atualize a lane em `tasks.md` a cada passagem.

## 7. Integrar

- Git Manager faz merge das WPs `aprovado` em `feat/NNN-slug`. Lane `pronto`.
- `.claude/specs/**` é commitado pelo Git Manager na branch `feat/NNN-slug`, no worktree principal (sem `.sdd-role`, hook no-op), no fim de cada onda.
- Fim da onda: `scripts/painel.sh NNN-slug --publicar` e checkpoint com o usuário (`references/painel.md`).
- Push e PR só com autorização explícita do usuário.
- Pouso do andar: mova as WPs `pronto` para `tasks-done.md` e libere os nomes em `equipe.md`. Remover worktree ou dispensar terminal só com autorização.
