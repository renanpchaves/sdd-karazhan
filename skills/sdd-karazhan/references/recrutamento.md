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
maestri list          # agentes, notas e conexões; reaproveite o Git Manager conectado
maestri role list     # roles por papel já criados (Global ou do workspace)
```

Nome de cada agente: o da folha, que já vem do `pick-name.sh` (o personagem, inicial maiúscula: `Grom`). Para papel extra: `scripts/pick-name.sh <orch|arch|rec|eng|rev|git>`. No canvas, o nome do terminal é o personagem e o badge é o papel.

## Roles: um por papel, criados uma vez por máquina

O role diz só o papel. Tudo que é do agente (WP, paths, Orchestrator, Git Manager, comando do `wp-check.sh`) vai na nota `tasks-<Nome>`. O único placeholder dos `agents/*.md` é `<SK>`, o mesmo para a máquina.

| Role (`--role`) | Arquivo |
|---|---|
| `Orchestrator` | `agents/orchestrator.md` |
| `Architect` | `agents/architect.md` |
| `Engineer` | `agents/engineer.md` |
| `Reviewer` | `agents/reviewer.md` |
| `Git Manager` | `agents/git-manager.md` |

Subagente (o Recon sempre) não usa role do Maestri. `SK` vale só na chamada do shell em que foi definido: defina-o junto com os comandos que o usam.

Para cada papel com terminal na folha (e `Orchestrator`) que `maestri role list` não lista:

```bash
SK="<raiz da skill>"   # caminho absoluto de skills/sdd-karazhan, resolvido pelo Orchestrator
maestri role create "Architect" "$(sed "s|<SK>|$SK|g" "$SK/agents/architect.md")" --scope global
maestri role create "Engineer" "$(sed "s|<SK>|$SK|g" "$SK/agents/engineer.md")" --scope global
```

Listado: reaproveite, não crie de novo. Antes de recrutar, confira se o texto está em dia: compare o `maestri role show "<Papel>"` inteiro com a saída de `sed "s|<SK>|$SK|g" "$SK/agents/<arquivo>.md"` (texto diferente: plugin atualizado, raiz mudou ou role de outra origem). O role é global, então nunca rode `maestri role write` sem o usuário: mostre o diff dos dois textos e pergunte. Recomende reescrever só quando `maestri list` não mostrar recruta vivo com aquele role, porque reescrever pode reiniciá-lo. Com o sim do usuário: `maestri role write "<Papel>" "$(sed "s|<SK>|$SK|g" "$SK/agents/<arquivo>.md")"`. Sem o sim, não recrute com esse role: o usuário decide (entrada em `bloqueios.md`).

## Nome do Orchestrator

O nome do Orchestrator é estável entre sessões: se o `You:` de `maestri list` já é um nome do pool `orch` de `roster.json` (sem diferenciar maiúsculas), use-o; só sorteie com `pick-name.sh orch` se não for.

O Orchestrator não renomeia o próprio terminal: `role assign` e `recruit --replace` só agem sobre recrutas, e `--replace` reiniciaria a sessão. Na primeira sessão em que sortear o nome, peça ao usuário, uma vez, que renomeie o terminal dele para esse nome (ex.: `Antonidas`) pela interface do Maestri. Atribuir o role `Orchestrator` ao terminal pode reiniciar a sessão: peça que o usuário faça isso entre sessões, não no meio de uma onda. As duas coisas são opcionais: sem elas, o Orchestrator só assina notas e entradas com o nome.

## Comandos (modo Maestri)

Por agente: nota, recruta com o role do papel, conecta. Architect `Alexstrasza` (terminal) e Engineer `Grom`:

```bash
maestri note create --name "tasks-Alexstrasza" "<conteúdo da nota>"
maestri recruit "Alexstrasza" --preset "<preset>" --role "Architect" --dir "<raiz do repo>"
maestri connect "Alexstrasza" "tasks-Alexstrasza"

maestri note create --name "tasks-Grom" "<conteúdo da nota>"
maestri recruit "Grom" --preset "<preset>" --role "Engineer" --dir "<worktree da WP>"
maestri connect "Grom" "tasks-Grom"
```

- `--dir`: Engineer no worktree da WP; Reviewer no worktree desanexado `../<repo>-rev`, único no andar; Architect e Git Manager (Grande) na raiz do repo.
- Preset: o da linha `Presets:` da folha. Engineer sempre em preset `claude`; Reviewer sempre em preset `codex`.
- `--role` é sempre o papel exato da tabela, com maiúscula e espaço (`"Git Manager"`), nunca o nome do agente.

## Uma nota por agente

Todo terminal recrutado tem a nota `tasks-<Nome>`, conectada a ele. É a única fonte do que é do agente. Primeira linha, em todas: `Orchestrator: <nome> · Git Manager: <nome>`. Depois, por papel:

- Engineer: o bloco da WP copiado de `tasks.md` (objetivo, possui, fora de escopo, aceite, evidência), com `Possui:` como os paths; o caminho absoluto de `spec.md` e a âncora `## WP-NN — título` (só essa seção); os caminhos absolutos de `bloqueios.md` e `decisoes.md`; o comando exato `<SK>/scripts/wp-check.sh WP-NN --tasks <abs>/tasks.md`, sem flag (só o aceite da WP); a base do diff (`feat/NNN-slug`).
- Reviewer: o mesmo, sem `decisoes.md`, com `--regressao` no comando, rodado depois do merge de integração do Git Manager.
- Architect: o slug `NNN-slug`, o caminho do mapa e os de `bloqueios.md` e `decisoes.md`.
- Git Manager: o slug, o `<repo>` e as WPs da onda, cada uma com paths (csv) e worktree.

Exemplo, `tasks-Grom`:

```
Orchestrator: Antonidas · Git Manager: Gazlowe
### WP-01 — filtro por empresa
- Possui: pkg/relatorio.py, tests/test_relatorio.py
- Objetivo: ... · Fora de escopo: ... · Aceite: ... · Evidência: ...
Spec: /abs/repo/.claude/specs/current/001-filtro/spec.md, seção "## WP-01 — filtro por empresa"
Bloqueios: /abs/repo/.claude/specs/bloqueios.md · Decisões: /abs/repo/.claude/specs/decisoes.md
wp-check: /abs/sk/scripts/wp-check.sh WP-01 --tasks /abs/repo/.claude/specs/current/001-filtro/tasks.md
Base: feat/001-filtro
```

- Engineer: uma WP por Engineer por andar. Nova WP é novo agente, novo worktree, novo `.sdd-role` e nova nota. Exceção: depois da caracterização (WP-01), o mesmo Engineer segue com a WP do módulo no mesmo worktree e branch; o Git Manager reinstala a guarda com os paths da nova WP e só a nota é reescrita (`maestri note write "tasks-<Nome>" "<conteúdo>"`). Role, terminal e worktree continuam (`references/ciclo.md`, passo 5).
- Reviewer: um por andar, então a nota dele é reescrita a cada WP: `maestri note write "tasks-<Nome>" "<conteúdo>"`.
- Pouso do andar: a nota do Reviewer diz `WP: andar (pouso)`, o comando `wp-check.sh WP-NN --tasks <abs> --tudo` (qualquer WP), diff vazio esperado, e o critério: aprovar = `aceite: ok` com `--tudo` e `testes: ok`.
- Leitura: `maestri note read "tasks-<Nome>"`.

## Delegar e acompanhar

```bash
maestri ask "Grom" "Objetivo: ... | WP: WP-01 | Fronteira: só os paths da nota | Retorno: bloco fixo do role"
maestri check "Grom"
maestri notify "Onda 1 pronta para checkpoint"
```

Case cada resposta pelo nome do agente. Retorno fora do bloco fixo: peça de novo no formato.

## Subagentes (Recon sempre; Architect e Git Manager conforme a folha)

Prompt do subagente = role com `<SK>` preenchido (`sed "s|<SK>|$SK|g" "$SK/agents/<arquivo>.md"`) + mensagem de delegação com o nome sorteado, o conteúdo que iria na nota e as quatro linhas. Use o tier da folha; registre em `equipe.md` igual a um terminal.

## Modo subagente (sem `maestri`)

- Descoberta: a sessão principal conversa com o usuário e passa as respostas ao subagente Architect, que só escreve a spec.
- Engineer e Git Manager: subagentes do Claude Code, com o role como prompt. O Engineer recebe o caminho absoluto do worktree e edita só ali.
- Reviewer: não há Codex. Subagente Claude em modelo diferente do Engineer; registre em `decisoes.md` como degradação.
- Guardrails: só `pre-commit` e `wp-check.sh`; o `path-guard` não se aplica, porque subagentes compartilham o cwd da sessão.
- Nomes em uso: `equipe.md`. Painel: `.claude/specs/painel.md` (o `painel.sh --publicar` decide sozinho).
- Anuncie o modo e as degradações na primeira linha do relatório.
