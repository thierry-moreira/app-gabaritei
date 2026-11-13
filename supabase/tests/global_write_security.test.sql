BEGIN;

SELECT plan(23);

SELECT ok(
  to_regprocedure('public.eh_app_aluno()') IS NULL,
  'the shared APP_TOKEN helper is removed'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE coalesce(qual, '') LIKE '%eh_app_aluno()%'
       OR coalesce(with_check, '') LIKE '%eh_app_aluno()%'
  ),
  'no RLS policy depends on APP_TOKEN'
);

SELECT ok(has_table_privilege('anon', 'public.explicacoes_ia', 'SELECT'), 'anon can read explanations');
SELECT ok(has_table_privilege('authenticated', 'public.explicacoes_ia', 'SELECT'), 'authenticated can read explanations');
SELECT ok(NOT has_table_privilege('anon', 'public.explicacoes_ia', 'INSERT'), 'anon cannot write explanations directly');
SELECT ok(NOT has_table_privilege('authenticated', 'public.explicacoes_ia', 'INSERT'), 'authenticated cannot write explanations directly');

SELECT ok(has_table_privilege('anon', 'public.ia_cache_estudo', 'SELECT'), 'anon can read study cache');
SELECT ok(has_table_privilege('authenticated', 'public.ia_cache_estudo', 'SELECT'), 'authenticated can read study cache');
SELECT ok(NOT has_table_privilege('anon', 'public.ia_cache_estudo', 'INSERT'), 'anon cannot write study cache directly');
SELECT ok(NOT has_table_privilege('authenticated', 'public.ia_cache_estudo', 'INSERT'), 'authenticated cannot write study cache directly');

SELECT ok(NOT has_table_privilege('anon', 'public.feedbacks_ia', 'SELECT'), 'anon cannot read AI feedback');
SELECT ok(NOT has_table_privilege('authenticated', 'public.feedbacks_ia', 'SELECT'), 'authenticated cannot read AI feedback');
SELECT ok(NOT has_table_privilege('anon', 'public.feedbacks_questoes', 'SELECT'), 'anon cannot read question feedback');
SELECT ok(NOT has_table_privilege('authenticated', 'public.feedbacks_questoes', 'SELECT'), 'authenticated cannot read question feedback');
SELECT ok(NOT has_table_privilege('anon', 'public.feedbacks_ia', 'INSERT'), 'anon cannot write AI feedback directly');
SELECT ok(NOT has_table_privilege('authenticated', 'public.feedbacks_ia', 'INSERT'), 'authenticated cannot write AI feedback directly');
SELECT ok(NOT has_table_privilege('anon', 'public.feedbacks_questoes', 'INSERT'), 'anon cannot write question feedback directly');
SELECT ok(NOT has_table_privilege('authenticated', 'public.feedbacks_questoes', 'INSERT'), 'authenticated cannot write question feedback directly');
SELECT ok(has_table_privilege('service_role', 'public.feedbacks_ia', 'INSERT'), 'service role can write AI feedback');
SELECT ok(has_table_privilege('service_role', 'public.feedbacks_questoes', 'INSERT'), 'service role can write question feedback');

SELECT ok(
  to_regclass('public.ia_cache_estudo_id_questao_tipo_uidx') IS NOT NULL,
  'study cache has a unique question/type key'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'cadernos'
      AND policyname = 'anon_escreve_dados_aluno'
      AND coalesce(with_check, '') LIKE '%eh_dono_do_aluno%'
  ),
  'personal-data write policies retain the owner check'
);

SELECT ok(
  position(
    'auth.uid()' IN pg_get_functiondef('public.eh_dono_do_aluno(integer)'::regprocedure)
  ) > 0,
  'owner authorization is still bound to auth.uid()'
);

SELECT * FROM finish();
ROLLBACK;
