{#
    usd_to_eur
    ---------------------------------------------------------------------------
    Convierte un importe en dólares a euros con el tipo de cambio de referencia
    del proyecto (variable usd_eur_rate del dbt_project.yml) y redondea a
    2 decimales.

    Los precios de lanzamiento en USD se publican sin impuestos, así que el
    resultado está en euros sin IVA (D-06).

    Argumentos:
      column_name  columna con el importe en dólares.

    Ejemplo:
      {{ usd_to_eur('launch_price_usd') }}
        -> round(launch_price_usd * 0.86, 2)::number(10,2)

    Si la variable no existe, dbt falla al compilar: mejor un error que un
    precio convertido con un tipo de cambio inventado.
#}
{% macro usd_to_eur(column_name) -%}
    round({{ column_name }} * {{ var('usd_eur_rate') }}, 2)::number(10,2)
{%- endmacro %}