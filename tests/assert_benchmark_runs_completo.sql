{{ config(store_failures=true) }}

-- =============================================================================
-- assert_benchmark_runs_completo
-- =============================================================================
-- Test de completitud de slv_blender_opendata__benchmark_runs.
--
-- Comprueba que toda pareja envío + escena (v4) del último snapshot de Bronze
-- existe en Silver. Devuelve las que faltan: si devuelve alguna fila, falla.
--
-- Por qué hace falta: el incremental solo relee los últimos 3 días. Si se
-- borran filas más antiguas de Silver, no las recupera y los tests de nulos y
-- duplicados siguen en verde. Este test es el único que detecta datos perdidos.
-- Solución si falla: dbt build --select slv_blender_opendata__benchmark_runs --full-refresh
--
-- Decisiones:
--   - Compara por run_id (envío + escena): detecta también escenas sueltas borradas.
--   - Solo el último snapshot: cada snapshot es el histórico completo, así el
--     coste no crece aunque Bronze acumule snapshots.
--   - Solo comprueba lo que falta en Silver, no lo que sobra: si Blender retira
--     un envío del snapshot, Silver lo conserva y eso no es un error.
--   - store_failures: guarda las filas que faltan en el schema *_dbt_test__audit
--     para poder investigarlas.
-- =============================================================================

with ultimo_snapshot as (
    select *
    from {{ ref('stg_blender_opendata__submissions') }}
    where schema_version = 'v4'
      and snapshot_date = (
          select max(snapshot_date)
          from {{ ref('stg_blender_opendata__submissions') }}
      )
),

-- Todas las parejas envío + escena que deberían estar en Silver
esperadas as (
    select distinct
          u.submission_id || '__' || f.value:scene:label::varchar   as run_id
        , u.submission_id
        , f.value:scene:label::varchar                              as scene_name
        , u.created_at
    from ultimo_snapshot u
       , lateral flatten(input => u.benchmark_data) f
)

-- Las que no están en Silver
select e.*
from esperadas e
left join {{ ref('slv_blender_opendata__benchmark_runs') }} slv
    on e.run_id = slv.run_id
where slv.run_id is null