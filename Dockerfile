FROM ubuntu:18.04

ARG PMP_HOME=/srv/pmp

ENV PMP_HOME=${PMP_HOME} \
    SERVER_STATE=master \
    TIMEOUT_DB=60 \
    TIMEOUT_PMP=300 \
    PMP_PORT=7272

COPY pmp.properties /tmp/pmp.properties
COPY entrypoint.sh /entrypoint.sh

# ADD ./ManageEngine_PMP_64bit.bin /tmp/pmp_installer.bin

RUN apt-get update && \
    apt-get install -y curl unzip && \
    curl -fsSL https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh \
      -o /usr/bin/wait-for-it.sh && \
    if [ "$(dpkg --print-architecture)" = "i386" ]; \
    then \
      install_bin=ManageEngine_PMP.bin; \
    else \
      install_bin=ManageEngine_PMP_64bit.bin; \
    fi && \
    echo "Grabbing md5 checksum from manageengine.com" && \
    curl -fsSL "https://www.manageengine.com/products/passwordmanagerpro/download.html" | \
      sed -n '/<!--PMP MD5SUM-->/,/<!--PMP MD5SUM-->/p;' | \
      sed -rn "/$install_bin/s/.*[<>]([^><]{32})[<>].+/\1/p" | \
      tr -d '\n' > /tmp/pmp_installer.bin.md5sum && \
    echo " /tmp/pmp_installer.bin" >> /tmp/pmp_installer.bin.md5sum && \
    cat /tmp/pmp_installer.bin.md5sum && \
    url="https://www.manageengine.com/products/passwordmanagerpro/8621641/${install_bin}" && \
    echo "Downloading PMP installer from $url" && \
    curl -fsSL -o /tmp/pmp_installer.bin "$url" && \
    md5sum -c /tmp/pmp_installer.bin.md5sum && \
    chmod +x /tmp/pmp_installer.bin /usr/bin/wait-for-it.sh && \
    # Update PMP_HOME in properties
    sed -i "s|/srv/pmp|${PMP_HOME}|" /tmp/pmp.properties && \
    /tmp/pmp_installer.bin -i silent -f /tmp/pmp.properties && \
    # If PMP_HOME does not end with a PMP dir then it get installed
    # in PMP_HOME/PMP
    if [ "$(basename $PMP_HOME)" != "PMP" ]; \
    then \
      mv "${PMP_HOME}/PMP" "/tmp/pmp.tmp" && \
      mv "${PMP_HOME}" "/tmp/pmp_deleteme" && \
      rmdir "/tmp/pmp_deleteme" && \
      mv "/tmp/pmp.tmp" "${PMP_HOME}"; \
    fi && \
    rm -rf "${PMP_HOME}/logs" && \
    mkdir -p /data/logs /data/backups && \
    ln -sf /data/logs "${PMP_HOME}/logs" && \
    ln -sf /data/backups "${PMP_HOME}/Backup" && \
    cd "${PMP_HOME}/bin" && \
    bash pmp.sh install | grep "installed successfully" && \
    # Save original config and symlink the conf dir
    mv "${PMP_HOME}/conf" "${PMP_HOME}/conf.orig" && \
    ln -sf /config "${PMP_HOME}/conf" && \
    # Do the same for PMP_HOME/lib (for license persistence)
    mv "${PMP_HOME}/lib" "${PMP_HOME}/lib.orig" && \
    ln -sf /data/lib "${PMP_HOME}/lib" && \
    # Cleanup
    rm -rf \
      /var/lib/apt/lists/* \
      /tmp/pmp_installer.bin \
      /tmp/pmp_installer.bin.md5sum \
      /tmp/pmp.properties

WORKDIR ${PMP_HOME}

# https://www.manageengine.com/products/passwordmanagerpro/help/installation.html#Ports
EXPOSE 5522/tcp 7070/tcp 7272/tcp 7273/tcp

ENTRYPOINT ["/entrypoint.sh"]

VOLUME ["/config"]
VOLUME ["/data"]

HEALTHCHECK --start-period=5m CMD curl -qskL https://localhost:7272 || exit 1
