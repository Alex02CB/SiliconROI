-- =============================================================================
-- slv_blender_opendata__device_products
-- =============================================================================
-- Capa Silver: cruce entre los dispositivos de Blender y los productos del
-- catálogo. Una fila por pareja dispositivo + producto.
--   1. Cruce directo: el device_key de Blender coincide con el del catálogo
--      (los dos lados normalizados con la macro clean_device_name).
--   2. Cruce por seed: las excepciones que la macro no resuelve (variantes de
--      memoria, versiones F/KF de Intel), en mapeo_dispositivos_blender.
-- Un dispositivo puede cruzar con dos productos (RTX 4060 Ti -> 8 GB y 16 GB)
-- y dos dispositivos con el mismo producto (i7-13700K y 13700KF -> 13700K).
-- Los dispositivos que no cruzan van a slv_blender_opendata__unmapped_devices.
-- =============================================================================

-- Dispositivos distintos que aparecen en Blender
with blender_devices as (
    select distinct device_key
    from {{ ref('slv_blender_opendata__benchmark_runs') }}
),

-- Productos del catálogo, CPUs y GPUs juntas, con su clave de cruce
catalog_products as (
    select
          cpu_name      as product_name
        , device_key
        , 'cpu'         as device_kind
    from {{ ref('slv_catalogo__cpus') }}

    union all

    select
          gpu_name      as product_name
        , device_key
        , 'gpu'         as device_kind
    from {{ ref('slv_catalogo__gpus') }}
),

-- 1 · Cruce directo por nombre normalizado
direct_matches as (
    select
          b.device_key
        , c.product_name
        , c.device_kind
        , 'directo'     as match_type
    from blender_devices b
    inner join catalog_products c
        on b.device_key = c.device_key
),

-- 2 · Cruce por las excepciones del seed
seed_matches as (
    select
          b.device_key
        , s.product_name
        , s.device_kind
        , s.motivo      as match_type
    from blender_devices b
    inner join {{ ref('mapeo_dispositivos_blender') }} s
        on b.device_key = s.blender_device_key
),

all_matches as (
    select * from direct_matches
    union all
    select * from seed_matches
),

-- Clave única de la pareja: si un dispositivo cruzara dos veces con el mismo
-- producto (por el catálogo y por el seed), el test unique lo detecta.
final as (
    select
          device_key || '__' || product_name    as device_product_id
        , *
    from all_matches
)

select * from final