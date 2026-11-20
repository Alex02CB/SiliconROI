{#
    clean_device_name
    ---------------------------------------------------------------------------
    Normaliza el nombre de un componente (CPU o GPU) quitando lo que añade el
    sistema operativo, sin tocar las mayúsculas originales.

    Pasos, de dentro afuera:
      1. trim: sin espacios en los extremos.
      2. Quita las marcas (R) y (TM).
      3. Quita la generación de Intel al principio ("13th Gen ").
      4. Quita las coletillas del final: "16-Core Processor", "Six-Core",
         "64-Cores", "Processor", "CPU @ 3.60GHz", "@ 2.30GHz",
         "w/ Radeon 780M Graphics", "with Radeon Vega", "Graphics".
      5. Deja un solo espacio entre palabras.
    Los patrones no distinguen mayúsculas (parámetro 'i' de regexp_replace).

    Argumentos:
      column_name  columna a limpiar.
      as_key       false (por defecto): nombre para mostrar.
                   true: el mismo nombre en minúsculas, para cruzar Blender
                   con el catálogo. Se aplica igual a los dos lados del cruce.

    Ejemplos:
      '13th Gen Intel(R) Core(TM) i9-13900K'
          -> 'Intel Core i9-13900K'          (as_key=false)
          -> 'intel core i9-13900k'          (as_key=true)
      'AMD Ryzen 9 7950X 16-Core Processor'  -> 'AMD Ryzen 9 7950X'
      'AMD Ryzen 5 2600 Six-Core Processor'  -> 'AMD Ryzen 5 2600'
      'Intel(R) Arc(TM) B580 Graphics'       -> 'Intel Arc B580'

    No quita "Laptop GPU": una GPU de portátil rinde menos que la de
    sobremesa con el mismo nombre y no deben cruzarse.

    Si esta macro cambia, los modelos incrementales que guardan su resultado
    necesitan --full-refresh: on_schema_change no detecta cambios de lógica.
#}
{% macro clean_device_name(column_name, as_key=false) -%}

    {%- set cleaned -%}
    trim(
        regexp_replace(
            regexp_replace(
                regexp_replace(
                    regexp_replace(
                        trim({{ column_name }}),
                        '[(]r[)]|[(]tm[)]', '', 1, 0, 'i'
                    ),
                    '^[0-9]+(st|nd|rd|th) gen ', '', 1, 0, 'i'
                ),
                ' [a-z0-9]+-cores?( processor)?$| processor$| (cpu )?@ .*$| w/ radeon.*$| with radeon.*$| graphics$', '', 1, 0, 'i'
            ),
            ' +', ' '
        )
    )
    {%- endset -%}

    {%- if as_key -%}
        lower({{ cleaned }})
    {%- else -%}
        {{ cleaned }}
    {%- endif -%}

{%- endmacro %}