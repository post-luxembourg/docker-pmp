FROM ubuntu:18.04

ENV PMP_HOME=/srv/PMP \
    SERVER_STATE=master \
    TIMEOUT_DB=60 \
    TIMEOUT_PMP=300

COPY pmp.properties /tmp/pmp.properties
COPY entrypoint.sh /entrypoint.sh

RUN apt-get update && \
    apt-get install -y curl unzip && \
    curl -fsSL https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh \
      -o /usr/bin/wait-for-it.sh && \
    if [ "$(dpkg --print-architecture)" = "i386" ]; \
    then \
      url=https://www.manageengine.com/products/passwordmanagerpro/8621641/ManageEngine_PMP.bin; \
    else \
      url=https://www.manageengine.com/products/passwordmanagerpro/8621641/ManageEngine_PMP_64bit.bin; \
    fi && \
    echo "Downloading PMP installer from $url" && \
    curl -fsSL -o /tmp/pmp_installer.bin "$url" && \
    rm -rf /var/lib/apt/lists/* && \
    chmod +x /tmp/pmp_installer.bin /usr/bin/wait-for-it.sh && \
    /tmp/pmp_installer.bin -i silent -f /tmp/pmp.properties && \
    rm -rf "${PMP_HOME}/logs" && \
    mkdir -p /data/logs /data/backups && \
    ln -sf /data/logs "${PMP_HOME}/logs" && \
    ln -sf /data/backups "${PMP_HOME}/Backup" && \
    cd "${PMP_HOME}/bin" && \
    bash pmp.sh install | grep "installed successfully" && \
    rm -rf /tmp/pmp_installer.bin /tmp/pmp.properties

WORKDIR ${PMP_HOME}

# https://www.manageengine.com/products/passwordmanagerpro/help/installation.html#Ports
EXPOSE 5522/tcp 7070/tcp 7272/tcp 7273/tcp

ENTRYPOINT ["/entrypoint.sh"]

VOLUME ["/config"]
VOLUME ["/data"]

HEALTHCHECK --start-period=5m CMD curl -qskL https://localhost:7272 || exit 1
