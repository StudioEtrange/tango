#!/bin/bash
TANGO_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TANGO_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"

export WORKING_DIR="${TANGO_CURRENT_RUNNING_DIR}"
export TANGO_VERSION=

# TANGO system requirements
TANGO_SYSTEM_REQUIREMENTS_LIST="awk sed docker"
for t in ${TANGO_SYSTEM_REQUIREMENTS_LIST}; do
	if ! type $t &>/dev/null; then
		echo "** ERROR : $t not found. Please install it."
		exit 1
	fi
done
# NOTES about different awk flavour.
# awk flavour diffenences
if ! awk 'BEGIN{ if(ENVIRON["HOME"]) exit 0; else exit 1;}'; then
	echo "** ERROR : Your current version of awk do not support ENVIRON. Please install a compatible awk flavour like GNU awk."
	exit 1
fi
if [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
	echo "** ERROR : You need at least bash version 4. Current version is ${BASH_VERSINFO:-0}."
	exit 1
fi



# TANGO
[ "${TANGO_ROOT}" = "" ] && TANGO_ROOT="${TANGO_CURRENT_FILE_DIR}/.."
TANGO_ROOT="$($STELLA_API rel_to_abs_path "${TANGO_ROOT}" "${TANGO_CURRENT_RUNNING_DIR}")"
# normalize path /foo/bar/../path is turned into /foo/bar
TANGO_ROOT="$(readlink -m "$TANGO_ROOT")"
TANGO_COMPOSE_FILE="${TANGO_ROOT}/tango.internal.docker-compose.yml"
TANGO_ENV_FILE="${TANGO_ROOT}/tango.internal.env"

TANGO_MODULES_ROOT="${TANGO_ROOT}/pool/modules"
TANGO_PLUGINS_ROOT="${TANGO_ROOT}/pool/plugins"



# switch to control modification of generated files and alteration of filesystem (files & folder)
TANGO_ALTER_GENERATED_FILES="ON"

# associative array for mapping plugins by service that are atteched to
declare -A TANGO_PLUGINS_BY_SERVICE_FULL
# associative array for mapping auto exec plugins by service executed at service launch
declare -A TANGO_PLUGINS_BY_SERVICE_FULL_AUTO_EXEC
# associative array for mapping services by plugin
declare -A TANGO_SERVICES_BY_PLUGIN_FULL


# load tango libs
for f in ${TANGO_ROOT}/pool/libs/*; do
	[ -f "${f}" ] && . ${f}
done

if [ "$1" = "-v" ]; then
	__tango_get_version
	exit 0
fi