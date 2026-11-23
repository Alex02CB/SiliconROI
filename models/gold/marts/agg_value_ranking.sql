-- =============================================================================
-- agg_value_ranking
-- =============================================================================
-- Caso de uso 1 · Rendimiento por euro.
-- Una fila por CPU y GPU con puntuación fiable y precio actual con stock:
--   - performance_per_100_eur: puntos de rendimiento (índice 0-100) por cada
--     100 € sin IVA, con el mejor precio de hoy.
--   - value_rank: posición dentro de su tipo (1 = mejor relación).
--   - single_thread_per_100_eur: lo mismo con el índice monohilo (solo CPUs).
-- Se compara sin IVA (D-06); el precio con IVA se conserva para la landing.
-- =============================================================================

with performance as (
    select * from {{ ref('int_product_performance') }}
),

current_prices as (
    select * from {{ ref('int_current_prices') }}
),

products as (
    select
          product_key
        , manufacturer
        , cpu_cores
        , cpu_socket
        , gpu_vram_gb
    from {{ ref('dim_products') }}
),

joined as (
    select
          perf.product_key
        , perf.product_type
        , perf.product_name
        , p.manufacturer
        , p.cpu_cores
        , p.cpu_socket
        , p.gpu_vram_gb
        , perf.backend
        , perf.benchmark_samples
        , perf.performance_index
        , perf.single_thread_index
        , cp.price_date
        , cp.best_store_name
        , cp.best_price_ex_vat_eur
        , cp.best_retail_price_eur
        , cp.highest_price_ex_vat_eur
        , cp.stores_in_stock
    from performance perf
    inner join current_prices cp
        on perf.product_key = cp.product_key
    inner join products p
        on perf.product_key = p.product_key
),

final as (
    select
          *
        , round(performance_index / best_price_ex_vat_eur * 100, 2)::number(8,2)      as performance_per_100_eur
        , round(single_thread_index / best_price_ex_vat_eur * 100, 2)::number(8,2)    as single_thread_per_100_eur
        , rank() over (
              partition by product_type
              order by performance_index / best_price_ex_vat_eur desc
          )                                                                           as value_rank
    from joined
)

select * from final