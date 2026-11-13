export type LegislationReference = {
  id: number | string | null;
  referencia: string;
};

export type GlobalWriteRequest =
  | {
      operation: "cache_explanation";
      id_questao: number;
      conteudo_explicacao: string;
      contexto_legislacao?: LegislationReference[];
    }
  | {
      operation: "cache_study";
      id_questao: number;
      tipo: "resumo" | "flashcard";
      conteudo_json:
        | { conteudo: string }
        | { frente: string; verso: string };
    }
  | {
      operation: "feedback_ai";
      id_questao: number;
      tipo: "explicacao" | "resumo" | "flashcard";
      motivo:
        | "conteudo_incorreto"
        | "citacao_legal"
        | "desatualizado"
        | "formatacao"
        | "outro";
      relato: string | null;
    }
  | {
      operation: "feedback_question";
      id_questao: number;
      tipo_erro:
        | "Gabarito Errado"
        | "Questão Desatualizada"
        | "Erro de Digitação/Formatação"
        | "Falta de Alternativa Correta"
        | "Outro";
      descricao: string;
    };

export class GlobalWriteValidationError extends Error {
  constructor() {
    super("invalid_payload");
    this.name = "GlobalWriteValidationError";
  }
}

const feedbackTypes = new Set(["explicacao", "resumo", "flashcard"]);
const feedbackReasons = new Set([
  "conteudo_incorreto",
  "citacao_legal",
  "desatualizado",
  "formatacao",
  "outro",
]);
const questionIssueTypes = new Set([
  "Gabarito Errado",
  "Questão Desatualizada",
  "Erro de Digitação/Formatação",
  "Falta de Alternativa Correta",
  "Outro",
]);
const forbiddenControls = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/;

export function parseGlobalWriteRequest(value: unknown): GlobalWriteRequest {
  if (!isRecord(value) || typeof value.operation !== "string") {
    throw new GlobalWriteValidationError();
  }

  const idQuestao = positiveSafeInteger(value.id_questao);

  switch (value.operation) {
    case "cache_explanation": {
      assertOnlyKeys(value, [
        "operation",
        "id_questao",
        "conteudo_explicacao",
        "contexto_legislacao",
      ]);
      const request: Extract<
        GlobalWriteRequest,
        { operation: "cache_explanation" }
      > = {
        operation: "cache_explanation",
        id_questao: idQuestao,
        conteudo_explicacao: boundedText(
          value.conteudo_explicacao,
          30_000,
        ),
      };
      if (value.contexto_legislacao !== undefined) {
        request.contexto_legislacao = parseLegislationReferences(
          value.contexto_legislacao,
        );
      }
      return request;
    }

    case "cache_study": {
      assertOnlyKeys(value, [
        "operation",
        "id_questao",
        "tipo",
        "conteudo_json",
      ]);
      if (value.tipo === "resumo") {
        if (
          !isRecord(value.conteudo_json) ||
          !hasOnlyKeys(value.conteudo_json, ["conteudo"])
        ) {
          throw new GlobalWriteValidationError();
        }
        return {
          operation: "cache_study",
          id_questao: idQuestao,
          tipo: "resumo",
          conteudo_json: {
            conteudo: boundedText(value.conteudo_json.conteudo, 20_000),
          },
        };
      }
      if (value.tipo === "flashcard") {
        if (
          !isRecord(value.conteudo_json) ||
          !hasOnlyKeys(value.conteudo_json, ["frente", "verso"])
        ) {
          throw new GlobalWriteValidationError();
        }
        return {
          operation: "cache_study",
          id_questao: idQuestao,
          tipo: "flashcard",
          conteudo_json: {
            frente: boundedText(value.conteudo_json.frente, 1_000),
            verso: boundedText(value.conteudo_json.verso, 4_000, true),
          },
        };
      }
      throw new GlobalWriteValidationError();
    }

    case "feedback_ai": {
      assertOnlyKeys(value, [
        "operation",
        "id_questao",
        "tipo",
        "motivo",
        "relato",
      ]);
      if (
        typeof value.tipo !== "string" ||
        !feedbackTypes.has(value.tipo) ||
        typeof value.motivo !== "string" ||
        !feedbackReasons.has(value.motivo)
      ) {
        throw new GlobalWriteValidationError();
      }
      const relato = value.relato;
      if (
        relato !== undefined && relato !== null &&
        (typeof relato !== "string" || relato.length > 1_000 ||
          forbiddenControls.test(relato))
      ) {
        throw new GlobalWriteValidationError();
      }
      return {
        operation: "feedback_ai",
        id_questao: idQuestao,
        tipo: value.tipo as "explicacao" | "resumo" | "flashcard",
        motivo: value.motivo as
          | "conteudo_incorreto"
          | "citacao_legal"
          | "desatualizado"
          | "formatacao"
          | "outro",
        relato: typeof relato === "string" && relato.trim().length > 0
          ? relato.trim()
          : null,
      };
    }

    case "feedback_question": {
      assertOnlyKeys(value, [
        "operation",
        "id_questao",
        "tipo_erro",
        "descricao",
      ]);
      if (
        typeof value.tipo_erro !== "string" ||
        !questionIssueTypes.has(value.tipo_erro)
      ) {
        throw new GlobalWriteValidationError();
      }
      const descricao = value.descricao === undefined ? "" : value.descricao;
      if (
        typeof descricao !== "string" || descricao.length > 4_000 ||
        forbiddenControls.test(descricao)
      ) {
        throw new GlobalWriteValidationError();
      }
      return {
        operation: "feedback_question",
        id_questao: idQuestao,
        tipo_erro: value.tipo_erro as
          | "Gabarito Errado"
          | "Questão Desatualizada"
          | "Erro de Digitação/Formatação"
          | "Falta de Alternativa Correta"
          | "Outro",
        descricao: descricao.trim().slice(0, 900),
      };
    }

    default:
      throw new GlobalWriteValidationError();
  }
}

function parseLegislationReferences(value: unknown): LegislationReference[] {
  if (!Array.isArray(value) || value.length > 5) {
    throw new GlobalWriteValidationError();
  }
  return value.map((item) => {
    if (
      !isRecord(item) || !hasOnlyKeys(item, ["id", "referencia"]) ||
      typeof item.referencia !== "string" ||
      item.referencia.trim().length === 0 || item.referencia.length > 250 ||
      forbiddenControls.test(item.referencia)
    ) {
      throw new GlobalWriteValidationError();
    }
    const id = item.id;
    if (
      id !== undefined && id !== null &&
      !(typeof id === "string" && id.length <= 100) &&
      !(typeof id === "number" && Number.isSafeInteger(id))
    ) {
      throw new GlobalWriteValidationError();
    }
    return {
      id: typeof id === "string" || typeof id === "number" ? id : null,
      referencia: item.referencia.trim(),
    };
  });
}

function positiveSafeInteger(value: unknown): number {
  if (
    typeof value !== "number" || !Number.isSafeInteger(value) || value <= 0
  ) {
    throw new GlobalWriteValidationError();
  }
  return value;
}

function boundedText(
  value: unknown,
  maxLength: number,
  allowEmpty = false,
): string {
  if (
    typeof value !== "string" || value.length > maxLength ||
    (!allowEmpty && value.trim().length === 0) ||
    forbiddenControls.test(value)
  ) {
    throw new GlobalWriteValidationError();
  }
  return value;
}

function assertOnlyKeys(
  value: Record<string, unknown>,
  allowed: string[],
): void {
  if (!hasOnlyKeys(value, allowed)) throw new GlobalWriteValidationError();
}

function hasOnlyKeys(
  value: Record<string, unknown>,
  allowed: string[],
): boolean {
  const allowedKeys = new Set(allowed);
  return Object.keys(value).every((key) => allowedKeys.has(key));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
