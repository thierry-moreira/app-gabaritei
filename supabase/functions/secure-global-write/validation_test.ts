import {
  GlobalWriteValidationError,
  parseGlobalWriteRequest,
} from "./validation.ts";

Deno.test("accepts explanation cache payload and legislation references", () => {
  const parsed = parseGlobalWriteRequest({
    operation: "cache_explanation",
    id_questao: 12,
    conteudo_explicacao: "Explicação válida.",
    contexto_legislacao: [{ id: 3, referencia: "Lei 8.112, art. 5º" }],
  });
  assert(parsed.operation === "cache_explanation");
  assert(parsed.contexto_legislacao?.length === 1);
});

Deno.test("rejects client-supplied owner fields and invalid question IDs", () => {
  assertThrows(() =>
    parseGlobalWriteRequest({
      operation: "cache_explanation",
      id_questao: 12,
      id_usuario: 44,
      conteudo_explicacao: "Explicação válida.",
    })
  );
  assertThrows(() =>
    parseGlobalWriteRequest({
      operation: "feedback_question",
      id_questao: 0,
      tipo_erro: "Outro",
    })
  );
});

Deno.test("validates summary and flashcard cache shapes", () => {
  const summary = parseGlobalWriteRequest({
    operation: "cache_study",
    id_questao: 21,
    tipo: "resumo",
    conteudo_json: { conteudo: "Resumo válido." },
  });
  assert(summary.operation === "cache_study");

  const flashcard = parseGlobalWriteRequest({
    operation: "cache_study",
    id_questao: 21,
    tipo: "flashcard",
    conteudo_json: { frente: "Pergunta?", verso: "Resposta." },
  });
  assert(flashcard.operation === "cache_study");

  assertThrows(() =>
    parseGlobalWriteRequest({
      operation: "cache_study",
      id_questao: 21,
      tipo: "resumo",
      conteudo_json: { conteudo: "Resumo", user_id: "outro usuário" },
    })
  );
});

Deno.test("accepts only known feedback categories and bounded text", () => {
  const feedback = parseGlobalWriteRequest({
    operation: "feedback_ai",
    id_questao: 9,
    tipo: "explicacao",
    motivo: "conteudo_incorreto",
    relato: "A justificativa está incorreta.",
  });
  assert(feedback.operation === "feedback_ai");

  assertThrows(() =>
    parseGlobalWriteRequest({
      operation: "feedback_ai",
      id_questao: 9,
      tipo: "admin",
      motivo: "conteudo_incorreto",
      relato: "",
    })
  );
});

Deno.test("truncates optional question-feedback text to the stored limit", () => {
  const feedback = parseGlobalWriteRequest({
    operation: "feedback_question",
    id_questao: 10,
    tipo_erro: "Outro",
    descricao: "x".repeat(1_200),
  });
  assert(feedback.operation === "feedback_question");
  assert(feedback.descricao.length === 900);
});

function assert(condition: boolean): asserts condition {
  if (!condition) throw new Error("Assertion failed");
}

function assertThrows(action: () => unknown): void {
  try {
    action();
  } catch (error) {
    if (error instanceof GlobalWriteValidationError) return;
    throw error;
  }
  throw new Error("Expected request validation to fail");
}
