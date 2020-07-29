ARG BASE_IMAGE=ubuntu:20.04
ARG BUILD_ENV=cached

# TODO i386 support
# FROM ${BASE_IMAGE} as build_cached
# ONBUILD COPY ./ManageEngine_PMP_64bit.bin /tmp/pmp_installer.bin

FROM ${BASE_IMAGE} as build_no_cache

FROM build_${BUILD_ENV}

ARG PMP_HOME=/srv/pmp
ARG PMP_VERSION=10404

ENV PMP_VERSION=${PMP_VERSION} \
    PMP_HOME=${PMP_HOME} \
    SERVER_STATE=master \
    TIMEOUT_DB=60 \
    TIMEOUT_PMP=300 \
    PMP_PORT=7272

COPY pmp.properties /tmp/pmp.properties
COPY entrypoint.sh /entrypoint.sh

COPY install.sh /install.sh

RUN bash /install.sh && rm -f /install.sh

WORKDIR /data

# https://www.manageengine.com/products/passwordmanagerpro/help/installation.html#Ports
EXPOSE 5522/tcp 7070/tcp 7272/tcp 7273/tcp

ENTRYPOINT ["/entrypoint.sh"]

VOLUME ["/data"]

HEALTHCHECK --start-period=5m CMD curl -fqskL https://localhost:7272
