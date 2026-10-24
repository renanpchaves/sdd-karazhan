# Convocação

Entrada: o pedido e as oito linhas do `inventario.sh`. O script dá fatos; o Orchestrator decide. Área tocada = módulo ou área do inventário que o pedido toca (plist, launchd → deploy).

## Níveis

| Nível | Quando | Contrato |
|---|---|---|
| Nível 0 | O diff cabe numa frase | Nenhum: não use a skill; faça direto e rode pytest |
| 1 | Pequena | Spec de 1 página: objetivo, arquivos e interfaces, fora de escopo, comandos de aceitação. `plan.md` opcional |
| 2 | Média, Grande, projeto novo, integração nova ou banco | Spec curta + testes de contrato e fixtures aprovados antes + ledger (`tasks.md`, `decisoes.md`) |

Tamanho: Pequena = uma área, 1 Engineer. Média = 2–3. Grande = áreas > `eng_max`, ou `grande`.

## Papéis

- **Architect** (claude/capaz): terminal com 2+ áreas, chamada nominal `arch` ou Grande; senão subagente de spec curta.
- **Recon** (claude/barato): subagente, só se `mapa` ≠ `ok` ou `esqueleto: fora`. Nunca em `repo: novo`.
- **Engineer**: terminal Claude Code, um por área, até `eng_max`. `capaz` em deploy, config, auth, db ou crypto; senão `medio`.
- **Reviewer** (codex/capaz): sempre terminal. `codex: não` → `Reviewer: NÃO CONVOCADO (sem Codex)`; pergunte ao usuário.
- **Git Manager** (claude/barato): subagente na Pequena e Média, terminal na Grande. `git-*` em `conectados` é reaproveitado.

Nome: `pick-name.sh <prefixo>`. Preset: família e tier em `presets`; sem o tier, o mais próximo da família (empate: o mais barato).

## Projeto novo

1. Git Manager subagente: `git init -b main`, `.gitignore`, commit vazio.
2. Architect primeiro: subagente se o usuário trouxe spec (converter, não reconstruir); terminal se trouxe ideia.
3. Dimensione pelas fronteiras do `plan.md`. Onda 1 = esqueleto em série, um Engineer seguindo `mapa-padrao.md`; depois, paralelo. Sem Recon.

## Brownfield

Módulo sem teste que vai mudar: antes, teste de caracterização (fixture gravada) em WP própria.

## Folha

Sete linhas, porquê inline:

```
Pedido: "adicionar filtro por empresa no relatório"
Sinais: módulos=1 (relatorio) · spec=não · mapa=ok · testes=sim · nível 1
Nível: Pequena — um módulo, sem regra de negócio nova
Terminais: eng-grom (claude/medio) — relatorio · rev-uther (codex/capaz)
Subagentes: arch-ysera — spec curta de 1 página · git-gazlowe (reaproveitado)
Não convocar: recon — mapa válido, esqueleto padrão
Presets: eng-grom=cc-mini rev-uther=cx arch-ysera=cc git-gazlowe=cc-mini
```

Pequena: mostre e convoque. Média e Grande: espere uma palavra. `NÃO CONVOCADO` ou chamada nominal inválida: mostre o motivo e espere.

## Chamada nominal

`/sdd-karazhan arch eng git`: só esses, nunca acrescente. `eng` exige `git`; `rev` exige `eng`. `grande` força Grande.

Fugiu da rubrica: uma linha em `decisoes.md` com o motivo.

## Exemplos

**relatorios**: a folha acima.

**licencas**, "novo coletor de licenças com plist no launchd": coleta e deploy, integração nova → Média, Nível 2. Terminais: arch (2 áreas), eng/medio coleta, eng/capaz deploy, rev. Subagente: git.

**sincronia**, "migração alembic + envio em lote": db, envio, outbox e deploy (`run.sh` migra) = 4 > `eng_max` 3 → Grande, Nível 2. Terminais: arch, 3 eng em ondas (capaz em db e deploy), rev, git. Antes: fixtures do envio e volta da migração aprovados.
