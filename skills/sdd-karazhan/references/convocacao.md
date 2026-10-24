# Convocação

Entrada: pedido + fatos do `inventario.sh`. O Orchestrator decide. Área tocada: módulo ou área citada no pedido (plist, launchd → deploy).

## Níveis

| Nível | Quando | Contrato |
|---|---|---|
| Nível 0 | O diff cabe numa frase | Nenhum: não use a skill; faça direto e rode pytest |
| 1 | Pequena | Spec de 1 página: objetivo, arquivos e interfaces, fora de escopo, comandos de aceitação. `plan.md` opcional |
| 2 | Média, Grande, projeto novo, integração nova ou banco | Spec curta, testes de contrato e fixtures aprovados antes, ledger (`tasks.md`, `decisoes.md`) |

Tamanho: Pequena = 1 Engineer; Média = 2–3; Grande = áreas > `eng_max` ou `grande`. Tamanho e contrato são eixos separados: 1 área com integração ou banco novo = Pequena + Nível 2.

## Papéis

- **Architect** (claude/capaz): terminal com 2+ áreas, nominal `arch` ou Grande; senão subagente de spec curta.
- **Recon** (claude/barato): subagente, só se `mapa` ≠ `ok` ou `esqueleto: fora`. Nunca em `repo: novo`.
- **Engineer**: terminal Claude Code, um por área, até `eng_max`. `capaz` em deploy, config, auth, db ou crypto; senão `medio`.
- **Reviewer** (codex/capaz): terminal. `codex: não` no Maestri → `Reviewer: NÃO CONVOCADO (sem Codex)`; pergunte ao usuário. Fora do Maestri: subagente Claude, outro preset, degradação em `decisoes.md`.
- **Git Manager** (claude/barato): subagente na Pequena e Média, terminal na Grande. `git-*` em `conectados` é reaproveitado.

Nome: `pick-name.sh <prefixo>`. Preset: família e tier em `presets`; sem o tier, sobe antes de descer (medio → capaz → barato).

`spec=sim`: `em curso` → continue nela (mesmo slug, WPs novas, sem scaffold); `aprovada` → slug novo cujo `spec.md` a cita.

## Projeto novo

1. Git Manager subagente: `git init -b main`, `.gitignore`, commit vazio.
2. Architect primeiro: subagente se o usuário trouxe spec (converter, não reconstruir); terminal se trouxe ideia.
3. Dimensione pelas fronteiras do `plan.md`. Onda 1 = esqueleto em série, um Engineer seguindo `mapa-padrao.md`; depois, paralelo.

Brownfield: módulo sem teste que vai mudar pede antes uma WP de teste de caracterização (fixture gravada).

## Folha

Sete linhas, porquê inline:

```
Pedido: "adicionar filtro por empresa no relatório"
Sinais: módulos=1 (relatorio) · spec=não · mapa=ok · testes=sim · nível 1
Nível: Pequena — um módulo, sem regra de negócio nova
Terminais: eng-grom (claude/medio) — relatorio · rev-uther (codex/capaz)
Subagentes: arch-ysera — spec curta de 1 página · git-gazlowe (reaproveitado)
Não convocar: recon — mapa válido, esqueleto padrão
Presets: eng-grom=cc rev-uther=cx arch-ysera=cc git-gazlowe=cc-mini
```

Pequena: mostre e convoque. Média e Grande: espere uma palavra. `NÃO CONVOCADO` ou nominal inválida: mostre o motivo e espere.

Chamada nominal (`/sdd-karazhan arch eng git`): só esses, nunca acrescente. `eng` exige `git`; `rev` exige `eng`. `grande` força Grande.

Fugiu da rubrica: motivo numa linha de `decisoes.md`.

## Exemplos

**relatorios**: a folha acima.

**licencas**, "novo coletor de licenças com plist no launchd": coleta e deploy, integração nova → Média, Nível 2. Terminais: arch (2 áreas), eng/medio coleta, eng/capaz deploy, rev.

**sincronia**, "migração alembic do centro de custo + sincronização incremental": db, schemas, sync, alembic = 4 > `eng_max` 3 → Grande, Nível 2. Terminais: arch, 3 eng/capaz (banco) em ondas, rev, git.
