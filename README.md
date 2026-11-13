# gabaritei_app

A new Flutter project.

## Configuração de ambiente

As credenciais são injetadas em tempo de compilação. Copie `env.example.json`
para `env.json` e preencha os valores:

```bash
flutter run --dart-define-from-file=env.json
flutter build apk --release --dart-define-from-file=env.json
```

Sem o `--dart-define-from-file=env.json` o app abre em uma tela de
"Configuração ausente" (não executa).

O cliente usa apenas `SUPABASE_URL` e `SUPABASE_ANON_KEY` (chave pública). Não
adicione `APP_TOKEN`, `service_role` ou outra chave secreta aos dart-defines.
Se o `env.json` local ainda tiver a propriedade antiga `APP_TOKEN`, remova-a
antes de compilar; esse arquivo é ignorado pelo Git.

## Escritas globais e Supabase

Leituras públicas de `explicacoes_ia` e `ia_cache_estudo` continuam disponíveis.
Gravações de cache e feedback passam por `secure-global-write`, que exige JWT,
perfil em `usuarios`, questão publicada, payload validado e rate limit por
usuário. A função está configurada com `verify_jwt = true`; feedbacks não são
consultáveis pelo cliente.

Aplique `supabase/migrations/20261111052459_secure_global_writes.sql` antes de
publicar `supabase/functions/secure-global-write`. A função usa as variáveis
server-side padrão do Supabase (`SUPABASE_URL`, `SUPABASE_ANON_KEY` e
`SUPABASE_SERVICE_ROLE_KEY`). Para Flutter Web em outro domínio, configure
`APP_ALLOWED_ORIGINS` como uma lista separada por vírgulas; o GitHub Pages do
app já está permitido e `localhost` é aceito para desenvolvimento.

Este checkout não contém as migrations históricas já aplicadas ao projeto.
Sincronize o histórico local/remoto antes de executar `supabase db push`; não
reaplique nem marque migrations existentes como novas. Depois da sincronização,
aplique o banco com `supabase db push` e publique a função com
`supabase functions deploy secure-global-write`.

## Chave do Stitch MCP (OpenCode)

`opencode.json` lê `STITCH_API_KEY` do ambiente e não deve conter a chave. Após
revogar a chave antiga e criar uma nova, configure essa variável fora do
checkout antes de iniciar o OpenCode. Restrinja a chave no Google Cloud ao
serviço/API e às quotas realmente necessárias; não foi possível verificar ou
alterar essas restrições por este ambiente.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
