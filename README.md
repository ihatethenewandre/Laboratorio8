# Laboratorio 8 – Análisis de viajes de taxi de Nueva York con DuckDB y Parquet

Flujo reproducible para descargar, consultar, transformar y visualizar los registros de viajes de taxis amarillos y verdes publicados por la New York City Taxi & Limousine Commission, TLC, en formato Parquet; todo el análisis se resuelve con DuckDB dentro de un ambiente de Docker Compose, se compara el desempeño de consultar los archivos Parquet frente a una tabla materializada y se construye un tablero de indicadores en Metabase que se actualiza al incorporar los datos de 2024, 2025 y 2026.

## Integrantes

• André Emilio Pivaral López – 23574  

**Universidad del Valle de Guatemala**  
Facultad de Ingeniería  
Departamento de Computación  
Data Science  
  
**Catedrático:** Boris Fernando Becerra Peláez  
**Sección:** 30

## Descripción

El proyecto trabaja con los archivos mensuales de viajes de taxis amarillos y verdes de la TLC para 2024, 2025 y los meses publicados de 2026, de enero a agosto, junto con la tabla de zonas de taxi. En total son 64 archivos Parquet con 121,184,384 registros y 2,073 MB en disco. Los archivos se obtienen con un script de descarga incremental que recibe los años como parámetro, omite lo ya descargado y verifica la completitud contra el servidor de la TLC. Desde ese punto todo el trabajo analítico se realiza con DuckDB directamente sobre los archivos, sin servidor de base de datos y sin cargar los datos completos en memoria con Pandas.

El notebook resuelve los nueve ejercicios del laboratorio. Verifica el ambiente, completa el script de descarga, explora los Parquet con consultas directas y metadatos, define reglas de calidad y responde nueve preguntas de análisis exploratorio sobre 2026. Después incorpora 2024 sin modificar ninguna consulta, mide con un benchmark el desempeño de consultar Parquet frente a una tabla materializada en DuckDB con cuatro volúmenes de datos, construye trece indicadores que alimentan un tablero en Metabase, incorpora 2025, analiza la evolución de los indicadores entre los tres años y discute las ventajas y limitaciones observadas. Cada consulta ejecutada se documenta automáticamente con su objetivo, fuentes, resultado y decisión. El informe en PDF resume la metodología, los resultados y la discusión, sin incluir código.

## Estructura del proyecto

    duckdb/
    ├── data/                                       no se versiona, se genera con los scripts
    │   ├── processed/
    │   │   ├── benchmark.duckdb                    tabla materializada del volumen completo del benchmark
    │   │   ├── manifiesto_descargas.csv            diagnóstico de completitud de cada archivo
    │   │   └── tablero.duckdb                      tablas de indicadores que lee Metabase
    │   └── raw/
    │       ├── green/2024 a green/2026/            green_tripdata_AAAA-MM.parquet
    │       ├── yellow/2024 a yellow/2026/          yellow_tripdata_AAAA-MM.parquet
    │       └── zonas/taxi_zone_lookup.csv          tabla de zonas de taxi de la TLC
    ├── docs/
    │   ├── benchmark/
    │   │   ├── benchmark_cargas.csv                volúmenes, tamaño en disco y tiempo de materialización
    │   │   ├── benchmark_comparacion.csv           mediana de ambas estrategias y su cociente
    │   │   ├── benchmark_detalle.csv               tiempo de cada repetición
    │   │   └── benchmark_resumen.csv               mediana por consulta, volumen y estrategia
    │   ├── figures/
    │   │   ├── Figura1.png a Figura15.png          figuras exportadas por el notebook
    │   │   └── indice_figuras.csv                  número y descripción de cada figura
    │   ├── tablero/
    │   │   ├── e7/                                 captura de cada tarjeta del tablero con 2024 y 2026
    │   │   ├── e8/                                 captura de cada tarjeta del tablero con los tres años
    │   │   ├── guia_metabase.md                    conexión de Metabase y configuración de cada tarjeta
    │   │   ├── indicadores.csv                     resumen de las tablas de indicadores construidas
    │   │   ├── tablero_estatico_e7_10.png a tablero_estatico_e8_13.png     indicadores dibujados con Matplotlib
    │   │   ├── tablero_metabase_2024_2026.png      tablero completo del Ejercicio 7
    │   │   └── tablero_metabase_2024_2025_2026.png tablero completo del Ejercicio 8
    │   └── consultas.md                            documentación de las 86 consultas ejecutadas
    ├── notebooks/
    │   └── Laboratorio8.ipynb
    ├── scripts/
    │   ├── benchmark.py                            benchmark de Parquet frente a tablas DuckDB
    │   ├── construir_tablero.py                    construye data/processed/tablero.duckdb
    │   ├── download_data.py                        descarga incremental y verificación de completitud
    │   ├── graficos_tablero.py                     evidencia estática de los indicadores
    │   └── taxis.py                                conexión, vistas, catálogo SQL y bitácora de consultas
    ├── sql/
    │   ├── 01_exploracion_parquet.sql              Ejercicio 3
    │   ├── 02_analisis_exploratorio.sql            capas de calidad y preguntas del Ejercicio 4
    │   ├── 03_incorporacion.sql                    validaciones y evolución de los Ejercicios 5 y 8
    │   ├── 04_benchmark.sql                        consultas del Ejercicio 6
    │   ├── 05_indicadores.sql                      indicadores de los Ejercicios 7 y 8
    │   └── vista_viajes_generada.sql               vista normalizada generada desde los esquemas
    ├── .gitignore
    ├── Dockerfile                                  servicio lab con Python, DuckDB y JupyterLab
    ├── docker-compose.yml
    ├── Informe.pdf
    ├── metabase.Dockerfile                         servicio metabase con el controlador de DuckDB
    ├── README.md
    └── requirements.txt

## Requisitos

- Docker Desktop con Docker Compose; no es necesario instalar Python ni crear un entorno virtual en la computadora
- Git
- Al menos 10 GB libres en disco; las imágenes ocupan unos 3 GB, los datos de los tres años 2.1 GB y la base del benchmark 2.6 GB
- Conexión a internet para construir las imágenes y descargar los datos
- Puertos 8888 y 3001 libres en la computadora
- Versiones fijadas en el ambiente; Python 3.11.14, DuckDB 1.5.5, JupyterLab 4.6.4, pandas 3.0.6, PyArrow 25.0.1, Matplotlib 3.11.2, Requests 2.34.2, Metabase v0.63.19 y el controlador de DuckDB 1.5.5.0 sobre Java 21

## Cómo levantar el ambiente

Desde una terminal, PowerShell en Windows, se clona el repositorio y se construyen los dos servicios:

```bash
git clone https://github.com/<usuario>/duckdb.git
cd duckdb
docker compose up --build -d
docker compose ps
```

La primera construcción tarda varios minutos. Al terminar, `docker compose ps` muestra los servicios lab y metabase en ejecución:

- JupyterLab en http://localhost:8888
- Metabase en http://localhost:3001

Dentro de los contenedores la carpeta del proyecto está montada en `/workspace`, por lo que las herramientas del ambiente usan rutas como `/workspace/data` y no las rutas de la computadora. Para detener el ambiente se usa `docker compose stop` y para volver a iniciarlo `docker compose start`.

## Cómo descargar los datos

El script descarga los años indicados, omite los archivos que ya existen y reporta los meses que la TLC todavía no publica. Sin parámetros descarga 2024, 2025 y 2026:

```bash
docker compose exec lab python scripts/download_data.py
docker compose exec lab python scripts/download_data.py --anios 2026
docker compose exec lab python scripts/download_data.py --anios 2024 2026
docker compose exec lab python scripts/download_data.py --verificar
```

La opción `--verificar` no descarga nada: comprueba que cada mes publicado exista localmente con el mismo tamaño que en el servidor y que se pueda abrir como Parquet, y guarda el diagnóstico en `data/processed/manifiesto_descargas.csv`. El conjunto está completo cuando todos los meses aparecen como completo y solo los meses posteriores al último publicado aparecen como no publicado. Volver a ejecutar el script no descarga de nuevo lo existente, por lo que puede repetirse conforme la TLC publique meses nuevos de 2026.

## Cómo ejecutar el análisis

El notebook ejecuta en orden las descargas de cada ejercicio, el análisis, el benchmark y la construcción de los indicadores. Como la base del tablero solo admite un proceso con escritura, Metabase se detiene mientras corre el notebook:

```bash
docker compose stop metabase
docker compose exec lab jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.timeout=-1 notebooks/Laboratorio8.ipynb
docker compose start metabase
```

También puede abrirse en JupyterLab, http://localhost:8888, y ejecutarse celda por celda desde `notebooks/Laboratorio8.ipynb`. La ejecución completa tarda varios minutos además de las descargas; solo el benchmark tarda cerca de 12 minutos. Al terminar se actualizan las figuras de `docs/figures`, la documentación de `docs/consultas.md`, los resultados de `docs/benchmark` y la base `data/processed/tablero.duckdb`.

## Cómo reproducir los benchmarks

El benchmark del Ejercicio 6 se puede ejecutar fuera del notebook. Usa su propia base, `data/processed/benchmark.duckdb`, y compara seis consultas sobre Parquet y sobre una tabla DuckDB con 1 mes, 3 meses, 12 meses y todos los meses de los años indicados, con una ejecución de calentamiento y cinco repeticiones medidas:

```bash
docker compose exec lab python scripts/benchmark.py --anios 2024 2026
docker compose exec lab python scripts/benchmark.py --anios 2024 2026 --repeticiones 5
```

Los resultados se guardan en `docs/benchmark`. Sin `--anios` el benchmark usa todos los años descargados. Los tiempos absolutos dependen del equipo, pero los cocientes entre estrategias deben ser similares a los reportados.

## Cómo generar los resultados principales

La base de indicadores del tablero se construye con los años deseados, con Metabase detenido:

```bash
docker compose stop metabase
docker compose exec lab python scripts/construir_tablero.py --anios 2024 2026
docker compose exec lab python scripts/construir_tablero.py
docker compose exec lab python scripts/graficos_tablero.py
docker compose start metabase
```

El primer comando de construcción corresponde al Ejercicio 7 y el segundo, sin `--anios`, al Ejercicio 8 con los tres años. `graficos_tablero.py` dibuja los mismos indicadores con Matplotlib en `docs/tablero/tablero_parte1.png` y `docs/tablero/tablero_parte2.png` como evidencia reproducible.

Para ver el tablero se abre http://localhost:3001, se crea la cuenta de administrador la primera vez y se agrega una base de datos de tipo DuckDB con el nombre Taxis NY, el archivo `/workspace/data/processed/tablero.duckdb` y la opción de solo lectura activada. Las trece tablas `ind_01` a `ind_13` alimentan las tarjetas del tablero Viajes de Taxi de Nueva York; la configuración de cada una está en `docs/tablero/guia_metabase.md`. Después de reconstruir la base se sincroniza el esquema desde la configuración de la base de datos en Metabase. Las capturas del tablero están en `docs/tablero/e7` y `docs/tablero/e8`.

## Contenido del análisis

- Ejercicio 1. Ambiente reproducible con Docker Compose, verificación de los servicios lab y metabase, herramientas disponibles, propósito de cada directorio e importancia de un ambiente reproducible.
- Ejercicio 2. Análisis y modificación del script de descarga para recibir los años como parámetro, calcular rutas desde su ubicación, distinguir errores de red de meses no publicados, descargar la tabla de zonas y verificar la completitud con un manifiesto.
- Ejercicio 3. Consultas directas sobre Parquet con parquet_file_metadata, parquet_schema, DESCRIBE, USING SAMPLE y SUMMARIZE; detección de variaciones de esquema, cuantificación de problemas de calidad y definición de ocho reglas de exclusión.
- Ejercicio 4. Vista normalizada generada desde los esquemas, capas de calidad y nueve preguntas de análisis exploratorio sobre 2026: calidad, evolución mensual, perfil horario y velocidad, diferencias entre taxis amarillos y verdes, distancias, pago y propina, zonas de origen, aeropuertos y tarifas por milla atípicas.
- Ejercicio 5. Incorporación de 2024 con el mismo script, validación de la cobertura y de los conteos por archivo, comparación de los meses comunes y ejecución sin cambios de las consultas del Ejercicio 4.
- Ejercicio 6. Benchmark de seis consultas sobre Parquet frente a una tabla materializada en DuckDB con cuatro volúmenes, mediana de cinco repeticiones, costo de materialización y escenarios de uso de cada estrategia.
- Ejercicio 7. Trece preguntas e indicadores calculados con SQL, base de indicadores para Metabase, tablero organizado en resumen, tiempo y pago, geografía y calidad, e interpretación de los indicadores de 2024 y 2026.
- Ejercicio 8. Incorporación de 2025, validación de las consultas sobre los tres años, actualización del tablero y análisis de la evolución de volumen, montos, tiempos, pago, recargos, calidad y perfil horario.
- Ejercicio 9. Discusión sobre las características de DuckDB, las ventajas y limitaciones de cada estrategia de acceso, la comparación con Pandas, la incorporación de datos nuevos, la automatización en producción y la reproducibilidad.

## Resultados principales

Indicadores de los viajes válidos de taxis amarillos y verdes; 2026 incluye de enero a agosto.

| Indicador | 2024 | 2025 | 2026 |
| --- | ---: | ---: | ---: |
| Registros publicados | 41,829,938 | 49,313,977 | 30,040,469 |
| Registros válidos | 96.34 % | 90.67 % | 95.04 % |
| Viajes válidos por día | 110,103 | 122,503 | 117,495 |
| Ingreso por día, USD | 3,144,396 | 3,527,445 | 3,547,287 |
| Total promedio por viaje, USD | 28.56 | 28.79 | 30.19 |
| Distancia mediana, millas | 1.80 | 1.90 | 1.93 |
| Duración mediana, minutos | 13.07 | 13.52 | 14.10 |
| Velocidad mediana, mph | 9.30 | 9.45 | 9.29 |
| Pago con tarjeta | 75.91 % | 68.68 % | 65.37 % |
| Pago sin registro | 9.23 % | 19.88 % | 24.83 % |
| Propina con tarjeta | 25.12 % | 25.43 % | 25.07 % |
| Participación de taxis verdes | 1.54 % | 1.25 % | 1.13 % |
| Viajes amarillos con cargo CBD | 0.00 % | 73.03 % | 72.39 % |

Benchmark con 2024 y 2026; tiempo total de las seis consultas con la mediana de cinco repeticiones.

| Volumen | Registros | Parquet, MB | Tabla DuckDB, MB | Creación de la tabla, s | Parquet, s | Tabla, s | Ejecuciones para amortizar |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 mes | 3,765,161 | 65.2 | 134.0 | 5.0 | 1.84 | 0.78 | 4.8 |
| 3 meses | 11,199,059 | 193.7 | 401.3 | 10.5 | 4.55 | 2.52 | 5.2 |
| 12 meses | 41,829,938 | 708.9 | 1,496.1 | 41.2 | 18.35 | 10.31 | 5.1 |
| Todos los meses | 71,870,407 | 1,228.6 | 2,584.0 | 93.1 | 41.80 | 19.11 | 4.1 |

La tabla materializada fue más rápida en todas las consultas, entre 2.5 y 3.4 veces en agregaciones y uniones, entre 6.4 y 12.7 veces en el filtro selectivo y apenas entre 1.0 y 1.4 veces en el cálculo de percentiles, a cambio del tiempo de creación y del doble de espacio en disco.

## Datos

Los archivos de datos no se incluyen en el repositorio; el `.gitignore` excluye `data/raw` y `data/processed`, y se obtienen con `scripts/download_data.py` desde la fuente original. La TLC publica cada mes con varias semanas de atraso, por lo que al momento de la ejecución estaban disponibles los meses de enero a agosto de 2026; los resultados de 2026 cambiarán al incorporar los meses siguientes.

Fuente de datos: NYC TLC Trip Record Data, https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
