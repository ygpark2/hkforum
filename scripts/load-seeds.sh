#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
RENDERER="$SCRIPT_DIR/render-seeds.py"

usage() {
    cat <<'EOF'
Usage:
  scripts/load-seeds.sh sqlite [db_path]
  scripts/load-seeds.sh postgres [connstr]
  scripts/load-seeds.sh mariadb [database]

Environment variables:
  LOCATION_REGION_SEED_SUFFIXES  Region seed suffixes, default ko
  SQLITE_DATABASE                SQLite DB path fallback
  POSTGRES_CONNSTR               PostgreSQL connstr fallback
  MARIADB_HOST                   MariaDB host, default 127.0.0.1
  MARIADB_PORT                   MariaDB port, default 3306
  MARIADB_USER                   MariaDB user, default root
  MARIADB_PASSWORD               MariaDB password, optional
  MARIADB_DATABASE               MariaDB database fallback

Notes:
  - Run schema migrations first.
  - App runtime officially supports sqlite/postgres. MariaDB here is seed SQL rendering/loading support.
EOF
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

backend=${1:-}
sql_file=$(mktemp "${TMPDIR:-/tmp}/hkforum-seeds.XXXXXX.sql")
trap 'rm -f "$sql_file"' EXIT HUP INT TERM

case "$backend" in
    sqlite)
        require_command sqlite3
        "$RENDERER" sqlite > "$sql_file"
        db_path=${2:-${SQLITE_DATABASE:-"$PROJECT_ROOT/data/hkforum.sqlite3"}}
        sqlite3 "$db_path" < "$sql_file"
        ;;
    postgres|postgresql)
        require_command psql
        "$RENDERER" postgres > "$sql_file"
        connstr=${2:-${POSTGRES_CONNSTR:-}}
        if [ -z "$connstr" ]; then
            echo "PostgreSQL connection string is required." >&2
            echo "Set POSTGRES_CONNSTR or pass it as the second argument." >&2
            exit 1
        fi
        psql "$connstr" -v ON_ERROR_STOP=1 -f "$sql_file"
        ;;
    mariadb|mysql)
        "$RENDERER" mariadb > "$sql_file"
        db_name=${2:-${MARIADB_DATABASE:-}}
        db_host=${MARIADB_HOST:-127.0.0.1}
        db_port=${MARIADB_PORT:-3306}
        db_user=${MARIADB_USER:-root}
        db_password=${MARIADB_PASSWORD:-}

        if [ -z "$db_name" ]; then
            echo "MariaDB database name is required." >&2
            echo "Set MARIADB_DATABASE or pass it as the second argument." >&2
            exit 1
        fi

        if command -v mariadb >/dev/null 2>&1; then
            db_client=mariadb
        elif command -v mysql >/dev/null 2>&1; then
            db_client=mysql
        else
            echo "Missing required command: mariadb or mysql" >&2
            exit 1
        fi

        MYSQL_PWD=$db_password \
            "$db_client" \
            --host="$db_host" \
            --port="$db_port" \
            --user="$db_user" \
            "$db_name" \
            < "$sql_file"
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac
