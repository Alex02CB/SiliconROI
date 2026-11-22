{#
    extract_number
    ---------------------------------------------------------------------------
    Extrae un número de un texto con unidades, tal como viene en las fichas
    del catálogo. Devuelve number(10,2), o null si no encuentra ese número.

    Argumentos:
      column_name  columna (o texto) de la que extraer el número.
      occurrence   qué número del texto devolver: 1 (por defecto) es el primero.

    Ejemplos:
      'Up to 4.9 GHz'   ->  4.90
      '125 W' / '65W'   ->  125.00 / 65.00
      '14 (6P+8E)'      ->  14 (occurrence 1) · 6 (2) · 8 (3)
      'DDR5-6000'       ->  5  (occurrence 1) · 6000 (2)
      '2x16GB'          ->  2  (occurrence 1) · 16 (2)
      '30-36-36-96'     ->  30 (occurrence 1)

    El modelo que la usa convierte el resultado a su tipo preciso (D-15),
    por ejemplo ::number(4,2) para una frecuencia o ::number(4,0) para núcleos.
#}
{% macro extract_number(column_name, occurrence=1) -%}
    try_to_decimal(
        regexp_substr({{ column_name }}, '[0-9]+([.][0-9]+)?', 1, {{ occurrence }}),
        10, 2
    )
{%- endmacro %}