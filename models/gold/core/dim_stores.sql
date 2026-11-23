-- =============================================================================
-- dim_stores
-- =============================================================================
-- Dimensión de tiendas, a partir del seed tiendas.
-- =============================================================================

with stores as (
    select * from {{ ref('tiendas') }}
),

final as (
    select
          {{ dbt_utils.generate_surrogate_key(['store_name']) }}  as store_key
        , store_name
        , store_type
        , headquarters_country
    from stores
)

select * from final