-- =============================================================================
-- dim_products
-- =============================================================================
-- Dimensión de productos: CPUs, GPUs y kits de RAM en una sola tabla (D-13).
-- Cada tipo rellena sus columnas y deja a null las de los demás: el
-- recomendador y los marts filtran por product_type.
-- product_key: clave sustituta (dbt_utils.generate_surrogate_key) a partir del
-- tipo y el nombre del producto.
-- =============================================================================

with cpu_products as (
    select
          'cpu'                         as product_type
        , cpu_name                      as product_name
        , manufacturer
        , product_family                as family
        , launch_date
        , launch_price_eur              as reference_price_eur
        , tdp_w
        , cores                         as cpu_cores
        , threads                       as cpu_threads
        , boost_clock_ghz               as cpu_boost_clock_ghz
        , socket                        as cpu_socket
        , supports_ddr4                 as cpu_supports_ddr4
        , supports_ddr5                 as cpu_supports_ddr5
        , has_integrated_graphics       as cpu_has_integrated_graphics
        , single_thread_score           as cpu_single_thread_score
        , null::number(3,0)             as gpu_vram_gb
        , null::varchar                 as gpu_memory_type
        , null::varchar                 as ram_memory_type
        , null::number(5,0)             as ram_speed_mts
        , null::number(4,0)             as ram_total_gb
        , null::number(5,2)             as ram_latency_ns
        , data_source
    from {{ ref('slv_catalogo__cpus') }}
),

gpu_products as (
    select
          'gpu'                         as product_type
        , gpu_name                      as product_name
        , manufacturer
        , architecture                  as family
        , launch_date
        , launch_price_eur              as reference_price_eur
        , tdp_w
        , null::number(3,0)             as cpu_cores
        , null::number(3,0)             as cpu_threads
        , null::number(4,2)             as cpu_boost_clock_ghz
        , null::varchar                 as cpu_socket
        , null::boolean                 as cpu_supports_ddr4
        , null::boolean                 as cpu_supports_ddr5
        , null::boolean                 as cpu_has_integrated_graphics
        , null::number(6,0)             as cpu_single_thread_score
        , vram_gb                       as gpu_vram_gb
        , memory_type                   as gpu_memory_type
        , null::varchar                 as ram_memory_type
        , null::number(5,0)             as ram_speed_mts
        , null::number(4,0)             as ram_total_gb
        , null::number(5,2)             as ram_latency_ns
        , data_source
    from {{ ref('slv_catalogo__gpus') }}
),

ram_products as (
    select
          'ram'                         as product_type
        , ram_kit_name                  as product_name
        , manufacturer
        , memory_type                   as family
        , null::date                    as launch_date
        , reference_price_eur           as reference_price_eur
        , null::number(4,0)             as tdp_w
        , null::number(3,0)             as cpu_cores
        , null::number(3,0)             as cpu_threads
        , null::number(4,2)             as cpu_boost_clock_ghz
        , null::varchar                 as cpu_socket
        , null::boolean                 as cpu_supports_ddr4
        , null::boolean                 as cpu_supports_ddr5
        , null::boolean                 as cpu_has_integrated_graphics
        , null::number(6,0)             as cpu_single_thread_score
        , null::number(3,0)             as gpu_vram_gb
        , null::varchar                 as gpu_memory_type
        , memory_type                   as ram_memory_type
        , speed_mts                     as ram_speed_mts
        , total_gb                      as ram_total_gb
        , latency_ns                    as ram_latency_ns
        , data_source
    from {{ ref('slv_catalogo__ram_kits') }}
),

all_products as (
    select * from cpu_products
    union all
    select * from gpu_products
    union all
    select * from ram_products
),

final as (
    select
          {{ dbt_utils.generate_surrogate_key(['product_type', 'product_name']) }}  as product_key
        , *
    from all_products
)

select * from final