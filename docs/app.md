# 📱 Arquitetura do App — Gabaritei

Este documento descreve a arquitetura do cliente Flutter do Gabaritei App.

---

## Visão geral

```text
Flutter (UI + camada de domínio)  ──HTTPS──▶  Supabase (PostgreSQL + Auth + Storage)
    lib/ + test/                       PostgREST + Realtime + RLS policies
```

O app segue uma camadação simples:

| Camada | Responsabilidade | Onde |
|---|---|---|
| **UI / Presentation** | Telas, widgets, navegação | `lib/presentation/` |
| **Domínio / Repositories** | Repositórios que abstraem dados locais e remotos | `lib/repositories/` |
| **Core / Services** | Configuração, banco local, IA, estatísticas, SM-2, validadores | `lib/core/`, `lib/services/` |
| **Banco remoto** | Supabase (PostgreSQL) com RLS — leitura via ANON key, escrita via Edge Function segura | `supabase/` |
| **Testes** | Testes de unidade e de widget | `test/` |

---

## Gerenciamento de estado

O app usa **Riverpod** (`flutter_riverpod ^3.4.3`) para gerenciar provedores globais:
- `providers.dart` — provedores de banco, autenticação e serviços
- `theme_mode_provider.dart` — controle de tema claro/escuro

---

## Navegação

A navegação usa **go_router** (`^18.1.3`) com rotas nomeadas e redirecionamento automático baseado na sessão do Supabase.

### Rotas públicas (sem autenticação)

| Rota | Nome | Tela |
|---|---|---|
| `/login` | `login` | `LoginScreen` |
| `/register` | `register` | `RegisterScreen` |
| `/forgot-password` | `forgotPassword` | `ForgotPasswordScreen` |

### Rotas privadas (requer login)

| Rota | Nome | Tela |
|---|---|---|
| `/home` | `home` | `DashboardScreen` |
| `/dashboard-detailed` | `dashboardDetailed` | `DashboardDetailedScreen` |
| `/questoes` | `questoes` | `QuestoesScreen` |
| `/cadernos` | `cadernos` | `CadernosScreen` |
| `/cadernos/:id` | `cadernoDetalhe` | `CadernoDetailScreen` |
| `/flashcards` | `flashcards` | `FlashcardsScreen` |
| `/flashcards/categoria/:id` | `flashcardsCategoria` | `FlashcardCategoriaScreen` |
| `/flashcards/estudo` | `flashcardsEstudo` | `FlashcardEstudoScreen` |
| `/resumos` | `resumos` | `ResumosScreen` |
| `/resumos/materia/:id` | `resumoMateria` | `ResumoMateriaScreen` |
| `/editais` | `editais` | `EditaisScreen` |
| `/editais/dashboard` | `editalDashboard` | `EditalDashboardScreen` |
| `/editais/estudar` | `editalEstudar` | `EditalEstudarScreen` |
| `/conta` | `conta` | `ContaScreen` |
| `/simulados` | `simulados` | `SimuladosScreen` |
| `/simulados/fazer` | `simuladoFazer` | `SimuladoFazerScreen` |
| `/simulados/ranking` | `simuladoRanking` | `SimuladoRankingScreen` |
| `/simulados/resultado` | `simuladoResultado` | `SimuladoResultadoScreen` |

O redirecionamento ocorre automaticamente:
- Não logado + rota privada → `/login`
- Logado + rota pública → `/home`


---

## Camada de dados

O app se comunica com o Supabase via `supabase_flutter ^2.18.3`.

### Banco local

Não há banco local persistente (como SQLite ou Hive) — todos os dados são lidos/gravados remotamente via Supabase PostgREST, com exceção do cache de credenciais via `flutter_secure_storage`.

### Repositórios

Cada domínio tem seu próprio repositório em `lib/repositories/`:

| Repositório | Responsabilidade |
|---|---|
| `auth_repository.dart` | Autenticação e perfil do usuário |
| `user_repository.dart` | Conta, meta diária, reset e exclusão de dados |
| `question_repository.dart` | Questões, comentários e denúncias |
| `simulado_repository.dart` | Simulados (públicos, privados, geração, ranking) |
| `edital_repository.dart` | Ciclo de estudos por edital |
| `flashcard_repository.dart` | Flashcards e categorias |
| `resumo_repository.dart` | Resumos de matéria |
| `caderno_repository.dart` | Cadernos de questões salvas |
| `dashboard_repository.dart` | Dados do painel do aluno |

---

## Serviços de domínio

| Serviço | Responsabilidade |
|---|---|
| `ai_provider_service.dart` | Chamadas BYOK para OpenAI, Gemini e Anthropic |
| `statistics_service.dart` | Estatísticas detalhadas por matéria/tópico |
| `streak_service.dart` | Cálculo da ofensiva (streak) no horário de Brasília |
| `sm2_service.dart` | Repetição espaçada SM-2 para flashcards |
| `legislacao_service.dart` | Contexto legislativo curado (RAG leve) |
| `dashboard_service.dart` | Agregação de dados do painel |
| `edital_engine.dart` | Lógica de seleção adaptativa de tópicos de edital |
| `simulado_service.dart` | Lógica de geração e correção de simulados |
| `pdf_fonts.dart` / `pdf_text.dart` | Geração de PDFs de simulados e resumos |
| `resumo_print_service.dart` / `simulado_print_service.dart` | Serviços de impressão/PDF |
| `global_write_gateway.dart` | Gateway para escritas protegidas via Edge Function |
| `moderation_service.dart` | Moderação de comentários e denúncias |

| `filtro_repository.dart` | Filtros salvos de busca |


---

## Provedores de IA (BYOK)

O app suporta **Bring Your Own Key** — o aluno configura sua própria chave de API em Configurações da conta.

| Provedor | Link da chave |
|---|---|
| OpenAI | platform.openai.com/api-keys |
| Google Gemini | aistudio.google.com/app/apikey |
| Anthropic | console.anthropic.com/account/keys |

A chave é **cifrada com DPAPI** e guardada somente no dispositivo do aluno. Explicações geradas ficam salvas no banco (cache global para todos os alunos) e são ancoradas em legislação curada quando disponível.

---

## Segurança do cliente

- `APP_TOKEN` e `service_role` **não** são injetados no cliente
- Apenas `SUPABASE_URL` e `SUPABASE_ANON_KEY` são usados no Flutter
- `env.json` é ignorado pelo Git; apenas `env.example.json` é versionado
- Todas as escritas sensíveis passam pela Edge Function `secure-global-write` com validação de JWT

---

## Testes

Localizados em `test/`, cobrindo:

| Diretório | O quê |
|---|---|
| `test/core/` | Config, banco, moderação, tempo, utils, validadores |
| `test/presentation/` | Telas de auth, cadernos, conta, dashboard, editais, flashcards, questões, resumos, simulados |
| `test/services/` | IA, dashboard, edital_engine, filtro, PDF, simulado, SM-2, estatísticas, streak, study_ai |

Comando para rodar:

```bash
flutter test
```

Com cobertura:

```bash
flutter test --coverage
```
