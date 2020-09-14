#!/bin/bash
TANGO_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TANGO_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"

# TANGO
[ "${TANGO_ROOT}" = "" ] && TANGO_ROOT="${TANGO_CURRENT_FILE_DIR}/.."
TANGO_ROOT="$($STELLA_API rel_to_abs_path "${TANGO_ROOT}" "${TANGO_CURRENT_RUNNING_DIR}")"
# normalize path /foo/bar/../path is turned into /foo/bar
TANGO_ROOT="$(readlink -m "$TANGO_ROOT")"
TANGO_COMPOSE_FILE="${TANGO_ROOT}/tango.internal.docker-compose.yml"
TANGO_ENV_FILE="${TANGO_ROOT}/tango.internal.env"

TANGO_MODULES_ROOT="${TANGO_ROOT}/pool/modules"
TANGO_PLUGINS_ROOT="${TANGO_ROOT}/pool/plugins"

TANGO_LOG_STATE="ON"
TANGO_LOG_LEVEL="INFO"

# associative array for mapping plugins by service that are atteched to
declare -A TANGO_PLUGINS_BY_SERVICE_FULL
# associative array for mapping auto exec plugins by service executed at service launch
declare -A TANGO_PLUGINS_BY_SERVICE_FULL_AUTO_EXEC
# associative array for mapping services by plugin
declare -A TANGO_SERVICES_BY_PLUGIN_FULL

# load some external libs
. "${TANGO_ROOT}/pool/bash_colors/bash_colors.sh"

# load tango libs
for f in ${TANGO_ROOT}/pool/libs/*; do
	[ -f "${f}" ] && . ${f}
done

