# Documentación de consultas

Archivo generado por el notebook a partir de la bitácora de consultas. Cada consulta se ejecutó directamente con DuckDB y su texto fuente se encuentra en la carpeta sql/.

## Ejercicio 3

### e3_inventario_archivos

- Objetivo: Contar los archivos disponibles y obtener sus filas, grupos de filas y tamaño leyendo solo los metadatos Parquet.
- Fuentes: data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/01_exploracion_parquet.sql
- Resultado: 16 filas y 6 columnas en 0.06 s
- Decisión: El número de archivos por tipo debe coincidir con los meses publicados por la TLC; el conteo de filas por metadatos sirve de referencia para validar lecturas posteriores.

```sql
SELECT
    regexp_extract(file_name, '(yellow|green)_tripdata', 1) AS tipo_taxi,
    regexp_extract(file_name, '(\d{4}-\d{2})\.parquet$', 1) AS periodo,
    regexp_extract(file_name, '[^/\\]+$') AS archivo,
    num_rows AS registros,
    num_row_groups AS grupos_filas,
    round(file_size_bytes / 1e6, 2) AS mb
FROM parquet_file_metadata(['data/raw/yellow/2026/*.parquet', 'data/raw/green/2026/*.parquet'])
ORDER BY tipo_taxi DESC, periodo
```

| tipo_taxi | periodo | archivo | registros | grupos_filas | mb |
| --- | --- | --- | --- | --- | --- |
| yellow | 2026-01 | yellow_tripdata_2026-01.parquet | 3724889 | 4 | 64.17 |
| yellow | 2026-02 | yellow_tripdata_2026-02.parquet | 3399866 | 4 | 58.68 |
| yellow | 2026-03 | yellow_tripdata_2026-03.parquet | 3952451 | 4 | 67.89 |
| yellow | 2026-04 | yellow_tripdata_2026-04.parquet | 3831240 | 4 | 64.82 |
| yellow | 2026-05 | yellow_tripdata_2026-05.parquet | 4090836 | 4 | 69.7 |
| yellow | 2026-06 | yellow_tripdata_2026-06.parquet | 3837248 | 4 | 65.47 |
| yellow | 2026-07 | yellow_tripdata_2026-07.parquet | 3530109 | 4 | 61.69 |
| yellow | 2026-08 | yellow_tripdata_2026-08.parquet | 3336716 | 4 | 59.04 |
| green | 2026-01 | green_tripdata_2026-01.parquet | 40272 | 1 | 0.99 |
| green | 2026-02 | green_tripdata_2026-02.parquet | 37373 | 1 | 0.92 |
| green | 2026-03 | green_tripdata_2026-03.parquet | 44208 | 1 | 1.08 |
| green | 2026-04 | green_tripdata_2026-04.parquet | 44238 | 1 | 1.08 |

### e3_resumen_archivos

- Objetivo: Resumir por tipo de taxi la cantidad de archivos, de registros y el volumen en disco.
- Fuentes: data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/01_exploracion_parquet.sql
- Resultado: 2 filas y 5 columnas en 0.06 s
- Decisión: Los taxis amarillos concentran la mayor parte del volumen, por lo que dominan los tiempos de consulta y cualquier agregado que no separe por tipo.

```sql
SELECT
    regexp_extract(file_name, '(yellow|green)_tripdata', 1) AS tipo_taxi,
    count(*) AS archivos,
    CAST(sum(num_rows) AS BIGINT) AS registros,
    round(sum(file_size_bytes) / 1e6, 1) AS mb,
    CAST(round(sum(num_rows) / count(*)) AS BIGINT) AS registros_por_archivo
FROM parquet_file_metadata(['data/raw/yellow/2026/*.parquet', 'data/raw/green/2026/*.parquet'])
GROUP BY ALL
ORDER BY tipo_taxi DESC
```

| tipo_taxi | archivos | registros | mb | registros_por_archivo |
| --- | --- | --- | --- | --- |
| yellow | 8 | 29703355 | 511.5 | 3712919 |
| green | 8 | 337114 | 8.3 | 42139 |

### e3_conteo_lectura

- Objetivo: Contar los registros leyendo los datos con read_parquet para confirmar que coinciden con los metadatos.
- Fuentes: data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/01_exploracion_parquet.sql
- Resultado: 2 filas y 2 columnas en 0.15 s
- Decisión: Si el conteo coincide con los metadatos, la lectura conjunta con union_by_name no pierde ni duplica registros.

```sql
SELECT
    regexp_extract(filename, '(yellow|green)_tripdata', 1) AS tipo_taxi,
    count(*) AS registros_leidos
FROM read_parquet(['data/raw/yellow/2026/*.parquet', 'data/raw/green/2026/*.parquet'], union_by_name = true, filename = true)
GROUP BY ALL
ORDER BY tipo_taxi DESC
```

| tipo_taxi | registros_leidos |
| --- | --- |
| yellow | 29703355 |
| green | 337114 |

### e3_esquema_amarillos

- Objetivo: Listar las columnas y los tipos de datos que DuckDB infiere al leer en conjunto los archivos de taxis amarillos.
- Fuentes: data/raw/yellow/2026/*.parquet
- Archivo SQL: sql/01_exploracion_parquet.sql
- Resultado: 21 filas y 6 columnas en 0.05 s
- Decisión: Las columnas de fecha usan el prefijo tpep y los identificadores de zona son enteros que se cruzan con la tabla de zonas.

```sql
DESCRIBE SELECT * FROM read_parquet(['data/raw/yellow/2026/*.parquet'], union_by_name = true)
```

| column_name | column_type | null | key | default | extra |
| --- | --- | --- | --- | --- | --- |
| VendorID | INTEGER | YES | None | None | None |
| tpep_pickup_datetime | TIMESTAMP | YES | None | None | None |
| tpep_dropoff_datetime | TIMESTAMP | YES | None | None | None |
| passenger_count | BIGINT | YES | None | None | None |
| trip_distance | DOUBLE | YES | None | None | None |
| RatecodeID | BIGINT | YES | None | None | None |
| store_and_fwd_flag | VARCHAR | YES | None | None | None |
| PULocationID | INTEGER | YES | None | None | None |
| DOLocationID | INTEGER | YES | None | None | None |
| payment_type | BIGINT | YES | None | None | None |
| fare_amount | DOUBLE | YES | None | None | None |
| extra | DOUBLE | YES | None | None | None |

### e3_esquema_verdes

- Objetivo: Listar las columnas y los tipos de datos de los archivos de taxis verdes.
- Fuentes: data/raw/green/2026/*.parquet
- Archivo SQL: sql/01_exploracion_parquet.sql
- Resultado: 22 filas y 6 columnas en 0.05 s
- Decisión: Los taxis verdes usan el prefijo lpep y tienen columnas propias, ehail_fee y trip_type, por lo que se construye una vista con nombres comunes para comparar ambos tipos.

```sql
DESCRIBE SELECT * FROM read_parquet(['data/raw/green/2026/*.parquet'], union_by_name = true)
```

| column_name | column_type | null | key | default | extra |
| --- | --- | --- | --- | --- | --- |
| VendorID | INTEGER | YES | None | None | None |
| lpep_pickup_datetime | TIMESTAMP | YES | None | None | None |
| lpep_dropoff_datetime | TIMESTAMP | YES | None | None | None |
| store_and_fwd_flag | VARCHAR | YES | None | None | None |
| RatecodeID | BIGINT | YES | None | None | None |
| PULocationID | INTEGER | YES | None | None | None |
| DOLocationID | INTEGER | YES | None | None | None |
| passenger_count | BIGINT | YES | None | None | None |
| trip_distance | DOUBLE | YES | None | None | None |
| fare_amount | DOUBLE | YES | None | None | None |
| extra | DOUBLE | YES | None | None | None |
| mta_tax | DOUBLE | YES | None | None | None |

### e3_variaciones_esquema

- Objetivo: Detectar columnas cuyo nombre exacto o tipo físico cambia entre archivos, o que no aparecen en todos los archivos de un tipo.
- Fuentes: data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/01_exploracion_parquet.sql
- Resultado: 2 filas y 6 columnas en 0.12 s
- Decisión: Las columnas con variaciones se leen con union_by_name, se comparan sin distinguir mayúsculas y se convierten a un tipo común en la vista normalizada.

```sql
WITH esquema AS (
    SELECT
        regexp_extract(file_name, '(yellow|green)_tripdata', 1) AS tipo_taxi,
        file_name,
        name AS columna,
        duckdb_type AS tipo
    FROM parquet_schema(['data/raw/yellow/2026/*.parquet', 'data/raw/green/2026/*.parquet'])
    WHERE name <> 'schema'
),
archivos AS (
    SELECT tipo_taxi, count(DISTINCT file_name) AS total_archivos
    FROM esquema
    GROUP BY ALL
)
SELECT
    e.tipo_taxi,
    lower(e.columna) AS columna,
    string_agg(DISTINCT e.columna, ', ' ORDER BY e.columna) AS nombres_exactos,
    string_agg(DISTINCT e.tipo, ', ' ORDER BY e.tipo) AS tipos,
    count(DISTINCT e.file_name) AS archivos_con_columna,
    a.total_archivos
FROM esquema e
JOIN archivos a USING (tipo_taxi)
GROUP BY e.tipo_taxi, lower(e.columna), a.total_archivos
HAVING count(DISTINCT e.columna) > 1
    OR count(DISTINCT e.tipo) > 1
    OR count(DISTINCT e.file_name) < a.total_archivos
ORDER BY e.tipo_taxi DESC, columna
```

| tipo_taxi | columna | nombres_exactos | tipos | archivos_con_columna | total_archivos |
| --- | --- | --- | --- | --- | --- |
| yellow | request_source | request_source | VARCHAR | 3 | 8 |
| green | request_source | request_source | VARCHAR | 3 | 8 |

### e3_muestra_amarillos

- Objetivo: Obtener una muestra aleatoria reproducible de registros de taxis amarillos.
- Fuentes: data/raw/yellow/2026/*.parquet
- Archivo SQL: sql/01_exploracion_parquet.sql
- Resultado: 8 filas y 21 columnas en 0.30 s
- Decisión: La muestra permite revisar el formato real de fechas, montos y códigos antes de definir reglas de calidad.

```sql
SELECT *
FROM read_parquet(['data/raw/yellow/2026/*.parquet'], union_by_name = true)
USING SAMPLE reservoir(8 ROWS) REPEATABLE (42)
```

| VendorID | tpep_pickup_datetime | tpep_dropoff_datetime | passenger_count | trip_distance | RatecodeID | store_and_fwd_flag | PULocationID | DOLocationID | payment_type | fare_amount | extra | mta_tax | tip_amount | tolls_amount | improvement_surcharge | total_amount | congestion_surcharge | Airport_fee | cbd_congestion_fee | request_source |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2 | 2026-01-01 00:24:41 | 2026-01-01 00:36:23 | 1 | 4.8 | 1 | N | 87 | 162 | 2 | 21.2 | 1 | 0.5 | 0 | 0 | 1 | 26.95 | 2.5 | 0 | 0.75 | None |
| 1 | 2026-01-01 02:08:35 | 2026-01-01 02:21:22 | 2 | 2.3 | 1 | N | 90 | 229 | 1 | 14.2 | 4.25 | 0.5 | 1.4 | 0 | 1 | 21.35 | 2.5 | 0 | 0.75 | None |
| 2 | 2026-01-01 02:01:56 | 2026-01-01 02:17:20 | 1 | 5.69 | 1 | N | 80 | 95 | 2 | 26.1 | 1 | 0.5 | 0 | 0 | 1 | 28.6 | 0 | 0 | 0 | None |
| 2 | 2026-01-01 04:36:54 | 2026-01-01 04:48:35 | 1 | 2.56 | 1 | N | 68 | 79 | 1 | 14.2 | 1 | 0.5 | 3.99 | 0 | 1 | 23.94 | 2.5 | 0 | 0.75 | None |
| 1 | 2026-01-01 09:37:17 | 2026-01-01 09:42:10 | 1 | 0.8 | 1 | N | 239 | 142 | 1 | 6.5 | 2.5 | 0.5 | 2.1 | 0 | 1 | 12.6 | 2.5 | 0 | 0 | None |
| 2 | 2026-01-01 11:29:34 | 2026-01-01 11:36:19 | 1 | 0.74 | 1 | N | 161 | 163 | 1 | 7.9 | 0 | 0.5 | 3.16 | 0 | 1 | 15.81 | 2.5 | 0 | 0.75 | None |
| 2 | 2026-01-01 11:42:55 | 2026-01-01 11:49:37 | 1 | 1.03 | 1 | N | 163 | 186 | 2 | 7.9 | 0 | 0.5 | 0 | 0 | 1 | 12.65 | 2.5 | 0 | 0.75 | None |
| 2 | 2026-01-01 13:36:51 | 2026-01-01 13:45:33 | 1 | 0.8 | 1 | N | 186 | 48 | 2 | 8.6 | 0 | 0.5 | 0 | 0 | 1 | 13.35 | 2.5 | 0 | 0.75 | None |

### e3_muestra_verdes

- Objetivo: Obtener una muestra aleatoria reproducible de registros de taxis verdes.
- Fuentes: data/raw/green/2026/*.parquet
- Archivo SQL: sql/01_exploracion_parquet.sql
- Resultado: 8 filas y 22 columnas en 0.14 s
- Decisión: Se confirma que los verdes comparten la mayoría de columnas con los amarillos, con nombres de fecha distintos.

```sql
SELECT *
FROM read_parquet(['data/raw/green/2026/*.parquet'], union_by_name = true)
USING SAMPLE reservoir(8 ROWS) REPEATABLE (42)
```

| VendorID | lpep_pickup_datetime | lpep_dropoff_datetime | store_and_fwd_flag | RatecodeID | PULocationID | DOLocationID | passenger_count | trip_distance | fare_amount | extra | mta_tax | tip_amount | tolls_amount | ehail_fee | improvement_surcharge | total_amount | payment_type | trip_type | congestion_surcharge | cbd_congestion_fee | request_source |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2 | 2026-01-03 17:06:05 | 2026-01-03 17:11:27 | N | 1 | 74 | 41 | 1 | 1.15 | 7.2 | 0 | 0.5 | 4 | 0 | nan | 1 | 12.7 | 1 | 1 | 0 | 0 | None |
| 2 | 2026-01-11 22:28:43 | 2026-01-11 22:32:53 | N | 1 | 74 | 42 | 2 | 0 | 5.8 | 1 | 0.5 | 1.66 | 0 | nan | 1 | 9.96 | 1 | 1 | 0 | 0 | None |
| 2 | 2026-01-13 18:36:59 | 2026-01-13 18:41:12 | N | 1 | 43 | 238 | 1 | 1.08 | 7.2 | 2.5 | 0.5 | 3.49 | 0 | nan | 1 | 17.44 | 1 | 1 | 2.75 | 0 | None |
| 2 | 2026-01-16 15:15:45 | 2026-01-16 15:43:34 | N | 1 | 244 | 233 | 1 | 9.39 | 38 | 0 | 0.5 | 0 | 0 | nan | 1 | 43 | 2 | 1 | 2.75 | 0.75 | None |
| 2 | 2026-01-20 15:12:55 | 2026-01-20 15:24:05 | N | 1 | 82 | 82 | 1 | 1.4 | 11.4 | 0 | 0.5 | 0 | 0 | nan | 1 | 12.9 | 2 | 1 | 0 | 0 | None |
| 2 | 2026-01-23 10:19:05 | 2026-01-23 10:37:24 | N | 1 | 74 | 238 | 1 | 3.02 | 18.4 | 0 | 0.5 | 4.53 | 0 | nan | 1 | 27.18 | 1 | 1 | 2.75 | 0 | None |
| 2 | 2026-01-24 15:40:48 | 2026-01-24 15:52:07 | N | 1 | 65 | 40 | 1 | 1.05 | 10.7 | 0 | 0.5 | 1.59 | 0 | nan | 1 | 13.79 | 1 | 1 | 0 | 0 | None |
| 2 | 2026-01-30 00:16:28 | 2026-01-30 00:23:47 | N | 1 | 75 | 238 | 1 | 1.36 | 9.3 | 1 | 0.5 | 1.77 | 0 | nan | 1 | 13.57 | 1 | 1 | 0 | 0 | None |

### e3_resumen_estadistico

- Objetivo: Obtener mínimos, máximos, promedios, cuartiles y porcentaje de nulos de cada columna de taxis amarillos con SUMMARIZE.
- Fuentes: data/raw/yellow/2026/*.parquet
- Archivo SQL: sql/01_exploracion_parquet.sql
- Resultado: 21 filas y 12 columnas en 28.90 s
- Decisión: Los extremos de distancia, montos y fechas indican valores imposibles que deben marcarse antes del análisis.

```sql
SUMMARIZE SELECT * FROM read_parquet(['data/raw/yellow/2026/*.parquet'], union_by_name = true)
```

| column_name | column_type | min | max | approx_unique | avg | std | q25 | q50 | q75 | count | null_percentage |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| VendorID | INTEGER | 1 | 7 | 4 | 1.885739809526567 | 0.7155277514022292 | 2 | 2 | 2 | 29703355 | 0 |
| tpep_pickup_datetime | TIMESTAMP | 2001-01-01 09:23:58 | 2026-08-31 23:59:59 | 16867928 | 2026-04-30 15:29:29.519432 | nan | 2026-03-03 03:21:46.663982 | 2026-05-01 07:46:38.347986 | 2026-06-26 01:43:36.126409 | 29703355 | 0 |
| tpep_dropoff_datetime | TIMESTAMP | 2001-01-01 16:09:38 | 2026-09-01 20:16:00 | 16587125 | 2026-04-30 15:47:08.186216 | nan | 2026-03-04 17:01:35.685536 | 2026-04-30 17:23:56.815865 | 2026-06-26 05:28:49.476139 | 29703355 | 0 |
| passenger_count | BIGINT | 0 | 9 | 11 | 1.2494318488564 | 0.6529195072996784 | 1 | 1 | 1 | 29703355 | 25.98 |
| trip_distance | DOUBLE | 0.0 | 328522.2 | 7217 | 5.55294014969123 | 550.6497893231015 | 1.022197829437098 | 1.8566666190531322 | 3.812071419057042 | 29703355 | 0 |
| RatecodeID | BIGINT | 1 | 99 | 7 | 4.527471444398553 | 18.000926540066864 | 1 | 1 | 1 | 29703355 | 25.98 |
| store_and_fwd_flag | VARCHAR | N | Y | 2 | nan | nan | nan | nan | nan | 29703355 | 25.98 |
| PULocationID | INTEGER | 1 | 265 | 290 | 161.57793013617484 | 66.74656703251749 | 117 | 161 | 233 | 29703355 | 0 |
| DOLocationID | INTEGER | 1 | 265 | 298 | 161.05139342003622 | 70.72548569211374 | 108 | 162 | 234 | 29703355 | 0 |
| payment_type | BIGINT | 0 | 5 | 6 | 0.8621735154160195 | 0.6463324345961866 | 0 | 1 | 1 | 29703355 | 0 |
| fare_amount | DOUBLE | -2555.2 | 7045.0 | 18028 | 21.2621287790636 | 18.958296845957697 | 10.007578677707947 | 15.826552485584818 | 26.49349238601903 | 29703355 | 0 |
| extra | DOUBLE | -7.5 | 244.35 | 360 | 1.1127003451293649 | 1.750691481670173 | 0.0 | 0.0 | 2.4995761854350067 | 29703355 | 0 |

### e3_calidad

- Objetivo: Cuantificar por tipo de taxi los principales problemas de calidad observables directamente en los archivos.
- Fuentes: data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/01_exploracion_parquet.sql
- Resultado: 2 filas y 13 columnas en 3.31 s
- Decisión: Cada problema se convierte en una regla de calidad de la vista viajes_calidad; los registros que la incumplen se excluyen del análisis pero se conservan y se cuentan.

```sql
WITH amarillos AS (
    SELECT
        'yellow' AS tipo_taxi, filename,
        tpep_pickup_datetime AS recogida, tpep_dropoff_datetime AS destino,
        passenger_count, trip_distance, fare_amount, total_amount, payment_type, RatecodeID, PULocationID
    FROM read_parquet(['data/raw/yellow/2026/*.parquet'], union_by_name = true, filename = true)
),
verdes AS (
    SELECT
        'green' AS tipo_taxi, filename,
        lpep_pickup_datetime AS recogida, lpep_dropoff_datetime AS destino,
        passenger_count, trip_distance, fare_amount, total_amount, payment_type, RatecodeID, PULocationID
    FROM read_parquet(['data/raw/green/2026/*.parquet'], union_by_name = true, filename = true)
),
todos AS (
    SELECT * FROM amarillos
    UNION ALL BY NAME
    SELECT * FROM verdes
)
SELECT
    tipo_taxi,
    count(*) AS registros,
    count(*) FILTER (WHERE strftime(recogida, '%Y-%m') <> regexp_extract(filename, '(\d{4}-\d{2})\.parquet$', 1)) AS fecha_fuera_del_mes,
    count(*) FILTER (WHERE destino <= recogida) AS destino_no_posterior,
    count(*) FILTER (WHERE date_diff('minute', recogida, destino) > 360) AS duracion_mayor_6h,
    count(*) FILTER (WHERE trip_distance <= 0) AS distancia_cero,
    count(*) FILTER (WHERE trip_distance > 200) AS distancia_mayor_200,
    count(*) FILTER (WHERE fare_amount < 0 OR total_amount < 0) AS montos_negativos,
    count(*) FILTER (WHERE passenger_count IS NULL) AS pasajeros_nulos,
    count(*) FILTER (WHERE passenger_count = 0) AS pasajeros_cero,
    count(*) FILTER (WHERE RatecodeID IS NULL OR RatecodeID = 99) AS tarifa_desconocida,
    count(*) FILTER (WHERE payment_type IS NULL OR payment_type IN (0, 5)) AS pago_sin_dato,
    count(*) FILTER (WHERE PULocationID IN (264, 265)) AS zona_desconocida
FROM todos
GROUP BY ALL
ORDER BY tipo_taxi DESC
```

| tipo_taxi | registros | fecha_fuera_del_mes | destino_no_posterior | duracion_mayor_6h | distancia_cero | distancia_mayor_200 | montos_negativos | pasajeros_nulos | pasajeros_cero | tarifa_desconocida | pago_sin_dato | zona_desconocida |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| yellow | 29703355 | 146 | 371683 | 7313 | 952231 | 704 | 161970 | 7716688 | 91359 | 8486381 | 7716690 | 49676 |
| green | 337114 | 98 | 234 | 1102 | 12212 | 69 | 1025 | 48775 | 4527 | 48777 | 48775 | 1131 |

### e3_rango_fechas

- Objetivo: Revisar las fechas mínima y máxima de recogida de cada archivo para detectar registros que no pertenecen al mes publicado.
- Fuentes: data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/01_exploracion_parquet.sql
- Resultado: 16 filas y 4 columnas en 1.63 s
- Decisión: El período de cada registro se toma del nombre del archivo y los viajes cuya fecha cae fuera de ese mes se marcan como inconsistentes.

```sql
WITH amarillos AS (
    SELECT filename, tpep_pickup_datetime AS recogida
    FROM read_parquet(['data/raw/yellow/2026/*.parquet'], union_by_name = true, filename = true)
),
verdes AS (
    SELECT filename, lpep_pickup_datetime AS recogida
    FROM read_parquet(['data/raw/green/2026/*.parquet'], union_by_name = true, filename = true)
)
SELECT
    regexp_extract(filename, '[^/\\]+$') AS archivo,
    min(recogida) AS primera_recogida,
    max(recogida) AS ultima_recogida,
    count(*) FILTER (WHERE strftime(recogida, '%Y-%m') <> regexp_extract(filename, '(\d{4}-\d{2})\.parquet$', 1)) AS fuera_del_mes
FROM (SELECT * FROM amarillos UNION ALL SELECT * FROM verdes)
GROUP BY ALL
ORDER BY archivo
```

| archivo | primera_recogida | ultima_recogida | fuera_del_mes |
| --- | --- | --- | --- |
| green_tripdata_2026-01.parquet | 2025-12-27 16:49:41 | 2026-02-01 21:08:36 | 22 |
| green_tripdata_2026-02.parquet | 2026-01-26 23:38:06 | 2026-03-01 09:48:53 | 11 |
| green_tripdata_2026-03.parquet | 2009-01-01 01:35:31 | 2026-03-31 23:57:29 | 9 |
| green_tripdata_2026-04.parquet | 2026-03-31 23:28:50 | 2026-05-01 07:53:18 | 3 |
| green_tripdata_2026-05.parquet | 2008-12-31 23:05:50 | 2026-05-31 23:59:13 | 10 |
| green_tripdata_2026-06.parquet | 2026-05-26 19:47:06 | 2026-07-01 03:21:24 | 13 |
| green_tripdata_2026-07.parquet | 2008-12-31 17:35:31 | 2026-08-01 14:36:42 | 16 |
| green_tripdata_2026-08.parquet | 2008-12-31 23:06:23 | 2026-08-31 23:58:28 | 14 |
| yellow_tripdata_2026-01.parquet | 2025-12-31 23:57:29 | 2026-02-01 00:45:01 | 7 |
| yellow_tripdata_2026-02.parquet | 2026-01-31 23:31:23 | 2026-03-01 00:51:48 | 16 |
| yellow_tripdata_2026-03.parquet | 2008-12-31 23:03:20 | 2026-04-01 00:06:25 | 19 |
| yellow_tripdata_2026-04.parquet | 2001-01-01 09:23:58 | 2026-05-01 00:01:28 | 12 |

### e3_codigos_pago

- Objetivo: Revisar los códigos de tipo de pago presentes en los archivos y su frecuencia.
- Fuentes: data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/01_exploracion_parquet.sql
- Resultado: 11 filas y 4 columnas en 0.42 s
- Decisión: Los códigos se traducen con el diccionario de la TLC; el código 0 y los nulos se tratan como pago sin registro y no como error.

```sql
WITH pagos AS (
    SELECT regexp_extract(filename, '(yellow|green)_tripdata', 1) AS tipo_taxi, payment_type AS codigo_pago
    FROM read_parquet(['data/raw/yellow/2026/*.parquet', 'data/raw/green/2026/*.parquet'], union_by_name = true, filename = true)
)
SELECT
    tipo_taxi,
    codigo_pago,
    count(*) AS registros,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS porcentaje
FROM pagos
GROUP BY tipo_taxi, codigo_pago
ORDER BY tipo_taxi DESC, codigo_pago
```

| tipo_taxi | codigo_pago | registros | porcentaje |
| --- | --- | --- | --- |
| yellow | 0 | 7716688 | 25.98 |
| yellow | 1 | 18941008 | 63.77 |
| yellow | 2 | 2708031 | 9.12 |
| yellow | 3 | 98138 | 0.33 |
| yellow | 4 | 239488 | 0.81 |
| yellow | 5 | 2 | 0 |
| green | 1 | 219980 | 65.25 |
| green | 2 | 65921 | 19.55 |
| green | 3 | 1688 | 0.5 |
| green | 4 | 750 | 0.22 |
| green | <NA> | 48775 | 14.47 |

## Ejercicio 4

### e4_calidad_exclusiones

- Objetivo: Pregunta 1. Qué proporción de registros incumple alguna regla de calidad y por qué motivo, en cada tipo de taxi.
- Fuentes: vista viajes_calidad, data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 17 filas y 4 columnas en 3.80 s
- Decisión: Si las exclusiones son una fracción pequeña del total, el análisis sobre viajes válidos representa bien al conjunto; los motivos dominantes se reportan como limitaciones.

```sql
SELECT
    tipo_taxi,
    coalesce(motivo_exclusion, 'Válido') AS clasificacion,
    count(*) AS registros,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 3) AS porcentaje
FROM viajes_calidad
GROUP BY tipo_taxi, clasificacion
ORDER BY tipo_taxi DESC, registros DESC
```

| tipo_taxi | clasificacion | registros | porcentaje |
| --- | --- | --- | --- |
| yellow | Válido | 28229225 | 95.04 |
| yellow | Distancia cero | 940717 | 3.167 |
| yellow | Duración nula o negativa | 371682 | 1.251 |
| yellow | Monto negativo o ajuste | 146227 | 0.492 |
| yellow | Velocidad mayor a 80 mph | 7342 | 0.025 |
| yellow | Duración mayor a 6 horas | 7309 | 0.025 |
| yellow | Distancia mayor a 200 millas | 698 | 0.002 |
| yellow | Fecha fuera del mes del archivo | 146 | 0 |
| yellow | Total mayor a 1000 dólares | 9 | 0 |
| green | Válido | 322011 | 95.52 |
| green | Distancia cero | 11962 | 3.548 |
| green | Duración mayor a 6 horas | 1096 | 0.325 |

### e4_viajes_mensuales

- Objetivo: Pregunta 2. Cómo evoluciona el número de viajes y el ingreso de cada mes por tipo de taxi.
- Fuentes: vista viajes_validos
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 16 filas y 7 columnas en 4.73 s
- Decisión: Los meses con menos días o con eventos particulares se comparan con viajes promedio por día y no solo con el total mensual.

```sql
SELECT
    tipo_taxi,
    anio_archivo AS anio,
    mes_archivo AS mes,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 0) AS viajes_por_dia,
    round(sum(total) / 1e6, 3) AS ingreso_millones,
    round(avg(total), 2) AS total_promedio
FROM viajes_validos
GROUP BY ALL
ORDER BY tipo_taxi DESC, anio, mes
```

| tipo_taxi | anio | mes | viajes | viajes_por_dia | ingreso_millones | total_promedio |
| --- | --- | --- | --- | --- | --- | --- |
| yellow | 2026 | 1 | 3516139 | 113,424 | 104.3 | 29.67 |
| yellow | 2026 | 2 | 3210025 | 114,644 | 97.75 | 30.45 |
| yellow | 2026 | 3 | 3762447 | 121,369 | 113.9 | 30.26 |
| yellow | 2026 | 4 | 3673823 | 122,461 | 110.6 | 30.1 |
| yellow | 2026 | 5 | 3911803 | 126,187 | 119.5 | 30.55 |
| yellow | 2026 | 6 | 3646098 | 121,537 | 111.6 | 30.6 |
| yellow | 2026 | 7 | 3345768 | 107,928 | 100.8 | 30.14 |
| yellow | 2026 | 8 | 3163122 | 102,036 | 95.4 | 30.16 |
| green | 2026 | 1 | 38633 | 1,246 | 0.935 | 24.21 |
| green | 2026 | 2 | 35650 | 1,273 | 0.867 | 24.32 |
| green | 2026 | 3 | 42373 | 1,367 | 1.053 | 24.85 |
| green | 2026 | 4 | 42224 | 1,407 | 1.068 | 25.29 |

### e4_patron_horario

- Objetivo: Pregunta 3. En qué horas y tipo de día se concentra la demanda y cómo cambia la velocidad del tráfico.
- Fuentes: vista viajes_validos
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 48 filas y 6 columnas en 6.30 s
- Decisión: El promedio diario por hora permite comparar entre semana y fin de semana aunque tengan distinto número de días.

```sql
SELECT
    tipo_dia,
    hora,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 1) AS viajes_por_dia,
    round(median(duracion_min), 1) AS duracion_mediana_min,
    round(median(velocidad_mph), 1) AS velocidad_mediana_mph
FROM viajes_validos
GROUP BY ALL
ORDER BY tipo_dia, hora
```

| tipo_dia | hora | viajes | viajes_por_dia | duracion_mediana_min | velocidad_mediana_mph |
| --- | --- | --- | --- | --- | --- |
| Entre semana | 0 | 427696 | 2,472 | 13.7 | 13.4 |
| Entre semana | 1 | 224679 | 1,299 | 13.1 | 14.3 |
| Entre semana | 2 | 127770 | 738.6 | 12.7 | 14.9 |
| Entre semana | 3 | 89083 | 514.9 | 13.3 | 15.5 |
| Entre semana | 4 | 103849 | 600.3 | 14.6 | 16.8 |
| Entre semana | 5 | 194679 | 1,125 | 13.4 | 15.8 |
| Entre semana | 6 | 409718 | 2,368 | 12.8 | 13.3 |
| Entre semana | 7 | 757335 | 4,378 | 13.2 | 10.6 |
| Entre semana | 8 | 1002941 | 5,797 | 14.6 | 8.8 |
| Entre semana | 9 | 971601 | 5,616 | 14.9 | 8.1 |
| Entre semana | 10 | 917898 | 5,306 | 15.4 | 7.7 |
| Entre semana | 11 | 954093 | 5,515 | 15.9 | 7.4 |

### e4_caracteristicas_tipo

- Objetivo: Pregunta 4. En qué se diferencian los viajes de taxis amarillos y verdes en distancia, duración, pasajeros y monto.
- Fuentes: vista viajes_validos
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 2 filas y 12 columnas en 14.30 s
- Decisión: Se reportan medianas y percentiles porque las distribuciones de distancia y monto son asimétricas y el promedio se ve arrastrado por los viajes largos.

```sql
SELECT
    tipo_taxi,
    count(*) AS viajes,
    round(avg(pasajeros), 2) AS pasajeros_promedio,
    round(quantile_cont(distancia_millas, 0.25), 2) AS distancia_p25,
    round(median(distancia_millas), 2) AS distancia_mediana,
    round(quantile_cont(distancia_millas, 0.75), 2) AS distancia_p75,
    round(quantile_cont(distancia_millas, 0.99), 2) AS distancia_p99,
    round(median(duracion_min), 1) AS duracion_mediana,
    round(quantile_cont(duracion_min, 0.99), 1) AS duracion_p99,
    round(median(total), 2) AS total_mediano,
    round(quantile_cont(total, 0.99), 2) AS total_p99,
    round(100.0 * count(*) FILTER (WHERE aeropuerto <> 'Sin aeropuerto') / count(*), 2) AS pct_aeropuerto
FROM viajes_validos
GROUP BY ALL
ORDER BY tipo_taxi DESC
```

| tipo_taxi | viajes | pasajeros_promedio | distancia_p25 | distancia_mediana | distancia_p75 | distancia_p99 | duracion_mediana | duracion_p99 | total_mediano | total_p99 | pct_aeropuerto |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| yellow | 28229225 | 1.25 | 1.1 | 1.93 | 3.95 | 19.52 | 14.1 | 71.3 | 23.58 | 105 | 8.16 |
| green | 322011 | 1.3 | 1.33 | 2.15 | 3.77 | 17.73 | 13.4 | 75.1 | 20.52 | 94.75 | 3.35 |

### e4_distribucion_distancia

- Objetivo: Pregunta 5. Cómo se distribuyen las distancias de los viajes en intervalos de una milla por tipo de taxi.
- Fuentes: vista viajes_validos
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 62 filas y 4 columnas en 4.71 s
- Decisión: La distribución por intervalos permite ver la cola de viajes largos que el resumen estadístico solo insinúa.

```sql
SELECT
    tipo_taxi,
    least(floor(distancia_millas), 30) AS millas,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 3) AS porcentaje
FROM viajes_validos
GROUP BY tipo_taxi, millas
ORDER BY tipo_taxi DESC, millas
```

| tipo_taxi | millas | viajes | porcentaje |
| --- | --- | --- | --- |
| yellow | 0 | 5918338 | 20.96 |
| yellow | 1 | 8535546 | 30.24 |
| yellow | 2 | 4442625 | 15.74 |
| yellow | 3 | 2339601 | 8.288 |
| yellow | 4 | 1442776 | 5.111 |
| yellow | 5 | 1003746 | 3.556 |
| yellow | 6 | 746043 | 2.643 |
| yellow | 7 | 586762 | 2.079 |
| yellow | 8 | 551532 | 1.954 |
| yellow | 9 | 498234 | 1.765 |
| yellow | 10 | 383242 | 1.358 |
| yellow | 11 | 269469 | 0.955 |

### e4_zonas_origen

- Objetivo: Pregunta 7. Desde qué zonas y distritos sale la mayor parte de los viajes de cada tipo de taxi.
- Fuentes: vista viajes_validos y tabla zonas
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 20 filas y 6 columnas en 6.31 s
- Decisión: Se comparan las diez zonas principales de cada tipo para verificar la separación geográfica de los servicios.

```sql
SELECT *
FROM (
    SELECT
        tipo_taxi,
        nombre_origen AS zona,
        distrito_origen AS distrito,
        count(*) AS viajes,
        round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS porcentaje,
        row_number() OVER (PARTITION BY tipo_taxi ORDER BY count(*) DESC) AS posicion
    FROM viajes_validos
    GROUP BY tipo_taxi, nombre_origen, distrito_origen
)
WHERE posicion <= 10
ORDER BY tipo_taxi DESC, posicion
```

| tipo_taxi | zona | distrito | viajes | porcentaje | posicion |
| --- | --- | --- | --- | --- | --- |
| yellow | Upper East Side South | Manhattan | 1252825 | 4.44 | 1 |
| yellow | Midtown Center | Manhattan | 1171647 | 4.15 | 2 |
| yellow | JFK Airport | Queens | 1125139 | 3.99 | 3 |
| yellow | Upper East Side North | Manhattan | 1113246 | 3.94 | 4 |
| yellow | Penn Station/Madison Sq West | Manhattan | 868652 | 3.08 | 5 |
| yellow | Midtown East | Manhattan | 864634 | 3.06 | 6 |
| yellow | Times Sq/Theatre District | Manhattan | 817475 | 2.9 | 7 |
| yellow | Lincoln Square East | Manhattan | 811726 | 2.88 | 8 |
| yellow | East Village | Manhattan | 756371 | 2.68 | 9 |
| yellow | Murray Hill | Manhattan | 737674 | 2.61 | 10 |
| green | East Harlem North | Manhattan | 87010 | 27.02 | 1 |
| green | East Harlem South | Manhattan | 41865 | 13 | 2 |

### e4_aeropuertos

- Objetivo: Pregunta 8. Cuánto pesan los viajes de aeropuerto y en qué se diferencian del resto.
- Fuentes: vista viajes_validos
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 8 filas y 7 columnas en 8.09 s
- Decisión: Los viajes de aeropuerto se analizan aparte porque tienen tarifa fija o recargos propios y elevan los promedios generales.

```sql
SELECT
    tipo_taxi,
    aeropuerto,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS porcentaje,
    round(median(distancia_millas), 2) AS distancia_mediana,
    round(median(duracion_min), 1) AS duracion_mediana,
    round(median(total), 2) AS total_mediano
FROM viajes_validos
GROUP BY tipo_taxi, aeropuerto
ORDER BY tipo_taxi DESC, viajes DESC
```

| tipo_taxi | aeropuerto | viajes | porcentaje | distancia_mediana | duracion_mediana | total_mediano |
| --- | --- | --- | --- | --- | --- | --- |
| yellow | Sin aeropuerto | 25924583 | 91.84 | 1.78 | 13.3 | 22.45 |
| yellow | JFK | 1313827 | 4.65 | 16.9 | 41.5 | 89.21 |
| yellow | LaGuardia | 942200 | 3.34 | 9.5 | 28.9 | 69.96 |
| yellow | Newark | 48615 | 0.17 | 17.31 | 37.2 | 131.7 |
| green | Sin aeropuerto | 311237 | 96.65 | 2.08 | 13.3 | 20.1 |
| green | LaGuardia | 8349 | 2.59 | 3.98 | 13.2 | 33.72 |
| green | JFK | 2263 | 0.7 | 14.25 | 38 | 73.2 |
| green | Newark | 162 | 0.05 | 21.87 | 44 | 145.8 |

### e4_pago_propina

- Objetivo: Pregunta 6. Cómo se reparten los métodos de pago y qué porcentaje de propina se registra en cada uno.
- Fuentes: vista viajes_validos
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 10 filas y 7 columnas en 6.06 s
- Decisión: La TLC solo registra propinas pagadas con tarjeta, por lo que el porcentaje de propina se calcula sobre pagos con tarjeta.

```sql
SELECT
    tipo_taxi,
    metodo_pago,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS porcentaje_viajes,
    round(avg(total), 2) AS total_promedio,
    round(100.0 * count(*) FILTER (WHERE propina > 0) / count(*), 2) AS pct_con_propina,
    round(median(100.0 * propina / nullif(tarifa, 0)), 2) AS propina_mediana_pct
FROM viajes_validos
GROUP BY tipo_taxi, metodo_pago
ORDER BY tipo_taxi DESC, viajes DESC
```

| tipo_taxi | metodo_pago | viajes | porcentaje_viajes | total_promedio | pct_con_propina | propina_mediana_pct |
| --- | --- | --- | --- | --- | --- | --- |
| yellow | Tarjeta de crédito | 18453112 | 65.37 | 30.02 | 91.13 | 26.38 |
| yellow | Sin registro | 7042056 | 24.95 | 32.44 | 8.26 | 0 |
| yellow | Efectivo | 2558820 | 9.06 | 26.02 | 0.01 | 0 |
| yellow | Disputa | 118822 | 0.42 | 28.65 | 0.03 | 0 |
| yellow | Sin cargo | 56415 | 0.2 | 24.24 | 0.02 | 0 |
| green | Tarjeta de crédito | 210959 | 65.51 | 25.58 | 91.49 | 23.55 |
| green | Efectivo | 62482 | 19.4 | 20.8 | 0 | 0 |
| green | Sin registro | 47617 | 14.79 | 30.67 | 15.46 | 0 |
| green | Sin cargo | 667 | 0.21 | 17.03 | 0.3 | 0 |
| green | Disputa | 286 | 0.09 | 17.92 | 0 | 0 |

### e4_atipicos_tarifa

- Objetivo: Pregunta 9. Qué viajes válidos tienen una tarifa por milla atípica según el criterio de rango intercuartílico.
- Fuentes: vista viajes_validos
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 2 filas y 8 columnas en 10.40 s
- Decisión: Los viajes fuera del rango intercuartílico no se eliminan porque pueden ser legítimos, como tarifas negociadas o viajes muy cortos; se reporta su proporción.

```sql
WITH tarifas AS (
    SELECT tipo_taxi, tarifa / distancia_millas AS tarifa_por_milla
    FROM viajes_validos
    WHERE distancia_millas >= 0.1
),
limites AS (
    SELECT
        tipo_taxi,
        quantile_cont(tarifa_por_milla, 0.25) AS q1,
        quantile_cont(tarifa_por_milla, 0.75) AS q3
    FROM tarifas
    GROUP BY ALL
)
SELECT
    t.tipo_taxi,
    round(l.q1, 2) AS q1,
    round(l.q3, 2) AS q3,
    round(l.q3 + 1.5 * (l.q3 - l.q1), 2) AS limite_superior,
    count(*) AS viajes,
    count(*) FILTER (WHERE t.tarifa_por_milla > l.q3 + 1.5 * (l.q3 - l.q1)) AS atipicos_altos,
    count(*) FILTER (WHERE t.tarifa_por_milla < l.q1 - 1.5 * (l.q3 - l.q1)) AS atipicos_bajos,
    round(100.0 * count(*) FILTER (WHERE t.tarifa_por_milla > l.q3 + 1.5 * (l.q3 - l.q1)
                                     OR t.tarifa_por_milla < l.q1 - 1.5 * (l.q3 - l.q1)) / count(*), 2) AS pct_atipicos
FROM tarifas t
JOIN limites l USING (tipo_taxi)
GROUP BY ALL
ORDER BY t.tipo_taxi DESC
```

| tipo_taxi | q1 | q3 | limite_superior | viajes | atipicos_altos | atipicos_bajos | pct_atipicos |
| --- | --- | --- | --- | --- | --- | --- | --- |
| yellow | 5.71 | 9.87 | 16.11 | 28005034 | 1450189 | 0 | 5.18 |
| green | 5.33 | 8.13 | 12.34 | 319401 | 14419 | 28201 | 13.34 |

## Ejercicio 5

### val_cobertura_anual

- Objetivo: Verificar por año y tipo de taxi cuántos archivos, meses y registros cubre la vista conjunta y su rango de fechas.
- Fuentes: vista viajes sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/03_incorporacion.sql
- Resultado: 4 filas y 7 columnas en 2.07 s
- Decisión: Cada año incorporado debe aparecer con todos sus meses publicados sin alterar los conteos de los años que ya existían.

```sql
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    count(DISTINCT archivo) AS archivos,
    count(DISTINCT mes_archivo) AS meses,
    count(*) AS registros,
    min(fecha_recogida) FILTER (WHERE year(fecha_recogida) = anio_archivo) AS primera_recogida,
    max(fecha_recogida) FILTER (WHERE year(fecha_recogida) = anio_archivo) AS ultima_recogida
FROM viajes
GROUP BY ALL
ORDER BY anio, tipo_taxi DESC
```

| anio | tipo_taxi | archivos | meses | registros | primera_recogida | ultima_recogida |
| --- | --- | --- | --- | --- | --- | --- |
| 2024 | yellow | 12 | 12 | 41169720 | 2024-01-01 00:00:00 | 2024-12-31 23:59:58 |
| 2024 | green | 12 | 12 | 660218 | 2024-01-01 00:03:57 | 2024-12-31 23:58:02 |
| 2026 | yellow | 8 | 8 | 29703355 | 2026-01-01 00:00:00 | 2026-08-31 23:59:59 |
| 2026 | green | 8 | 8 | 337114 | 2026-01-01 00:03:27 | 2026-08-31 23:58:28 |

### val_conteo_por_archivo

- Objetivo: Comparar archivo por archivo los registros que lee la vista conjunta con los registros declarados en los metadatos Parquet.
- Fuentes: data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/03_incorporacion.sql
- Resultado: 1 filas y 4 columnas en 0.44 s
- Decisión: Una diferencia distinta de cero indicaría que la unión de esquemas pierde o duplica filas; el resultado esperado es cero diferencias.

```sql
WITH metadatos AS (
    SELECT regexp_extract(file_name, '[^/\\]+$') AS archivo, num_rows AS registros_metadatos
    FROM parquet_file_metadata(['data/raw/yellow/2024/*.parquet', 'data/raw/yellow/2026/*.parquet', 'data/raw/green/2024/*.parquet', 'data/raw/green/2026/*.parquet'])
),
lectura AS (
    SELECT archivo, count(*) AS registros_vista
    FROM viajes
    GROUP BY ALL
)
SELECT
    count(*) AS archivos,
    CAST(sum(registros_metadatos) AS BIGINT) AS registros_metadatos,
    CAST(sum(registros_vista) AS BIGINT) AS registros_vista,
    count(*) FILTER (WHERE registros_vista IS DISTINCT FROM registros_metadatos) AS archivos_con_diferencia
FROM metadatos
FULL JOIN lectura USING (archivo)
```

| archivos | registros_metadatos | registros_vista | archivos_con_diferencia |
| --- | --- | --- | --- |
| 40 | 71870407 | 71870407 | 0 |

### val_esquema_por_anio

- Objetivo: Identificar columnas que existen solo en algunos años o cuyo tipo físico cambia de un año a otro.
- Fuentes: data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/03_incorporacion.sql
- Resultado: 4 filas y 4 columnas en 0.10 s
- Decisión: Las columnas nuevas o con otro tipo se resuelven en la vista normalizada, que rellena con nulos y convierte a un tipo común, por lo que las consultas de análisis no cambian.

```sql
WITH esquema AS (
    SELECT
        regexp_extract(file_name, '(yellow|green)_tripdata', 1) AS tipo_taxi,
        CAST(regexp_extract(file_name, '(\d{4})-\d{2}\.parquet$', 1) AS INTEGER) AS anio,
        lower(name) AS columna,
        duckdb_type AS tipo
    FROM parquet_schema(['data/raw/yellow/2024/*.parquet', 'data/raw/yellow/2026/*.parquet', 'data/raw/green/2024/*.parquet', 'data/raw/green/2026/*.parquet'])
    WHERE name <> 'schema'
),
por_columna AS (
    SELECT
        tipo_taxi,
        columna,
        string_agg(DISTINCT CAST(anio AS VARCHAR), ', ' ORDER BY CAST(anio AS VARCHAR)) AS anios_presente,
        string_agg(DISTINCT anio || ' ' || tipo, ', ' ORDER BY anio || ' ' || tipo) AS tipos_por_anio,
        count(DISTINCT anio) AS n_anios,
        count(DISTINCT tipo) AS n_tipos
    FROM esquema
    GROUP BY ALL
)
SELECT tipo_taxi, columna, anios_presente, tipos_por_anio
FROM por_columna
WHERE n_anios < (SELECT count(DISTINCT anio) FROM esquema) OR n_tipos > 1
ORDER BY tipo_taxi DESC, columna
```

| tipo_taxi | columna | anios_presente | tipos_por_anio |
| --- | --- | --- | --- |
| yellow | cbd_congestion_fee | 2026 | 2026 DOUBLE |
| yellow | request_source | 2026 | 2026 VARCHAR |
| green | cbd_congestion_fee | 2026 | 2026 DOUBLE |
| green | request_source | 2026 | 2026 VARCHAR |

### val_meses_comparables

- Objetivo: Comparar los mismos meses entre años para validar que la consulta conjunta produce series comparables.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/03_incorporacion.sql
- Resultado: 32 filas y 5 columnas en 9.02 s
- Decisión: Solo se comparan meses disponibles en todos los años para que las diferencias no se deban a meses faltantes.

```sql
WITH mensual AS (
    SELECT anio_archivo AS anio, mes_archivo AS mes, tipo_taxi, count(*) AS viajes
    FROM viajes_validos
    GROUP BY ALL
),
comunes AS (
    SELECT mes
    FROM mensual
    GROUP BY mes
    HAVING count(DISTINCT anio) = (SELECT count(DISTINCT anio) FROM mensual)
)
SELECT
    tipo_taxi,
    mes,
    anio,
    viajes,
    round(100.0 * (viajes / first_value(viajes) OVER (PARTITION BY tipo_taxi, mes ORDER BY anio) - 1), 2) AS cambio_pct_vs_primer_anio
FROM mensual
WHERE mes IN (SELECT mes FROM comunes)
ORDER BY tipo_taxi DESC, mes, anio
```

| tipo_taxi | mes | anio | viajes | cambio_pct_vs_primer_anio |
| --- | --- | --- | --- | --- |
| yellow | 1 | 2024 | 2867133 | 0 |
| yellow | 1 | 2026 | 3516139 | 22.64 |
| yellow | 2 | 2024 | 2899130 | 0 |
| yellow | 2 | 2026 | 3210025 | 10.72 |
| yellow | 3 | 2024 | 3437442 | 0 |
| yellow | 3 | 2026 | 3762447 | 9.45 |
| yellow | 4 | 2024 | 3411726 | 0 |
| yellow | 4 | 2026 | 3673823 | 7.68 |
| yellow | 5 | 2024 | 3615186 | 0 |
| yellow | 5 | 2026 | 3911803 | 8.2 |
| yellow | 6 | 2024 | 3425728 | 0 |
| yellow | 6 | 2026 | 3646098 | 6.43 |

### e4_calidad_exclusiones en el ejercicio 5

- Objetivo: Pregunta 1. Qué proporción de registros incumple alguna regla de calidad y por qué motivo, en cada tipo de taxi.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 17 filas y 4 columnas en 7.85 s
- Decisión: Si las exclusiones son una fracción pequeña del total, el análisis sobre viajes válidos representa bien al conjunto; los motivos dominantes se reportan como limitaciones.

```sql
SELECT
    tipo_taxi,
    coalesce(motivo_exclusion, 'Válido') AS clasificacion,
    count(*) AS registros,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 3) AS porcentaje
FROM viajes_calidad
GROUP BY tipo_taxi, clasificacion
ORDER BY tipo_taxi DESC, registros DESC
```

| tipo_taxi | clasificacion | registros | porcentaje |
| --- | --- | --- | --- |
| yellow | Válido | 67907499 | 95.82 |
| yellow | Distancia cero | 1705542 | 2.406 |
| yellow | Monto negativo o ajuste | 823599 | 1.162 |
| yellow | Duración nula o negativa | 385192 | 0.543 |
| yellow | Duración mayor a 6 horas | 29303 | 0.041 |
| yellow | Velocidad mayor a 80 mph | 19529 | 0.028 |
| yellow | Distancia mayor a 200 millas | 1820 | 0.003 |
| yellow | Fecha fuera del mes del archivo | 566 | 0.001 |
| yellow | Total mayor a 1000 dólares | 25 | 0 |
| green | Válido | 941376 | 94.39 |
| green | Distancia cero | 45892 | 4.601 |
| green | Duración mayor a 6 horas | 3723 | 0.373 |

### e4_viajes_mensuales en el ejercicio 5

- Objetivo: Pregunta 2. Cómo evoluciona el número de viajes y el ingreso de cada mes por tipo de taxi.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 40 filas y 7 columnas en 9.90 s
- Decisión: Los meses con menos días o con eventos particulares se comparan con viajes promedio por día y no solo con el total mensual.

```sql
SELECT
    tipo_taxi,
    anio_archivo AS anio,
    mes_archivo AS mes,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 0) AS viajes_por_dia,
    round(sum(total) / 1e6, 3) AS ingreso_millones,
    round(avg(total), 2) AS total_promedio
FROM viajes_validos
GROUP BY ALL
ORDER BY tipo_taxi DESC, anio, mes
```

| tipo_taxi | anio | mes | viajes | viajes_por_dia | ingreso_millones | total_promedio |
| --- | --- | --- | --- | --- | --- | --- |
| yellow | 2024 | 1 | 2867133 | 92,488 | 78.37 | 27.33 |
| yellow | 2024 | 2 | 2899130 | 99,970 | 78.94 | 27.23 |
| yellow | 2024 | 3 | 3437442 | 110,885 | 95.73 | 27.85 |
| yellow | 2024 | 4 | 3411726 | 113,724 | 96.14 | 28.18 |
| yellow | 2024 | 5 | 3615186 | 116,619 | 104.8 | 28.99 |
| yellow | 2024 | 6 | 3425728 | 114,191 | 98.25 | 28.68 |
| yellow | 2024 | 7 | 2971467 | 95,854 | 86.09 | 28.97 |
| yellow | 2024 | 8 | 2864961 | 92,418 | 83.71 | 29.22 |
| yellow | 2024 | 9 | 3481642 | 116,055 | 102.6 | 29.48 |
| yellow | 2024 | 10 | 3679557 | 118,695 | 108.1 | 29.38 |
| yellow | 2024 | 11 | 3507658 | 116,922 | 99.89 | 28.48 |
| yellow | 2024 | 12 | 3516644 | 113,440 | 103.3 | 29.37 |

### e4_patron_horario en el ejercicio 5

- Objetivo: Pregunta 3. En qué horas y tipo de día se concentra la demanda y cómo cambia la velocidad del tráfico.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 48 filas y 6 columnas en 16.30 s
- Decisión: El promedio diario por hora permite comparar entre semana y fin de semana aunque tengan distinto número de días.

```sql
SELECT
    tipo_dia,
    hora,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 1) AS viajes_por_dia,
    round(median(duracion_min), 1) AS duracion_mediana_min,
    round(median(velocidad_mph), 1) AS velocidad_mediana_mph
FROM viajes_validos
GROUP BY ALL
ORDER BY tipo_dia, hora
```

| tipo_dia | hora | viajes | viajes_por_dia | duracion_mediana_min | velocidad_mediana_mph |
| --- | --- | --- | --- | --- | --- |
| Entre semana | 0 | 971730 | 2,234 | 12.7 | 13.4 |
| Entre semana | 1 | 485084 | 1,115 | 11.8 | 14.2 |
| Entre semana | 2 | 268916 | 618.2 | 11.3 | 14.5 |
| Entre semana | 3 | 182498 | 419.5 | 11.9 | 15.3 |
| Entre semana | 4 | 206147 | 473.9 | 14 | 17 |
| Entre semana | 5 | 387057 | 889.8 | 12.6 | 15.9 |
| Entre semana | 6 | 885692 | 2,036 | 11.4 | 13.4 |
| Entre semana | 7 | 1735341 | 3,989 | 12.1 | 10.7 |
| Entre semana | 8 | 2327570 | 5,351 | 13.6 | 8.8 |
| Entre semana | 9 | 2319345 | 5,332 | 14.1 | 8.2 |
| Entre semana | 10 | 2267762 | 5,213 | 14.6 | 7.8 |
| Entre semana | 11 | 2373218 | 5,456 | 15.1 | 7.5 |

### e4_caracteristicas_tipo en el ejercicio 5

- Objetivo: Pregunta 4. En qué se diferencian los viajes de taxis amarillos y verdes en distancia, duración, pasajeros y monto.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 2 filas y 12 columnas en 35.62 s
- Decisión: Se reportan medianas y percentiles porque las distribuciones de distancia y monto son asimétricas y el promedio se ve arrastrado por los viajes largos.

```sql
SELECT
    tipo_taxi,
    count(*) AS viajes,
    round(avg(pasajeros), 2) AS pasajeros_promedio,
    round(quantile_cont(distancia_millas, 0.25), 2) AS distancia_p25,
    round(median(distancia_millas), 2) AS distancia_mediana,
    round(quantile_cont(distancia_millas, 0.75), 2) AS distancia_p75,
    round(quantile_cont(distancia_millas, 0.99), 2) AS distancia_p99,
    round(median(duracion_min), 1) AS duracion_mediana,
    round(quantile_cont(duracion_min, 0.99), 1) AS duracion_p99,
    round(median(total), 2) AS total_mediano,
    round(quantile_cont(total, 0.99), 2) AS total_p99,
    round(100.0 * count(*) FILTER (WHERE aeropuerto <> 'Sin aeropuerto') / count(*), 2) AS pct_aeropuerto
FROM viajes_validos
GROUP BY ALL
ORDER BY tipo_taxi DESC
```

| tipo_taxi | viajes | pasajeros_promedio | distancia_p25 | distancia_mediana | distancia_p75 | distancia_p99 | duracion_mediana | duracion_p99 | total_mediano | total_p99 | pct_aeropuerto |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| yellow | 67907499 | 1.3 | 1.08 | 1.85 | 3.62 | 19.87 | 13.5 | 70.7 | 22.2 | 104.9 | 9.3 |
| green | 941376 | 1.32 | 1.28 | 2.02 | 3.54 | 17.01 | 12.4 | 65.2 | 19.68 | 94.5 | 3.91 |

### e4_distribucion_distancia en el ejercicio 5

- Objetivo: Pregunta 5. Cómo se distribuyen las distancias de los viajes en intervalos de una milla por tipo de taxi.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 62 filas y 4 columnas en 12.37 s
- Decisión: La distribución por intervalos permite ver la cola de viajes largos que el resumen estadístico solo insinúa.

```sql
SELECT
    tipo_taxi,
    least(floor(distancia_millas), 30) AS millas,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 3) AS porcentaje
FROM viajes_validos
GROUP BY tipo_taxi, millas
ORDER BY tipo_taxi DESC, millas
```

| tipo_taxi | millas | viajes | porcentaje |
| --- | --- | --- | --- |
| yellow | 0 | 14613378 | 21.52 |
| yellow | 1 | 21612479 | 31.83 |
| yellow | 2 | 10868026 | 16 |
| yellow | 3 | 5365660 | 7.901 |
| yellow | 4 | 3052582 | 4.495 |
| yellow | 5 | 2037849 | 3.001 |
| yellow | 6 | 1475724 | 2.173 |
| yellow | 7 | 1152269 | 1.697 |
| yellow | 8 | 1165774 | 1.717 |
| yellow | 9 | 1136030 | 1.673 |
| yellow | 10 | 892343 | 1.314 |
| yellow | 11 | 629210 | 0.927 |

### e4_pago_propina en el ejercicio 5

- Objetivo: Pregunta 6. Cómo se reparten los métodos de pago y qué porcentaje de propina se registra en cada uno.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 10 filas y 7 columnas en 17.58 s
- Decisión: La TLC solo registra propinas pagadas con tarjeta, por lo que el porcentaje de propina se calcula sobre pagos con tarjeta.

```sql
SELECT
    tipo_taxi,
    metodo_pago,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS porcentaje_viajes,
    round(avg(total), 2) AS total_promedio,
    round(100.0 * count(*) FILTER (WHERE propina > 0) / count(*), 2) AS pct_con_propina,
    round(median(100.0 * propina / nullif(tarifa, 0)), 2) AS propina_mediana_pct
FROM viajes_validos
GROUP BY tipo_taxi, metodo_pago
ORDER BY tipo_taxi DESC, viajes DESC
```

| tipo_taxi | metodo_pago | viajes | porcentaje_viajes | total_promedio | pct_con_propina | propina_mediana_pct |
| --- | --- | --- | --- | --- | --- | --- |
| yellow | Tarjeta de crédito | 48618184 | 71.59 | 29.83 | 93.16 | 25.96 |
| yellow | Sin registro | 10737000 | 15.81 | 29.99 | 11.29 | 0 |
| yellow | Efectivo | 7836199 | 11.54 | 25.27 | 0.01 | 0 |
| yellow | Disputa | 504942 | 0.74 | 28.03 | 0.08 | 0 |
| yellow | Sin cargo | 211174 | 0.31 | 24.78 | 0.07 | 0 |
| green | Tarjeta de crédito | 636612 | 67.63 | 25.23 | 91.37 | 23.49 |
| green | Efectivo | 230224 | 24.46 | 20.76 | 0 | 0 |
| green | Sin registro | 71060 | 7.55 | 31.1 | 35.77 | 0 |
| green | Sin cargo | 2535 | 0.27 | 15.35 | 0.28 | 0 |
| green | Disputa | 945 | 0.1 | 15.51 | 0.11 | 0 |

### e4_zonas_origen en el ejercicio 5

- Objetivo: Pregunta 7. Desde qué zonas y distritos sale la mayor parte de los viajes de cada tipo de taxi.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 20 filas y 6 columnas en 11.08 s
- Decisión: Se comparan las diez zonas principales de cada tipo para verificar la separación geográfica de los servicios.

```sql
SELECT *
FROM (
    SELECT
        tipo_taxi,
        nombre_origen AS zona,
        distrito_origen AS distrito,
        count(*) AS viajes,
        round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS porcentaje,
        row_number() OVER (PARTITION BY tipo_taxi ORDER BY count(*) DESC) AS posicion
    FROM viajes_validos
    GROUP BY tipo_taxi, nombre_origen, distrito_origen
)
WHERE posicion <= 10
ORDER BY tipo_taxi DESC, posicion
```

| tipo_taxi | zona | distrito | viajes | porcentaje | posicion |
| --- | --- | --- | --- | --- | --- |
| yellow | Upper East Side South | Manhattan | 3124125 | 4.6 | 1 |
| yellow | Midtown Center | Manhattan | 3032641 | 4.47 | 2 |
| yellow | JFK Airport | Queens | 2994152 | 4.41 | 3 |
| yellow | Upper East Side North | Manhattan | 2804196 | 4.13 | 4 |
| yellow | Midtown East | Manhattan | 2245675 | 3.31 | 5 |
| yellow | Penn Station/Madison Sq West | Manhattan | 2192375 | 3.23 | 6 |
| yellow | Times Sq/Theatre District | Manhattan | 2155227 | 3.17 | 7 |
| yellow | Lincoln Square East | Manhattan | 2092544 | 3.08 | 8 |
| yellow | LaGuardia Airport | Queens | 1976577 | 2.91 | 9 |
| yellow | Murray Hill | Manhattan | 1877341 | 2.76 | 10 |
| green | East Harlem North | Manhattan | 233917 | 24.85 | 1 |
| green | East Harlem South | Manhattan | 130758 | 13.89 | 2 |

### e4_aeropuertos en el ejercicio 5

- Objetivo: Pregunta 8. Cuánto pesan los viajes de aeropuerto y en qué se diferencian del resto.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 8 filas y 7 columnas en 18.62 s
- Decisión: Los viajes de aeropuerto se analizan aparte porque tienen tarifa fija o recargos propios y elevan los promedios generales.

```sql
SELECT
    tipo_taxi,
    aeropuerto,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS porcentaje,
    round(median(distancia_millas), 2) AS distancia_mediana,
    round(median(duracion_min), 1) AS duracion_mediana,
    round(median(total), 2) AS total_mediano
FROM viajes_validos
GROUP BY tipo_taxi, aeropuerto
ORDER BY tipo_taxi DESC, viajes DESC
```

| tipo_taxi | aeropuerto | viajes | porcentaje | distancia_mediana | duracion_mediana | total_mediano |
| --- | --- | --- | --- | --- | --- | --- |
| yellow | Sin aeropuerto | 61591646 | 90.7 | 1.69 | 12.5 | 21 |
| yellow | JFK | 3547850 | 5.22 | 17.21 | 42.9 | 89.21 |
| yellow | LaGuardia | 2617786 | 3.85 | 9.6 | 28.9 | 69.2 |
| yellow | Newark | 150217 | 0.22 | 17.51 | 37.8 | 128.6 |
| green | Sin aeropuerto | 904551 | 96.09 | 1.95 | 12.3 | 19.2 |
| green | LaGuardia | 28249 | 3 | 3.91 | 13.1 | 32.88 |
| green | JFK | 8025 | 0.85 | 14.1 | 36.8 | 72.82 |
| green | Newark | 551 | 0.06 | 21.62 | 45.2 | 143.7 |

### e4_atipicos_tarifa en el ejercicio 5

- Objetivo: Pregunta 9. Qué viajes válidos tienen una tarifa por milla atípica según el criterio de rango intercuartílico.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 2 filas y 8 columnas en 22.57 s
- Decisión: Los viajes fuera del rango intercuartílico no se eliminan porque pueden ser legítimos, como tarifas negociadas o viajes muy cortos; se reporta su proporción.

```sql
WITH tarifas AS (
    SELECT tipo_taxi, tarifa / distancia_millas AS tarifa_por_milla
    FROM viajes_validos
    WHERE distancia_millas >= 0.1
),
limites AS (
    SELECT
        tipo_taxi,
        quantile_cont(tarifa_por_milla, 0.25) AS q1,
        quantile_cont(tarifa_por_milla, 0.75) AS q3
    FROM tarifas
    GROUP BY ALL
)
SELECT
    t.tipo_taxi,
    round(l.q1, 2) AS q1,
    round(l.q3, 2) AS q3,
    round(l.q3 + 1.5 * (l.q3 - l.q1), 2) AS limite_superior,
    count(*) AS viajes,
    count(*) FILTER (WHERE t.tarifa_por_milla > l.q3 + 1.5 * (l.q3 - l.q1)) AS atipicos_altos,
    count(*) FILTER (WHERE t.tarifa_por_milla < l.q1 - 1.5 * (l.q3 - l.q1)) AS atipicos_bajos,
    round(100.0 * count(*) FILTER (WHERE t.tarifa_por_milla > l.q3 + 1.5 * (l.q3 - l.q1)
                                     OR t.tarifa_por_milla < l.q1 - 1.5 * (l.q3 - l.q1)) / count(*), 2) AS pct_atipicos
FROM tarifas t
JOIN limites l USING (tipo_taxi)
GROUP BY ALL
ORDER BY t.tipo_taxi DESC
```

| tipo_taxi | q1 | q3 | limite_superior | viajes | atipicos_altos | atipicos_bajos | pct_atipicos |
| --- | --- | --- | --- | --- | --- | --- | --- |
| yellow | 5.74 | 9.59 | 15.36 | 67542358 | 3297492 | 0 | 4.88 |
| green | 5.62 | 8.17 | 12 | 933953 | 46240 | 32630 | 8.44 |

## Ejercicio 6

### b1_conteo_total

- Objetivo: Contar todos los registros, la consulta más simple posible, que en Parquet puede resolverse con metadatos.
- Fuentes: vista viajes sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/04_benchmark.sql
- Resultado: 1 filas y 1 columnas en 0.29 s
- Decisión: Mide el costo mínimo de abrir la fuente.

```sql
SELECT count(*) AS registros
FROM viajes
```

| registros |
| --- |
| 71870407 |

### b2_agregado_mensual

- Objetivo: Agregar viajes, ingreso y distancia por tipo de taxi, año y mes, como en el análisis temporal.
- Fuentes: vista viajes sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/04_benchmark.sql
- Resultado: 54 filas y 6 columnas en 4.29 s
- Decisión: Representa las consultas de tendencia que leen pocas columnas de todas las filas.

```sql
SELECT
    tipo_taxi,
    year(fecha_recogida) AS anio,
    month(fecha_recogida) AS mes,
    count(*) AS viajes,
    sum(total) AS ingreso,
    avg(distancia_millas) AS distancia_promedio
FROM viajes
GROUP BY ALL
ORDER BY ALL
```

| tipo_taxi | anio | mes | viajes | ingreso | distancia_promedio |
| --- | --- | --- | --- | --- | --- |
| green | 2008 | 12 | 9 | 290 | 5.197 |
| green | 2009 | 1 | 8 | 206.3 | 3.764 |
| green | 2023 | 12 | 2 | 37.58 | 2.9 |
| green | 2024 | 1 | 56555 | 1,267,029 | 31.49 |
| green | 2024 | 2 | 53578 | 1,212,739 | 17.67 |
| green | 2024 | 3 | 57451 | 1,315,890 | 13.52 |
| green | 2024 | 4 | 56473 | 1,319,444 | 12.09 |
| green | 2024 | 5 | 61007 | 1,499,246 | 14.61 |
| green | 2024 | 6 | 54738 | 1,360,763 | 13.99 |
| green | 2024 | 7 | 51820 | 1,283,191 | 11.29 |
| green | 2024 | 8 | 51806 | 1,345,425 | 19.7 |
| green | 2024 | 9 | 54422 | 1,451,826 | 18.42 |

### b3_filtro_selectivo

- Objetivo: Filtrar los viajes que salen de los aeropuertos con más de 10 millas y resumirlos por aeropuerto.
- Fuentes: vista viajes sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/04_benchmark.sql
- Resultado: 3 filas y 4 columnas en 4.82 s
- Decisión: Representa consultas con filtros muy selectivos, donde las estadísticas por grupo de filas permiten saltar datos.

```sql
SELECT
    zona_origen,
    count(*) AS viajes,
    avg(total) AS total_promedio,
    avg(duracion_min) AS duracion_promedio
FROM viajes
WHERE zona_origen IN (1, 132, 138)
  AND distancia_millas > 10
GROUP BY ALL
ORDER BY viajes DESC
```

| zona_origen | viajes | total_promedio | duracion_promedio |
| --- | --- | --- | --- |
| 132 | 2471662 | 88.46 | 49.43 |
| 138 | 760090 | 79.9 | 39.13 |
| 1 | 287 | 125.7 | 44.86 |

### b4_patron_horario

- Objetivo: Calcular viajes y duración mediana por día de la semana y hora.
- Fuentes: vista viajes sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/04_benchmark.sql
- Resultado: 168 filas y 4 columnas en 4.57 s
- Decisión: Representa agregaciones con muchas combinaciones de grupo y una mediana, que exigen ordenar valores.

```sql
SELECT
    isodow(fecha_recogida) AS dia_semana,
    hour(fecha_recogida) AS hora,
    count(*) AS viajes,
    median(duracion_min) AS duracion_mediana
FROM viajes
GROUP BY ALL
ORDER BY ALL
```

| dia_semana | hora | viajes | duracion_mediana |
| --- | --- | --- | --- |
| 1 | 0 | 160984 | 13.42 |
| 1 | 1 | 84133 | 12.53 |
| 1 | 2 | 49516 | 11.93 |
| 1 | 3 | 37330 | 12.3 |
| 1 | 4 | 46830 | 13.82 |
| 1 | 5 | 82812 | 12.48 |
| 1 | 6 | 178734 | 11.47 |
| 1 | 7 | 330907 | 11.97 |
| 1 | 8 | 437259 | 13.23 |
| 1 | 9 | 431310 | 13.48 |
| 1 | 10 | 423894 | 13.78 |
| 1 | 11 | 443148 | 14.07 |

### b5_percentiles

- Objetivo: Calcular percentiles de distancia y total por tipo de taxi y método de pago.
- Fuentes: vista viajes sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/04_benchmark.sql
- Resultado: 12 filas y 4 columnas en 11.27 s
- Decisión: Representa el análisis de distribuciones, la operación más costosa en memoria del exploratorio.

```sql
SELECT
    tipo_taxi,
    tipo_pago,
    quantile_cont(distancia_millas, [0.25, 0.5, 0.75, 0.99]) AS distancia_percentiles,
    quantile_cont(total, [0.25, 0.5, 0.75, 0.99]) AS total_percentiles
FROM viajes
GROUP BY ALL
ORDER BY ALL
```

| tipo_taxi | tipo_pago | distancia_percentiles | total_percentiles |
| --- | --- | --- | --- |
| green | 1 | [ 1.2   1.91  3.19 14.56] | [15.12 20.82 29.25 97.2 ] |
| green | 2 | [ 1.02  1.72  3.15 16.94] | [11.2    15.7    23.4    95.5201] |
| green | 3 | [ 0.     0.06   0.67  10.713] | [-4.5     4.5     8.7    83.9473] |
| green | 4 | [0.   0.1  0.68 9.38] | [-6.2   4.5   8.4  81.18] |
| green | 5 | [ 0.1    1.     2.8   10.676] | [ 7.  15.  26.2 60. ] |
| green | <NA> | [ 2.02    4.18    8.19   22.9996] | [17.7    26.12   39.73   91.3398] |
| yellow | 0 | [ 1.32  2.48  4.51 16.11] | [19.51 26.62 36.52 86.74] |
| yellow | 1 | [ 1.01  1.71  3.29 20.06] | [ 16.8   21.9   31.9  106.95] |
| yellow | 2 | [ 0.88  1.55  3.25 20.6 ] | [13.   17.5  26.6  94.15] |
| yellow | 3 | [ 0.03  0.82  2.2  20.9 ] | [-7.    10.1   18.55  95.644] |
| yellow | 4 | [ 0.58  1.37  3.54 22.67] | [-16.5   8.   18.5  97.5] |
| yellow | 5 | [0.   0.   0.   3.04] | [ 0.   0.   0.  58.9] |

### b6_union_zonas

- Objetivo: Unir los viajes con la tabla de zonas y resumir viajes e ingreso por distrito de origen y destino.
- Fuentes: vista viajes sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/04_benchmark.sql
- Resultado: 64 filas y 4 columnas en 3.09 s
- Decisión: Representa las consultas que combinan los viajes con otra tabla, como las del tablero por zona.

```sql
SELECT
    zo.distrito AS distrito_origen,
    zd.distrito AS distrito_destino,
    count(*) AS viajes,
    sum(v.total) AS ingreso
FROM viajes v
JOIN zonas zo ON v.zona_origen = zo.zona
JOIN zonas zd ON v.zona_destino = zd.zona
GROUP BY ALL
ORDER BY viajes DESC
```

| distrito_origen | distrito_destino | viajes | ingreso |
| --- | --- | --- | --- |
| Manhattan | Manhattan | 58545525 | 1,296,841,975 |
| Queens | Manhattan | 3497213 | 274,834,752 |
| Queens | Queens | 1921795 | 69,254,576 |
| Manhattan | Queens | 1880180 | 121,601,541 |
| Manhattan | Brooklyn | 1538209 | 67,605,899 |
| Queens | Brooklyn | 995631 | 64,100,490 |
| Brooklyn | Brooklyn | 954553 | 23,926,508 |
| Brooklyn | Manhattan | 619778 | 26,652,583 |
| Manhattan | Bronx | 339006 | 14,026,633 |
| Brooklyn | Queens | 201327 | 8,703,897 |
| Queens | N/A | 188772 | 23,270,449 |
| Bronx | Manhattan | 177623 | 6,729,656 |

## Ejercicio 7

### ind_01_resumen_anual

- Pregunta: P1. ¿Cuántos viajes válidos e ingresos genera el servicio de taxis cada año y cuál es el monto promedio por viaje?
- Objetivo: Resumir en tarjetas numéricas los indicadores generales de cada año.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 2 filas y 9 columnas en 17.68 s
- Justificación: Es el punto de partida del tablero, da la escala del servicio y permite comparar años con viajes e ingreso por día aunque 2026 esté incompleto.

```sql
SELECT
    anio_archivo AS anio,
    count(DISTINCT mes_archivo) AS meses,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 0) AS viajes_por_dia,
    round(sum(total), 2) AS ingreso_total,
    round(sum(total) / count(DISTINCT fecha), 2) AS ingreso_por_dia,
    round(avg(total), 2) AS ticket_promedio,
    round(median(distancia_millas), 2) AS distancia_mediana,
    round(median(duracion_min), 2) AS duracion_mediana
FROM viajes_validos
GROUP BY ALL
ORDER BY anio
```

| anio | meses | viajes | viajes_por_dia | ingreso_total | ingreso_por_dia | ticket_promedio | distancia_mediana | duracion_mediana |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2024 | 12 | 40297639 | 110,103 | 1,150,848,913 | 3,144,396 | 28.56 | 1.8 | 13.07 |
| 2026 | 8 | 28551236 | 117,495 | 861,990,774 | 3,547,287 | 30.19 | 1.93 | 14.1 |

### ind_02_tendencia_mensual

- Pregunta: P2. ¿Cómo evoluciona mes a mes la demanda de taxis amarillos y verdes?
- Objetivo: Construir la serie mensual de viajes por día e ingreso por tipo de taxi.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 40 filas y 7 columnas en 12.07 s
- Justificación: La serie temporal muestra estacionalidad y tendencia; se usa viajes por día para que los meses de distinta duración sean comparables.

```sql
SELECT
    make_date(anio_archivo, mes_archivo, 1) AS periodo,
    anio_archivo AS anio,
    mes_archivo AS mes,
    tipo_taxi,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 1) AS viajes_por_dia,
    round(sum(total), 2) AS ingreso
FROM viajes_validos
GROUP BY ALL
ORDER BY periodo, tipo_taxi DESC
```

| periodo | anio | mes | tipo_taxi | viajes | viajes_por_dia | ingreso |
| --- | --- | --- | --- | --- | --- | --- |
| 2024-01-01 00:00:00 | 2024 | 1 | yellow | 2867133 | 92,488 | 78,367,600 |
| 2024-01-01 00:00:00 | 2024 | 1 | green | 53149 | 1,714 | 1,178,701 |
| 2024-02-01 00:00:00 | 2024 | 2 | yellow | 2899130 | 99,970 | 78,938,879 |
| 2024-02-01 00:00:00 | 2024 | 2 | green | 50269 | 1,733 | 1,129,037 |
| 2024-03-01 00:00:00 | 2024 | 3 | yellow | 3437442 | 110,885 | 95,732,873 |
| 2024-03-01 00:00:00 | 2024 | 3 | green | 53949 | 1,740 | 1,227,853 |
| 2024-04-01 00:00:00 | 2024 | 4 | yellow | 3411726 | 113,724 | 96,138,862 |
| 2024-04-01 00:00:00 | 2024 | 4 | green | 52797 | 1,760 | 1,228,793 |
| 2024-05-01 00:00:00 | 2024 | 5 | yellow | 3615186 | 116,619 | 104,787,862 |
| 2024-05-01 00:00:00 | 2024 | 5 | green | 57323 | 1,849 | 1,403,016 |
| 2024-06-01 00:00:00 | 2024 | 6 | yellow | 3425728 | 114,191 | 98,249,305 |
| 2024-06-01 00:00:00 | 2024 | 6 | green | 51520 | 1,717 | 1,275,345 |

### ind_03_demanda_horaria

- Pregunta: P3. ¿En qué horas del día se concentra la demanda y cómo cambia entre semana y fin de semana?
- Objetivo: Calcular los viajes promedio por día en cada hora, separando días entre semana y fines de semana.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 96 filas y 5 columnas en 13.95 s
- Justificación: Identifica horas pico, útil para asignar flota; el promedio por día evita que entre semana domine solo por tener más días.

```sql
SELECT
    anio_archivo AS anio,
    tipo_dia,
    hora,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 1) AS viajes_promedio_dia
FROM viajes_validos
GROUP BY ALL
ORDER BY anio, tipo_dia, hora
```

| anio | tipo_dia | hora | viajes | viajes_promedio_dia |
| --- | --- | --- | --- | --- |
| 2024 | Entre semana | 0 | 544034 | 2,076 |
| 2024 | Entre semana | 1 | 260405 | 993.9 |
| 2024 | Entre semana | 2 | 141146 | 538.7 |
| 2024 | Entre semana | 3 | 93415 | 356.5 |
| 2024 | Entre semana | 4 | 102298 | 390.5 |
| 2024 | Entre semana | 5 | 192378 | 734.3 |
| 2024 | Entre semana | 6 | 475974 | 1,817 |
| 2024 | Entre semana | 7 | 978006 | 3,733 |
| 2024 | Entre semana | 8 | 1324629 | 5,056 |
| 2024 | Entre semana | 9 | 1347744 | 5,144 |
| 2024 | Entre semana | 10 | 1349864 | 5,152 |
| 2024 | Entre semana | 11 | 1419125 | 5,416 |

### ind_04_velocidad_horaria

- Pregunta: P4. ¿En qué horas el tráfico hace más lentos los viajes?
- Objetivo: Calcular la velocidad mediana y la duración mediana de los viajes en cada hora.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 48 filas y 5 columnas en 15.89 s
- Justificación: La velocidad es un indicador indirecto de congestión; se usa la mediana por ser robusta a registros extremos.

```sql
SELECT
    anio_archivo AS anio,
    hora,
    round(median(velocidad_mph), 2) AS velocidad_mediana_mph,
    round(median(duracion_min), 2) AS duracion_mediana_min,
    round(median(distancia_millas), 2) AS distancia_mediana
FROM viajes_validos
GROUP BY ALL
ORDER BY anio, hora
```

| anio | hora | velocidad_mediana_mph | duracion_mediana_min | distancia_mediana |
| --- | --- | --- | --- | --- |
| 2024 | 0 | 11.84 | 12.12 | 2.21 |
| 2024 | 1 | 12.1 | 11.1 | 2.09 |
| 2024 | 2 | 12.55 | 10.48 | 2.05 |
| 2024 | 3 | 13.55 | 10.37 | 2.2 |
| 2024 | 4 | 15.5 | 11.82 | 2.9 |
| 2024 | 5 | 16.51 | 11.88 | 3.02 |
| 2024 | 6 | 13.97 | 10.5 | 2.3 |
| 2024 | 7 | 11.15 | 11.18 | 1.91 |
| 2024 | 8 | 9.26 | 12.42 | 1.74 |
| 2024 | 9 | 8.96 | 12.75 | 1.7 |
| 2024 | 10 | 8.74 | 13.05 | 1.67 |
| 2024 | 11 | 8.26 | 13.63 | 1.63 |

### ind_05_dia_semana

- Pregunta: P5. ¿Qué días de la semana tienen más viajes y viajes más caros?
- Objetivo: Calcular viajes promedio por fecha y monto promedio para cada día de la semana.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 14 filas y 6 columnas en 15.16 s
- Justificación: Complementa el perfil horario y muestra si el fin de semana cambia el tipo de viaje además del volumen.

```sql
SELECT
    anio_archivo AS anio,
    dia_semana,
    CASE dia_semana WHEN 1 THEN '1 Lunes' WHEN 2 THEN '2 Martes' WHEN 3 THEN '3 Miércoles'
        WHEN 4 THEN '4 Jueves' WHEN 5 THEN '5 Viernes' WHEN 6 THEN '6 Sábado' ELSE '7 Domingo' END AS dia,
    round(count(*) / count(DISTINCT fecha), 1) AS viajes_promedio_dia,
    round(avg(total), 2) AS ticket_promedio,
    round(median(distancia_millas), 2) AS distancia_mediana
FROM viajes_validos
GROUP BY ALL
ORDER BY anio, dia_semana
```

| anio | dia_semana | dia | viajes_promedio_dia | ticket_promedio | distancia_mediana |
| --- | --- | --- | --- | --- | --- |
| 2024 | 1 | 1 Lunes | 94,668 | 29.81 | 1.82 |
| 2024 | 2 | 2 Martes | 109,217 | 28.53 | 1.73 |
| 2024 | 3 | 3 Miércoles | 115,454 | 28.62 | 1.73 |
| 2024 | 4 | 4 Jueves | 121,104 | 29.02 | 1.77 |
| 2024 | 5 | 5 Viernes | 114,578 | 28.46 | 1.77 |
| 2024 | 6 | 6 Sábado | 117,059 | 26.69 | 1.8 |
| 2024 | 7 | 7 Domingo | 98,955 | 29.06 | 1.99 |
| 2026 | 1 | 1 Lunes | 97,188 | 30.88 | 1.94 |
| 2026 | 2 | 2 Martes | 114,565 | 30.32 | 1.84 |
| 2026 | 3 | 3 Miércoles | 122,069 | 30.42 | 1.83 |
| 2026 | 4 | 4 Jueves | 128,907 | 30.75 | 1.85 |
| 2026 | 5 | 5 Viernes | 122,007 | 30.08 | 1.9 |

### ind_06_metodo_pago

- Pregunta: P6. ¿Cómo pagan los pasajeros y cómo cambia la participación de cada método entre años?
- Objetivo: Calcular la participación de cada método de pago por año y tipo de taxi.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 20 filas y 5 columnas en 14.32 s
- Justificación: El método de pago condiciona la propina registrada y refleja la adopción de pagos electrónicos.

```sql
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    metodo_pago,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo, tipo_taxi), 2) AS porcentaje
FROM viajes_validos
GROUP BY anio_archivo, tipo_taxi, metodo_pago
ORDER BY anio, tipo_taxi DESC, viajes DESC
```

| anio | tipo_taxi | metodo_pago | viajes | porcentaje |
| --- | --- | --- | --- | --- |
| 2024 | yellow | Tarjeta de crédito | 30165072 | 76.02 |
| 2024 | yellow | Efectivo | 5277379 | 13.3 |
| 2024 | yellow | Sin registro | 3694944 | 9.31 |
| 2024 | yellow | Disputa | 386120 | 0.97 |
| 2024 | yellow | Sin cargo | 154759 | 0.39 |
| 2024 | green | Tarjeta de crédito | 425653 | 68.72 |
| 2024 | green | Efectivo | 167742 | 27.08 |
| 2024 | green | Sin registro | 23443 | 3.79 |
| 2024 | green | Sin cargo | 1868 | 0.3 |
| 2024 | green | Disputa | 659 | 0.11 |
| 2026 | yellow | Tarjeta de crédito | 18453112 | 65.37 |
| 2026 | yellow | Sin registro | 7042056 | 24.95 |

### ind_07_propina

- Pregunta: P7. ¿Qué porcentaje de propina dejan los pasajeros que pagan con tarjeta y cómo varía por franja horaria y tipo de taxi?
- Objetivo: Calcular el porcentaje promedio y mediano de propina sobre la tarifa en pagos con tarjeta.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 20 filas y 7 columnas en 11.91 s
- Justificación: La propina es parte relevante del ingreso del conductor y solo es observable en pagos con tarjeta, lo que se respeta en el cálculo.

```sql
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    franja_horaria,
    count(*) AS viajes_tarjeta,
    round(avg(propina_pct), 2) AS propina_promedio_pct,
    round(median(propina_pct), 2) AS propina_mediana_pct,
    round(100.0 * count(*) FILTER (WHERE propina > 0) / count(*), 2) AS pct_con_propina
FROM viajes_validos
WHERE tipo_pago = 1 AND tarifa > 0
GROUP BY ALL
ORDER BY anio, tipo_taxi DESC, franja_horaria
```

| anio | tipo_taxi | franja_horaria | viajes_tarjeta | propina_promedio_pct | propina_mediana_pct | pct_con_propina |
| --- | --- | --- | --- | --- | --- | --- |
| 2024 | yellow | 1 Madrugada 0 a 5 | 2223298 | 25.52 | 25.88 | 91.01 |
| 2024 | yellow | 2 Mañana 6 a 9 | 3592351 | 24.13 | 25.13 | 92.52 |
| 2024 | yellow | 3 Mediodía 10 a 15 | 9791667 | 24.13 | 25.13 | 94.21 |
| 2024 | yellow | 4 Tarde 16 a 19 | 8153487 | 26.69 | 27.02 | 95.42 |
| 2024 | yellow | 5 Noche 20 a 23 | 6403924 | 25.25 | 26.13 | 95.62 |
| 2024 | green | 1 Madrugada 0 a 5 | 21221 | 20.91 | 22.72 | 84.65 |
| 2024 | green | 2 Mañana 6 a 9 | 66109 | 20.93 | 22.63 | 90.59 |
| 2024 | green | 3 Mediodía 10 a 15 | 138203 | 21.95 | 23 | 91.75 |
| 2024 | green | 4 Tarde 16 a 19 | 132587 | 23.66 | 25.17 | 92.5 |
| 2024 | green | 5 Noche 20 a 23 | 67520 | 22.57 | 23.91 | 90.93 |
| 2026 | yellow | 1 Madrugada 0 a 5 | 1274358 | 24.07 | 26.1 | 86.28 |
| 2026 | yellow | 2 Mañana 6 a 9 | 2209648 | 23.03 | 25.42 | 86.93 |

### ind_08_zonas_origen

- Pregunta: P8. ¿Desde qué zonas sale la mayor cantidad de viajes de cada tipo de taxi?
- Objetivo: Obtener las 15 zonas de origen con más viajes por año y tipo de taxi.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 60 filas y 7 columnas en 12.32 s
- Justificación: Muestra la concentración geográfica de la demanda y la diferencia de cobertura entre taxis amarillos y verdes.

```sql
SELECT *
FROM (
    SELECT
        anio_archivo AS anio,
        tipo_taxi,
        nombre_origen AS zona,
        distrito_origen AS distrito,
        count(*) AS viajes,
        round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo, tipo_taxi), 2) AS porcentaje,
        row_number() OVER (PARTITION BY anio_archivo, tipo_taxi ORDER BY count(*) DESC) AS posicion
    FROM viajes_validos
    GROUP BY anio_archivo, tipo_taxi, nombre_origen, distrito_origen
)
WHERE posicion <= 15
ORDER BY anio, tipo_taxi DESC, posicion
```

| anio | tipo_taxi | zona | distrito | viajes | porcentaje | posicion |
| --- | --- | --- | --- | --- | --- | --- |
| 2024 | yellow | Upper East Side South | Manhattan | 1871300 | 4.72 | 1 |
| 2024 | yellow | JFK Airport | Queens | 1869013 | 4.71 | 2 |
| 2024 | yellow | Midtown Center | Manhattan | 1860994 | 4.69 | 3 |
| 2024 | yellow | Upper East Side North | Manhattan | 1690950 | 4.26 | 4 |
| 2024 | yellow | Midtown East | Manhattan | 1381041 | 3.48 | 5 |
| 2024 | yellow | Times Sq/Theatre District | Manhattan | 1337752 | 3.37 | 6 |
| 2024 | yellow | Penn Station/Madison Sq West | Manhattan | 1323723 | 3.34 | 7 |
| 2024 | yellow | Lincoln Square East | Manhattan | 1280818 | 3.23 | 8 |
| 2024 | yellow | LaGuardia Airport | Queens | 1260365 | 3.18 | 9 |
| 2024 | yellow | Murray Hill | Manhattan | 1139667 | 2.87 | 10 |
| 2024 | yellow | Midtown North | Manhattan | 1136015 | 2.86 | 11 |
| 2024 | yellow | Upper West Side South | Manhattan | 1111351 | 2.8 | 12 |

### ind_09_distritos

- Pregunta: P9. ¿Cómo se reparten los viajes y el ingreso entre los distritos de la ciudad?
- Objetivo: Calcular viajes, ingreso y ticket promedio por distrito de origen y tipo de taxi.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 31 filas y 7 columnas en 10.72 s
- Justificación: Resume la geografía a un nivel legible y evidencia la especialización de los taxis verdes fuera del centro de Manhattan.

```sql
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    distrito_origen AS distrito,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo, tipo_taxi), 2) AS porcentaje,
    round(sum(total), 2) AS ingreso,
    round(avg(total), 2) AS ticket_promedio
FROM viajes_validos
GROUP BY anio_archivo, tipo_taxi, distrito_origen
ORDER BY anio, tipo_taxi DESC, viajes DESC
```

| anio | tipo_taxi | distrito | viajes | porcentaje | ingreso | ticket_promedio |
| --- | --- | --- | --- | --- | --- | --- |
| 2024 | yellow | Manhattan | 35243274 | 88.82 | 843,201,632 | 23.93 |
| 2024 | yellow | Queens | 3643399 | 9.18 | 266,761,345 | 73.22 |
| 2024 | yellow | Brooklyn | 553755 | 1.4 | 17,620,240 | 31.82 |
| 2024 | yellow | Bronx | 113723 | 0.29 | 4,075,053 | 35.83 |
| 2024 | yellow | Unknown | 113090 | 0.29 | 3,404,802 | 30.11 |
| 2024 | yellow | N/A | 8424 | 0.02 | 684,544 | 81.26 |
| 2024 | yellow | Staten Island | 1453 | 0 | 64,429 | 44.34 |
| 2024 | yellow | EWR | 1156 | 0 | 107,378 | 92.89 |
| 2024 | green | Manhattan | 376730 | 60.83 | 8,218,448 | 21.82 |
| 2024 | green | Queens | 152125 | 24.56 | 3,991,914 | 26.24 |
| 2024 | green | Brooklyn | 83134 | 13.42 | 2,473,542 | 29.75 |
| 2024 | green | Bronx | 6702 | 1.08 | 216,151 | 32.25 |

### ind_10_aeropuertos

- Pregunta: P10. ¿Qué peso tienen los viajes hacia o desde aeropuertos y cuánto más cuestan que un viaje urbano?
- Objetivo: Comparar viajes, participación, monto y duración de los viajes con JFK, LaGuardia, Newark y sin aeropuerto.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 8 filas y 7 columnas en 13.45 s
- Justificación: Los aeropuertos son pocos viajes pero de alto valor, por lo que explican parte importante del ingreso.

```sql
SELECT
    anio_archivo AS anio,
    aeropuerto,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo), 2) AS pct_viajes,
    round(100.0 * sum(total) / sum(sum(total)) OVER (PARTITION BY anio_archivo), 2) AS pct_ingreso,
    round(avg(total), 2) AS ticket_promedio,
    round(median(duracion_min), 1) AS duracion_mediana
FROM viajes_validos
GROUP BY anio_archivo, aeropuerto
ORDER BY anio, viajes DESC
```

| anio | aeropuerto | viajes | pct_viajes | pct_ingreso | ticket_promedio | duracion_mediana |
| --- | --- | --- | --- | --- | --- | --- |
| 2024 | Sin aeropuerto | 36260377 | 89.98 | 72.42 | 22.99 | 12 |
| 2024 | JFK | 2239785 | 5.56 | 16.35 | 84.01 | 43.7 |
| 2024 | LaGuardia | 1695486 | 4.21 | 10.09 | 68.5 | 28.8 |
| 2024 | Newark | 101991 | 0.25 | 1.14 | 128.3 | 38.1 |
| 2026 | Sin aeropuerto | 26235820 | 91.89 | 79.09 | 25.99 | 13.3 |
| 2026 | JFK | 1316090 | 4.61 | 12.42 | 81.37 | 41.5 |
| 2026 | LaGuardia | 950549 | 3.33 | 7.73 | 70.11 | 28.8 |
| 2026 | Newark | 48777 | 0.17 | 0.75 | 132.9 | 37.2 |

### ind_11_participacion_tipo

- Pregunta: P11. ¿Qué participación tienen los taxis verdes frente a los amarillos en viajes e ingreso y cómo cambia en el tiempo?
- Objetivo: Calcular viajes, ingreso y participación por tipo de taxi y año.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 4 filas y 7 columnas en 10.81 s
- Justificación: Permite seguir la evolución relativa de ambos servicios, que operan con reglas y zonas distintas.

```sql
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo), 2) AS pct_viajes,
    round(sum(total), 2) AS ingreso,
    round(100.0 * sum(total) / sum(sum(total)) OVER (PARTITION BY anio_archivo), 2) AS pct_ingreso,
    round(avg(total), 2) AS ticket_promedio
FROM viajes_validos
GROUP BY anio_archivo, tipo_taxi
ORDER BY anio, tipo_taxi DESC
```

| anio | tipo_taxi | viajes | pct_viajes | ingreso | pct_ingreso | ticket_promedio |
| --- | --- | --- | --- | --- | --- | --- |
| 2024 | yellow | 39678274 | 98.46 | 1,135,919,423 | 98.7 | 28.63 |
| 2024 | green | 619365 | 1.54 | 14,929,490 | 1.3 | 24.1 |
| 2026 | yellow | 28229225 | 98.87 | 853,818,401 | 99.05 | 30.25 |
| 2026 | green | 322011 | 1.13 | 8,172,373 | 0.95 | 25.38 |

### ind_12_calidad_datos

- Pregunta: P12. ¿Qué proporción de los registros publicados no es utilizable y por qué motivo?
- Objetivo: Contar los registros válidos y excluidos por motivo, año y tipo de taxi.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 34 filas y 5 columnas en 8.80 s
- Justificación: Hace visible la confiabilidad de los demás indicadores y documenta cuántos registros se descartan en cada año.

```sql
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    coalesce(motivo_exclusion, 'Válido') AS clasificacion,
    count(*) AS registros,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo, tipo_taxi), 3) AS porcentaje
FROM viajes_calidad
GROUP BY anio_archivo, tipo_taxi, clasificacion
ORDER BY anio, tipo_taxi DESC, registros DESC
```

| anio | tipo_taxi | clasificacion | registros | porcentaje |
| --- | --- | --- | --- | --- |
| 2024 | yellow | Válido | 39678274 | 96.38 |
| 2024 | yellow | Distancia cero | 764825 | 1.858 |
| 2024 | yellow | Monto negativo o ajuste | 677372 | 1.645 |
| 2024 | yellow | Duración mayor a 6 horas | 21994 | 0.053 |
| 2024 | yellow | Duración nula o negativa | 13510 | 0.033 |
| 2024 | yellow | Velocidad mayor a 80 mph | 12187 | 0.03 |
| 2024 | yellow | Distancia mayor a 200 millas | 1122 | 0.003 |
| 2024 | yellow | Fecha fuera del mes del archivo | 420 | 0.001 |
| 2024 | yellow | Total mayor a 1000 dólares | 16 | 0 |
| 2024 | green | Válido | 619365 | 93.81 |
| 2024 | green | Distancia cero | 33930 | 5.139 |
| 2024 | green | Duración mayor a 6 horas | 2627 | 0.398 |

### ind_13_cargos_mensuales

- Pregunta: P13. ¿Cómo cambian los recargos que paga el pasajero, en particular el cargo de congestión CBD?
- Objetivo: Calcular por mes el monto promedio de cada recargo y el porcentaje de viajes con cargo CBD.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 20 filas y 8 columnas en 12.42 s
- Justificación: Los recargos explican cambios en el total pagado que no se deben a la tarifa; el cargo CBD solo aparece en los archivos desde 2025.

```sql
SELECT
    make_date(anio_archivo, mes_archivo, 1) AS periodo,
    anio_archivo AS anio,
    round(avg(coalesce(cargo_cbd, 0)), 3) AS cargo_cbd_promedio,
    round(100.0 * count(*) FILTER (WHERE cargo_cbd > 0) / count(*), 2) AS pct_con_cargo_cbd,
    round(avg(recargo_congestion), 3) AS recargo_congestion_promedio,
    round(avg(total - tarifa - propina), 2) AS cargos_no_tarifa_promedio,
    round(avg(tarifa), 2) AS tarifa_promedio,
    round(avg(total), 2) AS total_promedio
FROM viajes_validos
GROUP BY ALL
ORDER BY periodo
```

| periodo | anio | cargo_cbd_promedio | pct_con_cargo_cbd | recargo_congestion_promedio | cargos_no_tarifa_promedio | tarifa_promedio | total_promedio |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2024-01-01 00:00:00 | 2024 | 0 | 0 | 2.297 | 5.41 | 18.45 | 27.24 |
| 2024-02-01 00:00:00 | 2024 | 0 | 0 | 2.309 | 5.4 | 18.38 | 27.15 |
| 2024-03-01 00:00:00 | 2024 | 0 | 0 | 2.301 | 5.39 | 19.11 | 27.77 |
| 2024-04-01 00:00:00 | 2024 | 0 | 0 | 2.295 | 5.42 | 19.41 | 28.1 |
| 2024-05-01 00:00:00 | 2024 | 0 | 0 | 2.294 | 5.45 | 20.1 | 28.92 |
| 2024-06-01 00:00:00 | 2024 | 0 | 0 | 2.296 | 5.4 | 19.92 | 28.62 |
| 2024-07-01 00:00:00 | 2024 | 0 | 0 | 2.264 | 5.46 | 20.12 | 28.9 |
| 2024-08-01 00:00:00 | 2024 | 0 | 0 | 2.247 | 5.48 | 20.35 | 29.16 |
| 2024-09-01 00:00:00 | 2024 | 0 | 0 | 2.287 | 5.4 | 20.64 | 29.44 |
| 2024-10-01 00:00:00 | 2024 | 0 | 0 | 2.299 | 5.47 | 20.34 | 29.31 |
| 2024-11-01 00:00:00 | 2024 | 0 | 0 | 2.309 | 5.32 | 19.71 | 28.42 |
| 2024-12-01 00:00:00 | 2024 | 0 | 0 | 2.304 | 5.41 | 20.35 | 29.29 |

## Ejercicio 8

### val_cobertura_anual en el ejercicio 8

- Objetivo: Verificar por año y tipo de taxi cuántos archivos, meses y registros cubre la vista conjunta y su rango de fechas.
- Fuentes: vista viajes sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/03_incorporacion.sql
- Resultado: 6 filas y 7 columnas en 3.52 s
- Decisión: Cada año incorporado debe aparecer con todos sus meses publicados sin alterar los conteos de los años que ya existían.

```sql
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    count(DISTINCT archivo) AS archivos,
    count(DISTINCT mes_archivo) AS meses,
    count(*) AS registros,
    min(fecha_recogida) FILTER (WHERE year(fecha_recogida) = anio_archivo) AS primera_recogida,
    max(fecha_recogida) FILTER (WHERE year(fecha_recogida) = anio_archivo) AS ultima_recogida
FROM viajes
GROUP BY ALL
ORDER BY anio, tipo_taxi DESC
```

| anio | tipo_taxi | archivos | meses | registros | primera_recogida | ultima_recogida |
| --- | --- | --- | --- | --- | --- | --- |
| 2024 | yellow | 12 | 12 | 41169720 | 2024-01-01 00:00:00 | 2024-12-31 23:59:58 |
| 2024 | green | 12 | 12 | 660218 | 2024-01-01 00:03:57 | 2024-12-31 23:58:02 |
| 2025 | yellow | 12 | 12 | 48722602 | 2025-01-01 00:00:00 | 2025-12-31 23:59:59 |
| 2025 | green | 12 | 12 | 591375 | 2025-01-01 00:01:11 | 2025-12-31 23:59:09 |
| 2026 | yellow | 8 | 8 | 29703355 | 2026-01-01 00:00:00 | 2026-08-31 23:59:59 |
| 2026 | green | 8 | 8 | 337114 | 2026-01-01 00:03:27 | 2026-08-31 23:58:28 |

### val_conteo_por_archivo en el ejercicio 8

- Objetivo: Comparar archivo por archivo los registros que lee la vista conjunta con los registros declarados en los metadatos Parquet.
- Fuentes: data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/03_incorporacion.sql
- Resultado: 1 filas y 4 columnas en 0.72 s
- Decisión: Una diferencia distinta de cero indicaría que la unión de esquemas pierde o duplica filas; el resultado esperado es cero diferencias.

```sql
WITH metadatos AS (
    SELECT regexp_extract(file_name, '[^/\\]+$') AS archivo, num_rows AS registros_metadatos
    FROM parquet_file_metadata(['data/raw/yellow/2024/*.parquet', 'data/raw/yellow/2025/*.parquet', 'data/raw/yellow/2026/*.parquet', 'data/raw/green/2024/*.parquet', 'data/raw/green/2025/*.parquet', 'data/raw/green/2026/*.parquet'])
),
lectura AS (
    SELECT archivo, count(*) AS registros_vista
    FROM viajes
    GROUP BY ALL
)
SELECT
    count(*) AS archivos,
    CAST(sum(registros_metadatos) AS BIGINT) AS registros_metadatos,
    CAST(sum(registros_vista) AS BIGINT) AS registros_vista,
    count(*) FILTER (WHERE registros_vista IS DISTINCT FROM registros_metadatos) AS archivos_con_diferencia
FROM metadatos
FULL JOIN lectura USING (archivo)
```

| archivos | registros_metadatos | registros_vista | archivos_con_diferencia |
| --- | --- | --- | --- |
| 64 | 121184384 | 121184384 | 0 |

### val_esquema_por_anio en el ejercicio 8

- Objetivo: Identificar columnas que existen solo en algunos años o cuyo tipo físico cambia de un año a otro.
- Fuentes: data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/03_incorporacion.sql
- Resultado: 4 filas y 4 columnas en 0.16 s
- Decisión: Las columnas nuevas o con otro tipo se resuelven en la vista normalizada, que rellena con nulos y convierte a un tipo común, por lo que las consultas de análisis no cambian.

```sql
WITH esquema AS (
    SELECT
        regexp_extract(file_name, '(yellow|green)_tripdata', 1) AS tipo_taxi,
        CAST(regexp_extract(file_name, '(\d{4})-\d{2}\.parquet$', 1) AS INTEGER) AS anio,
        lower(name) AS columna,
        duckdb_type AS tipo
    FROM parquet_schema(['data/raw/yellow/2024/*.parquet', 'data/raw/yellow/2025/*.parquet', 'data/raw/yellow/2026/*.parquet', 'data/raw/green/2024/*.parquet', 'data/raw/green/2025/*.parquet', 'data/raw/green/2026/*.parquet'])
    WHERE name <> 'schema'
),
por_columna AS (
    SELECT
        tipo_taxi,
        columna,
        string_agg(DISTINCT CAST(anio AS VARCHAR), ', ' ORDER BY CAST(anio AS VARCHAR)) AS anios_presente,
        string_agg(DISTINCT anio || ' ' || tipo, ', ' ORDER BY anio || ' ' || tipo) AS tipos_por_anio,
        count(DISTINCT anio) AS n_anios,
        count(DISTINCT tipo) AS n_tipos
    FROM esquema
    GROUP BY ALL
)
SELECT tipo_taxi, columna, anios_presente, tipos_por_anio
FROM por_columna
WHERE n_anios < (SELECT count(DISTINCT anio) FROM esquema) OR n_tipos > 1
ORDER BY tipo_taxi DESC, columna
```

| tipo_taxi | columna | anios_presente | tipos_por_anio |
| --- | --- | --- | --- |
| yellow | cbd_congestion_fee | 2025, 2026 | 2025 DOUBLE, 2026 DOUBLE |
| yellow | request_source | 2026 | 2026 VARCHAR |
| green | cbd_congestion_fee | 2025, 2026 | 2025 DOUBLE, 2026 DOUBLE |
| green | request_source | 2026 | 2026 VARCHAR |

### e4_calidad_exclusiones en el ejercicio 8

- Objetivo: Pregunta 1. Qué proporción de registros incumple alguna regla de calidad y por qué motivo, en cada tipo de taxi.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 18 filas y 4 columnas en 11.40 s
- Decisión: Si las exclusiones son una fracción pequeña del total, el análisis sobre viajes válidos representa bien al conjunto; los motivos dominantes se reportan como limitaciones.

```sql
SELECT
    tipo_taxi,
    coalesce(motivo_exclusion, 'Válido') AS clasificacion,
    count(*) AS registros,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 3) AS porcentaje
FROM viajes_calidad
GROUP BY tipo_taxi, clasificacion
ORDER BY tipo_taxi DESC, registros DESC
```

| tipo_taxi | clasificacion | registros | porcentaje |
| --- | --- | --- | --- |
| yellow | Válido | 112062682 | 93.7 |
| yellow | Monto negativo o ajuste | 3429034 | 2.867 |
| yellow | Distancia cero | 3092303 | 2.586 |
| yellow | Duración nula o negativa | 931496 | 0.779 |
| yellow | Duración mayor a 6 horas | 44218 | 0.037 |
| yellow | Velocidad mayor a 80 mph | 31164 | 0.026 |
| yellow | Distancia mayor a 200 millas | 3944 | 0.003 |
| yellow | Fecha fuera del mes del archivo | 780 | 0.001 |
| yellow | Total mayor a 1000 dólares | 56 | 0 |
| green | Válido | 1499624 | 94.39 |
| green | Distancia cero | 69798 | 4.393 |
| green | Velocidad mayor a 80 mph | 6343 | 0.399 |

### e4_viajes_mensuales en el ejercicio 8

- Objetivo: Pregunta 2. Cómo evoluciona el número de viajes y el ingreso de cada mes por tipo de taxi.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 64 filas y 7 columnas en 17.34 s
- Decisión: Los meses con menos días o con eventos particulares se comparan con viajes promedio por día y no solo con el total mensual.

```sql
SELECT
    tipo_taxi,
    anio_archivo AS anio,
    mes_archivo AS mes,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 0) AS viajes_por_dia,
    round(sum(total) / 1e6, 3) AS ingreso_millones,
    round(avg(total), 2) AS total_promedio
FROM viajes_validos
GROUP BY ALL
ORDER BY tipo_taxi DESC, anio, mes
```

| tipo_taxi | anio | mes | viajes | viajes_por_dia | ingreso_millones | total_promedio |
| --- | --- | --- | --- | --- | --- | --- |
| yellow | 2024 | 1 | 2867133 | 92,488 | 78.37 | 27.33 |
| yellow | 2024 | 2 | 2899130 | 99,970 | 78.94 | 27.23 |
| yellow | 2024 | 3 | 3437442 | 110,885 | 95.73 | 27.85 |
| yellow | 2024 | 4 | 3411726 | 113,724 | 96.14 | 28.18 |
| yellow | 2024 | 5 | 3615186 | 116,619 | 104.8 | 28.99 |
| yellow | 2024 | 6 | 3425728 | 114,191 | 98.25 | 28.68 |
| yellow | 2024 | 7 | 2971467 | 95,854 | 86.09 | 28.97 |
| yellow | 2024 | 8 | 2864961 | 92,418 | 83.71 | 29.22 |
| yellow | 2024 | 9 | 3481642 | 116,055 | 102.6 | 29.48 |
| yellow | 2024 | 10 | 3679557 | 118,695 | 108.1 | 29.38 |
| yellow | 2024 | 11 | 3507658 | 116,922 | 99.89 | 28.48 |
| yellow | 2024 | 12 | 3516644 | 113,440 | 103.3 | 29.37 |

### e4_patron_horario en el ejercicio 8

- Objetivo: Pregunta 3. En qué horas y tipo de día se concentra la demanda y cómo cambia la velocidad del tráfico.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 48 filas y 6 columnas en 22.27 s
- Decisión: El promedio diario por hora permite comparar entre semana y fin de semana aunque tengan distinto número de días.

```sql
SELECT
    tipo_dia,
    hora,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 1) AS viajes_por_dia,
    round(median(duracion_min), 1) AS duracion_mediana_min,
    round(median(velocidad_mph), 1) AS velocidad_mediana_mph
FROM viajes_validos
GROUP BY ALL
ORDER BY tipo_dia, hora
```

| tipo_dia | hora | viajes | viajes_por_dia | duracion_mediana_min | velocidad_mediana_mph |
| --- | --- | --- | --- | --- | --- |
| Entre semana | 0 | 1613746 | 2,319 | 12.7 | 13.6 |
| Entre semana | 1 | 809607 | 1,163 | 11.9 | 14.4 |
| Entre semana | 2 | 448964 | 645.1 | 11.4 | 14.7 |
| Entre semana | 3 | 303786 | 436.5 | 11.9 | 15.4 |
| Entre semana | 4 | 345756 | 496.8 | 14 | 17.1 |
| Entre semana | 5 | 638606 | 917.5 | 12.7 | 16 |
| Entre semana | 6 | 1457978 | 2,095 | 11.6 | 13.5 |
| Entre semana | 7 | 2856847 | 4,105 | 12.2 | 10.7 |
| Entre semana | 8 | 3821874 | 5,491 | 13.6 | 8.8 |
| Entre semana | 9 | 3811950 | 5,477 | 14.1 | 8.2 |
| Entre semana | 10 | 3731738 | 5,362 | 14.6 | 7.9 |
| Entre semana | 11 | 3894608 | 5,596 | 15.1 | 7.5 |

### e4_caracteristicas_tipo en el ejercicio 8

- Objetivo: Pregunta 4. En qué se diferencian los viajes de taxis amarillos y verdes en distancia, duración, pasajeros y monto.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 2 filas y 12 columnas en 68.58 s
- Decisión: Se reportan medianas y percentiles porque las distribuciones de distancia y monto son asimétricas y el promedio se ve arrastrado por los viajes largos.

```sql
SELECT
    tipo_taxi,
    count(*) AS viajes,
    round(avg(pasajeros), 2) AS pasajeros_promedio,
    round(quantile_cont(distancia_millas, 0.25), 2) AS distancia_p25,
    round(median(distancia_millas), 2) AS distancia_mediana,
    round(quantile_cont(distancia_millas, 0.75), 2) AS distancia_p75,
    round(quantile_cont(distancia_millas, 0.99), 2) AS distancia_p99,
    round(median(duracion_min), 1) AS duracion_mediana,
    round(quantile_cont(duracion_min, 0.99), 1) AS duracion_p99,
    round(median(total), 2) AS total_mediano,
    round(quantile_cont(total, 0.99), 2) AS total_p99,
    round(100.0 * count(*) FILTER (WHERE aeropuerto <> 'Sin aeropuerto') / count(*), 2) AS pct_aeropuerto
FROM viajes_validos
GROUP BY ALL
ORDER BY tipo_taxi DESC
```

| tipo_taxi | viajes | pasajeros_promedio | distancia_p25 | distancia_mediana | distancia_p75 | distancia_p99 | duracion_mediana | duracion_p99 | total_mediano | total_p99 | pct_aeropuerto |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| yellow | 112062682 | 1.3 | 1.09 | 1.86 | 3.68 | 19.79 | 13.5 | 70.9 | 22.1 | 104.9 | 9.13 |
| green | 1499624 | 1.31 | 1.3 | 2.04 | 3.57 | 17.22 | 12.6 | 65.4 | 19.85 | 95.22 | 3.84 |

### e4_distribucion_distancia en el ejercicio 8

- Objetivo: Pregunta 5. Cómo se distribuyen las distancias de los viajes en intervalos de una milla por tipo de taxi.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 62 filas y 4 columnas en 20.06 s
- Decisión: La distribución por intervalos permite ver la cola de viajes largos que el resumen estadístico solo insinúa.

```sql
SELECT
    tipo_taxi,
    least(floor(distancia_millas), 30) AS millas,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 3) AS porcentaje
FROM viajes_validos
GROUP BY tipo_taxi, millas
ORDER BY tipo_taxi DESC, millas
```

| tipo_taxi | millas | viajes | porcentaje |
| --- | --- | --- | --- |
| yellow | 0 | 23862024 | 21.29 |
| yellow | 1 | 35495336 | 31.68 |
| yellow | 2 | 17982394 | 16.05 |
| yellow | 3 | 8942943 | 7.98 |
| yellow | 4 | 5108049 | 4.558 |
| yellow | 5 | 3418332 | 3.05 |
| yellow | 6 | 2486453 | 2.219 |
| yellow | 7 | 1950037 | 1.74 |
| yellow | 8 | 1963089 | 1.752 |
| yellow | 9 | 1903754 | 1.699 |
| yellow | 10 | 1486072 | 1.326 |
| yellow | 11 | 1049444 | 0.936 |

### e4_pago_propina en el ejercicio 8

- Objetivo: Pregunta 6. Cómo se reparten los métodos de pago y qué porcentaje de propina se registra en cada uno.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 10 filas y 7 columnas en 23.77 s
- Decisión: La TLC solo registra propinas pagadas con tarjeta, por lo que el porcentaje de propina se calcula sobre pagos con tarjeta.

```sql
SELECT
    tipo_taxi,
    metodo_pago,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS porcentaje_viajes,
    round(avg(total), 2) AS total_promedio,
    round(100.0 * count(*) FILTER (WHERE propina > 0) / count(*), 2) AS pct_con_propina,
    round(median(100.0 * propina / nullif(tarifa, 0)), 2) AS propina_mediana_pct
FROM viajes_validos
GROUP BY tipo_taxi, metodo_pago
ORDER BY tipo_taxi DESC, viajes DESC
```

| tipo_taxi | metodo_pago | viajes | porcentaje_viajes | total_promedio | pct_con_propina | propina_mediana_pct |
| --- | --- | --- | --- | --- | --- | --- |
| yellow | Tarjeta de crédito | 78941242 | 70.44 | 29.93 | 93 | 26.17 |
| yellow | Sin registro | 19581657 | 17.47 | 28.33 | 9.98 | 0 |
| yellow | Efectivo | 12130568 | 10.82 | 25.25 | 0.01 | 0 |
| yellow | Disputa | 1037769 | 0.93 | 28.96 | 0.08 | 0 |
| yellow | Sin cargo | 371446 | 0.33 | 25.33 | 0.09 | 0 |
| green | Tarjeta de crédito | 1022271 | 68.17 | 25.41 | 91.4 | 23.49 |
| green | Efectivo | 354656 | 23.65 | 20.95 | 0 | 0 |
| green | Sin registro | 117214 | 7.82 | 31.1 | 34.47 | 0 |
| green | Sin cargo | 4039 | 0.27 | 15.27 | 0.2 | 0 |
| green | Disputa | 1444 | 0.1 | 15.59 | 0.07 | 0 |

### e4_zonas_origen en el ejercicio 8

- Objetivo: Pregunta 7. Desde qué zonas y distritos sale la mayor parte de los viajes de cada tipo de taxi.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 20 filas y 6 columnas en 18.11 s
- Decisión: Se comparan las diez zonas principales de cada tipo para verificar la separación geográfica de los servicios.

```sql
SELECT *
FROM (
    SELECT
        tipo_taxi,
        nombre_origen AS zona,
        distrito_origen AS distrito,
        count(*) AS viajes,
        round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS porcentaje,
        row_number() OVER (PARTITION BY tipo_taxi ORDER BY count(*) DESC) AS posicion
    FROM viajes_validos
    GROUP BY tipo_taxi, nombre_origen, distrito_origen
)
WHERE posicion <= 10
ORDER BY tipo_taxi DESC, posicion
```

| tipo_taxi | zona | distrito | viajes | porcentaje | posicion |
| --- | --- | --- | --- | --- | --- |
| yellow | Upper East Side South | Manhattan | 5122068 | 4.57 | 1 |
| yellow | Midtown Center | Manhattan | 4977924 | 4.44 | 2 |
| yellow | JFK Airport | Queens | 4872415 | 4.35 | 3 |
| yellow | Upper East Side North | Manhattan | 4550351 | 4.06 | 4 |
| yellow | Midtown East | Manhattan | 3657392 | 3.26 | 5 |
| yellow | Penn Station/Madison Sq West | Manhattan | 3635966 | 3.24 | 6 |
| yellow | Times Sq/Theatre District | Manhattan | 3547569 | 3.17 | 7 |
| yellow | Lincoln Square East | Manhattan | 3378437 | 3.01 | 8 |
| yellow | LaGuardia Airport | Queens | 3200910 | 2.86 | 9 |
| yellow | Murray Hill | Manhattan | 3062526 | 2.73 | 10 |
| green | East Harlem North | Manhattan | 376142 | 25.08 | 1 |
| green | East Harlem South | Manhattan | 212373 | 14.16 | 2 |

### e4_aeropuertos en el ejercicio 8

- Objetivo: Pregunta 8. Cuánto pesan los viajes de aeropuerto y en qué se diferencian del resto.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 8 filas y 7 columnas en 30.31 s
- Decisión: Los viajes de aeropuerto se analizan aparte porque tienen tarifa fija o recargos propios y elevan los promedios generales.

```sql
SELECT
    tipo_taxi,
    aeropuerto,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS porcentaje,
    round(median(distancia_millas), 2) AS distancia_mediana,
    round(median(duracion_min), 1) AS duracion_mediana,
    round(median(total), 2) AS total_mediano
FROM viajes_validos
GROUP BY tipo_taxi, aeropuerto
ORDER BY tipo_taxi DESC, viajes DESC
```

| tipo_taxi | aeropuerto | viajes | porcentaje | distancia_mediana | duracion_mediana | total_mediano |
| --- | --- | --- | --- | --- | --- | --- |
| yellow | Sin aeropuerto | 101832507 | 90.87 | 1.7 | 12.6 | 21 |
| yellow | JFK | 5760615 | 5.14 | 17.18 | 43.2 | 89.56 |
| yellow | LaGuardia | 4236125 | 3.78 | 9.58 | 28.8 | 69.31 |
| yellow | Newark | 233435 | 0.21 | 17.5 | 37.5 | 129.1 |
| green | Sin aeropuerto | 1442077 | 96.16 | 1.97 | 12.4 | 19.32 |
| green | LaGuardia | 43898 | 2.93 | 3.95 | 13.1 | 33.12 |
| green | JFK | 12809 | 0.85 | 14.24 | 37 | 74.16 |
| green | Newark | 840 | 0.06 | 21.4 | 44.8 | 144.7 |

### e4_atipicos_tarifa en el ejercicio 8

- Objetivo: Pregunta 9. Qué viajes válidos tienen una tarifa por milla atípica según el criterio de rango intercuartílico.
- Fuentes: vistas sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 2 filas y 8 columnas en 38.56 s
- Decisión: Los viajes fuera del rango intercuartílico no se eliminan porque pueden ser legítimos, como tarifas negociadas o viajes muy cortos; se reporta su proporción.

```sql
WITH tarifas AS (
    SELECT tipo_taxi, tarifa / distancia_millas AS tarifa_por_milla
    FROM viajes_validos
    WHERE distancia_millas >= 0.1
),
limites AS (
    SELECT
        tipo_taxi,
        quantile_cont(tarifa_por_milla, 0.25) AS q1,
        quantile_cont(tarifa_por_milla, 0.75) AS q3
    FROM tarifas
    GROUP BY ALL
)
SELECT
    t.tipo_taxi,
    round(l.q1, 2) AS q1,
    round(l.q3, 2) AS q3,
    round(l.q3 + 1.5 * (l.q3 - l.q1), 2) AS limite_superior,
    count(*) AS viajes,
    count(*) FILTER (WHERE t.tarifa_por_milla > l.q3 + 1.5 * (l.q3 - l.q1)) AS atipicos_altos,
    count(*) FILTER (WHERE t.tarifa_por_milla < l.q1 - 1.5 * (l.q3 - l.q1)) AS atipicos_bajos,
    round(100.0 * count(*) FILTER (WHERE t.tarifa_por_milla > l.q3 + 1.5 * (l.q3 - l.q1)
                                     OR t.tarifa_por_milla < l.q1 - 1.5 * (l.q3 - l.q1)) / count(*), 2) AS pct_atipicos
FROM tarifas t
JOIN limites l USING (tipo_taxi)
GROUP BY ALL
ORDER BY t.tipo_taxi DESC
```

| tipo_taxi | q1 | q3 | limite_superior | viajes | atipicos_altos | atipicos_bajos | pct_atipicos |
| --- | --- | --- | --- | --- | --- | --- | --- |
| yellow | 5.67 | 9.49 | 15.23 | 111405975 | 5390202 | 0 | 4.84 |
| green | 5.6 | 8.16 | 11.99 | 1488020 | 73409 | 55461 | 8.66 |

### ind_01_resumen_anual en el ejercicio 8

- Pregunta: P1. ¿Cuántos viajes válidos e ingresos genera el servicio de taxis cada año y cuál es el monto promedio por viaje?
- Objetivo: Resumir en tarjetas numéricas los indicadores generales de cada año.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 3 filas y 9 columnas en 25.41 s
- Justificación: Es el punto de partida del tablero, da la escala del servicio y permite comparar años con viajes e ingreso por día aunque 2026 esté incompleto.

```sql
SELECT
    anio_archivo AS anio,
    count(DISTINCT mes_archivo) AS meses,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 0) AS viajes_por_dia,
    round(sum(total), 2) AS ingreso_total,
    round(sum(total) / count(DISTINCT fecha), 2) AS ingreso_por_dia,
    round(avg(total), 2) AS ticket_promedio,
    round(median(distancia_millas), 2) AS distancia_mediana,
    round(median(duracion_min), 2) AS duracion_mediana
FROM viajes_validos
GROUP BY ALL
ORDER BY anio
```

| anio | meses | viajes | viajes_por_dia | ingreso_total | ingreso_por_dia | ticket_promedio | distancia_mediana | duracion_mediana |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2024 | 12 | 40297639 | 110,103 | 1,150,848,913 | 3,144,396 | 28.56 | 1.8 | 13.07 |
| 2025 | 12 | 44713431 | 122,503 | 1,287,517,360 | 3,527,445 | 28.79 | 1.9 | 13.52 |
| 2026 | 8 | 28551236 | 117,495 | 861,990,774 | 3,547,287 | 30.19 | 1.93 | 14.1 |

### ind_02_tendencia_mensual en el ejercicio 8

- Pregunta: P2. ¿Cómo evoluciona mes a mes la demanda de taxis amarillos y verdes?
- Objetivo: Construir la serie mensual de viajes por día e ingreso por tipo de taxi.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 64 filas y 7 columnas en 20.33 s
- Justificación: La serie temporal muestra estacionalidad y tendencia; se usa viajes por día para que los meses de distinta duración sean comparables.

```sql
SELECT
    make_date(anio_archivo, mes_archivo, 1) AS periodo,
    anio_archivo AS anio,
    mes_archivo AS mes,
    tipo_taxi,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 1) AS viajes_por_dia,
    round(sum(total), 2) AS ingreso
FROM viajes_validos
GROUP BY ALL
ORDER BY periodo, tipo_taxi DESC
```

| periodo | anio | mes | tipo_taxi | viajes | viajes_por_dia | ingreso |
| --- | --- | --- | --- | --- | --- | --- |
| 2024-01-01 00:00:00 | 2024 | 1 | yellow | 2867133 | 92,488 | 78,367,600 |
| 2024-01-01 00:00:00 | 2024 | 1 | green | 53149 | 1,714 | 1,178,701 |
| 2024-02-01 00:00:00 | 2024 | 2 | yellow | 2899130 | 99,970 | 78,938,879 |
| 2024-02-01 00:00:00 | 2024 | 2 | green | 50269 | 1,733 | 1,129,037 |
| 2024-03-01 00:00:00 | 2024 | 3 | yellow | 3437442 | 110,885 | 95,732,873 |
| 2024-03-01 00:00:00 | 2024 | 3 | green | 53949 | 1,740 | 1,227,853 |
| 2024-04-01 00:00:00 | 2024 | 4 | yellow | 3411726 | 113,724 | 96,138,862 |
| 2024-04-01 00:00:00 | 2024 | 4 | green | 52797 | 1,760 | 1,228,793 |
| 2024-05-01 00:00:00 | 2024 | 5 | yellow | 3615186 | 116,619 | 104,787,862 |
| 2024-05-01 00:00:00 | 2024 | 5 | green | 57323 | 1,849 | 1,403,016 |
| 2024-06-01 00:00:00 | 2024 | 6 | yellow | 3425728 | 114,191 | 98,249,305 |
| 2024-06-01 00:00:00 | 2024 | 6 | green | 51520 | 1,717 | 1,275,345 |

### ind_03_demanda_horaria en el ejercicio 8

- Pregunta: P3. ¿En qué horas del día se concentra la demanda y cómo cambia entre semana y fin de semana?
- Objetivo: Calcular los viajes promedio por día en cada hora, separando días entre semana y fines de semana.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 144 filas y 5 columnas en 19.01 s
- Justificación: Identifica horas pico, útil para asignar flota; el promedio por día evita que entre semana domine solo por tener más días.

```sql
SELECT
    anio_archivo AS anio,
    tipo_dia,
    hora,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 1) AS viajes_promedio_dia
FROM viajes_validos
GROUP BY ALL
ORDER BY anio, tipo_dia, hora
```

| anio | tipo_dia | hora | viajes | viajes_promedio_dia |
| --- | --- | --- | --- | --- |
| 2024 | Entre semana | 0 | 544034 | 2,076 |
| 2024 | Entre semana | 1 | 260405 | 993.9 |
| 2024 | Entre semana | 2 | 141146 | 538.7 |
| 2024 | Entre semana | 3 | 93415 | 356.5 |
| 2024 | Entre semana | 4 | 102298 | 390.5 |
| 2024 | Entre semana | 5 | 192378 | 734.3 |
| 2024 | Entre semana | 6 | 475974 | 1,817 |
| 2024 | Entre semana | 7 | 978006 | 3,733 |
| 2024 | Entre semana | 8 | 1324629 | 5,056 |
| 2024 | Entre semana | 9 | 1347744 | 5,144 |
| 2024 | Entre semana | 10 | 1349864 | 5,152 |
| 2024 | Entre semana | 11 | 1419125 | 5,416 |

### ind_04_velocidad_horaria en el ejercicio 8

- Pregunta: P4. ¿En qué horas el tráfico hace más lentos los viajes?
- Objetivo: Calcular la velocidad mediana y la duración mediana de los viajes en cada hora.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 72 filas y 5 columnas en 22.28 s
- Justificación: La velocidad es un indicador indirecto de congestión; se usa la mediana por ser robusta a registros extremos.

```sql
SELECT
    anio_archivo AS anio,
    hora,
    round(median(velocidad_mph), 2) AS velocidad_mediana_mph,
    round(median(duracion_min), 2) AS duracion_mediana_min,
    round(median(distancia_millas), 2) AS distancia_mediana
FROM viajes_validos
GROUP BY ALL
ORDER BY anio, hora
```

| anio | hora | velocidad_mediana_mph | duracion_mediana_min | distancia_mediana |
| --- | --- | --- | --- | --- |
| 2024 | 0 | 11.84 | 12.12 | 2.21 |
| 2024 | 1 | 12.1 | 11.1 | 2.09 |
| 2024 | 2 | 12.55 | 10.48 | 2.05 |
| 2024 | 3 | 13.55 | 10.37 | 2.2 |
| 2024 | 4 | 15.5 | 11.82 | 2.9 |
| 2024 | 5 | 16.51 | 11.88 | 3.02 |
| 2024 | 6 | 13.97 | 10.5 | 2.3 |
| 2024 | 7 | 11.15 | 11.18 | 1.91 |
| 2024 | 8 | 9.26 | 12.42 | 1.74 |
| 2024 | 9 | 8.96 | 12.75 | 1.7 |
| 2024 | 10 | 8.74 | 13.05 | 1.67 |
| 2024 | 11 | 8.26 | 13.63 | 1.63 |

### ind_05_dia_semana en el ejercicio 8

- Pregunta: P5. ¿Qué días de la semana tienen más viajes y viajes más caros?
- Objetivo: Calcular viajes promedio por fecha y monto promedio para cada día de la semana.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 21 filas y 6 columnas en 25.56 s
- Justificación: Complementa el perfil horario y muestra si el fin de semana cambia el tipo de viaje además del volumen.

```sql
SELECT
    anio_archivo AS anio,
    dia_semana,
    CASE dia_semana WHEN 1 THEN '1 Lunes' WHEN 2 THEN '2 Martes' WHEN 3 THEN '3 Miércoles'
        WHEN 4 THEN '4 Jueves' WHEN 5 THEN '5 Viernes' WHEN 6 THEN '6 Sábado' ELSE '7 Domingo' END AS dia,
    round(count(*) / count(DISTINCT fecha), 1) AS viajes_promedio_dia,
    round(avg(total), 2) AS ticket_promedio,
    round(median(distancia_millas), 2) AS distancia_mediana
FROM viajes_validos
GROUP BY ALL
ORDER BY anio, dia_semana
```

| anio | dia_semana | dia | viajes_promedio_dia | ticket_promedio | distancia_mediana |
| --- | --- | --- | --- | --- | --- |
| 2024 | 1 | 1 Lunes | 94,668 | 29.81 | 1.82 |
| 2024 | 2 | 2 Martes | 109,217 | 28.53 | 1.73 |
| 2024 | 3 | 3 Miércoles | 115,454 | 28.62 | 1.73 |
| 2024 | 4 | 4 Jueves | 121,104 | 29.02 | 1.77 |
| 2024 | 5 | 5 Viernes | 114,578 | 28.46 | 1.77 |
| 2024 | 6 | 6 Sábado | 117,059 | 26.69 | 1.8 |
| 2024 | 7 | 7 Domingo | 98,955 | 29.06 | 1.99 |
| 2025 | 1 | 1 Lunes | 105,504 | 29.81 | 1.9 |
| 2025 | 2 | 2 Martes | 119,834 | 28.82 | 1.8 |
| 2025 | 3 | 3 Miércoles | 126,405 | 28.85 | 1.8 |
| 2025 | 4 | 4 Jueves | 131,238 | 29.3 | 1.81 |
| 2025 | 5 | 5 Viernes | 126,476 | 28.88 | 1.85 |

### ind_06_metodo_pago en el ejercicio 8

- Pregunta: P6. ¿Cómo pagan los pasajeros y cómo cambia la participación de cada método entre años?
- Objetivo: Calcular la participación de cada método de pago por año y tipo de taxi.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 30 filas y 5 columnas en 19.39 s
- Justificación: El método de pago condiciona la propina registrada y refleja la adopción de pagos electrónicos.

```sql
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    metodo_pago,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo, tipo_taxi), 2) AS porcentaje
FROM viajes_validos
GROUP BY anio_archivo, tipo_taxi, metodo_pago
ORDER BY anio, tipo_taxi DESC, viajes DESC
```

| anio | tipo_taxi | metodo_pago | viajes | porcentaje |
| --- | --- | --- | --- | --- |
| 2024 | yellow | Tarjeta de crédito | 30165072 | 76.02 |
| 2024 | yellow | Efectivo | 5277379 | 13.3 |
| 2024 | yellow | Sin registro | 3694944 | 9.31 |
| 2024 | yellow | Disputa | 386120 | 0.97 |
| 2024 | yellow | Sin cargo | 154759 | 0.39 |
| 2024 | green | Tarjeta de crédito | 425653 | 68.72 |
| 2024 | green | Efectivo | 167742 | 27.08 |
| 2024 | green | Sin registro | 23443 | 3.79 |
| 2024 | green | Sin cargo | 1868 | 0.3 |
| 2024 | green | Disputa | 659 | 0.11 |
| 2025 | yellow | Tarjeta de crédito | 30323058 | 68.67 |
| 2025 | yellow | Sin registro | 8844657 | 20.03 |

### ind_07_propina en el ejercicio 8

- Pregunta: P7. ¿Qué porcentaje de propina dejan los pasajeros que pagan con tarjeta y cómo varía por franja horaria y tipo de taxi?
- Objetivo: Calcular el porcentaje promedio y mediano de propina sobre la tarifa en pagos con tarjeta.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 30 filas y 7 columnas en 17.41 s
- Justificación: La propina es parte relevante del ingreso del conductor y solo es observable en pagos con tarjeta, lo que se respeta en el cálculo.

```sql
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    franja_horaria,
    count(*) AS viajes_tarjeta,
    round(avg(propina_pct), 2) AS propina_promedio_pct,
    round(median(propina_pct), 2) AS propina_mediana_pct,
    round(100.0 * count(*) FILTER (WHERE propina > 0) / count(*), 2) AS pct_con_propina
FROM viajes_validos
WHERE tipo_pago = 1 AND tarifa > 0
GROUP BY ALL
ORDER BY anio, tipo_taxi DESC, franja_horaria
```

| anio | tipo_taxi | franja_horaria | viajes_tarjeta | propina_promedio_pct | propina_mediana_pct | pct_con_propina |
| --- | --- | --- | --- | --- | --- | --- |
| 2024 | yellow | 1 Madrugada 0 a 5 | 2223298 | 25.52 | 25.88 | 91.01 |
| 2024 | yellow | 2 Mañana 6 a 9 | 3592351 | 24.13 | 25.13 | 92.52 |
| 2024 | yellow | 3 Mediodía 10 a 15 | 9791667 | 24.13 | 25.13 | 94.21 |
| 2024 | yellow | 4 Tarde 16 a 19 | 8153487 | 26.69 | 27.02 | 95.42 |
| 2024 | yellow | 5 Noche 20 a 23 | 6403924 | 25.25 | 26.13 | 95.62 |
| 2024 | green | 1 Madrugada 0 a 5 | 21221 | 20.91 | 22.72 | 84.65 |
| 2024 | green | 2 Mañana 6 a 9 | 66109 | 20.93 | 22.63 | 90.59 |
| 2024 | green | 3 Mediodía 10 a 15 | 138203 | 21.95 | 23 | 91.75 |
| 2024 | green | 4 Tarde 16 a 19 | 132587 | 23.66 | 25.17 | 92.5 |
| 2024 | green | 5 Noche 20 a 23 | 67520 | 22.57 | 23.91 | 90.93 |
| 2025 | yellow | 1 Madrugada 0 a 5 | 2122437 | 24.64 | 26.25 | 89.04 |
| 2025 | yellow | 2 Mañana 6 a 9 | 3561635 | 24.25 | 25.59 | 89.79 |

### ind_08_zonas_origen en el ejercicio 8

- Pregunta: P8. ¿Desde qué zonas sale la mayor cantidad de viajes de cada tipo de taxi?
- Objetivo: Obtener las 15 zonas de origen con más viajes por año y tipo de taxi.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 90 filas y 7 columnas en 19.71 s
- Justificación: Muestra la concentración geográfica de la demanda y la diferencia de cobertura entre taxis amarillos y verdes.

```sql
SELECT *
FROM (
    SELECT
        anio_archivo AS anio,
        tipo_taxi,
        nombre_origen AS zona,
        distrito_origen AS distrito,
        count(*) AS viajes,
        round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo, tipo_taxi), 2) AS porcentaje,
        row_number() OVER (PARTITION BY anio_archivo, tipo_taxi ORDER BY count(*) DESC) AS posicion
    FROM viajes_validos
    GROUP BY anio_archivo, tipo_taxi, nombre_origen, distrito_origen
)
WHERE posicion <= 15
ORDER BY anio, tipo_taxi DESC, posicion
```

| anio | tipo_taxi | zona | distrito | viajes | porcentaje | posicion |
| --- | --- | --- | --- | --- | --- | --- |
| 2024 | yellow | Upper East Side South | Manhattan | 1871300 | 4.72 | 1 |
| 2024 | yellow | JFK Airport | Queens | 1869013 | 4.71 | 2 |
| 2024 | yellow | Midtown Center | Manhattan | 1860994 | 4.69 | 3 |
| 2024 | yellow | Upper East Side North | Manhattan | 1690950 | 4.26 | 4 |
| 2024 | yellow | Midtown East | Manhattan | 1381041 | 3.48 | 5 |
| 2024 | yellow | Times Sq/Theatre District | Manhattan | 1337752 | 3.37 | 6 |
| 2024 | yellow | Penn Station/Madison Sq West | Manhattan | 1323723 | 3.34 | 7 |
| 2024 | yellow | Lincoln Square East | Manhattan | 1280818 | 3.23 | 8 |
| 2024 | yellow | LaGuardia Airport | Queens | 1260365 | 3.18 | 9 |
| 2024 | yellow | Murray Hill | Manhattan | 1139667 | 2.87 | 10 |
| 2024 | yellow | Midtown North | Manhattan | 1136015 | 2.86 | 11 |
| 2024 | yellow | Upper West Side South | Manhattan | 1111351 | 2.8 | 12 |

### ind_09_distritos en el ejercicio 8

- Pregunta: P9. ¿Cómo se reparten los viajes y el ingreso entre los distritos de la ciudad?
- Objetivo: Calcular viajes, ingreso y ticket promedio por distrito de origen y tipo de taxi.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 47 filas y 7 columnas en 18.67 s
- Justificación: Resume la geografía a un nivel legible y evidencia la especialización de los taxis verdes fuera del centro de Manhattan.

```sql
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    distrito_origen AS distrito,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo, tipo_taxi), 2) AS porcentaje,
    round(sum(total), 2) AS ingreso,
    round(avg(total), 2) AS ticket_promedio
FROM viajes_validos
GROUP BY anio_archivo, tipo_taxi, distrito_origen
ORDER BY anio, tipo_taxi DESC, viajes DESC
```

| anio | tipo_taxi | distrito | viajes | porcentaje | ingreso | ticket_promedio |
| --- | --- | --- | --- | --- | --- | --- |
| 2024 | yellow | Manhattan | 35243274 | 88.82 | 843,201,632 | 23.93 |
| 2024 | yellow | Queens | 3643399 | 9.18 | 266,761,345 | 73.22 |
| 2024 | yellow | Brooklyn | 553755 | 1.4 | 17,620,240 | 31.82 |
| 2024 | yellow | Bronx | 113723 | 0.29 | 4,075,053 | 35.83 |
| 2024 | yellow | Unknown | 113090 | 0.29 | 3,404,802 | 30.11 |
| 2024 | yellow | N/A | 8424 | 0.02 | 684,544 | 81.26 |
| 2024 | yellow | Staten Island | 1453 | 0 | 64,429 | 44.34 |
| 2024 | yellow | EWR | 1156 | 0 | 107,378 | 92.89 |
| 2024 | green | Manhattan | 376730 | 60.83 | 8,218,448 | 21.82 |
| 2024 | green | Queens | 152125 | 24.56 | 3,991,914 | 26.24 |
| 2024 | green | Brooklyn | 83134 | 13.42 | 2,473,542 | 29.75 |
| 2024 | green | Bronx | 6702 | 1.08 | 216,151 | 32.25 |

### ind_10_aeropuertos en el ejercicio 8

- Pregunta: P10. ¿Qué peso tienen los viajes hacia o desde aeropuertos y cuánto más cuestan que un viaje urbano?
- Objetivo: Comparar viajes, participación, monto y duración de los viajes con JFK, LaGuardia, Newark y sin aeropuerto.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 12 filas y 7 columnas en 19.66 s
- Justificación: Los aeropuertos son pocos viajes pero de alto valor, por lo que explican parte importante del ingreso.

```sql
SELECT
    anio_archivo AS anio,
    aeropuerto,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo), 2) AS pct_viajes,
    round(100.0 * sum(total) / sum(sum(total)) OVER (PARTITION BY anio_archivo), 2) AS pct_ingreso,
    round(avg(total), 2) AS ticket_promedio,
    round(median(duracion_min), 1) AS duracion_mediana
FROM viajes_validos
GROUP BY anio_archivo, aeropuerto
ORDER BY anio, viajes DESC
```

| anio | aeropuerto | viajes | pct_viajes | pct_ingreso | ticket_promedio | duracion_mediana |
| --- | --- | --- | --- | --- | --- | --- |
| 2024 | Sin aeropuerto | 36260377 | 89.98 | 72.42 | 22.99 | 12 |
| 2024 | JFK | 2239785 | 5.56 | 16.35 | 84.01 | 43.7 |
| 2024 | LaGuardia | 1695486 | 4.21 | 10.09 | 68.5 | 28.8 |
| 2024 | Newark | 101991 | 0.25 | 1.14 | 128.3 | 38.1 |
| 2025 | Sin aeropuerto | 40778387 | 91.2 | 75.99 | 23.99 | 12.6 |
| 2025 | JFK | 2217549 | 4.96 | 14.32 | 83.16 | 43.7 |
| 2025 | LaGuardia | 1633988 | 3.65 | 8.83 | 69.6 | 28.4 |
| 2025 | Newark | 83507 | 0.19 | 0.85 | 131.3 | 36.9 |
| 2026 | Sin aeropuerto | 26235820 | 91.89 | 79.09 | 25.99 | 13.3 |
| 2026 | JFK | 1316090 | 4.61 | 12.42 | 81.37 | 41.5 |
| 2026 | LaGuardia | 950549 | 3.33 | 7.73 | 70.11 | 28.8 |
| 2026 | Newark | 48777 | 0.17 | 0.75 | 132.9 | 37.2 |

### ind_11_participacion_tipo en el ejercicio 8

- Pregunta: P11. ¿Qué participación tienen los taxis verdes frente a los amarillos en viajes e ingreso y cómo cambia en el tiempo?
- Objetivo: Calcular viajes, ingreso y participación por tipo de taxi y año.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 6 filas y 7 columnas en 16.46 s
- Justificación: Permite seguir la evolución relativa de ambos servicios, que operan con reglas y zonas distintas.

```sql
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo), 2) AS pct_viajes,
    round(sum(total), 2) AS ingreso,
    round(100.0 * sum(total) / sum(sum(total)) OVER (PARTITION BY anio_archivo), 2) AS pct_ingreso,
    round(avg(total), 2) AS ticket_promedio
FROM viajes_validos
GROUP BY anio_archivo, tipo_taxi
ORDER BY anio, tipo_taxi DESC
```

| anio | tipo_taxi | viajes | pct_viajes | ingreso | pct_ingreso | ticket_promedio |
| --- | --- | --- | --- | --- | --- | --- |
| 2024 | yellow | 39678274 | 98.46 | 1,135,919,423 | 98.7 | 28.63 |
| 2024 | green | 619365 | 1.54 | 14,929,490 | 1.3 | 24.1 |
| 2025 | yellow | 44155183 | 98.75 | 1,273,482,487 | 98.91 | 28.84 |
| 2025 | green | 558248 | 1.25 | 14,034,873 | 1.09 | 25.14 |
| 2026 | yellow | 28229225 | 98.87 | 853,818,401 | 99.05 | 30.25 |
| 2026 | green | 322011 | 1.13 | 8,172,373 | 0.95 | 25.38 |

### ind_12_calidad_datos en el ejercicio 8

- Pregunta: P12. ¿Qué proporción de los registros publicados no es utilizable y por qué motivo?
- Objetivo: Contar los registros válidos y excluidos por motivo, año y tipo de taxi.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 52 filas y 5 columnas en 13.20 s
- Justificación: Hace visible la confiabilidad de los demás indicadores y documenta cuántos registros se descartan en cada año.

```sql
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    coalesce(motivo_exclusion, 'Válido') AS clasificacion,
    count(*) AS registros,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo, tipo_taxi), 3) AS porcentaje
FROM viajes_calidad
GROUP BY anio_archivo, tipo_taxi, clasificacion
ORDER BY anio, tipo_taxi DESC, registros DESC
```

| anio | tipo_taxi | clasificacion | registros | porcentaje |
| --- | --- | --- | --- | --- |
| 2024 | yellow | Válido | 39678274 | 96.38 |
| 2024 | yellow | Distancia cero | 764825 | 1.858 |
| 2024 | yellow | Monto negativo o ajuste | 677372 | 1.645 |
| 2024 | yellow | Duración mayor a 6 horas | 21994 | 0.053 |
| 2024 | yellow | Duración nula o negativa | 13510 | 0.033 |
| 2024 | yellow | Velocidad mayor a 80 mph | 12187 | 0.03 |
| 2024 | yellow | Distancia mayor a 200 millas | 1122 | 0.003 |
| 2024 | yellow | Fecha fuera del mes del archivo | 420 | 0.001 |
| 2024 | yellow | Total mayor a 1000 dólares | 16 | 0 |
| 2024 | green | Válido | 619365 | 93.81 |
| 2024 | green | Distancia cero | 33930 | 5.139 |
| 2024 | green | Duración mayor a 6 horas | 2627 | 0.398 |

### ind_13_cargos_mensuales en el ejercicio 8

- Pregunta: P13. ¿Cómo cambian los recargos que paga el pasajero, en particular el cargo de congestión CBD?
- Objetivo: Calcular por mes el monto promedio de cada recargo y el porcentaje de viajes con cargo CBD.
- Fuentes: vista viajes_validos sobre data/raw/yellow/2024/*.parquet, data/raw/yellow/2025/*.parquet, data/raw/yellow/2026/*.parquet, data/raw/green/2024/*.parquet, data/raw/green/2025/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/05_indicadores.sql
- Resultado: 32 filas y 8 columnas en 18.19 s
- Justificación: Los recargos explican cambios en el total pagado que no se deben a la tarifa; el cargo CBD solo aparece en los archivos desde 2025.

```sql
SELECT
    make_date(anio_archivo, mes_archivo, 1) AS periodo,
    anio_archivo AS anio,
    round(avg(coalesce(cargo_cbd, 0)), 3) AS cargo_cbd_promedio,
    round(100.0 * count(*) FILTER (WHERE cargo_cbd > 0) / count(*), 2) AS pct_con_cargo_cbd,
    round(avg(recargo_congestion), 3) AS recargo_congestion_promedio,
    round(avg(total - tarifa - propina), 2) AS cargos_no_tarifa_promedio,
    round(avg(tarifa), 2) AS tarifa_promedio,
    round(avg(total), 2) AS total_promedio
FROM viajes_validos
GROUP BY ALL
ORDER BY periodo
```

| periodo | anio | cargo_cbd_promedio | pct_con_cargo_cbd | recargo_congestion_promedio | cargos_no_tarifa_promedio | tarifa_promedio | total_promedio |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2024-01-01 00:00:00 | 2024 | 0 | 0 | 2.297 | 5.41 | 18.45 | 27.24 |
| 2024-02-01 00:00:00 | 2024 | 0 | 0 | 2.309 | 5.4 | 18.38 | 27.15 |
| 2024-03-01 00:00:00 | 2024 | 0 | 0 | 2.301 | 5.39 | 19.11 | 27.77 |
| 2024-04-01 00:00:00 | 2024 | 0 | 0 | 2.295 | 5.42 | 19.41 | 28.1 |
| 2024-05-01 00:00:00 | 2024 | 0 | 0 | 2.294 | 5.45 | 20.1 | 28.92 |
| 2024-06-01 00:00:00 | 2024 | 0 | 0 | 2.296 | 5.4 | 19.92 | 28.62 |
| 2024-07-01 00:00:00 | 2024 | 0 | 0 | 2.264 | 5.46 | 20.12 | 28.9 |
| 2024-08-01 00:00:00 | 2024 | 0 | 0 | 2.247 | 5.48 | 20.35 | 29.16 |
| 2024-09-01 00:00:00 | 2024 | 0 | 0 | 2.287 | 5.4 | 20.64 | 29.44 |
| 2024-10-01 00:00:00 | 2024 | 0 | 0 | 2.299 | 5.47 | 20.34 | 29.31 |
| 2024-11-01 00:00:00 | 2024 | 0 | 0 | 2.309 | 5.32 | 19.71 | 28.42 |
| 2024-12-01 00:00:00 | 2024 | 0 | 0 | 2.304 | 5.41 | 20.35 | 29.29 |

### e8_evolucion_anual

- Objetivo: Comparar entre años los indicadores principales de volumen, monto, distancia, duración, velocidad y propina.
- Fuentes: vista viajes_validos sobre 2024, 2025 y 2026
- Archivo SQL: sql/03_incorporacion.sql
- Resultado: 3 filas y 12 columnas en 30.66 s
- Decisión: Como 2026 no tiene el año completo, el volumen se compara en viajes por día y los demás indicadores en promedios o medianas.

```sql
SELECT
    anio_archivo AS anio,
    count(DISTINCT mes_archivo) AS meses,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 0) AS viajes_por_dia,
    round(sum(total) / count(DISTINCT fecha), 0) AS ingreso_por_dia,
    round(avg(total), 2) AS total_promedio,
    round(avg(tarifa), 2) AS tarifa_promedio,
    round(median(distancia_millas), 2) AS distancia_mediana,
    round(median(duracion_min), 2) AS duracion_mediana,
    round(median(velocidad_mph), 2) AS velocidad_mediana,
    round(avg(propina_pct), 2) AS propina_pct_tarjeta,
    round(100.0 * count(*) FILTER (WHERE tipo_taxi = 'green') / count(*), 2) AS pct_verdes
FROM viajes_validos
GROUP BY ALL
ORDER BY anio
```

| anio | meses | viajes | viajes_por_dia | ingreso_por_dia | total_promedio | tarifa_promedio | distancia_mediana | duracion_mediana | velocidad_mediana | propina_pct_tarjeta | pct_verdes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2024 | 12 | 40297639 | 110,103 | 3,144,396 | 28.56 | 19.77 | 1.8 | 13.07 | 9.3 | 25.12 | 1.54 |
| 2025 | 12 | 44713431 | 122,503 | 3,527,445 | 28.79 | 19.99 | 1.9 | 13.52 | 9.45 | 25.43 | 1.25 |
| 2026 | 8 | 28551236 | 117,495 | 3,547,287 | 30.19 | 21.24 | 1.93 | 14.1 | 9.29 | 25.07 | 1.13 |

### e8_pago_por_anio

- Objetivo: Analizar cómo cambia la participación de cada método de pago entre años.
- Fuentes: vista viajes_validos sobre 2024, 2025 y 2026
- Archivo SQL: sql/03_incorporacion.sql
- Resultado: 15 filas y 4 columnas en 17.93 s
- Decisión: Un aumento del pago sin registro afecta el cálculo de propinas y debe considerarse al comparar años.

```sql
SELECT
    anio_archivo AS anio,
    metodo_pago,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo), 2) AS porcentaje
FROM viajes_validos
GROUP BY anio_archivo, metodo_pago
ORDER BY anio, viajes DESC
```

| anio | metodo_pago | viajes | porcentaje |
| --- | --- | --- | --- |
| 2024 | Tarjeta de crédito | 30590725 | 75.91 |
| 2024 | Efectivo | 5445121 | 13.51 |
| 2024 | Sin registro | 3718387 | 9.23 |
| 2024 | Disputa | 386779 | 0.96 |
| 2024 | Sin cargo | 156627 | 0.39 |
| 2025 | Tarjeta de crédito | 30708717 | 68.68 |
| 2025 | Sin registro | 8890811 | 19.88 |
| 2025 | Efectivo | 4418801 | 9.88 |
| 2025 | Disputa | 533326 | 1.19 |
| 2025 | Sin cargo | 161776 | 0.36 |
| 2026 | Tarjeta de crédito | 18664071 | 65.37 |
| 2026 | Sin registro | 7089673 | 24.83 |

### e8_cargos_por_anio

- Objetivo: Medir la presencia y el monto promedio de cada recargo por año, incluido el cargo de congestión CBD.
- Fuentes: vista viajes_validos sobre 2024, 2025 y 2026
- Archivo SQL: sql/03_incorporacion.sql
- Resultado: 6 filas y 8 columnas en 17.90 s
- Decisión: El cargo CBD no existe en los archivos de 2024 y la vista lo deja nulo, lo que permite comparar el antes y el después sin cambiar consultas.

```sql
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    round(100.0 * count(*) FILTER (WHERE cargo_cbd > 0) / count(*), 2) AS pct_con_cargo_cbd,
    round(avg(cargo_cbd), 3) AS cargo_cbd_promedio,
    round(avg(recargo_congestion), 3) AS recargo_congestion_promedio,
    round(avg(cargo_aeropuerto), 3) AS cargo_aeropuerto_promedio,
    round(avg(total - tarifa - propina), 2) AS cargos_no_tarifa_promedio,
    round(avg(total), 2) AS total_promedio
FROM viajes_validos
GROUP BY ALL
ORDER BY anio, tipo_taxi DESC
```

| anio | tipo_taxi | pct_con_cargo_cbd | cargo_cbd_promedio | recargo_congestion_promedio | cargo_aeropuerto_promedio | cargos_no_tarifa_promedio | total_promedio |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2024 | yellow | 0 | nan | 2.317 | 0.154 | 5.45 | 28.63 |
| 2024 | green | 0 | nan | 0.856 | nan | 3.41 | 24.1 |
| 2025 | yellow | 73.03 | 0.548 | 2.285 | 0.154 | 5.78 | 28.84 |
| 2025 | green | 9.62 | 0.073 | 0.913 | nan | 4.54 | 25.14 |
| 2026 | yellow | 72.39 | 0.543 | 2.256 | 0.168 | 6.07 | 30.25 |
| 2026 | green | 8.5 | 0.064 | 0.915 | nan | 6.04 | 25.38 |

### e8_calidad_por_anio

- Objetivo: Comparar entre años la proporción de registros excluidos por cada regla de calidad.
- Fuentes: vista viajes_calidad sobre 2024, 2025 y 2026
- Archivo SQL: sql/03_incorporacion.sql
- Resultado: 27 filas y 4 columnas en 12.40 s
- Decisión: Si la calidad cambia entre años, parte de las diferencias en los indicadores puede deberse al registro de los datos y no al comportamiento de los viajes.

```sql
SELECT
    anio_archivo AS anio,
    coalesce(motivo_exclusion, 'Válido') AS clasificacion,
    count(*) AS registros,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo), 3) AS porcentaje
FROM viajes_calidad
GROUP BY anio_archivo, clasificacion
ORDER BY anio, registros DESC
```

| anio | clasificacion | registros | porcentaje |
| --- | --- | --- | --- |
| 2024 | Válido | 40297639 | 96.34 |
| 2024 | Distancia cero | 798755 | 1.91 |
| 2024 | Monto negativo o ajuste | 678700 | 1.623 |
| 2024 | Duración mayor a 6 horas | 24621 | 0.059 |
| 2024 | Duración nula o negativa | 14170 | 0.034 |
| 2024 | Velocidad mayor a 80 mph | 14101 | 0.034 |
| 2024 | Distancia mayor a 200 millas | 1352 | 0.003 |
| 2024 | Fecha fuera del mes del archivo | 584 | 0.001 |
| 2024 | Total mayor a 1000 dólares | 16 | 0 |
| 2025 | Válido | 44713431 | 90.67 |
| 2025 | Monto negativo o ajuste | 2606492 | 5.286 |
| 2025 | Distancia cero | 1410667 | 2.861 |

### e8_hora_por_anio

- Objetivo: Comparar el perfil horario de la demanda y la velocidad entre años.
- Fuentes: vista viajes_validos sobre 2024, 2025 y 2026
- Archivo SQL: sql/03_incorporacion.sql
- Resultado: 72 filas y 4 columnas en 18.96 s
- Decisión: Se usa la participación de cada hora dentro del año para comparar la forma del perfil sin que influya el volumen total.

```sql
SELECT
    anio_archivo AS anio,
    hora,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo), 3) AS pct_viajes,
    round(median(velocidad_mph), 2) AS velocidad_mediana
FROM viajes_validos
GROUP BY anio_archivo, hora
ORDER BY anio, hora
```

| anio | hora | pct_viajes | velocidad_mediana |
| --- | --- | --- | --- |
| 2024 | 0 | 2.861 | 11.84 |
| 2024 | 1 | 1.849 | 12.1 |
| 2024 | 2 | 1.201 | 12.55 |
| 2024 | 3 | 0.784 | 13.55 |
| 2024 | 4 | 0.571 | 15.5 |
| 2024 | 5 | 0.626 | 16.51 |
| 2024 | 6 | 1.417 | 13.97 |
| 2024 | 7 | 2.778 | 11.15 |
| 2024 | 8 | 3.837 | 9.26 |
| 2024 | 9 | 4.201 | 8.96 |
| 2024 | 10 | 4.495 | 8.74 |
| 2024 | 11 | 4.877 | 8.26 |

## Capas de preparación

### crear_tabla_zonas

- Objetivo: Cargar la tabla de zonas de taxi de la TLC para traducir los identificadores de zona a distrito y nombre.
- Fuentes: data/raw/zonas/taxi_zone_lookup.csv
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 0 filas y 0 columnas en 0.02 s
- Decisión: Es la única tabla materializada de la capa de análisis porque tiene 265 filas y se une con cada consulta por zona.

```sql
CREATE OR REPLACE TABLE zonas AS
SELECT
    CAST(LocationID AS INTEGER) AS zona,
    Borough AS distrito,
    Zone AS nombre_zona,
    service_zone AS zona_servicio
FROM read_csv('data/raw/zonas/taxi_zone_lookup.csv', header = true)
```

### crear_vista_calidad

- Objetivo: Agregar a cada viaje etiquetas legibles, variables de calendario, velocidad y las reglas de calidad definidas en el Ejercicio 3.
- Fuentes: vista viajes sobre data/raw/yellow/2026/*.parquet, data/raw/green/2026/*.parquet
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 0 filas y 0 columnas en 0.05 s
- Decisión: Ningún registro se elimina de los archivos; las reglas solo marcan el motivo de exclusión para poder contar y justificar cada descarte.

```sql
CREATE OR REPLACE VIEW viajes_calidad AS
WITH base AS (
    SELECT
        *,
        CAST(fecha_recogida AS DATE) AS fecha,
        hour(fecha_recogida) AS hora,
        isodow(fecha_recogida) AS dia_semana,
        CASE WHEN distancia_millas > 0 AND duracion_min > 0
             THEN distancia_millas / (duracion_min / 60.0) END AS velocidad_mph
    FROM viajes
)
SELECT
    *,
    CASE WHEN dia_semana IN (6, 7) THEN 'Fin de semana' ELSE 'Entre semana' END AS tipo_dia,
    CASE
        WHEN hora BETWEEN 0 AND 5 THEN '1 Madrugada 0 a 5'
        WHEN hora BETWEEN 6 AND 9 THEN '2 Mañana 6 a 9'
        WHEN hora BETWEEN 10 AND 15 THEN '3 Mediodía 10 a 15'
        WHEN hora BETWEEN 16 AND 19 THEN '4 Tarde 16 a 19'
        ELSE '5 Noche 20 a 23'
    END AS franja_horaria,
    CASE tipo_pago
        WHEN 1 THEN 'Tarjeta de crédito'
        WHEN 2 THEN 'Efectivo'
        WHEN 3 THEN 'Sin cargo'
        WHEN 4 THEN 'Disputa'
        WHEN 6 THEN 'Viaje anulado'
        ELSE 'Sin registro'
    END AS metodo_pago,
    CASE codigo_tarifa
        WHEN 1 THEN 'Estándar'
        WHEN 2 THEN 'JFK'
        WHEN 3 THEN 'Newark'
        WHEN 4 THEN 'Nassau o Westchester'
        WHEN 5 THEN 'Negociada'
        WHEN 6 THEN 'Viaje grupal'
        ELSE 'Desconocida'
    END AS tarifa_aplicada,
    CASE
        WHEN anio_archivo IS NULL OR year(fecha_recogida) <> anio_archivo OR month(fecha_recogida) <> mes_archivo
            THEN 'Fecha fuera del mes del archivo'
        WHEN duracion_min IS NULL OR duracion_min <= 0 THEN 'Duración nula o negativa'
        WHEN duracion_min > 360 THEN 'Duración mayor a 6 horas'
        WHEN distancia_millas IS NULL OR distancia_millas <= 0 THEN 'Distancia cero'
        WHEN distancia_millas > 200 THEN 'Distancia mayor a 200 millas'
        WHEN velocidad_mph > 80 THEN 'Velocidad mayor a 80 mph'
        WHEN tarifa IS NULL OR total IS NULL OR tarifa < 0 OR total < 0 THEN 'Monto negativo o ajuste'
        WHEN total > 1000 THEN 'Total mayor a 1000 dólares'
        ELSE NULL
    END AS motivo_exclusion
FROM base
```

### crear_vista_validos

- Objetivo: Definir la vista de viajes válidos con distrito y nombre de las zonas de origen y destino.
- Fuentes: vista viajes_calidad y tabla zonas
- Archivo SQL: sql/02_analisis_exploratorio.sql
- Resultado: 0 filas y 0 columnas en 0.05 s
- Decisión: Todo el análisis posterior usa esta vista, de modo que las reglas de calidad se aplican igual en el análisis, el benchmark y el tablero.

```sql
CREATE OR REPLACE VIEW viajes_validos AS
SELECT
    v.* EXCLUDE (motivo_exclusion),
    coalesce(zo.distrito, 'Desconocido') AS distrito_origen,
    coalesce(zo.nombre_zona, 'Desconocida') AS nombre_origen,
    coalesce(zd.distrito, 'Desconocido') AS distrito_destino,
    coalesce(zd.nombre_zona, 'Desconocida') AS nombre_destino,
    CASE
        WHEN v.zona_origen = 132 OR v.zona_destino = 132 THEN 'JFK'
        WHEN v.zona_origen = 138 OR v.zona_destino = 138 THEN 'LaGuardia'
        WHEN v.zona_origen = 1 OR v.zona_destino = 1 THEN 'Newark'
        ELSE 'Sin aeropuerto'
    END AS aeropuerto,
    CASE WHEN v.tipo_pago = 1 AND v.tarifa > 0 THEN 100.0 * v.propina / v.tarifa END AS propina_pct
FROM viajes_calidad v
LEFT JOIN zonas zo ON v.zona_origen = zo.zona
LEFT JOIN zonas zd ON v.zona_destino = zd.zona
WHERE v.motivo_exclusion IS NULL
```
