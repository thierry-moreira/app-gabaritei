<div align="center">

<img src="assets/images/icone.webp" width="96" alt="Gabaritei App" />

# Gabaritei App

**Plataforma de estudos para concursos — questões, simulados, flashcards, resumos, cadernos e editais.**

Software livre e sem paywall. Todo aluno cadastrado usa tudo, e o progresso fica na nuvem com a própria conta.

![Flutter](https://img.shields.io/badge/Flutter-framework-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-language-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Postgres%20%2B%20RLS-3ECF8E?logo=supabase&logoColor=white)
![Android](https://img.shields.io/badge/Android-native-3DDC84?logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-native-000000?logo=apple&logoColor=white)

[Recursos](#recursos) · [Arquitetura](#arquitetura) · [Configuracao](#configuracao-de-ambiente) · [Supabase](#supabase-e-seguranca) · [Instalacao](#instalacao) · [Testes](#testes) · [Documentacao](#documentacao) · [Contribuicao](#contribuicao)

</div>

---

## <a id="recursos"></a> ✨ Recursos

| | |
|---|---|
| 📝 **Questões** | Questões de concursos com enunciado, alternativas, gabarito e explicação pedagógica |
| 📋 **Simulados** | Simulados personalizados por matéria com acompanhamento de desempenho |
| 🧠 **Flashcards** | Revisão com repetição espaçada (SM-2), sessão com flip e avaliação 0–3 |
| 📑 **Editais** | Trilha de estudo por edital, com progresso por tópico e ciclo de revisão |
| 📚 **Cadernos e filtros** | Coleções de questões salvas e filtros de busca reutilizáveis |
| 📊 **Painel do aluno** | Estatísticas, raio-X por matéria e tópico, curva de esquecimento e ofensiva (streak) |
| ☁️ **Conta na nuvem** | Login com Supabase Auth — o progresso acompanha o aluno em qualquer dispositivo |
| 🌗 **Tema claro/escuro** | Preferência salva na conta do usuário |

## <a id="arquitetura"></a> 🧱 Arquitetura

```text
Flutter (UI + camada de domínio)  ──HTTPS──▶  Supabase (PostgreSQL + Auth + Storage)
    lib/ + test/                       PostgREST + Realtime + RLS policies
```

| Camada | O quê | Onde |
|---|---|---|
| **UI / Presentation** | Telas e widgets do app (login, questões, simulados, flashcards, cadernos, painel) | `lib/presentation/` |
| **Domínio / Repositories** | Repositórios que abstraem dados locais e remotos | `lib/repositories/` |
| **Core / Services** | Configuração, banco local, IA, IA de resumos, estatísticas, SM-2, validadores | `lib/core/`, `lib/services/` |
| **Banco remoto** | Supabase (PostgreSQL) com RLS — leitura via ANON key, escrita via Edge Function segura | `supabase/` |
| **Testes** | Testes de unidade e de widget | `test/` |

## <a id="configuracao-de-ambiente"></a> 🔧 Configuração de ambiente

As credenciais são injetadas em tempo de compilação via `--dart-define-from-file`.

Copie `env.example.json` para `env.json` e preencha os valores:

```bash
cp env.example.json env.json
```

```json
{
  "SUPABASE_URL": "https://SEU-PROJETO.supabase.co",
  "SUPABASE_ANON_KEY": "sua-anon-key-publica"
}
```

### Comandos de execução

```bash
# Rodar em desenvolvimento
flutter run --dart-define-from-file=env.json

# Gerar APK release
flutter build apk --release --dart-define-from-file=env.json

# Analisar código estático
flutter analyze
```

> **Importante:** sem o `--dart-define-from-file=env.json` o app abre em uma tela de **"Configuração ausente"** e não executa.

### Segredo de variáveis

O cliente usa apenas `SUPABASE_URL` e `SUPABASE_ANON_KEY` (chave pública).  
**Não adicione** `APP_TOKEN`, `service_role` ou qualquer chave secreta aos dart-defines.

Se o `env.json` local ainda tiver a propriedade antiga `APP_TOKEN`, remova-a antes de compilar. Esse arquivo é **ignorado pelo Git** (`/env.json` está no `.gitignore`). Use apenas o `env.example.json` como template compartilhado.

## <a id="supabase-e-seguranca"></a> 🛡️ Supabase e segurança

### Escritas globais

Leituras públicas de `explicacoes_ia` e `ia_cache_estudo` continuam disponíveis.

Gravações de cache e feedback passam pela Edge Function `secure-global-write`, que exige:
- JWT válido
- Perfil em `usuarios`
- Questão publicada
- Payload validado
- Rate limit por usuário

A função está configurada com `verify_jwt = true`; feedbacks **não são consultáveis pelo cliente**.

### Deploy das migrations e Edge Function

```bash
# 1. Sincronize o histórico local/remoto (não reaplique migrations existentes)
supabase db push

# 2. Publique a Edge Function
supabase functions deploy secure-global-write
```

A Edge Function usa as variáveis server-side padrão do Supabase:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

### Flutter Web em outro domínio

Configure `APP_ALLOWED_ORIGINS` como lista separada por vírgulas.  
O GitHub Pages do app já está permitido; `localhost` é aceito para desenvolvimento.

> Este checkout **não contém** as migrations históricas já aplicadas ao projeto. Sincronize o histórico local/remoto antes de executar `supabase db push`.

## <a id="instalacao"></a> 🚀 Instalação

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (canal estável)
- [Dart SDK](https://dart.dev/get-dart) (incluído no Flutter)
- [Supabase CLI](https://supabase.com/docs/cli) (para migrations e Edge Functions)

### Primeiros passos

```bash
# 1. Clone o repositório
git clone https://github.com/thierry-moreira/app-gabaritei.git
cd app-gabaritei

# 2. Instale as dependências
flutter pub get

# 3. Configure o ambiente
cp env.example.json env.json
# Edite env.json com suas credenciais do Supabase

# 4. Rode o app
flutter run --dart-define-from-file=env.json
```

## <a id="testes"></a> ✅ Testes

```bash
# Rodar todos os testes
flutter test

# Rodar com cobertura
flutter test --coverage
```

A suíte de testes cobre validadores, serviços, repositórios, telas e utilitários de domínio.

## <a id="documentacao"></a> 📚 Documentação

| Documento | O quê |
|---|---|
| `analysis_options.yaml` | Regras de lint e análise estática do Dart |
| `pubspec.yaml` | Dependências e configuração do projeto Flutter |
| `supabase/migrations/` | Migrations do banco de dados Supabase |
| `supabase/functions/` | Edge Functions do Supabase |
| `lib/core/` | Camada core (config, banco local, validadores, utilitários) |
| `lib/repositories/` | Repositórios de dados |
| `test/` | Testes unitários e de widget |

## <a id="contribuicao"></a> 🤝 Contribuição

Issues e pull requests são bem-vindos!

Antes de abrir um PR:

1. Rode `flutter analyze` e garanta que não há erros de lint.
2. Rode `flutter test` e garante que todos os testes passam.
3. Se modificar o modelo de dados ou migrations, atualize a documentação em `supabase/`.

---

<p align="center">
  Feito com <b>Flutter</b> + <b>Supabase</b> • Gabaritei App
</p>