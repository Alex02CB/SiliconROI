-- =============================================================================
-- assert_recomendaciones_validas
-- =============================================================================
-- Ninguna recomendación puede incumplir las reglas de negocio:
--   - Superar el presupuesto.
--   - Tener menos VRAM o RAM que el mínimo del perfil.
--   - Usar gráficos integrados en un perfil que no los permite.
-- Devuelve las recomendaciones que incumplen alguna regla, con el motivo.
-- Si devuelve filas, el test falla; se guardan en el esquema de auditoría
-- (store_failures) para revisarlas en Snowflake.
-- =============================================================================

{{ config(store_failures=true) }}

with recommendations as (
    select * from {{ ref('agg_profile_recommendations') }}
    where has_solution
),

profiles as (
    select * from {{ ref('perfiles') }}
)

select
      r.profile_id
    , r.budget_ex_vat_eur
    , r.total_price_ex_vat_eur
    , r.gpu_name
    , r.gpu_vram_gb
    , r.ram_total_gb
    , case
          when r.total_price_ex_vat_eur > r.budget_ex_vat_eur         then 'supera_presupuesto'
          when r.gpu_vram_gb < p.min_vram_gb                          then 'vram_insuficiente'
          when r.ram_total_gb < p.min_ram_gb                          then 'ram_insuficiente'
          else 'graficos_integrados_no_permitidos'
      end                                                             as motivo
from recommendations r
inner join profiles p
    on r.profile_id = p.profile_id
where r.total_price_ex_vat_eur > r.budget_ex_vat_eur
   or r.gpu_vram_gb < p.min_vram_gb
   or r.ram_total_gb < p.min_ram_gb
   or (r.is_integrated_graphics and not p.allows_integrated_graphics)