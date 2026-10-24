# Ciclo

Sete passos, sempre nesta ordem. Os scripts ficam em `scripts/` da skill: o Orchestrator resolve a raiz do plugin (`${CLAUDE_PLUGIN_ROOT}/skills/sdd-karazhan`, ou o diretório base informado ao carregar a skill) e passa **caminhos absolutos** a todo agente, inclusive ao Reviewer no Codex. Nos roles essa raiz é o placeholder `<SK>`, o único deles, preenchido ao criar o role do papel (`references/recrutamento.md`); o resto do que é de cada agente vai na nota `tasks-<Nome>`. Scripts rodam na raiz do repo alvo, salvo indicação.

## 1. Inventariar

```bash
maestri list                     # responde → modo Maestri; comando ausente → modo subagente
maestri preset list              # presets do workspace (só no modo Maestri)
scripts/inventario.sh            # oito linhas de fatos: repo, módulos, áreas, specs, mapa, presets, conectados, bld_max
scripts/pick-name.sh orch        # só se o You: não é nome do pool orch; no Maestri, depois, maestri arrange (ver abaixo)
```

- Preset sem entrada em `.claude/specs/karazhan.json`: faça a pergunta única (`references/recrutamento.md`) antes de convocar.
- O script só coleta fatos. Não lê o pedido nem decide o time.
- Nome e role do Orchestrator (`references/recrutamento.md`): se o `You:` de `maestri list` já é um nome do pool `orch` (sem diferenciar maiúsculas), use-o; senão sorteie com `pick-name.sh orch` e, no Maestri, renomeie-se com `maestri arrange "<nome atual>" --name "<Nome>"` (sem reinício), avisando o usuário numa linha e usando o nome devolvido se vier `#2`. Garanta o role global `Orchestrator` (criação: seção Roles). Sem a linha `Orchestrator: <Nome> — role Orchestrator atribuído (usuário, <data>)` em `.claude/specs/equipe.md`, peça ao usuário, uma vez, que atribua o role pelo app (o Maestri recusa em si mesmo; reinicia o terminal) e registre a linha quando ele disser que atribuiu. Com a linha, não pergunte. Sem o role, siga. Modo subagente: só o sorteio.

## 2. Decidir

- Antes da folha, leia as entradas `lição` de `decisoes.md` (passo 7): elas valem como regra para esta feature.
- Com o pedido e o inventário, aplique `references/convocacao.md`: nível de contrato (0/1/2), tamanho do time, papéis, tiers, presets e nomes (`pick-name.sh <prefixo>` por papel; Git Manager em `conectados` com origem `terminal` é reaproveitado).
- Nível 0: o Orchestrator diz ao usuário que não vai usar a skill e para; o usuário faz direto.
- Mostre a folha (sete linhas, porquê inline; a linha `Tamanho:` diz Pequena, Média ou Grande). Pequena: siga sem esperar; os terminais só nascem depois do checkpoint da spec (passo 3), e o usuário responde `para` para ajustar o time. Média e Grande: espere uma palavra.
- Chamada nominal (`arch bld rev git`): só os papéis pedidos; `arch` nominal é terminal. `bld` sem `git` ou `rev` sem `bld`: mostre o motivo e pergunte de novo. Não complete a lista por conta própria. `grande` sozinho não é chamada nominal: só força o tamanho Grande.
- `Reviewer: NÃO CONVOCADO (sem Codex)` na linha `Terminais:`: pergunte ao usuário se segue sem Reviewer ou se configura um preset Codex. Não siga em silêncio.
- Registre em `decisoes.md` cada papel convocado e o sinal que o justificou; desvio da rubrica, com o motivo.
- `repo: novo`: duas folhas. Folha 1 (git + arch, com `Tamanho: a definir (até o plan.md)`) sempre espera uma palavra, porque o tamanho ainda não existe; o Git Manager subagente faz `git init -b main`, `.gitignore` e commit vazio, e o Architect escreve `spec.md` e `plan.md`. Folha 2 sai depois do `plan.md`, com uma área por fronteira (módulo ou pacote do `plan.md`, não arquivo), e segue as regras normais.
- Folha com Recon: rode-o como subagente com `agents/recon.md` antes do Architect (passo 3). Sem Recon, o Architect lê o mapa válido existente (`.claude/specs/mapa.md` ou `<brain_dir>/repos/<repo>.md`) mais o `mapa-padrao.md`.

## 3. Contratar

```bash
scripts/scaffold.sh NNN-slug     # NNN = próximo número livre em current/ e archive/
```

- Spec existente (`spec=sim`): siga a regra da rubrica; continuar ou reusar slug dispensa o `scaffold.sh`.
- Architect terminal (2+ áreas, chamada nominal `arch` ou Grande): conduz a descoberta e escreve `spec.md` e `plan.md`.
- Architect subagente (demais casos): escreve a spec curta com o que o Orchestrator passar. Na Pequena, a conversa de descoberta com o usuário é do Orchestrator, que entrega as respostas ao subagente; o Architect só escreve.
- Nível 1: spec de 1 página com comandos de aceitação; `plan.md` opcional. Nível 2: spec curta, testes de contrato e fixtures aprovados pelo usuário antes das WPs de implementação, `plan.md` obrigatório. Pequena + Nível 2: spec curta + lista dos testes de contrato exigidos; `plan.md` só com mais de uma WP.
- Brownfield: o Architect confere `tests/test_<mod>*` dos módulos que mudam. Sem teste, a WP-01 é o teste de caracterização (fixture gravada em `tests/fixtures/`, teste em `tests/`), feita em série pelo mesmo Builder da WP que muda o módulo, no mesmo worktree, antes dela, e revisada antes da WP do módulo. Não conta como área nem muda o tamanho. O oráculo dela, `tests/aceite/test_wp01_<mod>.py`, confere que `tests/test_<mod>*.py` existe (glob não vazio) e passa: `subprocess.run([sys.executable, "-m", "pytest", *arquivos])` com `returncode == 0`.
- Projeto novo: onda 1 é o esqueleto, em série, por um Builder seguindo `mapa-padrao.md`; depois, paralelo. O Builder do esqueleto roda o `setup.sh` depois de escrevê-lo, para o `aceite` já ter pytest.
- Architect escreve um arquivo de aceite por WP, `tests/aceite/test_wp<NN>_<slug>.py` (ex.: `test_wp01_filtro.py`, `test_wp02_envio.py`; um teste por critério de aceite da WP; Nível 2 também contrato e fixtures), antes das WPs começarem: oráculo que o Builder não edita (`references/guardrails.md`). Teste de contrato (Nível 2) vai no arquivo da WP dona da fronteira. Toda WP tem o seu arquivo: havendo algum `test_wp*`, WP sem arquivo dá `aceite: falha`.
- Checkpoint: o usuário aprova a spec. O Orchestrator nunca escreve spec.

## 4. Particionar

- Escreva uma WP por bloco em `tasks.md`, no formato do template do `scaffold.sh` (`### WP-NN — título`, `- Lane:`, `- Dono:`, `- Possui:`, `- Fora de escopo:`, `- Objetivo:`, `- Aceite:`, `- Evidência:`, `- Depende de:`).
- Um dono por path. `deploy/**`, `run.sh` e `setup.sh` têm dono explícito quando tocados.
- Ondas pelo campo `Depende de`.
- Cada WP deixa a branch mergeável: depois do merge dela, `feat/NNN-slug` roda e passa nos testes do que já existe, sem nada pela metade. Tamanho de WP: 30 a 90 minutos de trabalho do Builder; maior que isso, divida em duas WPs.

```bash
scripts/donos.sh NNN-slug        # precisa sair 0: orfaos: 0 e duplicados: 0
```

Lanes: `planejado` → `fazendo` → `revisão` → `aprovado` → `pronto` (integrada).

## 5. Recrutar

Git Manager primeiro, nesta ordem (`agents/git-manager.md`):

1. Branch `feat/NNN-slug` no worktree principal (`git switch -c feat/NNN-slug`, se faltar).
2. Nela, depois do checkpoint da spec, o commit de `tests/aceite/**` (e `.claude/specs/**`), no worktree principal (hook no-op). Sem isso as WPs nascem sem o oráculo.
3. Um worktree por WP da onda (com `setup.sh` rodado nele, se existir) e um único worktree do Reviewer no andar, desanexado, com guarda. O `-rev` também precisa das dependências: `setup.sh` em `../<repo>-rev` uma vez por andar, se existir, e de novo quando `requirements*`/`pyproject.toml` mudar.

```bash
git worktree add ../<repo>-WP-NN -b feat/NNN-slug-WP-NN feat/NNN-slug
scripts/guard-install.sh ../<repo>-WP-NN bld WP-NN <paths-csv>
git worktree add --detach ../<repo>-rev feat/NNN-slug        # uma vez por andar
scripts/guard-install.sh ../<repo>-rev rev WP-NN <paths-csv> # para rev, WP e paths não restringem: todo commit é bloqueado
```

- Uma WP por Builder por andar: nova WP é novo agente, novo worktree, novo `.sdd-role` e nova nota. Única exceção: a caracterização (WP-01) e a WP seguinte do mesmo módulo correm no mesmo worktree e na mesma branch (`feat/NNN-slug-WP-01`), com o mesmo Builder. Aprovada a WP-01, o Git Manager faz o merge dela em `feat/NNN-slug` e roda de novo `scripts/guard-install.sh <worktree> bld WP-02 <paths da WP-02>` (sobrescreve o `.sdd-role`); o Orchestrator delega a WP-02 reescrevendo a nota `tasks-<Nome>`. Sem terminal nem worktree novos: o role é o do papel e não muda; só a nota `tasks-<Nome>` é reescrita. A caracterização fixa só comportamento que deve ser preservado: mudança intencional de comportamento caracterizado é bloqueio, com emenda do Architect, e o arquivo de teste passa ao `Possui` da WP que muda o comportamento.
- Depois Builders e Reviewer, com os comandos de `references/recrutamento.md`. Registre cada um em `equipe.md`.

## 6. Delegar

- Mensagem de quatro linhas: objetivo, WP, fronteira, formato de retorno (o bloco fixo do role).
- A nota `tasks-<Nome>` traz o bloco da WP e o comando exato de evidência:

```bash
scripts/wp-check.sh WP-NN --tasks <abs>/.claude/specs/current/NNN-slug/tasks.md
```

  Esse é o comando do Builder, sem flag: a etapa `aceite` roda só o arquivo da WP. `--regressao` é do Reviewer, depois do merge de integração. Base padrão `feat/NNN-slug`; arquivos em `.claude/` são ignorados. Antes do commit o diff sai vazio: lint, testes e dry-run valem; o diff vale na rodada do Reviewer.
- Sequência por WP: Builder `ok` → Git Manager commita no worktree da WP (`git add -A`, `SDD_GIT_MANAGER=1`), antes da revisão → Git Manager integra `feat/NNN-slug` na branch da WP (`SDD_GIT_MANAGER=1 git -C <worktree> merge --no-edit feat/NNN-slug`), antes de toda revisão, para a regressão rodar com o código das WPs já integradas. O merge da WP aprovada anterior em `feat/NNN-slug` (lane `pronto`) acontece antes da integração da próxima revisão. Conflito: o Git Manager roda `git -C <worktree> merge --abort` e abre entrada em `bloqueios.md` para o Orchestrator, não `falha` ao Builder; com um dono por path, conflito é violação de dono ou arquivo fora do `## Dentro`, e o Architect emenda a spec. O diff de três pontos continua mostrando só a WP → Git Manager posiciona o worktree do Reviewer (`git -C ../<repo>-rev checkout --detach feat/NNN-slug-WP-NN`; na WP que segue a caracterização, a branch é `feat/NNN-slug-WP-01`) → Reviewer roda `wp-check.sh WP-NN --tasks <abs> --regressao` (a etapa `aceite` roda o `test_wp<NN>_*.py` da WP mais os das WPs em `pronto`, já integradas em `feat/NNN-slug`, contra regressão) e lê o diff (`aceite-intacto: falha` reprova; só falha de correção ou de requisito reprova, e `observações:` não volta como defeito) → `aprovado` ou volta ao Builder. Cada reprovação é anotada no `- Evidência:` da WP em `tasks.md` (rodada e defeitos), que é a contagem da regra abaixo.
- Revisões em série: o worktree `../<repo>-rev` é único, então o Reviewer revisa uma WP por vez. O Orchestrator enfileira os pedidos de revisão e só manda o próximo depois do retorno do anterior.
- `pre-commit` bloqueou por arquivo fora dos paths: se for artefato gerado conhecido (`__pycache__/`, `.pytest_cache/`, `.ruff_cache/`, `*.pyc`, `.claude/settings.local.json`), o Git Manager tira do stage só esses artefatos (`git -C <worktree> rm -r --cached <artefato>`), acrescenta o padrão a `$(git -C <worktree> rev-parse --git-path info/exclude)` (num worktree ligado `.git` é arquivo, não diretório) e repete o commit uma vez. O hook para no primeiro arquivo barrado: liste todos os artefatos em stage com `git -C <worktree> diff --cached --name-only` antes de tirar. Nenhum outro arquivo sai do stage. Qualquer outro arquivo: o Git Manager devolve `bloqueado` com a lista, e o Orchestrator manda ao Builder como `falha`. O Builder remove ou move o que gerou (pode apagar arquivo não rastreado que criou pelo shell) e reporta de novo.
- Builder `bloqueado`, ou segunda reprovação da mesma WP por ambiguidade de contrato ou regra de negócio: registre em `bloqueios.md` (formato em `references/painel.md`) e acione o dono da decisão (Architect para contrato, usuário para regra de negócio).
- Dois erros, Builder novo: na segunda reprovação da mesma WP por outro motivo, o contexto do Builder já está gasto. Recrute outro Builder (`pick-name.sh bld`, contexto limpo) para a mesma WP, no mesmo worktree e guarda, com a nota e os defeitos do Reviewer. O Orchestrator manda o antigo parar de editar e não lhe manda mais nada; dispensá-lo só com ok do usuário, nunca por conta própria. Registre a troca em `decisoes.md` e em `equipe.md`. Builder novo também com duas reprovações: vira bloqueio em `bloqueios.md`, e o usuário decide.
- Atualize a lane em `tasks.md` a cada passagem.

## 7. Integrar

- Git Manager faz merge das WPs `aprovado` em `feat/NNN-slug` logo após a aprovação, antes da integração da próxima revisão. Lane `pronto`.
- `.claude/specs/**` é commitado pelo Git Manager na branch `feat/NNN-slug`, no worktree principal (sem `.sdd-role`, hook no-op), no fim de cada onda.
- Fim da onda: `scripts/painel.sh NNN-slug --publicar` e checkpoint com o usuário (`references/painel.md`).
- Push e PR só com autorização explícita do usuário.
- Erro recorrente vira harness: quando um defeito, bloqueio ou `observações:` repete um problema já visto noutra feature (em `bloqueios.md` ou `decisoes.md`), registre em `decisoes.md` uma entrada `## <data> · <orch> · lição: <problema>` e corrija o harness, não só o código: teste estrutural ou linha no `CLAUDE.md` do repo viram WP com dono (na feature atual ou na próxima); linha no `mapa-padrao.md` da skill, o Orchestrator propõe e o usuário aplica.
- Pouso do andar: o Git Manager posiciona o worktree do Reviewer em `feat/NNN-slug` (`git -C ../<repo>-rev checkout --detach feat/NNN-slug`) e o Reviewer roda `scripts/wp-check.sh WP-NN --tasks <abs> --tudo` (qualquer WP; o diff sai vazio; nota de pouso em `references/recrutamento.md`): aprova com `aceite: ok` no `tests/aceite/` inteiro e `testes: ok`; senão volta ao Orchestrator como bloqueio. Depois, mova as WPs `pronto` para `tasks-done.md`, libere os nomes em `equipe.md`, mova `current/NNN-slug/` para `archive/<dominio>/NNN-slug/` e atualize `archive/INDEX.md`. Remover worktree ou dispensar terminal só com autorização.
