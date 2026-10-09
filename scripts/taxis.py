"""Utilidades compartidas del laboratorio 8.

Concentra en un solo lugar las rutas del proyecto, la conexion a DuckDB, la vista
normalizada de viajes, el catalogo de consultas SQL de la carpeta sql/, la
bitacora que documenta cada consulta ejecutada, el benchmark de Parquet frente a
tablas DuckDB y la construccion de la base de indicadores que consume Metabase.

El notebook, scripts/benchmark.py y scripts/construir_tablero.py importan este
modulo, de modo que todos usan exactamente las mismas definiciones.
"""

import re
import time
from pathlib import Path

import duckdb
import pandas as pd

RAIZ = Path(__file__).resolve().parents[1]
DIR_DATOS = RAIZ / "data"
DIR_RAW = DIR_DATOS / "raw"
DIR_PROCESADO = DIR_DATOS / "processed"
DIR_SQL = RAIZ / "sql"
DIR_DOCS = RAIZ / "docs"
DIR_TEMPORAL = DIR_PROCESADO / "duckdb_tmp"
ARCHIVO_ZONAS = DIR_RAW / "zonas" / "taxi_zone_lookup.csv"
BASE_BENCHMARK = DIR_PROCESADO / "benchmark.duckdb"
BASE_TABLERO = DIR_PROCESADO / "tablero.duckdb"

TIPOS_TAXI = ("yellow", "green")
LIMITE_MEMORIA = "3GB"

# columnas canonicas de la vista: nombre de salida, tipo SQL y nombres posibles en los archivos
COLUMNAS_VIAJE = [
    ("proveedor", "INTEGER", ["vendorid"]),
    ("fecha_recogida", "TIMESTAMP", ["tpep_pickup_datetime", "lpep_pickup_datetime"]),
    ("fecha_destino", "TIMESTAMP", ["tpep_dropoff_datetime", "lpep_dropoff_datetime"]),
    ("pasajeros", "DOUBLE", ["passenger_count"]),
    ("distancia_millas", "DOUBLE", ["trip_distance"]),
    ("codigo_tarifa", "INTEGER", ["ratecodeid"]),
    ("almacenado_y_enviado", "VARCHAR", ["store_and_fwd_flag"]),
    ("zona_origen", "INTEGER", ["pulocationid"]),
    ("zona_destino", "INTEGER", ["dolocationid"]),
    ("tipo_pago", "INTEGER", ["payment_type"]),
    ("tarifa", "DOUBLE", ["fare_amount"]),
    ("extra", "DOUBLE", ["extra"]),
    ("impuesto_mta", "DOUBLE", ["mta_tax"]),
    ("propina", "DOUBLE", ["tip_amount"]),
    ("peajes", "DOUBLE", ["tolls_amount"]),
    ("recargo_mejora", "DOUBLE", ["improvement_surcharge"]),
    ("recargo_congestion", "DOUBLE", ["congestion_surcharge"]),
    ("cargo_aeropuerto", "DOUBLE", ["airport_fee"]),
    ("cargo_cbd", "DOUBLE", ["cbd_congestion_fee"]),
    ("cargo_ehail", "DOUBLE", ["ehail_fee"]),
    ("total", "DOUBLE", ["total_amount"]),
    ("tipo_viaje", "INTEGER", ["trip_type"]),
]


def conectar(base=":memory:", solo_lectura=False, memoria=LIMITE_MEMORIA):
    """Abre DuckDB con limite de memoria y carpeta de desbordamiento a disco."""
    DIR_TEMPORAL.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(base), read_only=solo_lectura)
    con.execute(f"SET memory_limit = '{memoria}'")
    con.execute(f"SET temp_directory = '{DIR_TEMPORAL.as_posix()}'")
    con.execute("SET preserve_insertion_order = false")
    # en Jupyter sin ipywidgets DuckDB no permite cambiar la barra de progreso, que en ese caso ya esta inactiva
    try:
        con.execute("SET enable_progress_bar = false")
    except duckdb.Error:
        pass
    return con


def archivos_parquet(tipos=TIPOS_TAXI, anios=None):
    """Lista ordenada de los Parquet descargados para los tipos y anios indicados."""
    rutas = []
    for tipo in tipos:
        for carpeta in sorted((DIR_RAW / tipo).glob("*")):
            if carpeta.is_dir() and (anios is None or int(carpeta.name) in anios):
                rutas += sorted(carpeta.glob("*.parquet"))
    return rutas


def anios_disponibles():
    """Anios con al menos un archivo descargado."""
    return sorted({int(r.parent.name) for r in archivos_parquet()})


def patrones(tipo, anios):
    """Patrones glob por anio, que incluyen automaticamente cualquier archivo nuevo de esas carpetas."""
    return [f"{(DIR_RAW / tipo / str(a)).as_posix()}/*.parquet"
            for a in sorted(anios) if any((DIR_RAW / tipo / str(a)).glob("*.parquet"))]


def lista_sql(rutas):
    """Convierte rutas o patrones en una lista literal de SQL."""
    return "[" + ", ".join(f"'{Path(r).as_posix() if not isinstance(r, str) else r}'" for r in rutas) + "]"


def sql_vista_viajes(con, fuentes_por_tipo, nombre="viajes"):
    """Genera la vista normalizada que une taxis amarillos y verdes con nombres y tipos comunes.

    El esquema de cada tipo se lee de los propios archivos. Si una columna no existe en
    un tipo de taxi o en un periodo se rellena con NULL, de modo que la vista sigue
    funcionando cuando la TLC agrega o renombra columnas.
    """
    partes = []
    for tipo, fuentes in fuentes_por_tipo.items():
        if not fuentes:
            continue
        lectura = f"read_parquet({lista_sql(fuentes)}, union_by_name = true, filename = true)"
        presentes = {fila[0].lower(): fila[0] for fila in con.execute(f"DESCRIBE SELECT * FROM {lectura}").fetchall()}
        expresiones = [f"'{tipo}' AS tipo_taxi"]
        for salida, tipo_sql, candidatos in COLUMNAS_VIAJE:
            origen = next((presentes[c] for c in candidatos if c in presentes), None)
            valor = f'"{origen}"' if origen else "NULL"
            expresiones.append(f"CAST({valor} AS {tipo_sql}) AS {salida}")
        expresiones += [
            "CAST(regexp_extract(filename, '(\\d{4})-(\\d{2})\\.parquet$', 1) AS INTEGER) AS anio_archivo",
            "CAST(regexp_extract(filename, '(\\d{4})-(\\d{2})\\.parquet$', 2) AS INTEGER) AS mes_archivo",
            "regexp_extract(filename, '[^/\\\\]+$') AS archivo",
        ]
        partes.append("SELECT\n    " + ",\n    ".join(expresiones) + f"\nFROM {lectura}")
    consulta = "\nUNION ALL BY NAME\n".join(partes)
    return (
        f"CREATE OR REPLACE VIEW {nombre} AS\n"
        f"SELECT *,\n    date_diff('second', fecha_recogida, fecha_destino) / 60.0 AS duracion_min\n"
        f"FROM (\n{consulta}\n)"
    )


def crear_vista_viajes(con, anios=None, nombre="viajes", archivos=None, guardar=None):
    """Crea la vista normalizada sobre los anios indicados o sobre una lista explicita de archivos."""
    if archivos is not None:
        fuentes = {t: [a for a in archivos if Path(a).parent.parent.name == t] for t in TIPOS_TAXI}
    else:
        anios = anios or anios_disponibles()
        fuentes = {t: patrones(t, anios) for t in TIPOS_TAXI}
    sql = sql_vista_viajes(con, fuentes, nombre)
    con.execute(sql)
    if guardar is not None:
        encabezado = ("-- Vista normalizada generada por scripts/taxis.py a partir de los esquemas de los archivos.\n"
                      "-- Las rutas son relativas a la raiz del repositorio. No se edita a mano.\n\n")
        Path(guardar).write_text(encabezado + sql.replace(f"{RAIZ.as_posix()}/", "") + ";\n", encoding="utf-8")
    return sql


def cargar_consultas(ruta):
    """Lee un archivo SQL del catalogo con bloques encabezados por comentarios -- clave: valor."""
    texto = Path(ruta).read_text(encoding="utf-8")
    bloques = re.split(r"(?m)^-- id:", texto)[1:]
    catalogo = {}
    for bloque in bloques:
        lineas = ("-- id:" + bloque).strip().splitlines()
        meta, cuerpo = {}, []
        for linea in lineas:
            coincidencia = re.match(r"^--\s*(\w+):\s*(.*)$", linea)
            if coincidencia and not cuerpo:
                clave, valor = coincidencia.groups()
                meta[clave] = (meta[clave] + " " + valor.strip()) if clave in meta else valor.strip()
            elif linea.strip() or cuerpo:
                cuerpo.append(linea)
        sql = "\n".join(cuerpo).strip().rstrip(";").strip()
        meta.update({"sql": sql, "archivo": Path(ruta).name})
        catalogo[meta["id"]] = meta
    return catalogo


def catalogo_completo():
    """Une todos los archivos SQL de la carpeta sql/ en un solo catalogo."""
    catalogo = {}
    for ruta in sorted(DIR_SQL.glob("[0-9]*.sql")):
        catalogo.update(cargar_consultas(ruta))
    return catalogo


def sustituir(sql, parametros):
    for clave, valor in (parametros or {}).items():
        sql = sql.replace("{" + clave + "}", str(valor))
    return sql


class Bitacora:
    """Ejecuta consultas del catalogo y registra objetivo, fuentes, SQL, resultado, tiempo y decision."""

    def __init__(self, con, catalogo=None):
        self.con = con
        self.catalogo = catalogo or catalogo_completo()
        self.registros = []

    def ejecutar(self, id_consulta, parametros=None, fuentes=None, mostrar=None, filas=12, ejercicio=None):
        """Ejecuta una consulta del catalogo; con ejercicio se registra de nuevo una consulta reutilizada."""
        info = self.catalogo[id_consulta]
        ejercicio = ejercicio or info.get("ejercicio", "")
        registro = id_consulta if ejercicio == info.get("ejercicio", "") else f"{id_consulta} en el ejercicio {ejercicio}"
        sql = sustituir(info["sql"], parametros)
        inicio = time.perf_counter()
        relacion = self.con.sql(sql)
        resultado = relacion.df() if relacion is not None else pd.DataFrame()
        segundos = time.perf_counter() - inicio
        self.registros = [r for r in self.registros if r["id"] != registro] + [{
            "id": registro, "ejercicio": ejercicio, "objetivo": info.get("objetivo", ""),
            "pregunta": info.get("pregunta", ""), "fuentes": fuentes or info.get("fuentes", ""),
            "decision": info.get("decision", "") or info.get("justificacion", ""),
            "archivo_sql": info["archivo"], "sql": sql, "segundos": segundos,
            "filas": len(resultado), "columnas": resultado.shape[1], "muestra": resultado.head(filas),
        }]
        print(f"Consulta {registro}")
        print(f"  Objetivo: {info.get('objetivo', '')}")
        print(f"  Fuentes : {fuentes or info.get('fuentes', '')}")
        print(f"  Resultado: {len(resultado):,} filas en {segundos:.2f} s")
        if mostrar is not None and len(resultado):
            mostrar(resultado.head(filas) if filas else resultado)
        return resultado

    def documentar(self, id_consulta, resultado, segundos=None, ejercicio=None, fuentes=None):
        """Registra una consulta del catalogo cuyo resultado ya fue calculado en otro proceso."""
        info = self.catalogo[id_consulta]
        ejercicio = ejercicio or info.get("ejercicio", "")
        registro = id_consulta if ejercicio == info.get("ejercicio", "") else f"{id_consulta} en el ejercicio {ejercicio}"
        self.registros = [r for r in self.registros if r["id"] != registro] + [{
            "id": registro, "ejercicio": ejercicio, "objetivo": info.get("objetivo", ""),
            "pregunta": info.get("pregunta", ""), "fuentes": fuentes or info.get("fuentes", ""),
            "decision": info.get("decision", "") or info.get("justificacion", ""),
            "archivo_sql": info["archivo"], "sql": info["sql"], "segundos": segundos or 0.0,
            "filas": len(resultado), "columnas": resultado.shape[1], "muestra": resultado.head(12),
        }]

    def tabla(self):
        """Resumen tabular de las consultas registradas."""
        return pd.DataFrame([{k: r[k] for k in ("id", "ejercicio", "archivo_sql", "filas", "segundos")}
                             for r in self.registros])

    def exportar(self, ruta):
        """Escribe la documentacion de todas las consultas ejecutadas en formato Markdown."""
        lineas = ["# Documentación de consultas", "",
                  "Archivo generado por el notebook a partir de la bitácora de consultas. Cada consulta se ejecutó "
                  "directamente con DuckDB y su texto fuente se encuentra en la carpeta sql/.", ""]
        for ejercicio in sorted({r["ejercicio"] for r in self.registros}, key=lambda e: (not e.isdigit(), len(e), e)):
            lineas += [f"## Ejercicio {ejercicio}" if ejercicio.isdigit() else "## Capas de preparación", ""]
            for r in [r for r in self.registros if r["ejercicio"] == ejercicio]:
                lineas += [f"### {r['id']}", ""]
                if r["pregunta"]:
                    lineas += [f"- Pregunta: {r['pregunta']}"]
                lineas += [
                    f"- Objetivo: {r['objetivo']}",
                    f"- Fuentes: {r['fuentes']}",
                    f"- Archivo SQL: sql/{r['archivo_sql']}",
                    f"- Resultado: {r['filas']:,} filas y {r['columnas']} columnas en {r['segundos']:.2f} s",
                    f"- {'Justificación' if r['pregunta'] else 'Decisión'}: {r['decision'] or 'sin decisión asociada'}",
                    "", "```sql", r["sql"].replace(f"{RAIZ.as_posix()}/", ""), "```", "",
                ]
                if r["filas"]:
                    lineas += [tabla_markdown(r["muestra"]), ""]
        Path(ruta).write_text("\n".join(lineas), encoding="utf-8")
        return ruta


def tabla_markdown(df, max_filas=12):
    """Tabla Markdown simple sin dependencias adicionales."""
    df = df.head(max_filas)

    def celda(valor):
        if isinstance(valor, float):
            return f"{valor:,.4g}" if abs(valor) < 1e4 else f"{valor:,.0f}"
        texto = str(valor).replace("|", "/").replace("\n", " ")
        return texto[:60]

    encabezado = "| " + " | ".join(map(str, df.columns)) + " |"
    separador = "| " + " | ".join("---" for _ in df.columns) + " |"
    cuerpo = ["| " + " | ".join(celda(v) for v in fila) + " |" for fila in df.itertuples(index=False)]
    return "\n".join([encabezado, separador] + cuerpo)


def preparar_capas(con, anios=None, nombre="viajes", guardar=None):
    """Crea la vista normalizada, la vista de calidad, la vista de viajes validos y la tabla de zonas."""
    crear_vista_viajes(con, anios=anios, nombre=nombre, guardar=guardar)
    catalogo = catalogo_completo()
    for id_consulta in ("crear_tabla_zonas", "crear_vista_calidad", "crear_vista_validos"):
        con.execute(sustituir(catalogo[id_consulta]["sql"], {"ruta_zonas": ARCHIVO_ZONAS.as_posix()}))


def medir(con, sql, repeticiones):
    """Tiempos de ejecucion de una consulta, materializando el resultado completo."""
    tiempos = []
    for _ in range(repeticiones):
        inicio = time.perf_counter()
        con.execute(sql).fetchall()
        tiempos.append(time.perf_counter() - inicio)
    return tiempos


def volumenes_benchmark(anios=None):
    """Define subconjuntos crecientes de archivos para observar el efecto del volumen de datos."""
    anios = anios or anios_disponibles()
    meses = sorted({(int(r.parent.name), r.stem[-7:]) for r in archivos_parquet(anios=anios)})
    def archivos_de(periodos):
        return [r for r in archivos_parquet(anios=anios) if (int(r.parent.name), r.stem[-7:]) in periodos]
    reciente = max(anios)
    meses_recientes = [m for m in meses if m[0] == reciente]
    volumenes = {
        "1 mes": archivos_de(set(meses_recientes[:1])),
        "3 meses": archivos_de(set(meses_recientes[:3])),
        "12 meses": archivos_de(set(meses[-12:]) if len(anios) == 1 else {m for m in meses if m[0] == min(anios)}),
        "Todos los meses": archivos_de(set(meses)),
    }
    unicos, vistos = {}, set()
    for nombre, archivos in volumenes.items():
        clave = tuple(archivos)
        if archivos and clave not in vistos:
            unicos[nombre] = archivos
            vistos.add(clave)
    return unicos


def ejecutar_benchmark(volumenes, repeticiones=5, base=BASE_BENCHMARK, progreso=print, conservar_tablas=False):
    """Ejecuta las mismas consultas sobre Parquet directo y sobre tablas DuckDB para cada volumen.

    Por cada volumen se crea una vista sobre sus archivos Parquet y una tabla materializada
    desde esa vista. Cada consulta se ejecuta una vez de calentamiento y luego las repeticiones
    indicadas con cada estrategia. Al final la base conserva la tabla del volumen completo con
    el nombre viajes_materializada.
    """
    for ruta in (Path(base), Path(str(base) + ".wal")):
        ruta.unlink(missing_ok=True)
    con = conectar(base)
    con.execute(sustituir(catalogo_completo()["crear_tabla_zonas"]["sql"], {"ruta_zonas": ARCHIVO_ZONAS.as_posix()}))
    consultas = cargar_consultas(DIR_SQL / "04_benchmark.sql")
    detalle, cargas = [], []
    for indice, (volumen, archivos) in enumerate(volumenes.items(), start=1):
        vista, tabla = f"parquet_v{indice}", f"tabla_v{indice}"
        crear_vista_viajes(con, nombre=vista, archivos=archivos)
        con.execute("CHECKPOINT")
        bytes_antes = bytes_usados(con)
        inicio = time.perf_counter()
        con.execute(f"CREATE OR REPLACE TABLE {tabla} AS SELECT * FROM {vista}")
        con.execute("CHECKPOINT")
        segundos_carga = time.perf_counter() - inicio
        filas = con.execute(f"SELECT count(*) FROM {tabla}").fetchone()[0]
        cargas.append({"volumen": volumen, "archivos": len(archivos), "registros": filas,
                       "mb_parquet": sum(Path(a).stat().st_size for a in archivos) / 1e6,
                       "mb_tabla_duckdb": (bytes_usados(con) - bytes_antes) / 1e6,
                       "segundos_materializacion": segundos_carga})
        progreso(f"{volumen}: {len(archivos)} archivos, {filas:,} registros, tabla creada en {segundos_carga:.2f} s")
        for id_consulta, info in consultas.items():
            for estrategia, fuente in (("Parquet directo", vista), ("Tabla DuckDB", tabla)):
                sql = sustituir(info["sql"], {"fuente": fuente})
                primera = medir(con, sql, 1)[0]
                for numero, segundos in enumerate(medir(con, sql, repeticiones), start=1):
                    detalle.append({"volumen": volumen, "registros": filas, "consulta": id_consulta,
                                    "estrategia": estrategia, "repeticion": numero, "segundos": segundos,
                                    "primera_ejecucion": primera})
        # solo se conserva la tabla del volumen completo, las demas se eliminan para limitar el uso de disco
        if indice == len(volumenes):
            con.execute(f"ALTER TABLE {tabla} RENAME TO viajes_materializada")
        elif not conservar_tablas:
            con.execute(f"DROP TABLE {tabla}")
        con.execute("CHECKPOINT")
    con.close()
    return pd.DataFrame(detalle), pd.DataFrame(cargas)


def bytes_usados(con):
    """Bytes ocupados por bloques en uso dentro del archivo DuckDB."""
    bloques, tamanio = con.execute("SELECT used_blocks, block_size FROM pragma_database_size()").fetchone()
    return bloques * tamanio


def resumir_benchmark(detalle):
    """Mediana por consulta, volumen y estrategia, y cociente entre Parquet y tabla."""
    resumen = (detalle.groupby(["volumen", "registros", "consulta", "estrategia"], sort=False)
               .agg(mediana_s=("segundos", "median"), minimo_s=("segundos", "min"),
                    primera_s=("primera_ejecucion", "first"))
               .reset_index())
    ancho = resumen.pivot_table(index=["volumen", "registros", "consulta"], columns="estrategia",
                                values="mediana_s", sort=False).reset_index()
    ancho.columns.name = None
    ancho["parquet_entre_tabla"] = ancho["Parquet directo"] / ancho["Tabla DuckDB"]
    return resumen, ancho


def construir_tablero(anios=None, base=BASE_TABLERO, progreso=print):
    """Calcula las tablas de indicadores y las guarda en la base DuckDB que consume Metabase.

    La base se escribe primero en un archivo temporal y luego reemplaza a la anterior.
    Metabase debe estar detenido durante el reemplazo, porque un archivo DuckDB abierto
    por otro proceso no puede sobrescribirse.
    """
    temporal = Path(base).with_name(Path(base).stem + "_construccion.duckdb")
    for ruta in (temporal, Path(str(temporal) + ".wal")):
        ruta.unlink(missing_ok=True)
    con = conectar(temporal)
    preparar_capas(con, anios=anios)
    indicadores = cargar_consultas(DIR_SQL / "05_indicadores.sql")
    resumen = []
    for id_consulta, info in indicadores.items():
        inicio = time.perf_counter()
        con.execute(f"CREATE OR REPLACE TABLE {id_consulta} AS {info['sql']}")
        filas = con.execute(f"SELECT count(*) FROM {id_consulta}").fetchone()[0]
        resumen.append({"indicador": id_consulta, "pregunta": info.get("pregunta", ""),
                        "filas": filas, "segundos": time.perf_counter() - inicio})
        progreso(f"{id_consulta}: {filas} filas")
    con.execute("DROP VIEW IF EXISTS viajes_validos")
    con.execute("DROP VIEW IF EXISTS viajes_calidad")
    con.execute("DROP VIEW IF EXISTS viajes")
    con.execute("CHECKPOINT")
    con.close()
    try:
        temporal.replace(base)
    except PermissionError as error:
        raise PermissionError(
            f"No se pudo reemplazar {base}. Detenga Metabase con 'docker compose stop metabase' "
            "y vuelva a ejecutar la construccion."
        ) from error
    return pd.DataFrame(resumen)
