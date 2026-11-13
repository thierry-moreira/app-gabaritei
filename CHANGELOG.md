# Changelog

Todas as mudanças notáveis deste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adota versionamento semântico.

## [1.0.0] - 2026-11-13

### ✨ Adicionado

- **App Flutter** com suporte a Android e iOS
- **Autenticação** via Supabase Auth (login, cadastro, redefinição de senha)
- **Questões comentadas** com explicação pedagógica gerada por IA
- **Simulados** personalizados por matéria com gerador de PDF
- **Flashcards** com repetição espaçada (SM-2 customizado)
- **Resumos** e **cadernos** de estudos com filtros reutilizáveis
- **Editais** com trilha de estudo por tópico e ciclo de revisão
- **Painel do aluno** com estatísticas, raio-X por matéria e curva de esquecimento
- **Ofensiva (streak)** no horário de Brasília
- **Tema claro/escuro** com preferência salva na conta
- **Conta na nuvem** — o progresso acompanha o aluno em qualquer dispositivo

### 🛡️ Supabase e Segurança

- Edge Function `secure-global-write` para escritas protegidas por JWT
- Policies RLS em `explicacoes_ia`, `ia_cache_estudo`, `feedbacks_ia`, `feedbacks_questoes`
- Rate limiting por usuário via função `consume_global_write_rate_limit`
- Tabela privada `app_private.global_write_rate_limits` sem acesso público
- Função `eh_app_aluno()` removida (não usamos mais APP_TOKEN compartilhado)

### 🔧 Configuração

- Credenciais injetadas via `--dart-define-from-file=env.json`
- `env.example.json` como template compartilhado
- `env.json` ignorado pelo Git (`.gitignore`)

### 📦 Dependências principais

- Flutter SDK (canal estável)
- supabase_flutter ^2.18.3
- flutter_riverpod ^3.4.3
- go_router ^18.1.3
- flutter_secure_storage ^11.2.0
- pdf ^3.13.1, printing ^5.15.1
- fl_chart ^1.3.0
- val_latex_flutter ^0.1.4
