-- Versão alinhada à migration aplicada no Supabase: 20261111052459.
-- Cache global continua público para leitura, mas nenhuma gravação passa pelo
-- PostgREST com as chaves anon/publishable. Escritas são feitas pela Edge
-- Function com service_role depois de validar JWT, perfil e payload.

CREATE UNIQUE INDEX IF NOT EXISTS ia_cache_estudo_id_questao_tipo_uidx
  ON public.ia_cache_estudo (id_questao, tipo);

-- Elimina qualquer policy antiga destas tabelas para não deixar permissões
-- permissivas adicionais combinarem com as novas policies.
DO $migration$
DECLARE
  policy_row record;
  policy_roles text;
  using_expression text;
  check_expression text;
  policy_sql text;
BEGIN
  FOR policy_row IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'explicacoes_ia',
        'ia_cache_estudo',
        'feedbacks_ia',
        'feedbacks_questoes'
      )
  LOOP
    EXECUTE format(
      'DROP POLICY %I ON %I.%I',
      policy_row.policyname,
      policy_row.schemaname,
      policy_row.tablename
    );
  END LOOP;

  -- historico_respostas_anonimo não é usado pelo app atual. A única policy
  -- encontrada permitia gravar anonimamente com APP_TOKEN; falha fechado.
  IF to_regclass('public.historico_respostas_anonimo') IS NOT NULL THEN
    FOR policy_row IN
      SELECT schemaname, tablename, policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'historico_respostas_anonimo'
        AND (
          coalesce(qual, '') LIKE '%eh_app_aluno()%'
          OR coalesce(with_check, '') LIKE '%eh_app_aluno()%'
        )
    LOOP
      EXECUTE format(
        'DROP POLICY %I ON %I.%I',
        policy_row.policyname,
        policy_row.schemaname,
        policy_row.tablename
      );
    END LOOP;
  END IF;

  -- Nas policies de dados pessoais, remove só a condição do token. Antes de
  -- recriar cada policy, exige que reste uma checagem auth.uid() ou de posse.
  FOR policy_row IN
    SELECT *
    FROM pg_policies
    WHERE tablename NOT IN (
        'explicacoes_ia',
        'ia_cache_estudo',
        'feedbacks_ia',
        'feedbacks_questoes',
        'historico_respostas_anonimo'
      )
      AND (
        coalesce(qual, '') LIKE '%eh_app_aluno()%'
        OR coalesce(with_check, '') LIKE '%eh_app_aluno()%'
      )
  LOOP
    IF strpos(
      concat_ws(' ', policy_row.qual, policy_row.with_check),
      'eh_dono_do_aluno'
    ) = 0
      AND strpos(
        concat_ws(' ', policy_row.qual, policy_row.with_check),
        'auth.uid'
      ) = 0
    THEN
      RAISE EXCEPTION
        'Policy % on %.% has APP_TOKEN but no user-ownership guard; review it before migration',
        policy_row.policyname,
        policy_row.schemaname,
        policy_row.tablename;
    END IF;

    SELECT string_agg(
      CASE
        WHEN role_name = 'public' THEN 'PUBLIC'
        ELSE quote_ident(role_name)
      END,
      ', ' ORDER BY ordinal
    )
    INTO policy_roles
    FROM unnest(policy_row.roles) WITH ORDINALITY AS role_list(role_name, ordinal);

    using_expression := replace(
      replace(policy_row.qual, 'public.eh_app_aluno()', 'true'),
      'eh_app_aluno()',
      'true'
    );
    check_expression := replace(
      replace(policy_row.with_check, 'public.eh_app_aluno()', 'true'),
      'eh_app_aluno()',
      'true'
    );

    EXECUTE format(
      'DROP POLICY %I ON %I.%I',
      policy_row.policyname,
      policy_row.schemaname,
      policy_row.tablename
    );

    policy_sql := format(
      'CREATE POLICY %I ON %I.%I AS %s FOR %s TO %s',
      policy_row.policyname,
      policy_row.schemaname,
      policy_row.tablename,
      policy_row.permissive,
      policy_row.cmd,
      coalesce(policy_roles, 'PUBLIC')
    );
    IF using_expression IS NOT NULL THEN
      policy_sql := policy_sql || format(' USING (%s)', using_expression);
    END IF;
    IF check_expression IS NOT NULL THEN
      policy_sql := policy_sql || format(' WITH CHECK (%s)', check_expression);
    END IF;
    EXECUTE policy_sql;
  END LOOP;

  IF EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE coalesce(qual, '') LIKE '%eh_app_aluno()%'
      OR coalesce(with_check, '') LIKE '%eh_app_aluno()%'
  ) THEN
    RAISE EXCEPTION 'APP_TOKEN policy references remain after migration rewrite';
  END IF;
END
$migration$;

-- Remove tabela-level grants de escrita que seriam desnecessários mesmo com
-- RLS, e libera apenas SELECT nos dois caches intencionalmente públicos.
REVOKE ALL ON TABLE public.explicacoes_ia
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.explicacoes_ia TO anon, authenticated;

REVOKE ALL ON TABLE public.ia_cache_estudo
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.ia_cache_estudo TO anon, authenticated;

REVOKE ALL ON TABLE public.feedbacks_ia
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.feedbacks_questoes
  FROM PUBLIC, anon, authenticated;

ALTER TABLE public.explicacoes_ia ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ia_cache_estudo ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedbacks_ia ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedbacks_questoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY public_read_explicacoes_ia
  ON public.explicacoes_ia
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY public_read_ia_cache_estudo
  ON public.ia_cache_estudo
  FOR SELECT TO anon, authenticated
  USING (true);

-- Feedbacks não têm policy de SELECT/INSERT para anon ou authenticated. A
-- Edge Function usa service_role; leitura administrativa fica fora do cliente.

CREATE SCHEMA IF NOT EXISTS app_private;
REVOKE ALL ON SCHEMA app_private FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS app_private.global_write_rate_limits (
  user_id uuid NOT NULL,
  action text NOT NULL CHECK (
    action IN ('cache_explanation', 'cache_study', 'feedback')
  ),
  window_started_at timestamptz NOT NULL,
  request_count integer NOT NULL CHECK (request_count > 0),
  PRIMARY KEY (user_id, action)
);

ALTER TABLE app_private.global_write_rate_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE app_private.global_write_rate_limits
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.consume_global_write_rate_limit(
  p_user_id uuid,
  p_action text
)
RETURNS TABLE (allowed boolean, retry_after_seconds integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app_private
AS $function$
DECLARE
  v_limit integer;
  v_window_seconds integer := 3600;
  v_now timestamptz := clock_timestamp();
  v_window_started_at timestamptz;
  v_request_count integer;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required' USING ERRCODE = '22023';
  END IF;

  CASE p_action
    WHEN 'cache_explanation' THEN v_limit := 20;
    WHEN 'cache_study' THEN v_limit := 30;
    WHEN 'feedback' THEN v_limit := 10;
    ELSE RAISE EXCEPTION 'invalid rate-limit action' USING ERRCODE = '22023';
  END CASE;

  INSERT INTO app_private.global_write_rate_limits AS current_limit (
    user_id,
    action,
    window_started_at,
    request_count
  )
  VALUES (p_user_id, p_action, v_now, 1)
  ON CONFLICT (user_id, action) DO UPDATE
  SET
    window_started_at = CASE
      WHEN current_limit.window_started_at <=
        v_now - make_interval(secs => v_window_seconds)
      THEN v_now
      ELSE current_limit.window_started_at
    END,
    request_count = CASE
      WHEN current_limit.window_started_at <=
        v_now - make_interval(secs => v_window_seconds)
      THEN 1
      ELSE LEAST(current_limit.request_count + 1, v_limit + 1)
    END
  RETURNING current_limit.window_started_at, current_limit.request_count
  INTO v_window_started_at, v_request_count;

  RETURN QUERY
  SELECT
    v_request_count <= v_limit,
    GREATEST(
      0,
      CEIL(EXTRACT(EPOCH FROM (
        v_window_started_at + make_interval(secs => v_window_seconds) - v_now
      )))::integer
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.consume_global_write_rate_limit(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_global_write_rate_limit(uuid, text)
  TO service_role;

-- A função antiga continha o segredo compartilhado e não deve continuar
-- disponível como RPC depois que nenhuma policy depende dela.
DROP FUNCTION IF EXISTS public.eh_app_aluno();
