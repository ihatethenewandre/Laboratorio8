# CC3084 - Lab 8: DuckDB
#
# Metabase con el driver de DuckDB ya instalado.
#
# La imagen oficial de Metabase esta basada en Alpine y el driver de DuckDB
# incluye una libreria nativa que requiere glibc, por lo que no funciona ahi.
# Por eso la imagen se construye sobre Debian (jammy).
#
# Las versiones de Metabase, del driver y de duckdb en requirements.txt deben
# mantenerse alineadas entre si.
FROM eclipse-temurin:21-jre-jammy

ARG METABASE_VERSION=v0.63.19
ARG DUCKDB_DRIVER_VERSION=1.5.5.0

ENV MB_PLUGINS_DIR=/home/metabase/plugins/

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m -u 2000 metabase

WORKDIR /home/metabase

RUN mkdir -p /home/metabase/plugins /home/metabase/data \
 && curl -fSL --retry 5 --retry-delay 3 --retry-all-errors \
      -o /home/metabase/metabase.jar \
      "https://downloads.metabase.com/${METABASE_VERSION}/metabase.jar" \
 && curl -fSL --retry 5 --retry-delay 3 --retry-all-errors \
      -o /home/metabase/plugins/duckdb.metabase-driver.jar \
      "https://github.com/motherduckdb/metabase_duckdb_driver/releases/download/${DUCKDB_DRIVER_VERSION}/duckdb.metabase-driver.jar" \
 && chown -R metabase:metabase /home/metabase \
 && chmod 644 /home/metabase/metabase.jar \
              /home/metabase/plugins/duckdb.metabase-driver.jar

USER metabase
EXPOSE 3000

CMD ["java", "-jar", "/home/metabase/metabase.jar"]
