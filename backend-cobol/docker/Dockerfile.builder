# ビルド反復用イメージ(deps + Instant Client + GixSQL まで)。
# COBOL ソースはマウントして make するため、ソース変更で再ビルド不要。
FROM debian:12-slim
ARG GIXSQL_VER=1.0.20b
ARG INSTANTCLIENT_ZIP=instantclient-basiclite-linux.x64.zip
ARG INSTANTCLIENT_SDK=instantclient-sdk-linux.x64.zip
ENV DEBIAN_FRONTEND=noninteractive GIXHOME=/opt/gixsql
ENV ORACLE_HOME=/opt/oracle/instantclient
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential gnucobol nginx fcgiwrap spawn-fcgi \
      libaio1 unzip wget ca-certificates netcat-openbsd git \
      autoconf automake libtool pkg-config libspdlog-dev libfmt-dev \
    && rm -rf /var/lib/apt/lists/*
COPY backend-cobol/docker/vendor/${INSTANTCLIENT_ZIP} /tmp/ic.zip
COPY backend-cobol/docker/vendor/${INSTANTCLIENT_SDK} /tmp/icsdk.zip
RUN mkdir -p /opt/oracle && cd /opt/oracle \
    && unzip -oq /tmp/ic.zip && unzip -oq /tmp/icsdk.zip \
    && IC=$(ls -d /opt/oracle/instantclient_* | head -1) \
    && ln -s "$IC" /opt/oracle/instantclient \
    && echo /opt/oracle/instantclient > /etc/ld.so.conf.d/oracle.conf && ldconfig \
    && rm -f /tmp/ic.zip /tmp/icsdk.zip
COPY backend-cobol/docker/vendor/gixsql-${GIXSQL_VER}.tar.gz /tmp/gixsql.tar.gz
RUN mkdir -p /tmp/gixsql && tar xzf /tmp/gixsql.tar.gz -C /tmp/gixsql --strip-components=1 \
    && cd /tmp/gixsql && ./configure --prefix=${GIXHOME} --with-oracle=/opt/oracle/instantclient \
    && make -j"$(nproc)" && make install && rm -rf /tmp/gixsql /tmp/gixsql.tar.gz
ENV PATH="${GIXHOME}/bin:${PATH}"
WORKDIR /app/build
