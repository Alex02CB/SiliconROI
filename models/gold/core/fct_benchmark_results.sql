-- =============================================================================
-- fct_benchmark_results
-- =============================================================================
-- Hecho de rendimiento: una fila por envío de Blender y producto.
--   1. Solo equipos con un único dispositivo (D-20): con dos GPUs, la
--      puntuación no es de un producto.
--   2. Solo envíos completos, con las tres escenas.
--   3. Puntuación del envío = suma de samples por minuto de las tres escenas.
--   4. Producto: por el cruce de Silver (directo o por el seed). Un envío de
--      RTX 4060 Ti genera dos filas, una por variante de memoria.
-- Se conservan todas las versiones de Blender y todos los backends: el filtro
-- (D-21) se aplica al calcular las puntuaciones, en int_product_performance.
-- =============================================================================

with runs as (
    select *
    from {{ ref('slv_blender_opendata__benchmark_runs') }}
    where num_compute_devices = 1
),

-- Un resultado por envío, solo si tiene las tres escenas
submissions as (
    select
          submission_id
        , device_key
        , device_type
        , blender_version
        , split_part(blender_version, '.', 1) || '.' || split_part(blender_version, '.', 2)
                                                    as blender_version_minor
        , min(created_at)                           as created_at
        , sum(samples_per_minute)                   as score
    from runs
    group by submission_id, device_key, device_type, blender_version
    having count(distinct scene_name) = 3
),

device_products as (
    select * from {{ ref('slv_blender_opendata__device_products') }}
),

products as (
    select product_key, product_type, product_name
    from {{ ref('dim_products') }}
),

final as (
    select
          s.submission_id || '__' || pr.product_key    as benchmark_id
        , s.submission_id
        , pr.product_key
        , s.device_type
        , s.blender_version
        , s.blender_version_minor
        , s.score
        , to_date(s.created_at)                         as date_day
        , s.created_at
        , dp.match_type
    from submissions s
    inner join device_products dp
        on s.device_key = dp.device_key
    inner join products pr
        on  dp.device_kind  = pr.product_type
        and dp.product_name = pr.product_name
)

select * from final