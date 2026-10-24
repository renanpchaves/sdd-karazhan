# Desenvolvimento com agentes de código (2025–2026): o que reduz retrabalho de verdade

*Levantamento de campo para um engenheiro de segurança/TI que mantém vários serviços Python pequenos e médios (Graph API, jobs launchd, relatórios) e já usa spec como contrato, worktrees e revisão cruzada Claude Code + Codex. Data: 24/10/2026.*

**Legenda de evidência:** **[M]** = medido (RCT, survey grande, telemetria, experimento controlado); **[V]** = orientação de fornecedor (Anthropic, OpenAI, GitHub, AWS, Cursor e outros, que têm interesse no resultado); **[A]** = anedota ou relato de praticante. O peso de cada afirmação depende dessa classe.

---

## 1. O que a evidência medida diz (e o que não diz)

- **METR, RCT de 2025** [M]: 16 devs experientes de projetos open source grandes (média de 22k+ estrelas, 1M+ linhas), 246 issues reais de ~2h, sorteadas entre "IA permitida" e "IA proibida". Ferramentas: principalmente Cursor Pro com Claude 3.5/3.7 Sonnet. Com IA, as tarefas levaram **19% mais tempo**. Antes, os devs previam ganho de 24%; depois, ainda achavam que tinham ganhado ~20%. O próprio METR avisa que o resultado é um retrato do início de 2025, num contexto específico (repositórios maduros e muito familiares aos devs), e hoje marca a página como desatualizada. ([METR 2025](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/))
- **METR, atualização de fev/2026** [M, com ressalva forte]: com ferramentas do fim de 2025, os 10 devs que voltaram tiveram estimativa de ~18% menos tempo (IC de −38% a +9%), e 47 devs novos, ~4% menos (IC de −15% a +9%). Os dois intervalos incluem zero. O METR chama os números de pouco confiáveis porque de 30% a 50% dos devs disseram ter deixado de submeter tarefas que não queriam fazer sem IA (viés de seleção). Conclusão do próprio METR: o ganho provavelmente existe agora, mas o tamanho não está medido. ([METR 2026](https://metr.org/blog/2026-02-24-uplift-update/)) Uma nota separada do METR, com 7 funcionários usando Claude Code, estimou economia de 1,5x a 13x, mas os autores a tratam como **limite superior frouxo**, não como produtividade. ([METR nota](https://metr.org/notes/2026-02-17-exploratory-transcript-analysis-for-estimating-time-savings-from-coding-agents/))
- **DORA 2024** [M, correlacional]: a cada +25% de adoção de IA, o modelo estimou **−1,5% de throughput e −7,2% de estabilidade** de entrega. ([resumo OpsLevel](https://www.opslevel.com/resources/tl-dr-key-takeaways-from-the-2024-google-cloud-dora-report))
- **DORA 2025** [M, correlacional, ~5.000 respondentes, 90% usam IA]: o sinal do throughput virou positivo, mas a **instabilidade continua alta**. A hipótese "falha rápido, corrige rápido" não se sustentou nos dados. O "AI Capabilities Model" lista 7 capacidades que **amplificam** o efeito da IA: postura clara sobre IA, ecossistema de dados saudável, dados internos acessíveis à IA, **controle de versão forte, lotes pequenos**, foco no usuário e plataforma interna de qualidade. ([DORA 2025 PDF](https://services.google.com/fh/files/misc/2025_state_of_ai_assisted_software_development.pdf), [DORA insights](https://dora.dev/insights/balancing-ai-tensions/), [Capabilities Model](https://services.google.com/fh/files/misc/2025_dora_ai_capabilities_model.pdf))
- **Stack Overflow Survey 2025** [M, survey autorrelatado]: confiança na precisão da IA: 3,1% confiam muito, 29,6% confiam um pouco, 26,1% desconfiam um pouco e 19,6% desconfiam muito. A frustração nº 1 (66%) são soluções "quase certas, mas não exatamente", e 45,2% dizem que depurar código gerado por IA toma mais tempo. 72,2% não fazem "vibe coding" no trabalho profissional. ([SO 2025 – AI](https://survey.stackoverflow.co/2025/ai))
- **Faros AI, 2025** [M, telemetria de ~10 mil devs, fornecedor]: nos times de adoção alta, 21% mais tarefas e 98% mais PRs, mas **tempo de review +91%, PRs 154% maiores, bugs por dev +9%**, e as métricas da organização ficaram planas. ([Faros](https://www.faros.ai/ai-productivity-paradox))
- **CodeRabbit, dez/2025** [M, fornecedor de review]: em 470 PRs open source, os PRs co-assinados por IA tinham ~1,7x mais achados (10,83 contra 6,45), principalmente de lógica e correção. Limitação: a autoria foi inferida por label. ([CodeRabbit](https://www.coderabbit.ai/blog/state-of-ai-vs-human-code-generation-report))

**Leitura para o seu caso:** o gargalo saiu da escrita de código e foi para a **verificação e o review**. Tudo o que reduz o custo de verificar (lote pequeno, oráculo executável, contexto limpo) tem respaldo indireto mas consistente. Nenhum estudo mede diretamente "spec-first contra alternativa" em agentes. As recomendações de processo abaixo são, no máximo, [V] e [A] alinhadas com esses dados [M].

---

## 2. Spec-driven development: ferramentas e críticas

- **GitHub Spec Kit** [V]: fluxo specify → plan → tasks → implement, com checkpoint humano em cada fase. A GitHub recomenda para greenfield, para features em sistemas existentes e para modernização, mas diz que brownfield complexo exige "advanced context engineering" e chama o kit de "nosso experimento". Não apresenta métricas. ([GitHub blog, 09/2025](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/))
- **AWS Kiro** [V]: requirements.md (user stories com critérios em **EARS**, "WHEN … THE SYSTEM SHALL …"), depois design.md e tasks.md, com aprovação humana por fase e variantes requirements-first e design-first. ([Kiro docs](https://kiro.dev/docs/specs/feature-specs/))
- **Tessl** [V]: o único que mira "spec-anchored" e "spec-as-source". O registry tem 10k+ "usage specs" de bibliotecas. O próprio fornecedor afirma +35% de uso correto de API, sem verificação independente. ([Tessl](https://tessl.io/blog/tessl-launches-spec-driven-framework-and-registry), [eval Tessl](https://tessl.io/blog/proposed-evaluation-framework-for-coding-agents))
- **OpenSpec** [V/A]: trabalha com **specs delta** (ADDED, MODIFIED e REMOVED por mudança) e depois arquiva. A Thoughtworks o considera mais adequado a brownfield que o Spec Kit. ([OpenSpec concepts](https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md), [Thoughtworks Radar – OpenSpec](https://www.thoughtworks.com/en-us/radar/tools/openspec))
- **Crítica de Birgitta Böckeler (martinfowler.com, 15/10/2025)** [A, avaliação qualitativa]: separa *spec-first*, *spec-anchored* e *spec-as-source* e conclui que quase tudo hoje é só spec-first. O Kiro transformou um bug pequeno em 4 user stories e 16 critérios ("marreta para quebrar noz"). O Spec Kit gerou markdown repetitivo, e ela diz que prefere revisar código a revisar aquilo. O agente **ignorou a spec** e duplicou classes existentes. Pacotes pequenos e iterativos conflitam com spec antecipada. Em brownfield, adotar as ferramentas dá "ainda mais trabalho". Regenerar a partir da mesma spec dá código diferente. Ela traça um paralelo com o MDD: "inflexibilidade *e* não-determinismo". ([Böckeler SDD](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html))
- **Thoughtworks Radar vol. 33 (nov/2025)** [A, consenso de consultoria]: SDD ficou em "Assess". O Radar acha os fluxos "elaborados e opinativos", diz que as specs longas são difíceis de revisar e alerta: "talvez estejamos reaprendendo uma bitter lesson: escrever à mão regras detalhadas para IA não escala". ([Radar SDD](https://www.thoughtworks.com/radar/techniques/spec-driven-development)) O vol. 34 (abr/2026) diz que Spec Kit e afins servem melhor para greenfield que para brownfield. ([Radar vol. 34 PDF](https://www.thoughtworks.com/content/dam/thoughtworks/documents/radar/2026/04/tr_technology_radar_vol_34_en.pdf))
- **Anthropic** [V]: a recomendação é **proporcional**. Para features maiores, o Claude te entrevista e escreve um SPEC.md, e a execução acontece numa **sessão nova**. A melhor spec é autocontida: nomeia arquivos e interfaces, diz o que está fora do escopo e termina com um passo de verificação ponta a ponta. A regra para dispensar o plano: "se você consegue descrever o diff em uma frase, pule o plano". ([Claude Code best practices](https://code.claude.com/docs/en/best-practices))

**Onde as fontes divergem:** os fornecedores de SDD dizem que a spec antecipada evita retrabalho. Böckeler e a Thoughtworks dizem que ela muda o retrabalho de lugar (para o review de markdown) e gera *spec drift*, porque nada obriga o código a seguir a prosa. Os dois lados concordam que a especificação de intenção ajuda. A discordância é sobre **quanta prosa escrever e quem a fiscaliza**.

---

## 3. Harness engineering: a spec que se fiscaliza sozinha

- **OpenAI, "Harness engineering" (Lopopolo, 11/02/2026)** [V; post não acessado diretamente (403), detalhes vêm de resumos secundários]: um AGENTS.md curto (~100 linhas) funciona **como mapa**, e o "sistema de registro" fica em `docs/`. Planos de execução versionados no repo têm log de progresso e de decisões. **Invariantes vêm forçados por linters customizados e testes estruturais**: "ao impor invariantes em vez de microgerenciar implementações, os agentes entregam rápido sem corroer a base". Agentes de "garbage collection" combatem a entropia. ([OpenAI](https://openai.com/index/harness-engineering/), [Emil Sit](https://www.emilsit.net/t/2026/02/openai-harness-engineering/))
- **Böckeler sobre o harness** [A]: ela divide o harness em **guias** (feedforward: instruções e specs) e **sensores** (feedback: testes, linters, revisores). O post da OpenAI não trata da verificação de comportamento funcional. Em brownfield com muita entropia, ela não sabe se vale a pena ("como ligar análise estática num código que nunca teve"). E o harness leva meses para ficar bom, não é "um punhado de arquivos markdown". ([memo](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering-memo.html))
- **Naresh Jain, "Are Harnesses Worth the Cost?" (13/10/2026)** [M, pequeno: 10 execuções por condição, 178 testes de aceitação externos, um serviço Java greenfield]: com o modelo de fronteira, o harness (specs legíveis por máquina, exemplos, skill e testes determinísticos durante a codificação) custou ~7x mais e ~3x mais tempo **sem mudar o resultado (10/10 nos dois casos)**. Com o modelo barato, levou a aceitação de **3/10 para 10/10**, e mesmo assim saiu 33% mais barato que o de fronteira sem harness. As falhas se concentraram em **fronteiras de protocolo e integração**: fluxos 202, headers, códigos de erro exatos, nome de variável de ambiente. A recomendação dele é que o que muda com a capacidade do modelo é **quando** os sensores independentes rodam, não **se** devem existir. ([Jain](https://martinfowler.com/articles/are-harnesses-worth-the-cost.html))
- **Mitchell Hashimoto (05/02/2026)** [A]: sempre que o agente erra, mude o ambiente para que o mesmo erro não se repita, seja pelo AGENTS.md ou por uma ferramenta de verificação. ([resumo](https://www.bloss0m.com/en/blog/16-mitchell-hashimoto-harness-origin/))
- **Kief Morris (04/03/2026)** [A]: o humano deve ficar **"on the loop"**. Quando o resultado sai ruim, corrija o harness que o produziu em vez de remendar o artefato. Ficar "in the loop" (inspecionar tudo) não escala. ([Morris](https://martinfowler.com/articles/exploring-gen-ai/humans-and-agents.html))

---

## 4. Práticas que reduzem retrabalho, ordenadas pelo respaldo

1. **Um oráculo executável fora do controle do implementador.** A Anthropic diz que dar ao agente um check que ele consiga rodar é "a diferença entre uma sessão que você vigia e uma que você pode deixar sozinha", e sugere fixar esse check como gate determinístico (Stop hook) [V]. ([best practices](https://code.claude.com/docs/en/best-practices)) No compilador C feito por 16 agentes, Carlini conclui que "o verificador precisa ser quase perfeito, senão o Claude resolve o problema errado" [A/M]. ([Anthropic C compiler](https://www.anthropic.com/engineering/building-c-compiler)) Kent Beck relata agentes **apagando asserts e testes** [A] ([Beck](https://newsletter.kentbeck.com/p/genie-wants-to-leap)), e o harness da Anthropic proíbe editar testes e guarda o status em **JSON, que o modelo altera menos que Markdown** [V]. ([long-running harness](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents))
2. **Incrementos pequenos, uma feature por vez, cada uma deixando um estado "mergeável".** Esse é o antídoto da Anthropic contra "one-shotting" e contra o agente declarar vitória cedo demais [V]. DORA (lotes pequenos) e Faros (PRs 154% maiores, review +91%) dão o lado medido. A métrica de horizonte do METR mostra que a taxa de sucesso cai com o tamanho da tarefa [M]. ([METR time horizons](https://arxiv.org/abs/2503.14499))
3. **Estado em disco (ledger), não na memória do agente.** O padrão aparece em várias fontes independentes: claude-progress.txt + git + lista de features da Anthropic [V]; ExecPlans/PLANS.md da OpenAI, com seções obrigatórias de Progress, Surprises & Discoveries, Decision Log e Outcomes, e a regra "deve ser possível recomeçar *só* a partir do ExecPlan" [V] ([Cookbook ExecPlans](https://developers.openai.com/cookbook/articles/codex_exec_plans)); o loop Ralph com specs congeladas + fix_plan mutável, contexto zerado a cada volta [A] ([Huntley](https://ghuntley.com/ralph/)); READMEs e arquivos de progresso no compilador C. Isso evita o "agente re-deriva o estado" a cada sessão.
4. **Higiene de contexto.** O desempenho cai conforme o contexto enche ("context rot") [V]. Subagentes exploram e devolvem resumos de 1–2k tokens ([context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)). Depois de **2 correções fracassadas, use /clear e reescreva o prompt**. Mantenha CLAUDE.md e AGENTS.md curtos ("se remover esta linha não causaria erro, corte"). ([best practices](https://code.claude.com/docs/en/best-practices), [agents.md](https://agents.md/))
5. **Gate "explorar → planejar → executar" proporcional ao risco**, com o plano revisado antes do código e a execução numa sessão limpa [V]. Na Aider, separar raciocínio (architect) de edição (editor) melhorou o benchmark (85% em 2024) [M, benchmark do próprio fornecedor, antigo]. ([Aider](https://aider.chat/2024/09/26/architect.html))
6. **Revisão independente em contexto limpo.** A Anthropic recomenda o padrão Writer/Reviewer e um revisor que vê só o diff e os critérios, **orientado a apontar apenas lacunas de correção e de requisito**, porque o revisor que é instruído a achar problemas sempre acha alguns e empurra para o over-engineering [V]. **Revisão por modelo diferente:** a lógica é boa (viés de autopreferência existe e varia entre modelos), mas **não encontrei estudo que meça cross-model review de código contra review same-model em contexto limpo**. O ganho comprovado é o contexto separado; o modelo diferente é uma aposta razoável, não um fato. ([arXiv cross-context review](https://arxiv.org/html/2603.12123))
7. **Contract tests nas fronteiras.** É onde os agentes mais falharam no experimento de Jain [M pequeno]. Para você: respostas gravadas da Graph API como fixtures, schemas (pydantic) validados em teste, `plutil -lint` nos plists do launchd, golden files para relatórios.
8. **Evals antes de skills e regras.** Rode o modelo sem a skill, registre as falhas, escreva ~3 cenários, meça o baseline e escreva o mínimo necessário para passar, testando em cada modelo que for usar [V]. ([skill best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices))
9. **Âncora numa aplicação de referência.** Um serviço-modelo compilável e atualizado, usado como exemplo few-shot e como base para detectar drift [A]. Encaixa bem em quem cria muitos serviços parecidos. ([Böckeler, reference app](https://martinfowler.com/articles/exploring-gen-ai/anchoring-to-reference.html))

**TDD dentro do loop do agente, com fontes em desacordo:** Beck usa TDD estrito no prompt para conter o agente [A]. Já o experimento de Böckeler (ago/2026; Python greenfield; avaliação cega; pequeno) **não achou diferença de qualidade nem de mutation score**, custou de 3x a 8,5x mais tokens, e os agentes "fingiam" o red. Ela parou de pedir test-first e sugere mutation testing e "approved scenarios" [M pequeno]. ([TDD no loop](https://martinfowler.com/articles/exploring-gen-ai/tdd-in-the-agent-loop.html)) **Síntese:** o que tem valor é o **teste de aceitação como contrato fixo, escrito ou aprovado por você antes**, não o ritual red-green-refactor executado pelo agente.

---

## 5. Tamanho e montagem dos times de agentes

**Evidência e orientação:**
- No sistema de pesquisa multiagente da Anthropic, o desempenho foi +90,2% sobre o agente único, mas com ~**15x os tokens** de um chat (agente único: ~4x). O uso de tokens explicou 80% da variância. A própria Anthropic avisa que **a maioria das tarefas de código tem menos subtarefas realmente paralelizáveis** e que domínios com contexto compartilhado e dependências não combinam com multiagente [V/M interno]. ([multi-agent research](https://www.anthropic.com/engineering/multi-agent-research-system))
- Cognition, "Don't Build Multi-Agents" (06/2025) [V/A]: "ações carregam decisões implícitas", e subagentes paralelos tomam decisões conflitantes. O padrão recomendado é um agente linear, com subagentes só para responder perguntas. ([Cognition](https://cognition.com/blog/dont-build-multi-agents)) Em 2026 a própria Cognition lançou coordenação de vários Devins, mas manteve o princípio de compartilhar contexto.
- Cursor (01/2026) [A em escala]: com agentes "iguais" e locks, 20 agentes renderam como 2 ou 3. O que funcionou foi **planner → workers que não se coordenam entre si → judge**, com recomeço periódico do zero contra drift. Um papel de "integrador" virou gargalo. Escolha o modelo por papel. ([Cursor](https://cursor.com/blog/scaling-agents))
- Compilador C [A]: o paralelismo funcionou enquanto havia **muitos testes independentes falhando**. Quando havia um só alvo gigante (o kernel), "16 agentes não ajudaram, todos travados no mesmo bug". Ficou ~US$ 20 mil em 2 semanas. ([Anthropic](https://www.anthropic.com/engineering/building-c-compiler))
- Agent teams do Claude Code [V]: comece com **3 a 5 colegas**, de **5 a 6 tarefas por colega**, e **cada um dono de um conjunto diferente de arquivos**. Tarefas sequenciais, edição no mesmo arquivo ou muitas dependências pedem sessão única ou subagentes. ([agent teams](https://code.claude.com/docs/en/agent-teams))
- Simon Willison [A]: o review é o gargalo natural. Ele consegue revisar e fazer o merge de **uma mudança significativa por vez**, então paraleliza pesquisa, PoCs, manutenção pequena e trabalho já especificado em detalhe. ([Willison](https://simonwillison.net/2025/Oct/5/parallel-coding-agents/))

**Regra prática:**
- **Brownfield:** (1) primeiro o mapa: subagentes read-only exploram o repo e você gera um REPO_MAP/AGENTS.md curto; (2) **testes de caracterização e contract fixtures** do comportamento atual; (3) spec **delta** (só o que muda, à la OpenSpec); (4) implementação **serial** nas áreas quentes, com paralelismo só entre módulos realmente separados. Não tente montar um harness completo num código cheio de entropia (Böckeler).
- **Greenfield:** (1) **esqueleto serial** feito por um agente "inicializador": layout, AGENTS.md, script de init/run, CI, interfaces e contratos, teste ponta a ponta trivial; (2) só então espalhar o trabalho por módulos com donos de arquivo disjuntos e um oráculo por tarefa; (3) depois, agentes de limpeza contra a entropia.
- **Para os seus serviços pequenos e médios:** dentro de um serviço, o padrão eficiente é **1 implementador + 1 revisor** (o modelo diferente é bom, mas o essencial é o contexto limpo). O paralelismo rende mais **entre serviços/repos** (partição natural) ou em pesquisa e review do que dentro do mesmo serviço.

---

## 6. Veredito sobre "spec como contrato primeiro"

**Adaptar, não substituir.** Mantenha a ideia de contrato antecipado, porque todas as fontes, inclusive as críticas, valorizam deixar a intenção explícita. Mude **a forma do contrato** e **o tamanho dele**:

| Nível | Quando | Contrato |
|---|---|---|
| 0 | O diff cabe numa frase | Prompt direto + check executável (pytest/ruff). Sem spec, sem plan mode. |
| 1 | Feature de um serviço, de horas a 1 dia | Plan mode e um **SPEC de 1 página**: objetivo, arquivos e interfaces, fora de escopo, **comandos de aceitação**. Execução em sessão nova, revisor em contexto limpo. |
| 2 | Serviço novo, integração nova (Graph, launchd), mudança que cruza fronteiras | SPEC curto + **contract tests e fixtures escritos ou aprovados por você antes** + ExecPlan/ledger vivo (Progress, Decisions) + Stop hook rodando testes, lint e tipos. |

Princípios: (a) **o contrato que vale é o executável**; a prosa fica para intenção e fora de escopo (reduz o spec drift, porque teste não deriva em silêncio); (b) o implementador **não pode editar** os testes de aceitação; (c) especifique **deltas**, não o sistema inteiro; (d) quando o agente erra de forma recorrente, corrija o harness (lint, teste, linha no AGENTS.md), não só o código; (e) mantenha um serviço de referência como âncora para os próximos.

**Lacunas e itens não verificados:** o post da OpenAI sobre harness engineering não pôde ser lido direto (403), então números como "1M de linhas" e "~1.500 PRs" vêm de resumos secundários. O artigo completo de Böckeler sobre "guides and sensors" também não foi lido na fonte. Não há estudo controlado comparando SDD com outros fluxos, nem revisão cross-model com same-model. Os estudos de Jain e de Böckeler (TDD) são pequenos e de um só cenário.

---

## Fontes

- METR 2025 RCT: https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/
- METR 2026, atualização: https://metr.org/blog/2026-02-24-uplift-update/
- METR, nota sobre transcripts: https://metr.org/notes/2026-02-17-exploratory-transcript-analysis-for-estimating-time-savings-from-coding-agents/
- METR, horizontes de tempo: https://arxiv.org/abs/2503.14499
- DORA 2025: https://services.google.com/fh/files/misc/2025_state_of_ai_assisted_software_development.pdf
- DORA AI Capabilities Model: https://services.google.com/fh/files/misc/2025_dora_ai_capabilities_model.pdf
- DORA insights: https://dora.dev/insights/balancing-ai-tensions/
- DORA 2024 (resumo): https://www.opslevel.com/resources/tl-dr-key-takeaways-from-the-2024-google-cloud-dora-report
- Stack Overflow 2025 (IA): https://survey.stackoverflow.co/2025/ai
- Faros AI: https://www.faros.ai/ai-productivity-paradox
- CodeRabbit: https://www.coderabbit.ai/blog/state-of-ai-vs-human-code-generation-report
- Böckeler, SDD (Kiro, Spec Kit, Tessl): https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html
- Böckeler, harness: https://martinfowler.com/articles/exploring-gen-ai/harness-engineering-memo.html
- Böckeler, TDD no loop: https://martinfowler.com/articles/exploring-gen-ai/tdd-in-the-agent-loop.html
- Böckeler, aplicação de referência: https://martinfowler.com/articles/exploring-gen-ai/anchoring-to-reference.html
- Jain, custo do harness: https://martinfowler.com/articles/are-harnesses-worth-the-cost.html
- Morris, humanos no loop: https://martinfowler.com/articles/exploring-gen-ai/humans-and-agents.html
- Thoughtworks Radar, SDD: https://www.thoughtworks.com/radar/techniques/spec-driven-development
- Thoughtworks Radar vol. 34: https://www.thoughtworks.com/content/dam/thoughtworks/documents/radar/2026/04/tr_technology_radar_vol_34_en.pdf
- Thoughtworks Radar, OpenSpec: https://www.thoughtworks.com/en-us/radar/tools/openspec
- GitHub Spec Kit: https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/
- Kiro specs: https://kiro.dev/docs/specs/feature-specs/
- Tessl: https://tessl.io/blog/tessl-launches-spec-driven-framework-and-registry
- OpenSpec: https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md
- Claude Code best practices: https://code.claude.com/docs/en/best-practices
- Claude Code agent teams: https://code.claude.com/docs/en/agent-teams
- Anthropic, Building effective agents: https://www.anthropic.com/engineering/building-effective-agents
- Anthropic, context engineering: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- Anthropic, multi-agent research: https://www.anthropic.com/engineering/multi-agent-research-system
- Anthropic, long-running harness: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- Anthropic, compilador C: https://www.anthropic.com/engineering/building-c-compiler
- Anthropic, skill best practices: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- OpenAI, harness engineering: https://openai.com/index/harness-engineering/ (resumo: https://www.emilsit.net/t/2026/02/openai-harness-engineering/)
- OpenAI Cookbook, ExecPlans: https://developers.openai.com/cookbook/articles/codex_exec_plans
- AGENTS.md: https://agents.md/
- Cursor, scaling agents: https://cursor.com/blog/scaling-agents
- Cognition, Don't Build Multi-Agents: https://cognition.com/blog/dont-build-multi-agents
- Huntley, Ralph: https://ghuntley.com/ralph/
- Aider, architect/editor: https://aider.chat/2024/09/26/architect.html
- Kent Beck: https://newsletter.kentbeck.com/p/genie-wants-to-leap
- Simon Willison, agentes paralelos: https://simonwillison.net/2025/Oct/5/parallel-coding-agents/
- Hashimoto (resumo): https://www.bloss0m.com/en/blog/16-mitchell-hashimoto-harness-origin/
- Cross-context review (arXiv): https://arxiv.org/html/2603.12123
