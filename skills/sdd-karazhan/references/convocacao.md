# Convocação

Entrada: pedido + `inventario.sh`; o Orchestrator decide em três passos: conta as áreas, escolhe o tamanho, escolhe o nível.

## 1. Área

Grupo de arquivos que um Builder muda sozinho, sem tocar nos de outro. Grupos (do inventário):

- cada módulo do pacote, com o teste dele: `coleta.py` + `tests/test_coleta.py`;
- `deploy`: `deploy/*.plist`, `run.sh`, `setup.sh`;
- `config`: `config/`, `.env.example`;
- `migracoes`: `alembic/` junto com `models`, `db` e `schemas`.

Arquivos que precisam mudar juntos para a mudança fazer sentido são UMA área, mesmo em módulos diferentes (ex.: `graph_client.py` + `coleta.py` para ler um campo novo). A contagem é de áreas que o pedido **muda**, não das que ele só lê.

## 2. Tamanho (o time)

| Tamanho | Áreas tocadas | Builders | Architect | Git Manager | Aprovação do time |
|---|---|---|---|---|---|
| Pequena | 1 | 1 | subagente | subagente | automática |
| Média | 2 a `bld_max` | 1 por área | terminal | subagente | o usuário aprova |
| Grande | mais que `bld_max`, ou `grande` | `bld_max`, áreas agrupadas por dependência | terminal | terminal | o usuário aprova |

Reviewer: um, em Codex, em qualquer tamanho.

## 3. Nível (o contrato)

Independe do tamanho:

| Nível | Quando | Contrato |
|---|---|---|
| Nível 0 | O diff cabe numa frase | Nenhum: o Orchestrator avisa que não usa a skill e para; o usuário faz direto, com pytest |
| 1 | Pequena sem banco, integração nova nem auth | Spec de 1 página: objetivo, arquivos e interfaces, fora de escopo, comandos de aceitação. `plan.md` opcional |
| 2 | Média ou Grande; ou qualquer tamanho com banco (migração inclusa), integração nova ou auth; ou projeto novo | Spec curta, testes de contrato e fixtures aprovados antes, ledger (`tasks.md`, `decisoes.md`); `plan.md` com 2+ WPs |

| Pedido | Áreas | Tamanho | Nível |
|---|---|---|---|
| "corrigir o texto do e-mail" | 1 | — | 0 |
| "filtro por empresa no relatório" | 1 | Pequena | 1 |
| "ler um campo novo da API do Graph no coletor" | 1 | Pequena | 2 |
| "coletor novo com plist no launchd" | 2 | Média | 2 |
| "migração + sincronização + relatório + envio" | 4 | Grande | 2 |

## Papéis

- **Architect** (claude/capaz): terminal ou subagente conforme a tabela de tamanho; nominal `arch` = terminal.
- **Recon** (claude/barato): subagente antes do Architect se `mapa` ≠ `ok` ou `esqueleto: fora`; nunca em `repo: novo`.
- **Builder**: terminal Claude Code; agrupamento por dependência na Grande (ex.: relatorio+envio). `capaz` em deploy, config, auth, db (migração inclusa) ou crypto; senão `medio`. Várias áreas: o tier mais alto.
- **Reviewer** (codex/capaz): terminal. Sem Codex: no Maestri, `Reviewer: NÃO CONVOCADO (sem Codex)` em `Terminais:` e pergunte; fora dele, subagente Claude noutro preset, degradação em `decisoes.md`.
- **Git Manager** (claude/barato): conforme a tabela de tamanho. Reaproveita o de `conectados` só com origem `terminal`.

Nome: `pick-name.sh <prefixo>` (o personagem, ex.: `Grom`). Em `Terminais:` e `Subagentes:`, papel antes do nome (`Builder Grom`); em `Presets:`, `Nome=preset`. Preset: família e tier em `presets`; sem o tier, sobe antes de descer (medio → capaz → barato).

`spec=sim`: `em curso` e o pedido cabe nela → continue (mesmo slug, novas WPs); `vazia` e o pedido cabe no slug → reuse o slug; senão → slug novo, citando a anterior se for `aprovada`.

Projeto novo: duas folhas. Folha 1 (git + arch, `Tamanho: a definir (até o plan.md)`) sempre espera uma palavra: Git Manager subagente (`git init -b main`, `.gitignore`, commit vazio); Architect: subagente se o usuário trouxe spec (converter, não reconstruir), terminal se trouxe ideia. Folha 2, depois do `plan.md`: uma área por fronteira (módulo ou pacote do `plan.md`, não arquivo), regras normais; onda 1 = esqueleto em série (um Builder, `mapa-padrao.md`).

Brownfield: o Architect confere `tests/test_<mod>*`; sem teste, a WP-01 é o teste de caracterização (fixture em `tests/fixtures/`, teste em `tests/`), feita em série pelo Builder do módulo, no mesmo worktree, antes da WP dele, e revisada antes da WP do módulo; não muda o tamanho.

Folha: sete linhas, porquê inline. Pequena segue sem esperar, mas os terminais só nascem após o checkpoint da spec (passo 3), e `para` ajusta o time. `NÃO CONVOCADO` ou nominal inválida: mostre o motivo e espere.

Chamada nominal (`/sdd-karazhan arch bld git`): só esses; `bld` exige `git`, `rev` exige `bld`. `grande` sozinho só força o tamanho.

Desvio da rubrica: uma linha em `decisoes.md`.

Erro recorrente vira harness: antes da folha, leia as entradas `lição` de `decisoes.md`. O mesmo problema em 2 features vira teste estrutural ou linha no `mapa-padrao.md` (ou no `CLAUDE.md` do repo), registrado como `lição` (`references/ciclo.md`).

## Exemplos

**relatorios**:
```
Pedido: "adicionar filtro por empresa no relatório"
Sinais: áreas=1 (relatorio) · spec=não · mapa=ok · testes=sim · nível 1
Tamanho: Pequena — 1 área, sem regra de negócio nova
Terminais: Builder Grom (claude/medio) — relatorio · Reviewer Uther (codex/capaz) — Codex, contexto limpo
Subagentes: Architect Ysera — spec curta de 1 página · Git Manager Gazlowe (reaproveitado)
Não convocar: recon — mapa válido, esqueleto padrão
Presets: Grom=cc (medio → cc, sem preset medio) Uther=cx Ysera=cc Gazlowe=cc-mini
```

**licencas**:
```
Pedido: "novo coletor de licenças com plist no launchd"
Sinais: áreas=2 (coleta, deploy) · spec=não · mapa=ok · testes=sim · nível 2
Tamanho: Média — 2 áreas
Terminais: Architect Nozdormu (claude/capaz) — 2 áreas · Builder Saurfang (claude/medio) — coleta · Builder Thrall (claude/capaz) — deploy · Reviewer Tirion (codex/capaz) — revisão
Subagentes: Git Manager Gallywix — Média
Não convocar: recon — mapa válido, esqueleto padrão
Presets: Nozdormu=cc Saurfang=cc Thrall=cc Tirion=cx Gallywix=cc-mini
```

**sincronia**:
```
Pedido: "migração alembic do centro de custo + sincronização incremental + relatório e envio do fechamento"
Sinais: áreas=4 (migracoes+db+schemas, sync, relatorio, envio) · spec=não · mapa=ok · testes=sim · nível 2
Tamanho: Grande — 4 áreas > bld_max 3
Terminais: Architect Kalecgos (claude/capaz) — Grande · Builder Durotan (claude/capaz) — migracoes+db+schemas, uma área · Builder Cairne (claude/medio) — sync · Builder Baine (claude/medio) — relatorio+envio, por dependência · Reviewer Bolvar (codex/capaz) — revisão · Git Manager Mekkatorque (claude/barato) — Grande
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
Não convocar: recon — repo novo; bld e rev — só na folha 2
Presets: Ysera=cc Gazlowe=cc-mini
```
