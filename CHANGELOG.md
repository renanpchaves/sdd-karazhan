# Changelog

## 0.1.2 — 2026-10-24

- Worktrees das WPs e do Reviewer ficam dentro do repo, em `.worktrees/WP-NN` e `.worktrees/rev`, escondidos pelo `info/exclude` do git. Nada mais de pastas irmãs na raiz de projetos.
- `scaffold.sh` cria `.claude/specs/.gitignore`: `equipe.md`, `painel.md`, `karazhan.json`, `mapa.md` e `bloqueios.md` não vão para o git.
- Arquivos versionados (`tasks.md`, `decisoes.md`) usam o papel (`Dono: Builder`), nunca o nome do personagem.
- `mapa-padrao.md` e exemplos da rubrica sem nomes de repos ou serviços internos.

**Migração**
- Worktrees antigos em `../<repo>-WP-NN` e `../<repo>-rev`: o andar em curso continua neles (os caminhos saem do `git worktree list`). No pouso, o Orchestrator propõe `git worktree remove` dos que estão limpos e integrados, só com o seu ok.
- `equipe.md`, `painel.md`, `karazhan.json`, `mapa.md` ou `bloqueios.md` já commitados em `.claude/specs/`: rode o `scaffold.sh` uma vez e `git rm --cached` neles. Guarde antes uma cópia do `karazhan.json`: o `pull` desse commit noutro clone apaga o arquivo local (presets).

## 0.1.1 — 2026-10-24

- Nome no canvas é o personagem (inicial maiúscula); o badge mostra o papel. Roles do Maestri genéricos e globais.
- Tudo do agente fica na nota `tasks-<Nome>`.
- Orchestrator se renomeia com `maestri arrange`; o role `Orchestrator` é atribuído por você, uma vez, pelo app.
- Ícone e cor por papel no `recruit`. `maestri role delete` só com o seu ok.

**Migração (breaking)**
- Engineer virou **Builder**: chave `eng` → `bld`, `eng_max` → `bld_max`. `role=eng` e `eng_max` ainda são aceitos.
- Roles antigos (`Engineer`, roles com nome de personagem): `maestri role list` e `maestri role delete "<Nome>"`.

## 0.1.0 — 2026-10-23

- Primeira versão: convocação por inventário, contrato em níveis, oráculo de aceite, guardrails (`path-guard`, `pre-commit`, `wp-check`) e elenco de Warcraft.
