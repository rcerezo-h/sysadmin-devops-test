#!/usr/bin/env bash

set -Eeuo pipefail

BACKUP_DIR="/var/backups/inventario"
DB_NAME="inventario"
DB_USER="inventario"
DB_HOST="localhost"
RETENTION_DAYS=7

TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_FILE="${BACKUP_DIR}/inventario-${TIMESTAMP}.sql"
COMPRESSED_FILE="${BACKUP_FILE}.gz"

# Evita que otros usuarios puedan leer los backups creados.
umask 077

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

cleanup() {
    rm -f -- "$BACKUP_FILE"
}

trap cleanup ERR INT TERM

mkdir -p "$BACKUP_DIR"

log "Iniciando backup en ${COMPRESSED_FILE}"

pg_dump \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    "$DB_NAME" > "$BACKUP_FILE"

gzip "$BACKUP_FILE"

log "Limpiando backups de más de ${RETENTION_DAYS} días"

find "$BACKUP_DIR" \
    -type f \
    -name 'inventario-*.sql.gz' \
    -mtime "+${RETENTION_DAYS}" \
    -delete

trap - ERR INT TERM

log "Backup completado correctamente: ${COMPRESSED_FILE}"