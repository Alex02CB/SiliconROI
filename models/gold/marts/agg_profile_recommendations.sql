-- =============================================================================
-- agg_profile_recommendations
-- =============================================================================
-- Caso de uso 2 · Recomendación de equipo por perfil y presupuesto.
-- Una fila por perfil y presupuesto: el equipo (CPU + GPU + RAM + plataforma)
-- recomendado para el perfil, cuyo precio total no supera el presupuesto.
--   1. Presupuestos: de budget_min a budget_max en pasos de budget_step (vars).
--   2. CPU: con puntuación fiable y stock hoy, más el coste de plataforma de su
--      socket (seed plataformas: placa base, fuente, caja y SSD).
--   3. GPU: con puntuación y stock, o "Gráficos integrados" (0 €, índice 0)
--      si el perfil lo permite y la CPU los tiene.
--   4. RAM: el kit más barato que cumple el mínimo del perfil, de un tipo
--      compatible con la CPU (DDR4 / DDR5).
--   5. Requisitos del perfil: VRAM mínima y RAM mínima (seed perfiles).
--   6. Puntuación (0-100) = peso_multihilo × índice CPU
--                         + peso_monohilo × índice monohilo
--                         + peso_GPU × índice GPU
--   7. Rendimiento objetivo (target_score del seed perfiles): por encima de
--      él, el perfil no aprovecha más rendimiento. Se ordena por
--      effective_score = least(puntuación, objetivo) y, si empatan, gana el
--      equipo más barato. Con objetivo 100 (sin límite) se elige el de más
--      puntuación; con objetivo 65 (oficina) se elige el más barato que llega
--      a 65, en lugar de gastar todo el presupuesto.
-- Los presupuestos sin ningún equipo posible se conservan (has_solution = false).
-- Importes sin IVA (D-06); se añaden los equivalentes con IVA para la landing.
-- =============================================================================

{%- set n_budgets = ((var('budget_max') - var('budget_min')) // var('budget_step')) + 1 %}

with profiles as (
    select * from {{ ref('perfiles') }}
),

platforms as (
    select socket, platform_cost_eur
    from {{ ref('plataformas') }}
),

performance as (
    select * from {{ ref('int_product_performance') }}
),

current_prices as (
    select * from {{ ref('int_current_prices') }}
),

products as (
    select * from {{ ref('dim_products') }}
),

-- 1. Escala de presupuestos (800, 900, ... 5000)
budget_series as (
    {{ dbt_utils.generate_series(upper_bound=n_budgets) }}
),

budgets as (
    select
        ({{ var('budget_min') }} + (generated_number - 1) * {{ var('budget_step') }})::number(6,0)  as budget_eur
    from budget_series
),

-- 2. CPUs candidatas, con el coste de su plataforma
cpu_options as (
    select
          perf.product_key                  as cpu_key
        , perf.product_name                 as cpu_name
        , perf.performance_index            as cpu_multi_index
        , perf.single_thread_index          as cpu_single_index
        , p.cpu_socket
        , p.cpu_supports_ddr4
        , p.cpu_supports_ddr5
        , p.cpu_has_integrated_graphics
        , cp.best_price_ex_vat_eur          as cpu_price_ex_vat_eur
        , cp.best_store_name                as cpu_store_name
        , pl.platform_cost_eur
    from performance perf
    inner join current_prices cp
        on perf.product_key = cp.product_key
    inner join products p
        on perf.product_key = p.product_key
    inner join platforms pl
        on p.cpu_socket = pl.socket
    where perf.product_type = 'cpu'
),

-- 3. GPUs candidatas + opción de gráficos integrados
gpu_options as (
    select
          perf.product_key                  as gpu_key
        , perf.product_name                 as gpu_name
        , perf.performance_index            as gpu_index
        , p.gpu_vram_gb
        , cp.best_price_ex_vat_eur          as gpu_price_ex_vat_eur
        , cp.best_store_name                as gpu_store_name
        , false                             as is_integrated_graphics
    from performance perf
    inner join current_prices cp
        on perf.product_key = cp.product_key
    inner join products p
        on perf.product_key = p.product_key
    where perf.product_type = 'gpu'

    union all

    select
          null                              as gpu_key
        , 'Gráficos integrados'             as gpu_name
        , 0                                 as gpu_index
        , 0                                 as gpu_vram_gb
        , 0                                 as gpu_price_ex_vat_eur
        , null                              as gpu_store_name
        , true                              as is_integrated_graphics
),

-- 4a. Kits de RAM con precio actual
ram_options as (
    select
          p.product_key                     as ram_key
        , p.product_name                    as ram_name
        , upper(p.ram_memory_type)          as ram_memory_type
        , p.ram_total_gb
        , cp.best_price_ex_vat_eur          as ram_price_ex_vat_eur
        , cp.best_store_name                as ram_store_name
    from products p
    inner join current_prices cp
        on p.product_key = cp.product_key
    where p.product_type = 'ram'
),

-- 4b. Para cada perfil y tipo de memoria, el kit más barato que cumple el mínimo
cheapest_ram as (
    select
          pr.profile_id
        , r.*
    from profiles pr
    inner join ram_options r
        on r.ram_total_gb >= pr.min_ram_gb
    qualify row_number() over (
        partition by pr.profile_id, r.ram_memory_type
        order by r.ram_price_ex_vat_eur, r.ram_total_gb desc, r.ram_name
    ) = 1
),

-- 4c. Para cada perfil y CPU, la RAM compatible más barata (DDR4 o DDR5)
cpu_with_ram as (
    select
          r.profile_id
        , c.*
        , r.ram_key
        , r.ram_name
        , r.ram_memory_type
        , r.ram_total_gb
        , r.ram_price_ex_vat_eur
        , r.ram_store_name
    from cpu_options c
    inner join cheapest_ram r
        on (r.ram_memory_type = 'DDR4' and c.cpu_supports_ddr4)
        or (r.ram_memory_type = 'DDR5' and c.cpu_supports_ddr5)
    qualify row_number() over (
        partition by r.profile_id, c.cpu_key
        order by r.ram_price_ex_vat_eur, r.ram_name
    ) = 1
),

-- 5 y 6. Todos los equipos posibles de cada perfil, con su precio y puntuación
builds_scored as (
    select
          pr.profile_id
        , pr.target_score
        , cr.cpu_key
        , cr.cpu_name
        , cr.cpu_socket
        , cr.cpu_store_name
        , cr.cpu_price_ex_vat_eur
        , g.gpu_key
        , g.gpu_name
        , g.gpu_vram_gb
        , g.is_integrated_graphics
        , g.gpu_store_name
        , g.gpu_price_ex_vat_eur
        , cr.ram_key
        , cr.ram_name
        , cr.ram_memory_type
        , cr.ram_total_gb
        , cr.ram_store_name
        , cr.ram_price_ex_vat_eur
        , cr.platform_cost_eur
        , cr.cpu_price_ex_vat_eur
          + g.gpu_price_ex_vat_eur
          + cr.ram_price_ex_vat_eur
          + cr.platform_cost_eur                                as total_price_ex_vat_eur
        , pr.weight_cpu_multi  * cr.cpu_multi_index
          + pr.weight_cpu_single * cr.cpu_single_index
          + pr.weight_gpu        * g.gpu_index                  as profile_score
    from profiles pr
    inner join cpu_with_ram cr
        on cr.profile_id = pr.profile_id
    inner join gpu_options g
        on  g.gpu_vram_gb >= pr.min_vram_gb
        and (
                not g.is_integrated_graphics
             or (pr.allows_integrated_graphics and cr.cpu_has_integrated_graphics)
            )
),

-- 7. Puntuación útil para el perfil: no cuenta lo que supera su objetivo
builds as (
    select
          *
        , least(profile_score, target_score)                    as effective_score
    from builds_scored
),

-- El mejor equipo de cada perfil que cabe en cada presupuesto
best_builds as (
    select
          b.budget_eur
        , bu.*
    from budgets b
    inner join builds bu
        on bu.total_price_ex_vat_eur <= b.budget_eur
    qualify row_number() over (
        partition by bu.profile_id, b.budget_eur
        order by bu.effective_score desc nulls last, bu.total_price_ex_vat_eur, bu.cpu_name, bu.gpu_name
    ) = 1
),

-- Todos los perfiles × presupuestos, también los que no tienen solución
final as (
    select
          pr.profile_id
        , pr.profile_name
        , b.budget_eur                                                                  as budget_ex_vat_eur
        , round(b.budget_eur * (1 + {{ var('vat_rate') }}), 2)::number(10,2)            as budget_with_vat_eur
        , bb.cpu_key is not null                                                        as has_solution
        , bb.cpu_key
        , bb.cpu_name
        , bb.cpu_socket
        , bb.cpu_store_name
        , bb.cpu_price_ex_vat_eur
        , bb.gpu_key
        , bb.gpu_name
        , bb.gpu_vram_gb
        , bb.is_integrated_graphics
        , bb.gpu_store_name
        , bb.gpu_price_ex_vat_eur
        , bb.ram_key
        , bb.ram_name
        , bb.ram_memory_type
        , bb.ram_total_gb
        , bb.ram_store_name
        , bb.ram_price_ex_vat_eur
        , bb.platform_cost_eur
        , bb.total_price_ex_vat_eur::number(10,2)                                       as total_price_ex_vat_eur
        , round(bb.total_price_ex_vat_eur * (1 + {{ var('vat_rate') }}), 2)::number(10,2)
                                                                                        as total_price_with_vat_eur
        , (b.budget_eur - bb.total_price_ex_vat_eur)::number(10,2)                      as budget_left_eur
        , round(bb.profile_score, 2)::number(5,2)                                       as profile_score
        , pr.target_score
        , round(bb.effective_score, 2)::number(5,2)                                     as effective_score
    from profiles pr
    cross join budgets b
    left join best_builds bb
        on  bb.profile_id = pr.profile_id
        and bb.budget_eur = b.budget_eur
)

select * from final