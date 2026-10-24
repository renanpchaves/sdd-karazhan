---
name: sdd-karazhan
description: Orquestra times de agentes de IA, no canvas do Maestri ou com subagentes no terminal, com a spec em markdown como contrato. Convoca só o time que a missão precisa, decidido sobre fatos do repo, com Builder em Claude Code e Reviewer em Codex. Use quando o usuário mencionar Maestri, Modo Maestro, partitura, andar (do Maestri), recrutar agente, git manager, sdd-karazhan, ou pedir para orquestrar agentes ou planejar uma feature com time.
---

# sdd-karazhan

**Recebeu um role de executor (Builder, Reviewer, Git Manager, Recon, Architect)? Pare aqui.** Esta skill é do Orchestrator. Siga só o seu role.

1. A spec é o contrato. Ninguém implementa sem ela.
2. O time mínimo sai dos fatos do `inventario.sh` e da rubrica, não de palpite.
3. Builder em Claude, Reviewer em Codex. Quem produz não aprova.

## Antes de tudo

Rode `maestri list`. Sem `maestri`, siga em modo subagente e diga isso na primeira linha do relatório (`references/recrutamento.md`).

## Ciclo

Detalhe em `references/ciclo.md`. Scripts em `scripts/`.

1. Inventariar: `inventario.sh` imprime os fatos.
2. Decidir: o time sai de `references/convocacao.md`. Mostre a folha; Pequena segue sem esperar (terminais só depois do checkpoint da spec), Média e Grande esperam uma palavra.
3. Contratar: Recon (antes do Architect, se a folha pedir), `scaffold.sh`, Architect.
4. Particionar: `donos.sh` precisa sair 0.
5. Recrutar: Git Manager, Builders e Reviewer (`references/recrutamento.md`).
6. Delegar: quatro linhas por WP. Evidência com `wp-check.sh`.
7. Integrar: `painel.sh --publicar` e checkpoint.

Níveis de contrato: 0 (diff de uma frase: sem skill), 1 (Pequena: spec de 1 página), 2 (Média, Grande, projeto novo, integração ou banco: spec, testes de contrato e ledger). Tamanho do time é outro eixo.

## Papéis

Cada role fica em `agents/<arquivo>.md`. Nome do agente: o personagem (`Grom`); no Maestri, o badge mostra o papel. Prefixo é só a chave do pool no `pick-name.sh`.

| Papel | Prefixo | Faz |
|---|---|---|
| Orchestrator | `orch` | Rege. Não codifica. |
| Architect | `arch` | Descoberta, `spec.md`, `plan.md`. |
| Recon | `rec` | Mapeia o repo. Subagente. |
| Builder | `bld` | Implementa a WP no worktree. |
| Reviewer | `rev` | Testa, lê o diff, aprova ou devolve. |
| Git Manager | `git` | Dono do git: worktree, commit, PR. |

## Regras

1. Um dono por path. Worktree por WP.
2. Git é só do Git Manager.
3. Nada destrutivo ou externo sem o usuário dizer sim.
4. Handoff por arquivo. Chat não é contrato.
5. Quem produz não aprova.

## Precedência

nota-guia → papel ativo → spec.md → plan.md → CLAUDE.md → chat
