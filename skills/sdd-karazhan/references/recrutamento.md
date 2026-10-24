# Recrutamento

Carregue no passo 5 do ciclo. A skill nunca escolhe modelo, comando ou flag de bypass: usa só o que `maestri preset list` devolve, traduzido pelo `karazhan.json`.

## Pergunta única do `karazhan.json`

Na primeira sessão do workspace, rode `maestri preset list` e, numa só mensagem, pergunte ao usuário a família (`claude` ou `codex`) e o tier (`barato`, `medio` ou `capaz`) de cada preset. Grave em `.claude/specs/karazhan.json`:

```json
{
  "presets": {
    "cc-opus": {"family": "claude", "tier": "capaz"},
    "cc-haiku": {"family": "claude", "tier": "barato"},
    "codex-high": {"family": "codex", "tier": "capaz"}
  },
  "config": {},
  "brain_dir": null
}
```

Nas sessões seguintes, pergunte só pelos nomes novos de `maestri preset list` que não estão em `presets`. Não reabra os já gravados.

## Antes de recrutar

```bash
maestri list          # agentes, notas e conexões; reaproveite git-* conectado
maestri role list     # role existente com o mesmo nome: reaproveite, não duplique
```

Nome de cada agente: o da folha, que já vem do `pick-name.sh`. Para papel extra: `scripts/pick-name.sh <orch|arch|rec|eng|rev|git>`.

## Comandos (modo Maestri)

Preencha `<SK>`, `<ORCH>`, `<GIT>`, `<WP>`, `<PATHS>` e `<NOTA>` do role com `sed`, sem editar o arquivo da skill:

```bash
# forma geral: maestri role create "<nome>" "$(cat agents/x.md)"
SK="<raiz da skill>"   # caminho absoluto de skills/sdd-karazhan, resolvido pelo Orchestrator
maestri role create "eng-grom" "$(sed -e "s|<SK>|$SK|g" -e 's|<ORCH>|orch-jaina|g' -e 's|<GIT>|git-gazlowe|g' \
  -e 's|<WP>|WP-01|g' -e 's|<PATHS>|pkg/coleta.py, tests/test_coleta.py|g' \
  -e 's|<NOTA>|tasks-eng-grom|g' "$SK/agents/engineer.md")"
maestri note create --name "tasks-eng-grom" "<conteúdo da nota>"
maestri recruit "eng-grom" --preset "<preset>" --role "eng-grom" --dir "<worktree>"
maestri connect "eng-grom" "tasks-eng-grom"
```

- `--dir`: Engineer no worktree da WP; Reviewer no worktree desanexado `../<repo>-rev`, único no andar; Architect e Git Manager (Grande) na raiz do repo.
- Preset: o da linha `Presets:` da folha. Engineer sempre em preset `claude`; Reviewer sempre em preset `codex`.
- `role create` sempre com `"$(sed ... $SK/agents/x.md)"`: todo role tem ao menos `<SK>` a preencher. Placeholder sem valor para o papel (ex.: `<GIT>` no Recon) não aparece no role.

## Uma nota por executor

Só `tasks-<nome>`. Conteúdo:

- o bloco da WP copiado de `tasks.md` (objetivo, possui, fora de escopo, aceite, evidência);
- o caminho absoluto de `spec.md` e a âncora `## WP-NN — título` (só essa seção);
- os caminhos absolutos de `bloqueios.md` e `decisoes.md` (o Reviewer não recebe `decisoes.md`);
- o comando exato do `wp-check.sh`, com caminho absoluto e `--tasks`;
- a base do diff (`feat/NNN-slug`).

- Engineer: uma WP por Engineer por andar. Nova WP é novo role, novo worktree, novo `.sdd-role` e nova nota. Exceção: depois da caracterização (WP-01), o mesmo Engineer recebe a WP do módulo, ainda com tudo novo (`references/ciclo.md`, passo 5).
- Reviewer: um por andar, então a nota dele é reescrita a cada WP: `maestri note write "tasks-<nome-rev>" "<conteúdo>"`. O role do Reviewer não tem `<WP>` nem `<PATHS>`: a WP e os paths vêm da nota.
- Leitura: `maestri note read "tasks-<nome>"`.

## Delegar e acompanhar

```bash
maestri ask "eng-grom" "Objetivo: ... | WP: WP-01 | Fronteira: só os paths da nota | Retorno: bloco fixo do role"
maestri check "eng-grom"
maestri notify "Onda 1 pronta para checkpoint"
```

Case cada resposta pelo nome do agente. Retorno fora do bloco fixo: peça de novo no formato.

## Subagentes (Recon sempre; Architect e Git Manager conforme a folha)

Prompt do subagente = role com placeholders preenchidos (inclusive `<SK>`) + mensagem de quatro linhas. Sem nota no canvas, `<NOTA>` vira "a mensagem de delegação" e o conteúdo da nota vai na própria mensagem. Use o tier da folha e o nome sorteado; registre em `equipe.md` igual a um terminal.

## Modo subagente (sem `maestri`)

- Descoberta: a sessão principal conversa com o usuário e passa as respostas ao subagente Architect, que só escreve a spec.
- Engineer e Git Manager: subagentes do Claude Code, com o role como prompt. O Engineer recebe o caminho absoluto do worktree e edita só ali.
- Reviewer: não há Codex. Subagente Claude em modelo diferente do Engineer; registre em `decisoes.md` como degradação.
- Guardrails: só `pre-commit` e `wp-check.sh`; o `path-guard` não se aplica, porque subagentes compartilham o cwd da sessão.
- Nomes em uso: `equipe.md`. Painel: `.claude/specs/painel.md` (o `painel.sh --publicar` decide sozinho).
- Anuncie o modo e as degradações na primeira linha do relatório.
