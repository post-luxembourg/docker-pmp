FROM ubuntu:18.04

ENV PMP_HOME=/srv/PMP
ENV SERVER_STATE=master
ENV TIMEOUT_DB=60
ENV TIMEOUT_PMP=300

ADD https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh \
  /usr/bin/wait-for-it.sh

ADD https://www.manageengine.com/products/passwordmanagerpro/8621641/ManageEngine_PMP_64bit.bin \
      /tmp/ManageEngine_PMP_64bit.bin
# Comment the line above and uncomment the next one to use a local binary
# COPY ManageEngine_PMP_64bit.bin /tmp/ManageEngine_PMP_64bit.bin

COPY pmp.properties /tmp/pmp.properties
COPY entrypoint.sh /entrypoint.sh

RUN apt-get update && \
    apt-get install -y curl unzip && \
    rm -rf /var/lib/apt/lists/* && \
    chmod +x /tmp/ManageEngine_PMP_64bit.bin /usr/bin/wait-for-it.sh && \
    /tmp/ManageEngine_PMP_64bit.bin -i silent -f /tmp/pmp.properties && \
    rm -rf "${PMP_HOME}/logs" && \
    mkdir -p /data/logs /data/backups && \
    ln -sf /data/logs "${PMP_HOME}/logs" && \
    ln -sf /data/backups "${PMP_HOME}/Backup" && \
    cd "${PMP_HOME}/bin" && \
    bash pmp.sh install | grep "installed successfully" && \
    rm -rf /tmp/ManageEngine_PMP_64bit.bin /tmp/pmp.properties

WORKDIR ${PMP_HOME}

# https://www.manageengine.com/products/passwordmanagerpro/help/installation.html#Ports
# Built-in SSHd aka SSH CLI API
EXPOSE 5522/tcp
# API
EXPOSE 7070/tcp
# HTTP Management UI
EXPOSE 7272/tcp
# Remote Desktop Gateway Port
EXPOSE 7273/tcp

ENTRYPOINT ["/entrypoint.sh"]

VOLUME ["/config"]
VOLUME ["/data"]

HEALTHCHECK --start-period=5m CMD curl -qskL https://localhost:7272 || exit 1
