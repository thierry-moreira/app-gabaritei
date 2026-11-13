import { createClient } from "npm:@supabase/supabase-js@2";

import {
  GlobalWriteValidationError,
  parseGlobalWriteRequest,
  type GlobalWriteRequest,
} from "./validation.ts";

const allowedProductionOrigins = new Set([
  "https://thierry-moreira.github.io",
]);
const maxRequestBytes = 64 * 1024;

Deno.serve(async (request) => {
  const origin = request.headers.get("Origin");
  if (origin !== null && !isAllowedOrigin(origin)) {
    return json(403, { code: "origin_not_allowed" }, null);
  }

  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: responseHeaders(origin),
    });
  }
  if (request.method !== "POST") {
    return json(405, { code: "method_not_allowed" }, origin, {
      Allow: "POST, OPTIONS",
    });
  }

  const token = bearerToken(request.headers.get("Authorization"));
  if (token === null) {
    return json(401, { code: "unauthorized" }, origin);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json(500, { code: "server_configuration_error" }, origin);
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser(
    token,
  );
  const user = authData.user;
  if (authError || !user) {
    return json(401, { code: "unauthorized" }, origin);
  }

  const contentType = request.headers.get("Content-Type")
    ?.split(";")[0]
    ?.trim()
    .toLowerCase();
  if (contentType !== "application/json") {
    return json(415, { code: "json_required" }, origin);
  }

  let rawBody: string;
  try {
    rawBody = await request.text();
  } catch {
    return json(400, { code: "invalid_payload" }, origin);
  }
  if (new TextEncoder().encode(rawBody).byteLength > maxRequestBytes) {
    return json(413, { code: "payload_too_large" }, origin);
  }

  let parsedBody: unknown;
  try {
    parsedBody = JSON.parse(rawBody);
  } catch {
    return json(400, { code: "invalid_payload" }, origin);
  }

  let write: GlobalWriteRequest;
  try {
    write = parseGlobalWriteRequest(parsedBody);
  } catch (error) {
    if (error instanceof GlobalWriteValidationError) {
      return json(400, { code: "invalid_payload" }, origin);
    }
    return json(400, { code: "invalid_payload" }, origin);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // A valid Auth JWT alone is not enough: the caller must have an app profile.
  const { data: profile, error: profileError } = await admin
    .from("usuarios")
    .select("id")
    .eq("auth_id", user.id)
    .maybeSingle();
  if (profileError) {
    return json(500, { code: "authorization_check_failed" }, origin);
  }
  if (!profile) {
    return json(403, { code: "profile_required" }, origin);
  }

  const rateAction = write.operation === "feedback_ai" ||
      write.operation === "feedback_question"
    ? "feedback"
    : write.operation;
  const { data: rateData, error: rateError } = await admin.rpc(
    "consume_global_write_rate_limit",
    { p_user_id: user.id, p_action: rateAction },
  );
  if (rateError) {
    return json(500, { code: "rate_limit_unavailable" }, origin);
  }
  const rateResult = Array.isArray(rateData) ? rateData[0] : rateData;
  if (!rateResult || typeof rateResult.allowed !== "boolean") {
    return json(500, { code: "rate_limit_unavailable" }, origin);
  }
  if (!rateResult.allowed) {
    const retryAfter = Math.max(
      1,
      Number(rateResult.retry_after_seconds) || 60,
    );
    return json(429, {
      code: "rate_limited",
      retry_after_seconds: retryAfter,
    }, origin, { "Retry-After": String(retryAfter) });
  }

  // Never let a client seed a cache or feedback record for a missing or
  // unpublished question.
  const { data: question, error: questionError } = await admin
    .from("questoes")
    .select("id_questao, id_subtopico")
    .eq("id_questao", write.id_questao)
    .eq("status", "publicada")
    .maybeSingle();
  if (questionError) {
    return json(500, { code: "question_check_failed" }, origin);
  }
  if (!question) {
    return json(404, { code: "question_not_found" }, origin);
  }

  const { error: writeError } = await persistGlobalWrite(admin, write, question);
  if (writeError) {
    // Do not log payloads, feedback text, tokens, or user identifiers.
    console.error("secure-global-write database operation failed", {
      operation: write.operation,
      code: writeError.code,
    });
    return json(500, { code: "write_failed" }, origin);
  }

  return json(200, { ok: true }, origin);
});

async function persistGlobalWrite(
  admin: ReturnType<typeof createClient>,
  write: GlobalWriteRequest,
  question: { id_questao: number; id_subtopico: number | null },
) {
  switch (write.operation) {
    case "cache_explanation": {
      const row = {
        id_questao: write.id_questao,
        conteudo_explicacao: write.conteudo_explicacao,
        ...(write.contexto_legislacao === undefined
          ? {}
          : { contexto_legislacao: write.contexto_legislacao }),
      };
      return await admin.from("explicacoes_ia").upsert(row, {
        onConflict: "id_questao",
        ignoreDuplicates: true,
      });
    }

    case "cache_study": {
      let idMateria: number | null = null;
      if (question.id_subtopico !== null) {
        const { data: topic, error } = await admin
          .from("subtopicos")
          .select("id_materia")
          .eq("id_subtopico", question.id_subtopico)
          .maybeSingle();
        if (error) return { error };
        idMateria = topic?.id_materia ?? null;
      }
      return await admin.from("ia_cache_estudo").upsert({
        id_questao: write.id_questao,
        id_materia: idMateria,
        tipo: write.tipo,
        conteudo_json: write.conteudo_json,
      }, {
        onConflict: "id_questao,tipo",
        ignoreDuplicates: true,
      });
    }

    case "feedback_ai":
      return await admin.from("feedbacks_ia").insert({
        id_questao: write.id_questao,
        tipo: write.tipo,
        motivo: write.motivo,
        relato: write.relato,
      });

    case "feedback_question": {
      const descricao = write.descricao.trim();
      const relato = ("[" + write.tipo_erro + "]" +
        (descricao ? " " + descricao : "")).slice(0, 1_000);
      return await admin.from("feedbacks_questoes").insert({
        id_questao: write.id_questao,
        relato,
      });
    }
  }
}

function bearerToken(header: string | null): string | null {
  const match = /^Bearer\s+([^\s]+)$/i.exec(header ?? "");
  return match?.[1] ?? null;
}

function isAllowedOrigin(origin: string): boolean {
  const configuredOrigins = (Deno.env.get("APP_ALLOWED_ORIGINS") ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
  if (allowedProductionOrigins.has(origin) || configuredOrigins.includes(origin)) {
    return true;
  }
  try {
    const url = new URL(origin);
    return url.protocol === "http:" &&
      (url.hostname === "localhost" || url.hostname === "127.0.0.1");
  } catch {
    return false;
  }
}

function responseHeaders(
  origin: string | null,
  extra: Record<string, string> = {},
): Headers {
  const headers = new Headers({
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Cache-Control": "no-store",
    "Vary": "Origin",
    ...extra,
  });
  if (origin !== null) headers.set("Access-Control-Allow-Origin", origin);
  return headers;
}

function json(
  status: number,
  body: Record<string, unknown>,
  origin: string | null,
  extraHeaders: Record<string, string> = {},
): Response {
  const headers = responseHeaders(origin, extraHeaders);
  headers.set("Content-Type", "application/json; charset=utf-8");
  return new Response(JSON.stringify(body), { status, headers });
}
