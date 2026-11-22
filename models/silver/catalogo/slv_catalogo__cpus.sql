-- =============================================================================
-- slv_catalogo__cpus
-- =============================================================================
-- Capa Silver: una fila por CPU del catálogo, con los valores convertidos a
-- número y la puntuación monohilo incorporada.
--   1. Une cada CPU con su puntuación monohilo (test relationships en el source).
--   2. Convierte los textos con unidades a números con tipo preciso (D-15),
--      con la macro extract_number.
--   3. Precio de lanzamiento en euros sin IVA (macro usd_to_eur, D-06).
--   4. device_key: la clave para cruzar con Blender (macro clean_device_name).
-- =============================================================================

with cpus as (
    select * from {{ ref('stg_catalogo__cpus') }}
),

single_thread as (
    select * from {{ ref('stg_catalogo__cpu_monohilo') }}
),

cleaned as (
    select
        -- Identificación
          c.cpu_name
        , {{ clean_device_name('c.cpu_name', as_key=true) }}                    as device_key
        , c.manufacturer
        , c.product_family
        , c.launch_date

        -- Núcleos: "14 (6P+8E)" en Intel, "8" en AMD.
        -- AMD no distingue tipos de núcleo: todos cuentan como P y 0 como E.
        , {{ extract_number('c.cores') }}::number(3,0)                          as cores
        , coalesce(
              {{ extract_number('c.cores', 2) }},
              {{ extract_number('c.cores') }}
          )::number(3,0)                                                        as p_cores
        , coalesce({{ extract_number('c.cores', 3) }}, 0)::number(3,0)          as e_cores
        , c.threads::number(3,0)                                                as threads

        -- Frecuencias, caché y consumo
        , {{ extract_number('c.base_clock') }}::number(4,2)                     as base_clock_ghz
        , {{ extract_number('c.boost_clock') }}::number(4,2)                    as boost_clock_ghz
        , {{ extract_number('c.l3_cache') }}::number(4,0)                       as l3_cache_mb
        , {{ extract_number('c.tdp') }}::number(4,0)                            as tdp_w

        -- Compatibilidad con placa y RAM (D-14)
        , c.socket
        , contains(upper(c.supported_memory), 'DDR4')                           as supports_ddr4
        , contains(upper(c.supported_memory), 'DDR5')                           as supports_ddr5
        , regexp_substr(c.supported_memory, 'DDR4[- ]([0-9]+)', 1, 1, 'e', 1)::number(5,0)
                                                                                as max_ddr4_mts
        , regexp_substr(c.supported_memory, 'DDR5[- ]([0-9]+)', 1, 1, 'e', 1)::number(5,0)
                                                                                as max_ddr5_mts

        -- Gráfica integrada: "No" o el nombre de la iGPU
        , c.integrated_graphics <> 'No'                                         as has_integrated_graphics
        , nullif(c.integrated_graphics, 'No')                                   as integrated_graphics_name

        -- Precio
        , c.launch_price_usd::number(10,2)                                      as launch_price_usd
        , {{ usd_to_eur('c.launch_price_usd') }}                                as launch_price_eur

        -- Rendimiento monohilo (otra fuente y otra fiabilidad: se conserva su origen)
        , st.single_thread_score::number(6,0)                                   as single_thread_score
        , st.benchmark_name                                                     as single_thread_benchmark
        , st.data_source                                                        as single_thread_source

        -- Trazabilidad
        , c.data_source
        , c.captured_at
        , c.loaded_at
    from cpus c
    left join single_thread st
        on c.cpu_name = st.cpu_name
)

select * from cleaned