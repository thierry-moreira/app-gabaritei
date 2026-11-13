# 🤖 IA e Provedores (BYOK) — Gabaritei

Este documento descreve o sistema de inteligência artificial do Gabaritei App, baseado no modelo **BYOK** (Bring Your Own Key).

---

## Visão geral

O app não possui uma chave de IA própria embarcada. O aluno configura sua própria chave de API em Configurações da conta, e as chamadas são feitas diretamente aos provedores (OpenAI, Google Gemini, Anthropic).

A chave é **cifrada com DPAPI** e guardada somente no dispositivo do aluno. Nunca é enviada para o servidor do Gabaritei.

---

## Provedores suportados

| Provedor | Link da chave | Modelos padrão |
|---|---|---|
| OpenAI | platform.openai.com/api-keys | gpt-5.6-luna, gpt-6-sol, etc. |
| Google Gemini | aistudio.google.com/app/apikey | gemini-2.5-pro, etc. |
| Anthropic | console.anthropic.com/account/keys | claude-sonnet-4, etc. |

---

## Fluxo de uso

1. O aluno acessa Configurações da conta e insere sua chave de API
2. A chave é cifrada localmente (DPAPI) e armazenada no dispositivo
3. Ao solicitar uma explicação, resumo ou flashcard, o app chama diretamente o provedor com a chave do aluno
4. O resultado pode ser salvo no cache global (`explicacoes_ia`, `ia_cache_estudo`) para benefício de todos os alunos
5. O conteúdo é ancorado em legislação curada quando disponível (RAG leve contra alucinação)

---

## Serviço: AiProviderService

Localizado em `lib/services/ai_provider_service.dart`.

Responsabilidades:
- Validar chave de API sem gastar tokens (endpoint de listagem de modelos)
- Enviar requisições de geração de texto (texto e imagem)
- Tratamento de erros do provedor (401, 403, 404, 402, 429)
- Controle de timeout e tamanho máximo de imagem (8 MB)

Configurações de timeout:
- Timeout geral: 120 segundos
- Ping (validação): 15 segundos
- Imagem: 20 segundos

---

## Cache global de IA

Explicações e resumos gerados podem ser salvos no banco compartilhado:

| Tabela | Finalidade |
|---|---|
| `explicacoes_ia` | Explicações de questões (chave: id_questao) |
| `ia_cache_estudo` | Resumos e flashcards (chave: id_questao + tipo) |

A escrita é feita via Edge Function `secure-global-write` com validação de JWT e rate limiting.

---

## Segurança

- A chave de API **não** é enviada para o servidor do Gabaritei
- A chave é armazenada somente no dispositivo do aluno (cifrada com DPAPI)
- O app nunca expõe `APP_TOKEN` ou `service_role` no cliente
- Problemas nas respostas da IA podem ser reportados pelo botão 🚩 (triagem humana)
