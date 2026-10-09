-- Vista normalizada generada por scripts/taxis.py a partir de los esquemas de los archivos.
-- Las rutas son relativas a la raiz del repositorio. No se edita a mano.

CREATE OR REPLACE VIEW viajes AS
SELECT *,
    date_diff('second', fecha_recogida, fecha_destino) / 60.0 AS duracion_min
FROM (
SELECT
    'yellow' AS tipo_taxi,
    CAST("VendorID" AS INTEGER) AS proveedor,
    CAST("tpep_pickup_datetime" AS TIMESTAMP) AS fecha_recogida,
    CAST("tpep_dropoff_datetime" AS TIMESTAMP) AS fecha_destino,
    CAST("passenger_count" AS DOUBLE) AS pasajeros,
    CAST("trip_distance" AS DOUBLE) AS distancia_millas,
    CAST("RatecodeID" AS INTEGER) AS codigo_tarifa,
    CAST("store_and_fwd_flag" AS VARCHAR) AS almacenado_y_enviado,
    CAST("PULocationID" AS INTEGER) AS zona_origen,
    CAST("DOLocationID" AS INTEGER) AS zona_destino,
    CAST("payment_type" AS INTEGER) AS tipo_pago,
    CAST("fare_amount" AS DOUBLE) AS tarifa,
    CAST("extra" AS DOUBLE) AS extra,
    CAST("mta_tax" AS DOUBLE) AS impuesto_mta,
    CAST("tip_amount" AS DOUBLE) AS propina,
    CAST("tolls_amount" AS DOUBLE) AS peajes,
    CAST("improvement_surcharge" AS DOUBLE) AS recargo_mejora,
    CAST("congestion_surcharge" AS DOUBLE) AS recargo_congestion,
    CAST("Airport_fee" AS DOUBLE) AS cargo_aeropuerto,
    CAST("cbd_congestion_fee" AS DOUBLE) AS cargo_cbd,
    CAST(NULL AS DOUBLE) AS cargo_ehail,
    CAST("total_amount" AS DOUBLE) AS total,
    CAST(NULL AS INTEGER) AS tipo_viaje,
    CAST(regexp_extract(filename, '(\d{4})-(\d{2})\.parquet$', 1) AS INTEGER) AS anio_archivo,
    CAST(regexp_extract(filename, '(\d{4})-(\d{2})\.parquet$', 2) AS INTEGER) AS mes_archivo,
    regexp_extract(filename, '[^/\\]+$') AS archivo
FROM read_parquet(['data/raw/yellow/2024/*.parquet', 'data/raw/yellow/2025/*.parquet', 'data/raw/yellow/2026/*.parquet'], union_by_name = true, filename = true)
UNION ALL BY NAME
SELECT
    'green' AS tipo_taxi,
    CAST("VendorID" AS INTEGER) AS proveedor,
    CAST("lpep_pickup_datetime" AS TIMESTAMP) AS fecha_recogida,
    CAST("lpep_dropoff_datetime" AS TIMESTAMP) AS fecha_destino,
    CAST("passenger_count" AS DOUBLE) AS pasajeros,
    CAST("trip_distance" AS DOUBLE) AS distancia_millas,
    CAST("RatecodeID" AS INTEGER) AS codigo_tarifa,
    CAST("store_and_fwd_flag" AS VARCHAR) AS almacenado_y_enviado,
    CAST("PULocationID" AS INTEGER) AS zona_origen,
    CAST("DOLocationID" AS INTEGER) AS zona_destino,
    CAST("payment_type" AS INTEGER) AS tipo_pago,
    CAST("fare_amount" AS DOUBLE) AS tarifa,
    CAST("extra" AS DOUBLE) AS extra,
    CAST("mta_tax" AS DOUBLE) AS impuesto_mta,
    CAST("tip_amount" AS DOUBLE) AS propina,
    CAST("tolls_amount" AS DOUBLE) AS peajes,
    CAST("improvement_surcharge" AS DOUBLE) AS recargo_mejora,
    CAST("congestion_surcharge" AS DOUBLE) AS recargo_congestion,
    CAST(NULL AS DOUBLE) AS cargo_aeropuerto,
    CAST("cbd_congestion_fee" AS DOUBLE) AS cargo_cbd,
    CAST("ehail_fee" AS DOUBLE) AS cargo_ehail,
    CAST("total_amount" AS DOUBLE) AS total,
    CAST("trip_type" AS INTEGER) AS tipo_viaje,
    CAST(regexp_extract(filename, '(\d{4})-(\d{2})\.parquet$', 1) AS INTEGER) AS anio_archivo,
    CAST(regexp_extract(filename, '(\d{4})-(\d{2})\.parquet$', 2) AS INTEGER) AS mes_archivo,
    regexp_extract(filename, '[^/\\]+$') AS archivo
FROM read_parquet(['data/raw/green/2024/*.parquet', 'data/raw/green/2025/*.parquet', 'data/raw/green/2026/*.parquet'], union_by_name = true, filename = true)
);
