-- =============================================================================
-- dim_date
-- =============================================================================
-- Calendario: un día por fila, desde el inicio del histórico de precios
-- (variable price_history_start) hasta hoy. Generado con dbt_utils.date_spine.
-- season: calendario comercial español, el mismo que usa el simulador.
-- =============================================================================

with spine as (
    {{ dbt_utils.date_spine(
        datepart   = "day",
        start_date = "cast('" ~ var('price_history_start') ~ "' as date)",
        end_date   = "dateadd(day, 1, current_date())"
    ) }}
),

final as (
    select
          date_day::date                                    as date_day
        , year(date_day)                                    as year
        , month(date_day)                                   as month
        , to_char(date_day, 'YYYY-MM')                      as year_month
        , weekofyear(date_day)                              as week_of_year
        , dayofweekiso(date_day)                            as day_of_week      -- 1 lunes … 7 domingo
        , dayofweekiso(date_day) in (6, 7)                  as is_weekend
        , case
              when month(date_day) = 11 and day(date_day) >= 20     then 'Black Friday'
              when (month(date_day) = 12 and day(date_day) >= 26)
                or (month(date_day) = 1  and day(date_day) <= 15)   then 'Rebajas de enero'
              when month(date_day) = 12                             then 'Navidad'
              when month(date_day) in (7, 8)                        then 'Verano'
              else 'Temporada normal'
          end                                               as season
    from spine
)

select * from final