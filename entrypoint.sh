#!/usr/bin/env bash

POSTGRES_HOST=${POSTGRES_HOST:-database}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_DB=${POSTGRES_DB:-pmp}
POSTGRES_USER=${POSTGRES_USER:-pmp}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-pmppassword}

SERVER_STATE=${SERVER_STATE:-master}
TIMEOUT_DB=${TIMEOUT_DB:-60}
TIMEOUT_PMP=${TIMEOUT_PMP:-300}

db_setup() {
  local db_conf="${PMP_HOME}/conf/database_params.conf"

  # Update DB connection parameters
  sed -ri 's/^(username)=.*/\1='"$POSTGRES_USER"'/' "$db_conf"
  sed -ri 's/^(password)=.*/\1='"$POSTGRES_PASSWORD"'/' "$db_conf"
  # sed -i 's|^\(url\)=.*|\1=jdbc:postgresql://'"${POSTGRES_HOST}"':'"${POSTGRES_PORT}"'/'"${POSTGRES_DB}"'?ssl=true\&sslmode=prefer|' "$db_conf"
  sed -ri 's|^(url)=.*|\1=jdbc:postgresql://'"${POSTGRES_HOST}"':'"${POSTGRES_PORT}"'/'"${POSTGRES_DB}"'?ssl=false|' \
    "$db_conf"
  sed -ri 's/^(db.password.encrypted)=.*/\1=false/' "$db_conf"

  # Disable startup of internal DB
  sed -ri 's|(.*name="StartDBServer" value=").+|\1false"/>|' \
    "${PMP_HOME}/conf/customer-config.xml"
}

symlink_default_backup_dir() {
  # Symlink default database backup location to /data volume
  mkdir -p /data/backups

  if ! [[ -L "${PMP_HOME}/Backup" ]]
  then
    ln -sf "/data/backups" "${PMP_HOME}/Backup"
  fi
}

symlink_logs_dir() {
  mkdir -p /data/logs

  if ! [[ -L "${PMP_HOME}/logs" ]]
  then
    ln -sf "/data/logs" "${PMP_HOME}/logs"
  fi
}

init_data_dir() {
  symlink_logs_dir
  symlink_default_backup_dir
}

set_server_state() {
  echo "$SERVER_STATE" > "${PMP_HOME}/conf/serverstate.conf"
}

init_conf_dir() {
  local lockfile=/config/.INIT_SYNC_DONE

  if ! [[ -e "$lockfile" ]]
  then
    echo "Copying config files to /config"
    if cp -a "${PMP_HOME}/conf.orig/"* /config
    then
      touch "$lockfile"
    fi
  fi

  # Ensure PMP_HOME/conf is symlinked to /config
  if ! [[ -L "${PMP_HOME}/conf" ]]
  then
    ln -sf /config "${PMP_HOME}/conf"
  fi

  set_server_state
}

wait_for_db() {
  if ! wait-for-it.sh -t "$TIMEOUT_DB" "${POSTGRES_HOST}:${POSTGRES_PORT}"
  then
    echo -n "Timed out while trying to reach the database " >&2
    echo "${POSTGRES_HOST}:${POSTGRES_PORT} - Timeout: ${TIMEOUT_DB}s" >&2
    exit 8
  fi
}

start_pmp() {
  /etc/init.d/pmp-service start

  (tail -f "${PMP_HOME}"/logs/*)&
}

wait_for_pmp() {
  if ! wait-for-it.sh -t "$TIMEOUT_PMP" localhost:7272
  then
    echo "PMP failed to start - Timeout: ${TIMEOUT_PMP}s" >&2
    exit 7
  fi
}

pmp_is_running() {
  # while ps -aux | grep -q "${PMP_HOME}"
  /etc/init.d/pmp-service status | grep -q "PMP is running"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  init_conf_dir
  init_data_dir

  db_setup
  wait_for_db

  start_pmp
  wait_for_pmp

  while pmp_is_running
  do
    sleep 5
  done
fi
