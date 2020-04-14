#!/bin/bash
TANGO_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TANGO_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"

# TANGO
[ "${TANGO_ROOT}" = "" ] && TANGO_ROOT="${TANGO_CURRENT_FILE_DIR}/.."
TANGO_ROOT="$($STELLA_API rel_to_abs_path "${TANGO_ROOT}" "${TANGO_CURRENT_RUNNING_DIR}")"
# normallize path /foo/bar/../path is turned into /foo/bar
TANGO_ROOT="$(readlink -m "$TANGO_ROOT")"
TANGO_COMPOSE_FILE="${TANGO_ROOT}/tango.docker-compose.yml"
TANGO_ENV_FILE="${TANGO_ROOT}/tango.env"

# load tango libs
for f in ${TANGO_ROOT}/pool/libs/*; do
	[ -f "${f}" ] && . ${f}
done


# # generate temporary bash env files with default tango env file
# GENERATED_ENV_FILE_FOR_BASH="/tmp/generated.tango.bash.env"
# __create_env_for_bash

# # load variables 
# # so priority here become :
# # 	- default env file
# . "${GENERATED_ENV_FILE_FOR_BASH}"