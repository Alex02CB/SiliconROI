-- =============================================================================
-- stg_catalogo__cpu_monohilo
-- =============================================================================
-- Capa Staging: relación 1:1 con Bronze. Renombrado al inglés, sin cambiar
-- el contenido. Puntuación monohilo estimada en la escala de Geekbench 6.
-- =============================================================================

with source as (
    select * from {{ source('catalogo', 'cpu_monohilo') }}
),

renamed as (
    select
          cpu_nombre            as cpu_name
        , benchmark             as benchmark_name
        , puntuacion_monohilo   as single_thread_score
        , fuente                as data_source
        , fecha_captura         as captured_at
        , _loaded_at            as loaded_at
    from source
)

select * from renamed