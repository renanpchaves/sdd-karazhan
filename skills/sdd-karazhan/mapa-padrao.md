# Mapa padrão — esqueleto Python + launchd

Vale para repo com esqueleto padrão (`mapa-check.sh` diz `esqueleto=padrao`: `deploy/*.plist`, `tests/` e um pacote na raiz). Automações Python que rodam no macOS via launchd ou Cowork. Pacote em `src/` (`src/__init__.py`) também conta como esqueleto padrão. Repo fora disso pede Recon.

## Organização

- `<pacote>/` na raiz, com o nome do repo (`relatorios/`, `sincronia/`, `auditoria/`, `termos/`; `src/` nos mais antigos). Módulos típicos:
  - entrada e configuração: `cli.py`, `config.py`, `logging_setup.py`
  - clientes externos: `graph_client.py` ou `cliente.py` (Microsoft Graph, helpdesk, monitoramento)
  - coleta: `coleta.py` ou `coletor.py`
  - transformação: `transformar.py` ou `normalizar.py`
  - envio: `envio.py`, `outbox.py` ou `mailer.py`
  - relatório: `relatorio.py` ou `report.py`
  - estado: `estado.py` ou `db.py`; guardas de execução: `guardas.py`
- `config/`: `config/settings.py`, `config/*.json`.
- `tests/`: `conftest.py`, `fabrica.py` ou `fakes.py`, `fixtures/*.json`, `test_<modulo>.py` (pytest).
- `deploy/`: `com.exemplo.<nome>.plist` e `ARMAR.md`; às vezes `rotina-nuvem-SKILL.md` para Cowork.
- Raiz: `run.sh`, `setup.sh`, `.env.example`, `pyproject.toml` ou `requirements.txt`, `README.md`, `DECISOES.md`.
- Às vezes: `alembic/` (migrações), `backups/`, `historico/`, `logs/.gitkeep`, `.claude/specs/` herdado do sdd-maestri.

## Convenções

- CLI com `--dry-run`: executa tudo sem enviar e-mail nem gravar estado real. É o que o `wp-check.sh` roda.
- Logs em stderr; saída em JSON no stdout.
- Outbox antes de enviar: a mensagem é gravada e só então enviada.
- Segredos só em `.env`; `.env.example` lista as chaves sem valor.
- E-mail e SharePoint via Microsoft Graph.
- Testes com `fixtures/*.json` e fakes (`fabrica.py` ou `fakes.py`) no lugar dos clientes externos.

## Onde o pedido toca

Casar as palavras do pedido com os módulos que o `inventario.sh` lista; quem casa é o Orchestrator (`references/convocacao.md`). Mudança em CLI, `config.py` ou cliente externo pode tocar também `.env.example` e `README.md`: confira e dê dono.

## Onde é perigoso

- Arquivo executado pelo launchd: `run.sh` e o `.plist`. Erro aqui para a rotina em produção sem aviso.
- Estado em disco: `backups/`, `historico/`, SQLite. Apagar ou migrar perde histórico.
- Migração alembic: mexe no banco em produção; exige aceite próprio e caminho de volta.
- Tudo que envia e-mail ou escreve em sistema externo: só testar com `--dry-run`.
- `.env`: agente não lê, não copia e não commita.

## Testes de contrato nas fronteiras

Onde o código encosta em sistema externo, o teste trava o formato, não só a lógica. Nível 2 exige; o Architect os põe no aceite.

- Microsoft Graph (e as demais APIs): respostas reais gravadas em `tests/fixtures/*.json`, sem segredo nem dado pessoal; o cliente é testado contra elas.
- Schema pydantic validado em teste contra essas fixtures (`Modelo.model_validate(...)`): mudança na API quebra o teste, não a produção.
- launchd: `plutil -lint deploy/*.plist` em teste; fora do macOS, `plistlib.load` do Python como checagem portátil, nunca skip.
- Relatório: golden files em `tests/fixtures/` comparados por igualdade; mudança intencional regrava o golden no mesmo diff.

## Fronteiras sugeridas de WP

| WP | Possui |
|---|---|
| coleta | `<pacote>/coleta*.py`, clientes externos, `tests/test_coleta*.py`, fixtures da coleta |
| transformação | `<pacote>/transformar.py` ou `normalizar.py`, testes correspondentes |
| envio | `<pacote>/envio.py`, `outbox.py`, `mailer.py`, testes correspondentes |
| relatório | `<pacote>/relatorio.py` ou `report.py`, testes correspondentes |
| deploy | `deploy/**`, `run.sh`, `setup.sh` — sempre com dono explícito quando tocados |

`cli.py`, `config.py` e `.env.example` ficam com a WP que muda a interface; nunca com duas.
