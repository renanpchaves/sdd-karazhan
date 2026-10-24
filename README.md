<p align="center">
  <img src="assets/banner.jpg" alt="sdd-karazhan" width="100%">
</p>

**Spec primeiro. Time mínimo. Revisão independente.**

Plugin do Claude Code para orquestrar times de agentes de IA. Roda com terminais no canvas do [Maestri](https://maestri.dev) ou com subagentes num terminal comum.

---

## A ideia, em quatro frases

1. Arquiteto escreve contrato. Engineer cumpre contrato. Ninguém implementa sem contrato.
2. Um Engineer, um worktree, um dono por arquivo. Hook impede o resto.
3. Quem escreve código é Claude. Quem julga é Codex. Sempre.
4. Convoca só quem a missão precisa. Script levanta os fatos, o Orchestrator decide, você vê o porquê.

## Por que existe

Time grande para feature pequena custa caro. Nota e painel escritos à mão gastam token. Pergunta de preset toda hora cansa. Orquestração assim dá preguiça de chamar.

A resposta: script inventaria o repo, script cria notas, script gera painel, script sorteia nome. O Orchestrator só decide.

## Quem vem à festa

| Papel | Prefixo | Faz |
|---|---|---|
| **Orchestrator** | `orch` | Rege. Não codifica. |
| **Architect** | `arch` | Descoberta, `spec.md`, `plan.md`, aceite como teste em `tests/aceite/`. |
| **Recon** | `rec` | Entra, mapeia o repo, sai. Subagente. |
| **Engineer** | `eng` | Implementa no worktree dele. **Claude Code.** |
| **Reviewer** | `rev` | Roda teste, lê diff, aprova ou devolve. **Codex.** |
| **Git Manager** | `git` | Worktree, hook, commit, PR. Dono do git. |

Nome no canvas: o personagem; o badge mostra o papel (`Grom`, badge `Engineer`). O nome sai de um elenco de Warcraft (`roster.json`, editável; só letras). Papel diz o trabalho. Nome dá identidade. Não precisa saber lore. O prefixo da tabela é só a chave do pool no `pick-name.sh`.

## Como usar

```
/sdd-karazhan adicionar filtro por empresa no relatório
```

O `inventario.sh` imprime oito linhas de fatos: módulos, áreas, specs, mapa, presets, Codex, quem já está conectado. Não lê o pedido. O Orchestrator cruza pedido e fatos com a rubrica (`references/convocacao.md`) e monta a folha, com o porquê de cada papel:

```
Pedido: "adicionar filtro por empresa no relatório"
Sinais: áreas=1 (relatorio) · spec=não · mapa=ok · testes=sim · nível 1
Tamanho: Pequena — 1 área, sem regra de negócio nova
Terminais: Engineer Grom (claude/medio) — relatorio · Reviewer Uther (codex/capaz) — Codex, contexto limpo
Subagentes: Architect Ysera — spec curta de 1 página · Git Manager Gazlowe (reaproveitado)
Não convocar: recon — mapa válido, esqueleto padrão
Presets: Grom=cc (medio → cc, sem preset medio) Uther=cx Ysera=cc Gazlowe=cc-mini
```

Pequena: a folha aparece e o trabalho segue sem esperar; os terminais só nascem depois que você aprova a spec. Para mudar o time, responda `para`. Média e Grande: você diz "vai". Sem Codex, ou chamada nominal inválida: o Orchestrator pergunta antes.

Já sabe quem quer? Chama pelo nome:

```
/sdd-karazhan arch eng git
```

Vem só quem você chamou. Engineer exige Git Manager; Reviewer exige Engineer. Faltou: o Orchestrator avisa e pergunta de novo. `/sdd-karazhan grande <pedido>` não é chamada nominal: só força o tamanho Grande.

## Três níveis

| Nível | Quando | Contrato | Time |
|---|---|---|---|
| **0** | O diff cabe numa frase | Nenhum. O Orchestrator avisa que não vai usar a skill e para: você faz direto e roda pytest. | Você |
| **1** | Pequena: uma área | Spec de 1 página com comandos de aceitação | 1 Engineer · Reviewer · Architect subagente · Git Manager subagente |
| **2** | Média, Grande, projeto novo, integração nova ou banco (inclusive migração) | Spec curta, testes de contrato e fixtures aprovados antes, ledger | Média: 2 a `eng_max` Engineers. Grande: mais áreas que `eng_max`, Architect e Git Manager em terminal |

Pequena: 2 terminais executores (Engineer + Reviewer) mais o seu. Quem orquestra não implementa. Quem implementa não revisa. Dois pares de olhos, sempre.

Nível e tamanho são eixos separados: uma área com integração ou banco (inclusive migração) é Pequena com contrato Nível 2.

Projeto novo: duas folhas. A primeira (Git Manager faz `git init`, Architect escreve spec e plan) sempre espera sua palavra; a segunda sai do `plan.md`, e a onda 1 é o esqueleto, em série. Repo antigo com módulo sem teste: teste de caracterização antes de mexer.

## Regras que não se negociam

1. Um dono por path. Worktree por WP. Hook bloqueia o resto.
2. Git é só do Git Manager. `pre-commit` rejeita arquivo fora dos paths da WP.
3. Nada destrutivo ou externo sem você dizer sim. Merge, deploy, PR, deletar nó do canvas.
4. Handoff é por arquivo. Chat não é contrato.
5. Quem produz não aprova. Reviewer em Codex, em outro terminal, lendo diff.
6. Teste de aceite é do Architect, em `tests/aceite/`, um arquivo por WP. Engineer não toca. Hook, `pre-commit` e `wp-check` garantem.

## Ciclo que não gera retrabalho

- Reviewer só reprova por correção ou requisito. Estilo vai em `observações` e não reprova.
- Segunda reprovação da mesma WP: Engineer novo, contexto limpo.
- Mesmo erro em duas features: vira teste, linha no `mapa-padrao.md` ou no `CLAUDE.md` do repo. Registrado como `lição`.
- Cada WP deixa a branch mergeável. 30 a 90 minutos. Maior que isso, divide.
- Antes de cada revisão, o Git Manager integra a feature na branch da WP. Regressão das WPs prontas roda no Reviewer.

Por que assim: [`docs/pesquisa/2026-10-24-praticas-agentes.md`](docs/pesquisa/2026-10-24-praticas-agentes.md), levantamento de campo com fontes.

## Scripts (o que não gasta token)

| Script | Faz |
|---|---|
| `inventario.sh` | Lista fatos do repo. O Orchestrator decide o time. |
| `pick-name.sh eng` | Sorteia nome livre do elenco. |
| `scaffold.sh 003-slug` | Cria specs e tasks. |
| `mapa-check.sh` | Mapa ainda vale? Idade e impressão digital da árvore. |
| `donos.sh 003-slug` | Arquivo no escopo sem dono? Lista. |
| `wp-check.sh WP-03` | Lint, pytest, `aceite` (oráculo da WP), `--dry-run` real, diff restrito aos paths, arquivo fora do path, `aceite-intacto`. `--regressao` soma o aceite das WPs prontas; `--tudo`, o `tests/aceite/` inteiro. |
| `painel.sh 003-slug` | Gera o painel do `tasks.md`. |
| `guard-install.sh` | Instala `.sdd-role` e `pre-commit` no worktree. |

## Onde roda

- **Maestri:** cada papel é um terminal no canvas, com nota própria e worktree próprio. Reviewer em Codex.
- **Terminal comum, sem Maestri:** os papéis viram subagentes do Claude Code; Reviewer em Claude com preset diferente; guard de path vira só checagem de diff. A skill avisa na primeira linha qual modo está ativo.

## Instalar

```
claude plugin marketplace add renanpchaves/sdd-karazhan
claude plugin install sdd-karazhan@sdd-karazhan
```

Dentro do Claude Code: `/plugin marketplace add renanpchaves/sdd-karazhan` e `/plugin install sdd-karazhan@sdd-karazhan`.

Ou, para Claude Code, Codex, Cursor e outros agentes:

```
npx skills add renanpchaves/sdd-karazhan
```

Instala a skill (roles, referências, scripts). Não registra o hook `path-guard`: a guarda de paths fica só no `pre-commit` e no `wp-check`. Para o Reviewer em Codex é o caminho normal.

Requer `git` e `jq`. `maestri` para o modo completo. `codex` para o Reviewer. `coreutils` no macOS (`brew install coreutils`) para o timeout.

Outro plugin com os mesmos gatilhos (Maestri, partitura, andar)? Desative um deles com `claude plugin disable <nome>`.

Primeira sessão num workspace cria `.claude/specs/karazhan.json` com uma única pergunta: família e tier de cada preset.

No Maestri, o plugin cria na máquina até cinco roles globais, um por papel: `Architect`, `Engineer`, `Reviewer`, `Git Manager` e `Orchestrator`. Valem para todos os projetos. Para remover: liste com `maestri role list` e apague pela interface do Maestri.

Testes: `bash tests/run.sh`

## Créditos

- Referência para a criação deste plugin: [SDD-Maestri](https://github.com/AndreRenatoMenezes/SDD-Maestri), de Andre Renato Menezes, MIT. Metodologia, cinco regras e estrutura de specs vêm de lá.
- Nomes dos personagens: Warcraft, © Blizzard Entertainment. Uso nominal, sem afiliação.

MIT. Veja [LICENSE](LICENSE).
