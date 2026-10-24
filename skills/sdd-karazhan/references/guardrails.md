# Guardrails

As regras de git e de path são garantidas pelo ambiente, não pela memória do agente. São **lombadas, não fronteira de segurança**: um Engineer com Bash consegue contorná-las. O `pre-commit` é a última barreira antes do histórico, e o Reviewer, com `wp-check.sh`, é a última antes do merge.

## `.sdd-role`

Gravado por `scripts/guard-install.sh <worktree> <eng|rev> <WP-NN> <paths-csv>` na raiz do worktree, e escondido do git via `info/exclude` (caminho real: `git rev-parse --git-path info/exclude`, porque num worktree ligado `.git` é arquivo):

```
role=eng
wp=WP-01
paths=pkg/coleta.py, tests/test_coleta.py
root=<raiz da skill>
aceite=tests/aceite/**
```

- Quem roda: o Git Manager, um worktree por WP (`eng`) e um único worktree desanexado do Reviewer por andar (`rev`; ali WP e paths não restringem nada, o `pre-commit` bloqueia todo commit).
- `guard-install.sh` recusa (exit 2) se `core.hooksPath` estiver definido (husky e afins) ou se já existir um `pre-commit` que não é do sdd-karazhan. Nesses casos o Git Manager devolve `bloqueado` e o usuário decide se encadeia o hook à mão.

## `pre-commit`

- Instalado uma vez em `.git/hooks`: os worktrees compartilham os hooks. Sem `.sdd-role` na raiz do worktree, não faz nada (o checkout principal segue livre).
- `role=eng`: bloqueia arquivo em stage fora dos paths da WP. Usa `--no-renames`, para um rename não esconder o path de origem.
- `role=rev`: bloqueia qualquer commit com arquivo em stage.
- Sem `SDD_GIT_MANAGER` no ambiente: bloqueia o commit.
- `root=` do `.sdd-role` aponta para a skill instalada. Depois de atualizar o plugin ele pode ficar velho: o `pre-commit` bloqueia com "rode guard-install.sh novamente", e o Git Manager roda de novo.

## Piso de `SDD_GIT_MANAGER`

É piso de prosa assumido: a variável aparece na mensagem de erro e qualquer agente pode copiá-la. Serve para que commit fora do Git Manager seja um ato deliberado, não um acidente. A barreira real é a checagem determinística de paths do `pre-commit` e do `wp-check.sh`.

## `path-guard.sh` (Claude Code)

Hook `PreToolUse` do plugin para `Edit`, `Write`, `MultiEdit` e `NotebookEdit` (`hooks/hooks.json`).

- Ativa pelo cwd da sessão: só age se a raiz do worktree do cwd tiver `.sdd-role`. Por isso o Engineer nasce com `--dir` no seu worktree.
- `role=eng`: bloqueia escrita fora dos paths da WP, fora do worktree e em `.sdd-role`.
- `role=rev`: bloqueia toda edição.
- Não cobre Bash (redirecionamento, `sed -i`, cópia): para isso existem o `pre-commit` e o `wp-check.sh`.
- No modo subagente não se aplica: subagentes compartilham o cwd da sessão principal.

## `wp-check.sh`

`scripts/wp-check.sh WP-NN [--base <ref>] [--tasks <arquivo>]` roda lint, testes, dry-run real, diff, fora-dos-paths e aceite-intacto contra a base (padrão `feat/<slug>`), ignorando `.claude/`. Arquivo commitado fora dos paths da WP é `falha`, independente de quem commitou.

## Oráculo de aceite

- O quê: `tests/aceite/test_<slug>.py` traz os comandos de aceitação da spec como testes executáveis. É a prática com mais respaldo contra retrabalho: o implementador roda o teste, mas não o edita.
- Quem: só o Architect escreve ali, antes das WPs começarem (subagente: no worktree principal). Engineer e Reviewer não.
- Como o ambiente garante: `.sdd-role` leva `aceite=tests/aceite/**`. Com `role=eng`, o `path-guard.sh` nega escrita ali (`tests/aceite é do Architect`) antes de olhar os paths, e o `pre-commit` nega stage (`bloqueado: <path> — tests/aceite é do Architect`), mesmo com `paths=tests/**`. O `wp-check.sh` fecha: `aceite-intacto: falha` se a WP mudou algo em `tests/aceite/` contra a base, e o Reviewer reprova.
- Limite: como o resto, não cobre Bash; o `aceite-intacto` pega o que for commitado.

## Codex (verificação da Task 6)

O Codex CLI 0.153.2 tem hooks (feature `hooks`, exige confiança no projeto), mas a compatibilidade do `path-guard.sh` com os hooks de ferramenta do Codex **não foi verificada**. A garantia mínima no Codex é: sandbox `workspace-write` com raiz no worktree desanexado do Reviewer, `pre-commit` com `role=rev` e a checagem de diff do `wp-check.sh`. O role do Reviewer proíbe editar; o ambiente garante que nada editado ali chegue ao histórico.
