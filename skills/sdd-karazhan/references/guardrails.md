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
- `role=eng`: bloqueia arquivo em stage fora dos paths da WP. Usa `--no-renames`, para um rename não esconder o path de origem. Também bloqueia stage em `tests/aceite/**` (`aceite=` do `.sdd-role`, sem diferenciar maiúsculas), mesmo que `paths` case.
- `role=rev`: bloqueia qualquer commit com arquivo em stage.
- Sem `SDD_GIT_MANAGER` no ambiente: bloqueia o commit.
- `root=` do `.sdd-role` aponta para a skill instalada. Depois de atualizar o plugin ele pode ficar velho: o `pre-commit` bloqueia com "rode guard-install.sh novamente", e o Git Manager roda de novo.

## Piso de `SDD_GIT_MANAGER`

É piso de prosa assumido: a variável aparece na mensagem de erro e qualquer agente pode copiá-la. Serve para que commit fora do Git Manager seja um ato deliberado, não um acidente. A barreira real é a checagem determinística de paths do `pre-commit` e do `wp-check.sh`.

## `path-guard.sh` (Claude Code)

Hook `PreToolUse` do plugin para `Edit`, `Write`, `MultiEdit` e `NotebookEdit` (`hooks/hooks.json`).

- Ativa pelo cwd da sessão: só age se a raiz do worktree do cwd tiver `.sdd-role`. Por isso o Engineer nasce com `--dir` no seu worktree.
- `role=eng`: bloqueia escrita fora dos paths da WP, fora do worktree, em `.sdd-role` e em `tests/aceite/**` (antes dos paths; o caminho é normalizado: `//`, `/./` e maiúsculas não contornam).
- `role=rev`: bloqueia toda edição.
- Não cobre Bash (redirecionamento, `sed -i`, cópia): para isso existem o `pre-commit` e o `wp-check.sh`.
- No modo subagente não se aplica: subagentes compartilham o cwd da sessão principal.

## `wp-check.sh`

`scripts/wp-check.sh WP-NN [--base <ref>] [--tasks <arquivo>] [--regressao|--tudo]` roda lint, testes, aceite, dry-run real, diff, fora-dos-paths e aceite-intacto contra a base (padrão `feat/<slug>`), ignorando `.claude/`. Arquivo commitado fora dos paths da WP é `falha`, independente de quem commitou.

## Oráculo de aceite

- O quê: um arquivo por WP, `tests/aceite/test_wp<NN>_<slug>.py`, traz os comandos de aceitação da WP como testes executáveis. É a prática com mais respaldo contra retrabalho: o implementador roda o teste, mas não o edita.
- Quem: só o Architect escreve ali, antes das WPs começarem (subagente: no worktree principal). Engineer e Reviewer não.
- Como o ambiente garante: `.sdd-role` leva `aceite=tests/aceite/**`. Com `role=eng`, o `path-guard.sh` nega escrita ali (`tests/aceite é do Architect`) antes de olhar os paths, e o `pre-commit` nega stage (`bloqueado: <path> — tests/aceite é do Architect`), mesmo com `paths=tests/**`. O `wp-check.sh` fecha com duas etapas. `aceite-intacto: falha` sempre que a WP muda `tests/aceite/`, `pytest.ini`, `pytest.toml` ou `.pytest.toml`. Em `pyproject.toml`, `setup.cfg` e `tox.ini`, só quando uma linha `+`/`-` do diff é seção do pytest (`[tool.pytest…`, `[tool:pytest]`, `[pytest]`) ou chave dele seguida de `=` (`testpaths`, `addopts`, `python_files`, `pythonpath`, `filterwarnings` e afins); dependência como `"pytest>=8"` ou `"pytest-mock"` passa. Em `conftest.py` e `tests/conftest.py`, só quando uma linha `+`/`-` toca hook de coleta ou skip/xfail (`pytest_collection_modifyitems`, `pytest_ignore_collect`, `collect_ignore`, `pytest_pycollect`, `pytest_runtest_setup`, `mark.skip`, `mark.xfail`, `pytest.skip`, `pytest.xfail`); fixture comum passa. A etapa lista cada arquivo que reprovou. A etapa `aceite` de `WP-NN` roda `tests/aceite/test_wp<NN>_*.py` (é o que o Engineer roda); com `--regressao` (Reviewer, depois do merge de integração), soma os arquivos das WPs com lane `pronto`, já integradas em `feat/NNN-slug` (o cabeçalho lista quais); sem nenhum `test_wp*` no diretório, roda `tests/aceite/` inteiro e avisa no cabeçalho; havendo `test_wp*` mas nenhum da WP, `falha` (`sem arquivo da WP`); `--tudo` força o diretório inteiro (pouso do andar). Para a regressão achar o código das WPs prontas, o Git Manager integra `feat/NNN-slug` na branch da WP antes de toda revisão (`SDD_GIT_MANAGER=1 git -C <worktree> merge --no-edit feat/NNN-slug`; conflito: `merge --abort` e entrada em `bloqueios.md`); o diff de três pontos continua só da WP. O `pre-commit` não roda em merge sem conflito. A etapa `testes` ignora `tests/aceite/`. `aceite-intacto` vale para a feature toda. `aceite: falha` se o pytest sai com código diferente de 0, não coleta nada (exit 5) ou tem linha de resumo `SKIPPED`/`XFAIL` (um caminho com "xfail" não conta); sem a pasta, `falha` se a `spec.md` da feature cita `tests/aceite` (oráculo declarado na spec mas ausente), senão `ausente`; com a pasta presente e sem pytest, `falha` (`pytest ausente com oráculo presente`). O Reviewer reprova com qualquer uma.
- Antes das WPs: o Git Manager commita `tests/aceite/**` em `feat/NNN-slug` (`references/ciclo.md`, passo 5), senão os worktrees nascem sem o oráculo.
- Limite: não cobre Bash. Um `.sdd-role` sem `aceite=` (instalação antiga) ou editado pelo Bash desliga a proteção do hook e do `pre-commit`; `aceite-intacto` e `aceite` do `wp-check.sh` são a rede final. `guard-install.sh` de novo restaura.

## Codex (verificação da Task 6)

O Codex CLI 0.153.2 tem hooks (feature `hooks`, exige confiança no projeto), mas a compatibilidade do `path-guard.sh` com os hooks de ferramenta do Codex **não foi verificada**. A garantia mínima no Codex é: sandbox `workspace-write` com raiz no worktree desanexado do Reviewer, `pre-commit` com `role=rev` e a checagem de diff do `wp-check.sh`. O role do Reviewer proíbe editar; o ambiente garante que nada editado ali chegue ao histórico.
