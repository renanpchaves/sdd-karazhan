<p align="center">
  <img src="assets/banner.jpg" alt="sdd-karazhan" width="100%">
</p>

# sdd-karazhan

**Spec primeiro. Time mínimo. Codex julga o Claude.**

Plugin do Claude Code para orquestrar agentes no [Maestri](https://maestri.dev).

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

| Papel | Prefixo | Faz | Elenco |
|---|---|---|---|
| **Orchestrator** | `orch` | Rege. Não codifica. | Magos de Dalaran: `antonidas`, `jaina`, `aethas`, `khadgar`, `aegwynn`, `kelthuzad` |
| **Architect** | `arch` | Descoberta, `spec.md`, `plan.md`, aceite como teste. | Dragões: `alexstrasza`, `nozdormu`, `ysera`, `kalecgos`, `wrathion`, `ebyssian`, `vyranoth`, `merithra`, `krasus` |
| **Recon** | `rec` | Entra, mapeia o repo, sai. Subagente. | Batedores: `garona`, `valeera`, `mathias`, `shandris`, `nathanos`, `rexxar` |
| **Engineer** | `eng` | Implementa no worktree dele. **Claude Code.** | Linha de frente: `grom`, `saurfang`, `durotan`, `orgrim`, `cairne`, `baine`, `thrall`, `varian`, `muradin`, `magni`, `tyrande`, `malfurion`, `illidan` |
| **Reviewer** | `rev` | Roda teste, lê diff, aprova ou devolve. **Codex.** | Julgadores: `uther`, `tirion`, `turalyon`, `bolvar`, `liadrin`, `alleria`, `arthas` |
| **Git Manager** | `git` | Worktree, hook, commit, PR. Dono do git. | Goblins e gnomos: `gazlowe`, `gallywix`, `mekkatorque`, `thermaplugg`, `brann`, `sprocket` |

Nome no canvas: `prefixo-personagem`. `eng-grom` implementa. `rev-arthas` devolve a WP inteira por um defeito. `git-gazlowe` cobra barato.

Papel diz o trabalho. Nome dá identidade. Não precisa saber lore.

## Como usar

```
/sdd-karazhan adicionar filtro por empresa no relatório
```

O `inventario.sh` imprime oito linhas de fatos: módulos, áreas, specs, mapa, presets, Codex, quem já está conectado. Não lê o pedido. O Orchestrator cruza pedido e fatos com a rubrica (`references/convocacao.md`) e monta a folha, com o porquê de cada papel:

```
Pedido: "adicionar filtro por empresa no relatório"
Sinais: módulos=1 (relatorio) · spec=não · mapa=ok · testes=sim · nível 1
Nível: Pequena — um módulo, sem regra de negócio nova
Terminais: eng-grom (claude/medio) — relatorio · rev-uther (codex/capaz)
Subagentes: arch-ysera — spec curta de 1 página · git-gazlowe (reaproveitado)
Não convocar: recon — mapa válido, esqueleto padrão
Presets: eng-grom=cc rev-uther=cx arch-ysera=cc git-gazlowe=cc-mini
```

Pequena: a folha aparece e o time já é convocado. Média e Grande: você diz "vai". Sem Codex, ou chamada nominal inválida: o Orchestrator pergunta antes.

Já sabe quem quer? Chama pelo nome:

```
/sdd-karazhan arch eng git
```

Vem só quem você chamou. Engineer exige Git Manager; Reviewer exige Engineer. Faltou: o Orchestrator avisa e pergunta de novo.

## Três níveis

| Nível | Quando | Contrato | Time |
|---|---|---|---|
| **0** | O diff cabe numa frase | Nenhum. Não use a skill: faça direto e rode pytest. | Você |
| **1** | Pequena: uma área | Spec de 1 página com comandos de aceitação | 1 Engineer · Reviewer · Architect subagente |
| **2** | Média, Grande, projeto novo, integração nova ou banco | Spec curta, testes de contrato e fixtures aprovados antes, ledger | Média: 2–3 Engineers. Grande: mais áreas que `eng_max`, Architect e Git Manager em terminal |

Mínimo é 3 terminais. Quem orquestra não implementa. Quem implementa não revisa. Dois pares de olhos, sempre.

Projeto novo: o Git Manager faz `git init`, o Architect vem primeiro e a onda 1 é o esqueleto, em série. Repo antigo com módulo sem teste: teste de caracterização antes de mexer.

## Regras que não se negociam

1. Um dono por path. Worktree por WP. Hook bloqueia o resto.
2. Git é só do Git Manager. `pre-commit` rejeita arquivo fora dos paths da WP.
3. Nada destrutivo ou externo sem você dizer sim. Merge, deploy, PR, deletar nó do canvas.
4. Handoff é por arquivo. Chat não é contrato.
5. Quem produz não aprova. Reviewer em Codex, em outro terminal, lendo diff.

## Scripts (o que não gasta token)

| Script | Faz |
|---|---|
| `inventario.sh` | Lista fatos do repo. O Orchestrator decide o time. |
| `pick-name.sh eng` | Sorteia nome livre do elenco. |
| `scaffold.sh 003-slug` | Cria specs e tasks. |
| `mapa-check.sh` | Mapa ainda vale? Idade e impressão digital da árvore. |
| `donos.sh 003-slug` | Arquivo no escopo sem dono? Lista. |
| `wp-check.sh WP-03` | Lint, pytest, `--dry-run` real, diff restrito aos paths, arquivo fora do path. |
| `painel.sh 003-slug` | Gera o painel do `tasks.md`. |
| `guard-install.sh` | Instala `.sdd-role` e `pre-commit` no worktree. |

## Fora do Maestri

Funciona. Com degradação explícita: papéis viram subagentes do Claude Code, Reviewer cai para Claude em preset diferente, guard de path vira só checagem de diff. A skill avisa na primeira linha.

## Instalar

```
claude plugin marketplace add renanpchaves/sdd-karazhan
claude plugin install sdd-karazhan@sdd-karazhan
```

Dentro do Claude Code: `/plugin marketplace add renanpchaves/sdd-karazhan` e `/plugin install sdd-karazhan@sdd-karazhan`.

Requer `git` e `jq`. `maestri` para o modo completo. `codex` para o Reviewer. `coreutils` no macOS (`brew install coreutils`) para o timeout.

Outro plugin com os mesmos gatilhos (Maestri, partitura, andar)? Desative um deles com `claude plugin disable <nome>`.

Primeira sessão num workspace cria `.claude/specs/karazhan.json` com uma única pergunta: família e tier de cada preset.

Testes: `bash tests/run.sh`

## Créditos

- Referência para a criação deste plugin: [SDD-Maestri](https://github.com/AndreRenatoMenezes/SDD-Maestri), de Andre Renato Menezes, MIT. Metodologia, cinco regras e estrutura de specs vêm de lá.
- Nomes dos personagens: Warcraft, © Blizzard Entertainment. Uso nominal, sem afiliação.

MIT. Veja [LICENSE](LICENSE).
