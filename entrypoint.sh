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

sync_lib_dir() {
  local ext_lib_path=/data/lib
  local lockfile="${ext_lib_path}/.INIT_SYNC_DONE"

  if ! [[ -e "$lockfile" ]]
  then
    echo "Copying lib dir to ${ext_lib_path}"
    if cp -a "${PMP_HOME}/lib.orig" "$ext_lib_path"
    then
      touch "$lockfile"
    fi
  fi

  # Ensure PMP_HOME/lib is symlinked to /data/lib
  if ! [[ -L "${PMP_HOME}/lib" ]]
  then
    ln -sf "$ext_lib_path" "${PMP_HOME}/lib"
  fi
}

init_data_dir() {
  symlink_logs_dir
  symlink_default_backup_dir
  sync_lib_dir
}

init_pmp_license() {
  local ext_license_path=/data/RegisterLicense.xml
  local pmp_license_path="${PMP_HOME}/licenses/RegisterLicense.xml"

  if [[ -r "$ext_license_path" ]]
  then
    echo "Installing license file to $pmp_license_path"
    cp "$ext_license_path" "$pmp_license_path"
  fi
}

check_pmp_license() {
  local ext_license_path=/data/RegisterLicense.xml
  local pmp_license_path="${PMP_HOME}/licenses/RegisterLicense.xml"

  if [[ -r "$pmp_license_path" ]]
  then
    if ! [[ -r "$ext_license_path" ]] || ! cmp "$ext_license_path" "$pmp_license_path"
    then
      echo "License change detected. Saving it to ${ext_license_path}."
      cp "$pmp_license_path" "$ext_license_path"
    fi
  fi
}

set_server_state() {
  echo "$SERVER_STATE" > "${PMP_HOME}/conf/serverstate.conf"
}

init_conf_dir() {
  local ext_conf_path=/config
  local lockfile="${ext_conf_path}/.INIT_SYNC_DONE"

  if ! [[ -e "$lockfile" ]]
  then
    echo "Copying config files to ${ext_conf_path}."
    if cp -a "${PMP_HOME}/conf.orig/"* "$ext_conf_path"
    then
      touch "$lockfile"
    fi
  fi

  # Ensure PMP_HOME/conf is symlinked to /config
  if ! [[ -L "${PMP_HOME}/conf" ]]
  then
    ln -sf "$ext_conf_path" "${PMP_HOME}/conf"
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

  init_pmp_license
  start_pmp
  wait_for_pmp

  while pmp_is_running
  do
    check_pmp_license
    sleep 5
  done
fi
