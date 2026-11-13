# 🛣️ Rotas do App — Gabaritei

Este documento detalha todas as rotas do cliente Flutter, organizadas por domínio.

---

## Autenticação (público)

| Rota | Nome da rota | Tela | Descrição |
|---|---|---|---|
| `/login` | `login` | `LoginScreen` | Tela de login com Supabase Auth |
| `/register` | `register` | `RegisterScreen` | Cadastro de novo usuário |
| `/forgot-password` | `forgotPassword` | `ForgotPasswordScreen` | Redefinição de senha |

---

## Home / Dashboard

| Rota | Nome da rota | Tela | Descrição |
|---|---|---|---|
| `/home` | `home` | `DashboardScreen` | Painel principal com estatísticas e ofensiva |
| `/dashboard-detailed` | `dashboardDetailed` | `DashboardDetailedScreen` | Estatísticas detalhadas por matéria e tópico |

---

## Questões

| Rota | Nome da rota | Tela | Descrição |
|---|---|---|---|
| `/questoes` | `questoes` | `QuestoesScreen` | Lista de questões com filtros |

---

## Cadernos

| Rota | Nome da rota | Tela | Descrição |
|---|---|---|---|
| `/cadernos` | `cadernos` | `CadernosScreen` | Lista de cadernos salvos |
| `/cadernos/:id` | `cadernoDetalhe` | `CadernoDetailScreen` | Detalhe de um caderno específico |

---

## Flashcards

| Rota | Nome da rota | Tela | Descrição |
|---|---|---|---|
| `/flashcards` | `flashcards` | `FlashcardsScreen` | Lista de categorias de flashcards |
| `/flashcards/categoria/:id` | `flashcardsCategoria` | `FlashcardCategoriaScreen` | Flashcards de uma categoria |
| `/flashcards/estudo` | `flashcardsEstudo` | `FlashcardEstudoScreen` | Modo de estudo com repetição espaçada |

---

## Resumos

| Rota | Nome da rota | Tela | Descrição |
|---|---|---|---|
| `/resumos` | `resumos` | `ResumosScreen` | Lista de resumos por matéria |
| `/resumos/materia/:id` | `resumoMateria` | `ResumoMateriaScreen` | Resumo detalhado de uma matéria |

---

## Editais

| Rota | Nome da rota | Tela | Descrição |
|---|---|---|---|
| `/editais` | `editais` | `EditaisScreen` | Lista de ciclos de edital |
| `/editais/dashboard` | `editalDashboard` | `EditalDashboardScreen` | Dashboard de progresso do edital |
| `/editais/estudar` | `editalEstudar` | `EditalEstudarScreen` | Estudo adaptativo por tópico |

---

## Conta

| Rota | Nome da rota | Tela | Descrição |
|---|---|---|---|
| `/conta` | `conta` | `ContaScreen` | Configurações da conta, tema, meta diária, BYOK |

---

## Simulados

| Rota | Nome da rota | Tela | Descrição |
|---|---|---|---|
| `/simulados` | `simulados` | `SimuladosScreen` | Lista de simulados (públicos e privados) |
| `/simulados/fazer` | `simuladoFazer` | `SimuladoFazerScreen` | Realizar um simulado |
| `/simulados/ranking` | `simuladoRanking` | `SimuladoRankingScreen` | Ranking de um simulado |
| `/simulados/resultado` | `simuladoResultado` | `SimuladoResultadoScreen` | Resultado detalhado de um simulado |

---

## Redirecionamento automático

O `GoRouter` redireciona automaticamente:

| Situação | Destino |
|---|---|
| Não logado + acessa rota privada | `/login` |
| Logado + acessa rota pública (`/login`, `/register`, `/forgot-password`) | `/home` |
