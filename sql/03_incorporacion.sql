-- Ejercicios 5 y 8. Validación de la incorporación incremental de años y análisis de evolución.
--
-- Las consultas de validación se ejecutan sin cambios después de agregar 2024 y después
-- de agregar 2025; solo cambia el conjunto de archivos que cubre la vista "viajes".
-- Parámetro: {todos} lista SQL con los patrones glob de todos los archivos de taxis

-- id: val_cobertura_anual
-- ejercicio: 5
-- objetivo: Verificar por año y tipo de taxi cuántos archivos, meses y registros cubre la vista conjunta y su rango de fechas.
-- fuentes: vista viajes sobre todos los años descargados
-- decision: Cada año incorporado debe aparecer con todos sus meses publicados sin alterar los conteos de los años que ya existían.
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
ORDER BY anio, tipo_taxi DESC;

-- id: val_conteo_por_archivo
-- ejercicio: 5
-- objetivo: Comparar archivo por archivo los registros que lee la vista conjunta con los registros declarados en los metadatos Parquet.
-- fuentes: vista viajes y parquet_file_metadata de todos los archivos
-- decision: Una diferencia distinta de cero indicaría que la unión de esquemas pierde o duplica filas; el resultado esperado es cero diferencias.
WITH metadatos AS (
    SELECT regexp_extract(file_name, '[^/\\]+$') AS archivo, num_rows AS registros_metadatos
    FROM parquet_file_metadata({todos})
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
FULL JOIN lectura USING (archivo);

-- id: val_esquema_por_anio
-- ejercicio: 5
-- objetivo: Identificar columnas que existen solo en algunos años o cuyo tipo físico cambia de un año a otro.
-- fuentes: parquet_schema de todos los archivos descargados
-- decision: Las columnas nuevas o con otro tipo se resuelven en la vista normalizada, que rellena con nulos y convierte a un tipo común, por lo que las consultas de análisis no cambian.
WITH esquema AS (
    SELECT
        regexp_extract(file_name, '(yellow|green)_tripdata', 1) AS tipo_taxi,
        CAST(regexp_extract(file_name, '(\d{4})-\d{2}\.parquet$', 1) AS INTEGER) AS anio,
        lower(name) AS columna,
        duckdb_type AS tipo
    FROM parquet_schema({todos})
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
ORDER BY tipo_taxi DESC, columna;

-- id: val_meses_comparables
-- ejercicio: 5
-- objetivo: Comparar los mismos meses entre años para validar que la consulta conjunta produce series comparables.
-- fuentes: vista viajes_validos sobre todos los años descargados
-- decision: Solo se comparan meses disponibles en todos los años para que las diferencias no se deban a meses faltantes.
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
ORDER BY tipo_taxi DESC, mes, anio;

-- id: e8_evolucion_anual
-- ejercicio: 8
-- objetivo: Comparar entre años los indicadores principales de volumen, monto, distancia, duración, velocidad y propina.
-- fuentes: vista viajes_validos sobre 2024, 2025 y 2026
-- decision: Como 2026 no tiene el año completo, el volumen se compara en viajes por día y los demás indicadores en promedios o medianas.
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
ORDER BY anio;

-- id: e8_pago_por_anio
-- ejercicio: 8
-- objetivo: Analizar cómo cambia la participación de cada método de pago entre años.
-- fuentes: vista viajes_validos sobre 2024, 2025 y 2026
-- decision: Un aumento del pago sin registro afecta el cálculo de propinas y debe considerarse al comparar años.
SELECT
    anio_archivo AS anio,
    metodo_pago,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo), 2) AS porcentaje
FROM viajes_validos
GROUP BY anio_archivo, metodo_pago
ORDER BY anio, viajes DESC;

-- id: e8_cargos_por_anio
-- ejercicio: 8
-- objetivo: Medir la presencia y el monto promedio de cada recargo por año, incluido el cargo de congestión CBD.
-- fuentes: vista viajes_validos sobre 2024, 2025 y 2026
-- decision: El cargo CBD no existe en los archivos de 2024 y la vista lo deja nulo, lo que permite comparar el antes y el después sin cambiar consultas.
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
ORDER BY anio, tipo_taxi DESC;

-- id: e8_calidad_por_anio
-- ejercicio: 8
-- objetivo: Comparar entre años la proporción de registros excluidos por cada regla de calidad.
-- fuentes: vista viajes_calidad sobre 2024, 2025 y 2026
-- decision: Si la calidad cambia entre años, parte de las diferencias en los indicadores puede deberse al registro de los datos y no al comportamiento de los viajes.
SELECT
    anio_archivo AS anio,
    coalesce(motivo_exclusion, 'Válido') AS clasificacion,
    count(*) AS registros,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo), 3) AS porcentaje
FROM viajes_calidad
GROUP BY anio_archivo, clasificacion
ORDER BY anio, registros DESC;

-- id: e8_hora_por_anio
-- ejercicio: 8
-- objetivo: Comparar el perfil horario de la demanda y la velocidad entre años.
-- fuentes: vista viajes_validos sobre 2024, 2025 y 2026
-- decision: Se usa la participación de cada hora dentro del año para comparar la forma del perfil sin que influya el volumen total.
SELECT
    anio_archivo AS anio,
    hora,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo), 3) AS pct_viajes,
    round(median(velocidad_mph), 2) AS velocidad_mediana
FROM viajes_validos
GROUP BY anio_archivo, hora
ORDER BY anio, hora;
