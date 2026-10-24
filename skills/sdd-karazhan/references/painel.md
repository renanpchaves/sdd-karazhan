# Painel

O painel é a leitura de `tasks.md`, `bloqueios.md` e `equipe.md`, gerada por script. O Orchestrator nunca o escreve à mão.

## Quando publicar

Só em dois momentos:

1. **Fim de onda**, junto com o checkpoint humano.
2. **Bloqueio crítico**: um bloqueio que para a onda ou exige decisão do usuário.

Mudança de lane no meio da onda não republica.

## Comando

```bash
scripts/painel.sh NNN-slug              # imprime o painel (markdown)
scripts/painel.sh NNN-slug --publicar   # e publica
```

- Com `maestri`: escreve na nota `painel-NNN-slug` (cria na primeira vez, substitui nas seguintes).
- Sem `maestri`: grava `.claude/specs/painel.md`.

Conteúdo: tabela de WPs (WP, lane, dono, possui), bloqueios abertos e equipe. Painel errado se corrige na fonte (`tasks.md`, `bloqueios.md`, `equipe.md`) e se gera de novo.

## Formato de `bloqueios.md`

O `painel.sh` considera aberto todo bloco sem linha `- Resolução:`.

Qualquer agente abre entrada, inclusive o Git Manager num conflito de integração; o Orchestrator resolve e escreve a `- Resolução:` (nos de contrato, o Architect).

```md
## 2026-10-24 · Grom · aceite do WP-02 não diz o fuso do relatório
- Escopo: WP-02 (pkg/relatorio.py)
- Segue andando: WP-01 e WP-03
- Dono da decisão: usuário
- Resolução: America/Sao_Paulo; spec emendada por Ysera
```

`- Resolução:` só entra quando o bloqueio estiver resolvido, escrita por quem resolveu: o Orchestrator nos bloqueios de orquestração, o Architect nos de contrato.

## Formato de `decisoes.md`

O arquivo é do Orchestrator; o Architect acrescenta as próprias entradas, com ele como autor.

```md
## 2026-10-24 · Jaina · Reviewer em subagente Claude (sem Codex)
- Racional: modo subagente, sem terminal Codex disponível
- Alternativas: configurar preset Codex; seguir sem Reviewer
- Custo de reverter: baixo, recrutar Reviewer Codex na próxima onda
- Escopo: feature 001-filtro-empresa
```
