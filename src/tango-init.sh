#!/bin/bash
TANGO_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TANGO_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"

# TANGO
[ "${TANGO_ROOT}" = "" ] && TANGO_ROOT="${TANGO_CURRENT_FILE_DIR}/.."
TANGO_ROOT="$($STELLA_API rel_to_abs_path "${TANGO_ROOT}" "${TANGO_CURRENT_RUNNING_DIR}")"
# normallize path /foo/bar/../path is turned into /foo/bar
TANGO_ROOT="$(readlink -m "$TANGO_ROOT")"
TANGO_COMPOSE_FILE="${TANGO_ROOT}/tango.internal.docker-compose.yml"
TANGO_ENV_FILE="${TANGO_ROOT}/tango.internal.env"

TANGO_MODULES_ROOT="${TANGO_ROOT}/pool/modules"

# load tango libs
for f in ${TANGO_ROOT}/pool/libs/*; do
	[ -f "${f}" ] && . ${f}
done

