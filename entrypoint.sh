#!/usr/bin/env bash

POSTGRES_HOST=${POSTGRES_HOST:-database}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_DB=${POSTGRES_DB:-pmp}
POSTGRES_USER=${POSTGRES_USER:-pmp}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-pmppassword}

SERVER_STATE=${SERVER_STATE:-master}
TIMEOUT_DB=${TIMEOUT_DB:-60}
TIMEOUT_PMP=${TIMEOUT_PMP:-300}

set_server_state() {
  echo "$SERVER_STATE" > "${PMP_HOME}/conf/serverstate.conf"
}

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

  # Update enc key location if there's one in /config
  set_enc_key_location
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

set_enc_key_location() {
  # Set encryption key location
  local pmp_key_vol="/config/pmp_key.key"

  if [[ -e "$pmp_key_vol" ]]
  then
    echo "$pmp_key_vol" > "${PMP_HOME}/conf/manage_key.conf"
  fi
}

save_enc_key() {
  local pmp_key="${PMP_HOME}/conf/pmp_key.key"
  local pmp_key_vol="/config/pmp_key.key"

  if [[ -e "$pmp_key" ]]
  then
    echo "Move pmp_key.key to /config"
    echo "$pmp_key_vol" > "${PMP_HOME}/conf/manage_key.conf"
    mv "$pmp_key" "$pmp_key_vol"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  set_server_state
  db_setup
  wait_for_db

  symlink_logs_dir
  symlink_default_backup_dir

  start_pmp
  wait_for_pmp

  while pmp_is_running
  do
    # Move key to /config
    save_enc_key
    sleep 5
  done
fi
