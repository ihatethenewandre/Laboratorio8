#!/usr/bin/env python3
"""Descarga y verifica los archivos Parquet del NYC TLC Trip Record Data.

Descarga los registros de viajes de taxis amarillos (yellow) y verdes (green)
para los anios indicados, junto con la tabla de zonas de taxi de la TLC. El
script es incremental: puede ejecutarse tantas veces como se quiera y solo
descarga lo que falta, de modo que incorporar un anio nuevo consiste en
agregarlo a la lista de anios.

Fuente oficial de los datos:
    https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page

Uso:
    python scripts/download_data.py                        anios 2024, 2025 y 2026
    python scripts/download_data.py --anios 2026           solo 2026
    python scripts/download_data.py --anios 2024 2026      2024 y 2026
    python scripts/download_data.py --taxi yellow          solo amarillos
    python scripts/download_data.py --verificar            verifica completitud

Los archivos se guardan en:
    data/raw/<tipo>/<anio>/<nombre-original>.parquet
    data/raw/zonas/taxi_zone_lookup.csv

Comportamiento:
  - Las rutas se resuelven a partir de la ubicacion del script, por lo que el
    resultado es el mismo sin importar desde que carpeta se ejecute.
  - La TLC publica cada mes con varias semanas de atraso. El script consulta al
    servidor que meses estan publicados y distingue entre un mes que aun no
    existe y un error de red, que no deben confundirse.
  - Un archivo que ya existe localmente no se vuelve a descargar.
  - La descarga se hace sobre un nombre temporal y solo se renombra al
    terminar, de modo que una interrupcion no deja archivos .parquet a medias.
  - Con --verificar no se descarga nada: se compara cada archivo local con el
    publicado, por tamanio y por lectura de sus metadatos Parquet, y se guarda
    un manifiesto en data/processed/manifiesto_descargas.csv.
"""

import argparse
import csv
import sys
from pathlib import Path

import requests

ANIOS_DISPONIBLES = (2024, 2025, 2026)
TIPOS_TAXI = ("yellow", "green")
URL_BASE = "https://d37ci6vzurychx.cloudfront.net/trip-data"
URL_ZONAS = "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv"

# las rutas se calculan desde la raiz del repositorio y no desde la carpeta actual
RAIZ = Path(__file__).resolve().parents[1]
DIR_DESTINO = RAIZ / "data" / "raw"
ARCHIVO_ZONAS = DIR_DESTINO / "zonas" / "taxi_zone_lookup.csv"
ARCHIVO_MANIFIESTO = RAIZ / "data" / "processed" / "manifiesto_descargas.csv"

# segundos de espera por peticion
TIEMPO_ESPERA = 60
# intentos por archivo antes de darse por vencido
INTENTOS = 3
# 1 MiB por bloque de descarga
BLOQUE = 1024 * 1024
SUFIJO_TEMPORAL = ".part"
SEPARADOR = "-" * 60

# estados posibles de un archivo en el servidor
PUBLICADO = "publicado"
NO_PUBLICADO = "no_publicado"
ERROR_RED = "error_red"


def construir_nombre(tipo: str, anio: int, mes: int) -> str:
    """Nombre del archivo publicado por la TLC, p. ej. yellow_tripdata_2026-01.parquet."""
    return f"{tipo}_tripdata_{anio}-{mes:02d}.parquet"


def construir_url(tipo: str, anio: int, mes: int) -> str:
    """URL completa del archivo Parquet mensual."""
    return f"{URL_BASE}/{construir_nombre(tipo, anio, mes)}"


def ruta_destino(tipo: str, anio: int, mes: int) -> Path:
    """Ruta local donde se guarda el archivo."""
    return DIR_DESTINO / tipo / str(anio) / construir_nombre(tipo, anio, mes)


def consultar_publicacion(url: str) -> tuple:
    """Consulta el servidor sin descargar y devuelve el estado y el tamanio publicado.

    La TLC sirve los archivos desde CloudFront, que responde 403 o 404 cuando el
    archivo no existe. Cualquier otro fallo se informa como error de red para no
    confundir un problema de conexion con un mes que aun no se publica.
    """
    try:
        respuesta = requests.head(url, timeout=TIEMPO_ESPERA, allow_redirects=True)
    except requests.RequestException as error:
        return ERROR_RED, None, type(error).__name__
    if respuesta.ok:
        tamanio = respuesta.headers.get("Content-Length")
        return PUBLICADO, int(tamanio) if tamanio else None, ""
    if respuesta.status_code in (403, 404):
        return NO_PUBLICADO, None, f"HTTP {respuesta.status_code}"
    return ERROR_RED, None, f"HTTP {respuesta.status_code}"


def formato_tamanio(n: float) -> str:
    for unidad in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unidad == "GiB":
            return f"{n:.1f} {unidad}"
        n /= 1024
    return f"{n:.1f} GiB"


def descargar_archivo(url: str, destino: Path) -> int:
    """Descarga `url` en `destino`. Devuelve la cantidad de bytes escritos."""
    destino.parent.mkdir(parents=True, exist_ok=True)
    temporal = destino.with_name(destino.name + SUFIJO_TEMPORAL)

    ultimo_error = None
    for intento in range(1, INTENTOS + 1):
        try:
            with requests.get(url, stream=True, timeout=TIEMPO_ESPERA) as respuesta:
                respuesta.raise_for_status()
                escritos = 0
                with temporal.open("wb") as archivo:
                    for bloque in respuesta.iter_content(chunk_size=BLOQUE):
                        if bloque:
                            archivo.write(bloque)
                            escritos += len(bloque)
            if escritos == 0:
                raise requests.RequestException("el servidor devolvio un archivo vacio")
            temporal.replace(destino)
            return escritos
        except requests.RequestException as error:
            ultimo_error = error
            temporal.unlink(missing_ok=True)
            if intento < INTENTOS:
                print(f"      intento {intento}/{INTENTOS} fallido ({error}); reintentando")

    raise requests.RequestException(f"no se pudo descargar {url}: {ultimo_error}")


def descargar_zonas() -> str:
    """Descarga la tabla de zonas de taxi si aun no existe localmente."""
    if ARCHIVO_ZONAS.exists() and ARCHIVO_ZONAS.stat().st_size > 0:
        print(f"  zonas  ya existe, se omite -> {ARCHIVO_ZONAS.relative_to(RAIZ)}")
        return "omitido"
    try:
        escritos = descargar_archivo(URL_ZONAS, ARCHIVO_ZONAS)
    except requests.RequestException as error:
        print(f"  zonas  ERROR: {error}")
        return "fallido"
    print(f"  zonas  listo ({formato_tamanio(escritos)}) -> {ARCHIVO_ZONAS.relative_to(RAIZ)}")
    return "descargado"


def resumen_vacio() -> dict:
    return {"descargados": 0, "omitidos": 0, "no_publicados": [], "fallidos": [], "errores_red": []}


def descargar(tipo: str, anio: int) -> dict:
    """Descarga todos los meses publicados de un tipo de taxi para un anio."""
    print(f"\n{tipo.upper()} {anio}")
    print(SEPARADOR)
    resumen = resumen_vacio()

    for mes in range(1, 13):
        etiqueta = f"{anio}-{mes:02d}"
        destino = ruta_destino(tipo, anio, mes)

        if destino.exists() and destino.stat().st_size > 0:
            print(f"  {etiqueta}  ya existe, se omite")
            resumen["omitidos"] += 1
            continue

        url = construir_url(tipo, anio, mes)
        estado, _, detalle = consultar_publicacion(url)
        if estado == NO_PUBLICADO:
            print(f"  {etiqueta}  aun no publicado por la TLC")
            resumen["no_publicados"].append(etiqueta)
            continue
        if estado == ERROR_RED:
            print(f"  {etiqueta}  no se pudo consultar el servidor ({detalle})")
            resumen["errores_red"].append(etiqueta)
            continue

        print(f"  {etiqueta}  descargando...")
        try:
            escritos = descargar_archivo(url, destino)
        except requests.RequestException as error:
            print(f"  {etiqueta}  ERROR: {error}")
            resumen["fallidos"].append(etiqueta)
        else:
            print(f"  {etiqueta}  listo ({formato_tamanio(escritos)}) -> {destino.relative_to(RAIZ)}")
            resumen["descargados"] += 1

    return resumen


def filas_parquet(ruta: Path):
    """Lee solo los metadatos del Parquet para confirmar que es legible y contar sus filas."""
    try:
        import pyarrow.parquet as pq
        return pq.read_metadata(ruta).num_rows, ""
    except Exception as error:
        return None, str(error)


def verificar(tipos, anios) -> int:
    """Compara los archivos locales con los publicados y guarda un manifiesto."""
    filas = []
    for tipo in tipos:
        for anio in anios:
            for mes in range(1, 13):
                destino = ruta_destino(tipo, anio, mes)
                estado, tamanio_remoto, detalle = consultar_publicacion(construir_url(tipo, anio, mes))
                existe = destino.exists() and destino.stat().st_size > 0
                tamanio_local = destino.stat().st_size if existe else None
                registros, error_lectura = filas_parquet(destino) if existe else (None, "")
                if existe and error_lectura:
                    diagnostico = "archivo local ilegible"
                elif estado == PUBLICADO and not existe:
                    diagnostico = "publicado pero no descargado"
                elif estado == PUBLICADO and tamanio_remoto is not None and tamanio_local != tamanio_remoto:
                    diagnostico = "tamanio distinto al publicado"
                elif estado == PUBLICADO:
                    diagnostico = "completo"
                elif estado == NO_PUBLICADO:
                    diagnostico = "local sin publicacion remota" if existe else "no publicado"
                else:
                    diagnostico = "local sin verificacion remota" if existe else "sin verificacion remota"
                filas.append({
                    "tipo": tipo, "anio": anio, "mes": mes,
                    "archivo": destino.relative_to(RAIZ).as_posix(),
                    "estado_remoto": estado, "tamanio_remoto": tamanio_remoto,
                    "existe_local": existe, "tamanio_local": tamanio_local,
                    "registros": registros, "diagnostico": diagnostico,
                })

    ARCHIVO_MANIFIESTO.parent.mkdir(parents=True, exist_ok=True)
    with ARCHIVO_MANIFIESTO.open("w", newline="", encoding="utf-8") as archivo:
        escritor = csv.DictWriter(archivo, fieldnames=list(filas[0]))
        escritor.writeheader()
        escritor.writerows(filas)

    conteo = {}
    for fila in filas:
        conteo[fila["diagnostico"]] = conteo.get(fila["diagnostico"], 0) + 1
    problemas = [f for f in filas if f["diagnostico"] in
                 ("publicado pero no descargado", "tamanio distinto al publicado", "archivo local ilegible")]

    print("\nVERIFICACION DE COMPLETITUD")
    print(SEPARADOR)
    for diagnostico, cantidad in sorted(conteo.items()):
        print(f"  {diagnostico:<32} {cantidad}")
    total_registros = sum(f["registros"] or 0 for f in filas)
    print(f"  {'registros en archivos locales':<32} {total_registros:,}")
    print(f"  manifiesto -> {ARCHIVO_MANIFIESTO.relative_to(RAIZ)}")
    for fila in problemas:
        print(f"  PROBLEMA {fila['archivo']}: {fila['diagnostico']}")
    print(SEPARADOR)
    return 1 if problemas else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Descarga los datos de taxis del NYC TLC.")
    parser.add_argument(
        "--taxi", choices=(*TIPOS_TAXI, "all"), default="all",
        help="tipo de taxi a descargar (por defecto: all)",
    )
    parser.add_argument(
        "--anios", type=int, nargs="+", default=list(ANIOS_DISPONIBLES),
        help="anios a descargar (por defecto: 2024 2025 2026)",
    )
    parser.add_argument(
        "--verificar", action="store_true",
        help="no descarga; verifica la completitud de los archivos locales",
    )
    argumentos = parser.parse_args()

    tipos = TIPOS_TAXI if argumentos.taxi == "all" else (argumentos.taxi,)
    anios = sorted(set(argumentos.anios))

    if argumentos.verificar:
        return verificar(tipos, anios)

    total = resumen_vacio()
    print("ZONAS DE TAXI")
    print(SEPARADOR)
    estado_zonas = descargar_zonas()
    for anio in anios:
        for tipo in tipos:
            resumen = descargar(tipo, anio)
            total["descargados"] += resumen["descargados"]
            total["omitidos"] += resumen["omitidos"]
            for clave in ("no_publicados", "fallidos", "errores_red"):
                total[clave] += [f"{tipo} {m}" for m in resumen[clave]]

    print("\nRESUMEN")
    print(SEPARADOR)
    print(f"  anios          : {', '.join(map(str, anios))}")
    print(f"  zonas          : {estado_zonas}")
    print(f"  descargados    : {total['descargados']}")
    print(f"  ya existian    : {total['omitidos']}")
    print(f"  no publicados  : {len(total['no_publicados'])}")
    if total["no_publicados"]:
        print(f"      {', '.join(total['no_publicados'])}")
    print(f"  errores de red : {len(total['errores_red'])}")
    if total["errores_red"]:
        print(f"      {', '.join(total['errores_red'])}")
    print(f"  fallidos       : {len(total['fallidos'])}")
    if total["fallidos"]:
        print(f"      {', '.join(total['fallidos'])}")
    print(SEPARADOR)

    return 1 if total["fallidos"] or total["errores_red"] else 0


if __name__ == "__main__":
    sys.exit(main())
