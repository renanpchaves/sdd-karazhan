# Convocação

Entrada: pedido + `inventario.sh`; o Orchestrator decide. Área tocada: módulo citado no pedido ou área do inventário (plist, launchd → `deploy`; alembic → `migracoes`). Áreas implícitas pela migração (`models`, `db`, `schemas`, as que existirem) contam como UMA área junto com a migração: um Engineer.

## Nível e tamanho

| Nível | Quando | Contrato |
|---|---|---|
| Nível 0 | O diff cabe numa frase | Nenhum: o Orchestrator avisa que não usa a skill e para; o usuário faz direto, com pytest |
| 1 | Pequena | Spec de 1 página: objetivo, arquivos e interfaces, fora de escopo, comandos de aceitação. `plan.md` opcional |
| 2 | Média, Grande, projeto novo, integração nova ou banco (inclusive migração) | Spec curta, testes de contrato e fixtures aprovados antes, ledger (`tasks.md`, `decisoes.md`) |

Tamanho: Pequena = 1 área; Média = 2 a `eng_max`; Grande = mais que `eng_max`, ou `grande`. Tamanho e contrato são eixos separados: 1 área com integração ou banco (inclusive migração, que já leva `models`/`db`/`schemas`) = Pequena + Nível 2 (Architect subagente: spec curta + testes de contrato exigidos; `plan.md` só com 2+ WPs).

## Papéis

- **Architect** (claude/capaz): terminal com 2+ áreas, nominal `arch` ou Grande; senão subagente de spec curta.
- **Recon** (claude/barato): subagente antes do Architect se `mapa` ≠ `ok` ou `esqueleto: fora`; nunca em `repo: novo`.
- **Engineer**: terminal Claude Code, um por área, até `eng_max`; com mais áreas que `eng_max`, agrupe por dependência (ex.: relatorio+envio num Engineer). `capaz` em deploy, config, auth, db (migração inclusa) ou crypto; senão `medio`. Várias áreas: o tier mais alto.
- **Reviewer** (codex/capaz): terminal. Sem Codex: no Maestri, `Reviewer: NÃO CONVOCADO (sem Codex)` em `Terminais:` e pergunte; fora dele, subagente Claude noutro preset, degradação em `decisoes.md`.
- **Git Manager** (claude/barato): subagente na Pequena e Média, terminal na Grande. Reaproveita o Git Manager de `conectados` só com origem `terminal`.

Nome: `pick-name.sh <prefixo>` (o personagem, ex.: `Grom`). Em `Terminais:` e `Subagentes:`, papel antes do nome (`Engineer Grom`); em `Presets:`, `Nome=preset`. Preset: família e tier em `presets`; sem o tier, sobe antes de descer (medio → capaz → barato).

`spec=sim`: `em curso` e o pedido cabe nela → continue (mesmo slug, novas WPs); `vazia` e o pedido cabe no slug → reuse o slug; senão → slug novo, citando a anterior se for `aprovada`.

Projeto novo: duas folhas. Folha 1 (git + arch, `Tamanho: a definir (até o plan.md)`) sempre espera uma palavra: Git Manager subagente (`git init -b main`, `.gitignore`, commit vazio); Architect: subagente se o usuário trouxe spec (converter, não reconstruir), terminal se trouxe ideia. Folha 2, depois do `plan.md`: uma área por fronteira (módulo ou pacote do `plan.md`, não arquivo), regras normais; onda 1 = esqueleto em série (um Engineer, `mapa-padrao.md`).

Brownfield: o Architect confere `tests/test_<mod>*`; sem teste, a WP-01 é o teste de caracterização (fixture em `tests/fixtures/`, teste em `tests/`), feita em série pelo Engineer do módulo, no mesmo worktree, antes da WP dele, e revisada antes da WP do módulo; não muda o tamanho.

Folha: sete linhas, porquê inline. Pequena: mostre e siga; terminais só nascem após o checkpoint da spec (passo 3), e `para` ajusta o time. Média e Grande: espere uma palavra. `NÃO CONVOCADO` ou nominal inválida: mostre o motivo e espere.

Chamada nominal (`/sdd-karazhan arch eng git`): só esses; `eng` exige `git`, `rev` exige `eng`. `grande` sozinho só força o tamanho.

Desvio da rubrica: uma linha em `decisoes.md`.

Erro recorrente vira harness: antes da folha, leia as entradas `lição` de `decisoes.md`. O mesmo problema em 2 features vira teste estrutural ou linha no `mapa-padrao.md` (ou no `CLAUDE.md` do repo), registrado como `lição` (`references/ciclo.md`).

## Exemplos

**relatorios**:
```
Pedido: "adicionar filtro por empresa no relatório"
Sinais: áreas=1 (relatorio) · spec=não · mapa=ok · testes=sim · nível 1
Tamanho: Pequena — 1 área, sem regra de negócio nova
Terminais: Engineer Grom (claude/medio) — relatorio · Reviewer Uther (codex/capaz) — Codex, contexto limpo
Subagentes: Architect Ysera — spec curta de 1 página · Git Manager Gazlowe (reaproveitado)
Não convocar: recon — mapa válido, esqueleto padrão
Presets: Grom=cc (medio → cc, sem preset medio) Uther=cx Ysera=cc Gazlowe=cc-mini
```

**licencas**:
```
Pedido: "novo coletor de licenças com plist no launchd"
Sinais: áreas=2 (coleta, deploy) · spec=não · mapa=ok · testes=sim · nível 2
Tamanho: Média — 2 áreas
Terminais: Architect Nozdormu (claude/capaz) — 2 áreas · Engineer Saurfang (claude/medio) — coleta · Engineer Thrall (claude/capaz) — deploy · Reviewer Tirion (codex/capaz) — revisão
Subagentes: Git Manager Gallywix — Média
Não convocar: recon — mapa válido, esqueleto padrão
Presets: Nozdormu=cc Saurfang=cc Thrall=cc Tirion=cx Gallywix=cc-mini
```

**sincronia**:
```
Pedido: "migração alembic do centro de custo + sincronização incremental + relatório e envio do fechamento"
Sinais: áreas=4 (migracoes+db+schemas, sync, relatorio, envio) · spec=não · mapa=ok · testes=sim · nível 2
Tamanho: Grande — 4 áreas > eng_max 3
Terminais: Architect Kalecgos (claude/capaz) — Grande · Engineer Durotan (claude/capaz) — migracoes+db+schemas, uma área · Engineer Cairne (claude/medio) — sync · Engineer Baine (claude/medio) — relatorio+envio, por dependência · Reviewer Bolvar (codex/capaz) — revisão · Git Manager Mekkatorque (claude/barato) — Grande
Subagentes: nenhum
Não convocar: recon — mapa válido, esqueleto padrão
Presets: Kalecgos=cc Durotan=cc Cairne=cc Baine=cc Bolvar=cx Mekkatorque=cc-mini
```

**coletor-alertas** (projeto novo, folha 1):
```
Pedido: "serviço novo que coleta alertas do monitoramento e manda resumo diário"
Sinais: áreas=0 (repo novo) · spec=não · mapa=ausente · testes=não · nível 2
Tamanho: a definir (até o plan.md)
Terminais: Architect Ysera (claude/capaz) — trouxe ideia, não spec
Subagentes: Git Manager Gazlowe — git init
Não convocar: recon — repo novo; eng e rev — só na folha 2
Presets: Ysera=cc Gazlowe=cc-mini
```
