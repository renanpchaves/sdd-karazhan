# Changelog

## Não lançado

- `wp-check.sh`: sem `feat/<slug>`, a base sai da branch da WP (`feat/NNN-slug-WP-NN` sem o sufixo, também com HEAD desanexado no worktree do Reviewer). `main` fica como último recurso e aparece no resumo como `base: main (aviso: …)`, para `fora-dos-paths: falha` não ser lido como defeito da WP.
- Orchestrator não roda `wp-check.sh` nem testes: a evidência é do Builder (sem flag) e do Reviewer (`--regressao`). Antes do commit, `diff` e `fora-dos-paths` saem vazios e não são evidência.
- Worktree sem `setup.sh`: o Git Manager devolve `bloqueado` em vez de deixar o Builder instalar dependência, o que cai em prompt de permissão e para o andar.
- Dispensar agente no Maestri apaga também a nota `tasks-<Nome>` dele, antes do `dismiss`. Antes a nota ficava órfã no canvas, fora do alcance do CLI. O ok do usuário para dispensar cobre as duas; `painel-NNN-slug`, notas de quem continua e notas do usuário ficam.

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
