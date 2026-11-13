# 🗄️ Banco de Dados e Segurança — Gabaritei

Este documento descreve o modelo de dados, as políticas RLS (Row Level Security) e o modelo de segurança do Supabase.

---

## Visão geral

O banco de dados é hospedado no Supabase (PostgreSQL). O cliente Flutter acessa os dados via PostgREST usando a **ANON key pública**, e a segurança vive nas **policies RLS** no banco, não no segredo da chave.

As escritas sensíveis (cache de IA, feedbacks) são feitas por uma **Edge Function** (`secure-global-write`) que roda com `service_role` após validar JWT, perfil de usuário e payload.

## Tabelas públicas

### usuarios

Perfis dos alunos cadastrados via Supabase Auth.

| Coluna | Tipo | Descrição |
|---|---|---|
| `id` | uuid | Chave primária |
| `auth_id` | uuid | Referência ao auth.users |
| `username` | text | Nome de usuário público |
| `email` | text | E-mail do usuário |
| `meta_diaria` | integer | Meta diária de questões |
| `tema_escuro` | boolean | Preferência de tema |
| `criado_em` | timestamptz | Data de criação |

### questoes

Banco de questões de concursos.

| Coluna | Tipo | Descrição |
|---|---|---|
| `id_questao` | integer | Chave primária |
| `enunciado` | text | Texto da questão |
| `alternativa_a` / `b` / `c` / `d` | text | Alternativas |
| `gabarito` | text | Letra correta |
| `explicacao` | text | Explicação pedagógica |
| `id_materia` | integer | Referência à matéria |
| `id_topico` | integer | Referência ao tópico |
| `id_banca` | integer | Referência à banca |
| `id_orgao` | integer | Referência ao órgão |
| `id_cargo` | integer | Referência ao cargo |
| `ano` | integer | Ano da prova |
| `nivel` | text | Nível de dificuldade |

### materias / topicos

Hierarquia de matérias e tópicos para organização do estudo.

---

## Tabelas de progresso do aluno

### historico_respostas

Registro de cada questão respondida pelo aluno.

| Coluna | Tipo | Descrição |
|---|---|---|
| `id` | uuid | Chave primária |
| `id_usuario` | uuid | Referência ao usuário |
| `id_questao` | integer | Referência à questão |
| `resposta` | text | Resposta do aluno |
| `is_correct` | boolean | Se acertou |
| `criado_em` | timestamptz | Data/Hora da resposta |

### flashcards / flashcard_categorias

Flashcards com repetição espaçada (SM-2).

### simulados / simulados_questoes

Simulados criados pelo aluno, podendo ser públicos ou privados.

### cadernos / cadernos_questoes

Coleções salvas de questões.

### editais_ciclo / editais_materias / editais_topicos / editais_progresso

Trilha de estudo por edital com progresso por tópico.



## Cache global de IA

### explicacoes_ia

Cache de explicações geradas por IA, compartilhado entre todos os alunos.

| Coluna | Tipo | Descrição |
|---|---|---|
| `id_questao` | integer | Chave primária (única por questão) |
| `conteudo_explicacao` | text | Conteúdo da explicação |
| `contexto_legislacao` | text | Contexto legislativo curado (opcional) |
| `atualizado_em` | timestamptz | Última atualização |

### ia_cache_estudo

Cache de resumos e flashcards gerados por IA.

| Coluna | Tipo | Descrição |
|---|---|---|
| `id_questao` | integer | Parte da chave composta |
| `tipo` | text | Tipo (resumo, flashcard, etc.) |
| `conteudo_json` | jsonb | Conteúdo em JSON |
| `atualizado_em` | timestamptz | Última atualização |

Único por par (`id_questao`, `tipo`).


## Feedbacks

### feedbacks_ia

Feedbacks sobre respostas da IA. Não são consultáveis pelo cliente.

### feedbacks_questoes

Feedbacks sobre questões (erros, sugestões). Não são consultáveis pelo cliente.

---

## Tabelas privadas (app_private)

### global_write_rate_limits

Rate limiting para escritas globais via Edge Function. Acesso restrito ao `service_role`.

| Coluna | Tipo | Descrição |
|---|---|---|
| `user_id` | uuid | ID do usuário |
| `action` | text | Tipo de ação (cache_explanation, cache_study, feedback) |
| `window_started_at` | timestamptz | Início da janela de tempo |
| `request_count` | integer | Contador de requisições na janela |

Limites por hora:
- `cache_explanation`: 20
- `cache_study`: 30
- `feedback`: 10


---

## Políticas RLS

### Leitura pública (anon + authenticated)

| Tabela | Policy | Acesso |
|---|---|---|
| `explicacoes_ia` | `public_read_explicacoes_ia` | SELECT |
| `ia_cache_estudo` | `public_read_ia_cache_estudo` | SELECT |

### Dados do usuário (authenticated)

Tabelas de progresso (`usuarios`, `historico_respostas`, `flashcards`, `simulados`, `cadernos`, `editais_*`) possuem políticas que restringem acesso ao próprio usuário via `auth.uid()` ou verificação de posse (`eh_dono_do_aluno`).

### Feedbacks

Nenhuma policy de SELECT/INSERT para `anon` ou `authenticated`. A Edge Function usa `service_role` para gravar; leitura administrativa fica fora do cliente.

---

## Edge Function: secure-global-write

Endpoint HTTPS que recebe escritas protegidas:

1. Valida origem (CORS)
2. Valida Bearer token JWT via Supabase Auth
3. Verifica perfil do usuário na tabela `usuarios`
4. Aplica rate limiting via `consume_global_write_rate_limit`
5. Persiste na tabela destino usando `service_role`

Operações suportadas:
- `cache_explanation` — upsert em `explicacoes_ia`
- `cache_study` — upsert em `ia_cache_estudo`
- `feedback_ai` — insert em `feedbacks_ia`
- `feedback_question` — insert em `feedbacks_questoes`

Variáveis de ambiente necessárias:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `APP_ALLOWED_ORIGINS` (opcional, lista separada por vírgulas)

---

## Deploy

```bash
# 1. Sincronizar histórico de migrations
supabase db push

# 2. Publicar Edge Function
supabase functions deploy secure-global-write
```

---

## Migrações

| Arquivo | Descrição |
|---|---|
| `supabase/migrations/20261111052459_secure_global_writes.sql` | Índices únicos, políticas RLS, tabela de rate limiting, função `consume_global_write_rate_limit`, remoção de `eh_app_aluno()` |

> Este checkout **não contém** as migrations históricas já aplicadas ao projeto. Sincronize o histórico local/remoto antes de executar `supabase db push`.

