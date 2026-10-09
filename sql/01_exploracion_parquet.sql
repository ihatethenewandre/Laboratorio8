-- Ejercicio 3. Consultas directas sobre archivos Parquet.
--
-- Todas las consultas leen los archivos descargados sin importarlos a una tabla.
-- Los parámetros entre llaves se sustituyen desde el notebook:
--   {todos}      lista SQL con los patrones glob de todos los archivos de taxis
--   {amarillos}  lista SQL con los patrones glob de taxis amarillos
--   {verdes}     lista SQL con los patrones glob de taxis verdes
-- Cada bloque comienza con "-- id:" y sus metadatos documentan objetivo, fuentes y decisión.

-- id: e3_inventario_archivos
-- ejercicio: 3
-- objetivo: Contar los archivos disponibles y obtener sus filas, grupos de filas y tamaño leyendo solo los metadatos Parquet.
-- fuentes: data/raw/yellow/<anio>/*.parquet y data/raw/green/<anio>/*.parquet
-- decision: El número de archivos por tipo debe coincidir con los meses publicados por la TLC; el conteo de filas por metadatos sirve de referencia para validar lecturas posteriores.
SELECT
    regexp_extract(file_name, '(yellow|green)_tripdata', 1) AS tipo_taxi,
    regexp_extract(file_name, '(\d{4}-\d{2})\.parquet$', 1) AS periodo,
    regexp_extract(file_name, '[^/\\]+$') AS archivo,
    num_rows AS registros,
    num_row_groups AS grupos_filas,
    round(file_size_bytes / 1e6, 2) AS mb
FROM parquet_file_metadata({todos})
ORDER BY tipo_taxi DESC, periodo;

-- id: e3_resumen_archivos
-- ejercicio: 3
-- objetivo: Resumir por tipo de taxi la cantidad de archivos, de registros y el volumen en disco.
-- fuentes: metadatos de todos los archivos Parquet descargados
-- decision: Los taxis amarillos concentran la mayor parte del volumen, por lo que dominan los tiempos de consulta y cualquier agregado que no separe por tipo.
SELECT
    regexp_extract(file_name, '(yellow|green)_tripdata', 1) AS tipo_taxi,
    count(*) AS archivos,
    CAST(sum(num_rows) AS BIGINT) AS registros,
    round(sum(file_size_bytes) / 1e6, 1) AS mb,
    CAST(round(sum(num_rows) / count(*)) AS BIGINT) AS registros_por_archivo
FROM parquet_file_metadata({todos})
GROUP BY ALL
ORDER BY tipo_taxi DESC;

-- id: e3_conteo_lectura
-- ejercicio: 3
-- objetivo: Contar los registros leyendo los datos con read_parquet para confirmar que coinciden con los metadatos.
-- fuentes: todos los archivos Parquet descargados, leídos con union_by_name
-- decision: Si el conteo coincide con los metadatos, la lectura conjunta con union_by_name no pierde ni duplica registros.
SELECT
    regexp_extract(filename, '(yellow|green)_tripdata', 1) AS tipo_taxi,
    count(*) AS registros_leidos
FROM read_parquet({todos}, union_by_name = true, filename = true)
GROUP BY ALL
ORDER BY tipo_taxi DESC;

-- id: e3_esquema_amarillos
-- ejercicio: 3
-- objetivo: Listar las columnas y los tipos de datos que DuckDB infiere al leer en conjunto los archivos de taxis amarillos.
-- fuentes: data/raw/yellow/<anio>/*.parquet
-- decision: Las columnas de fecha usan el prefijo tpep y los identificadores de zona son enteros que se cruzan con la tabla de zonas.
DESCRIBE SELECT * FROM read_parquet({amarillos}, union_by_name = true);

-- id: e3_esquema_verdes
-- ejercicio: 3
-- objetivo: Listar las columnas y los tipos de datos de los archivos de taxis verdes.
-- fuentes: data/raw/green/<anio>/*.parquet
-- decision: Los taxis verdes usan el prefijo lpep y tienen columnas propias, ehail_fee y trip_type, por lo que se construye una vista con nombres comunes para comparar ambos tipos.
DESCRIBE SELECT * FROM read_parquet({verdes}, union_by_name = true);

-- id: e3_variaciones_esquema
-- ejercicio: 3
-- objetivo: Detectar columnas cuyo nombre exacto o tipo físico cambia entre archivos, o que no aparecen en todos los archivos de un tipo.
-- fuentes: esquema interno de cada archivo Parquet mediante parquet_schema
-- decision: Las columnas con variaciones se leen con union_by_name, se comparan sin distinguir mayúsculas y se convierten a un tipo común en la vista normalizada.
WITH esquema AS (
    SELECT
        regexp_extract(file_name, '(yellow|green)_tripdata', 1) AS tipo_taxi,
        file_name,
        name AS columna,
        duckdb_type AS tipo
    FROM parquet_schema({todos})
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
ORDER BY e.tipo_taxi DESC, columna;

-- id: e3_muestra_amarillos
-- ejercicio: 3
-- objetivo: Obtener una muestra aleatoria reproducible de registros de taxis amarillos.
-- fuentes: data/raw/yellow/<anio>/*.parquet
-- decision: La muestra permite revisar el formato real de fechas, montos y códigos antes de definir reglas de calidad.
SELECT *
FROM read_parquet({amarillos}, union_by_name = true)
USING SAMPLE reservoir(8 ROWS) REPEATABLE (42);

-- id: e3_muestra_verdes
-- ejercicio: 3
-- objetivo: Obtener una muestra aleatoria reproducible de registros de taxis verdes.
-- fuentes: data/raw/green/<anio>/*.parquet
-- decision: Se confirma que los verdes comparten la mayoría de columnas con los amarillos, con nombres de fecha distintos.
SELECT *
FROM read_parquet({verdes}, union_by_name = true)
USING SAMPLE reservoir(8 ROWS) REPEATABLE (42);

-- id: e3_resumen_estadistico
-- ejercicio: 3
-- objetivo: Obtener mínimos, máximos, promedios, cuartiles y porcentaje de nulos de cada columna de taxis amarillos con SUMMARIZE.
-- fuentes: data/raw/yellow/<anio>/*.parquet
-- decision: Los extremos de distancia, montos y fechas indican valores imposibles que deben marcarse antes del análisis.
SUMMARIZE SELECT * FROM read_parquet({amarillos}, union_by_name = true);

-- id: e3_calidad
-- ejercicio: 3
-- objetivo: Cuantificar por tipo de taxi los principales problemas de calidad observables directamente en los archivos.
-- fuentes: todos los archivos Parquet descargados de taxis amarillos y verdes
-- decision: Cada problema se convierte en una regla de calidad de la vista viajes_calidad; los registros que la incumplen se excluyen del análisis pero se conservan y se cuentan.
WITH amarillos AS (
    SELECT
        'yellow' AS tipo_taxi, filename,
        tpep_pickup_datetime AS recogida, tpep_dropoff_datetime AS destino,
        passenger_count, trip_distance, fare_amount, total_amount, payment_type, RatecodeID, PULocationID
    FROM read_parquet({amarillos}, union_by_name = true, filename = true)
),
verdes AS (
    SELECT
        'green' AS tipo_taxi, filename,
        lpep_pickup_datetime AS recogida, lpep_dropoff_datetime AS destino,
        passenger_count, trip_distance, fare_amount, total_amount, payment_type, RatecodeID, PULocationID
    FROM read_parquet({verdes}, union_by_name = true, filename = true)
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
ORDER BY tipo_taxi DESC;

-- id: e3_rango_fechas
-- ejercicio: 3
-- objetivo: Revisar las fechas mínima y máxima de recogida de cada archivo para detectar registros que no pertenecen al mes publicado.
-- fuentes: todos los archivos Parquet descargados
-- decision: El período de cada registro se toma del nombre del archivo y los viajes cuya fecha cae fuera de ese mes se marcan como inconsistentes.
WITH amarillos AS (
    SELECT filename, tpep_pickup_datetime AS recogida
    FROM read_parquet({amarillos}, union_by_name = true, filename = true)
),
verdes AS (
    SELECT filename, lpep_pickup_datetime AS recogida
    FROM read_parquet({verdes}, union_by_name = true, filename = true)
)
SELECT
    regexp_extract(filename, '[^/\\]+$') AS archivo,
    min(recogida) AS primera_recogida,
    max(recogida) AS ultima_recogida,
    count(*) FILTER (WHERE strftime(recogida, '%Y-%m') <> regexp_extract(filename, '(\d{4}-\d{2})\.parquet$', 1)) AS fuera_del_mes
FROM (SELECT * FROM amarillos UNION ALL SELECT * FROM verdes)
GROUP BY ALL
ORDER BY archivo;

-- id: e3_codigos_pago
-- ejercicio: 3
-- objetivo: Revisar los códigos de tipo de pago presentes en los archivos y su frecuencia.
-- fuentes: todos los archivos Parquet descargados
-- decision: Los códigos se traducen con el diccionario de la TLC; el código 0 y los nulos se tratan como pago sin registro y no como error.
WITH pagos AS (
    SELECT regexp_extract(filename, '(yellow|green)_tripdata', 1) AS tipo_taxi, payment_type AS codigo_pago
    FROM read_parquet({todos}, union_by_name = true, filename = true)
)
SELECT
    tipo_taxi,
    codigo_pago,
    count(*) AS registros,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS porcentaje
FROM pagos
GROUP BY tipo_taxi, codigo_pago
ORDER BY tipo_taxi DESC, codigo_pago;
