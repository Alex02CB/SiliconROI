-- =============================================================================
-- stg_catalogo__cpus
-- =============================================================================
-- Capa Staging: relación 1:1 con Bronze. Renombrado al inglés, sin cambiar
-- el contenido. Las columnas con unidades ("5.1 GHz", "65W", "14 (6P+8E)")
-- siguen siendo texto: convertirlas en números es trabajo de Silver.
-- =============================================================================

with source as (
    select * from {{ source('catalogo', 'cpus') }}
),

renamed as (
    select
          cpu_nombre               as cpu_name
        , fabricante               as manufacturer
        , familia                  as product_family
        , fecha_lanzamiento        as launch_date
        , nucleos                  as cores
        , hilos                    as threads
        , frecuencia_base          as base_clock
        , frecuencia_boost         as boost_clock
        , cache_l3                 as l3_cache
        , tdp                      as tdp
        , socket                   as socket
        , memoria_soportada        as supported_memory
        , graficos_integrados      as integrated_graphics
        , precio_lanzamiento_usd   as launch_price_usd
        , fuente                   as data_source
        , fecha_captura            as captured_at
        , _loaded_at               as loaded_at
    from source
)

select * from renamed