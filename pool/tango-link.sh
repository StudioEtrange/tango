#!/bin/bash
_TANGO_LINK_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_TANGO_LINK_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"

[[ "$0" != "$BASH_SOURCE" ]] && sourced=1 || sourced=0

# INIT TANGO -------------------
# TANGO lookup order
#       1. TANGO_ROOT is defined externally ==> instance mode : isolated or shared       
#       2. "${_TANGO_LINK_CURRENT_FILE_DIR}/tango"     ==> instance mode : isolated only. shared instance is not compatible with this location
#       3. "${_TANGO_LINK_CURRENT_FILE_DIR}/../tango"  ==> instance mode : isolated or shared
VENDORIZED_TANGO_ROOT="${_TANGO_LINK_CURRENT_FILE_DIR}/tango"
INSTANCE_MODE_SHARED_OK=
if [ "${TANGO_ROOT}" = "" ]; then
    if [ -d "${VENDORIZED_TANGO_ROOT}" ]; then
        TANGO_ROOT="${VENDORIZED_TANGO_ROOT}"
    elif [ -d "${_TANGO_LINK_CURRENT_FILE_DIR}/../tango" ]; then
        TANGO_ROOT="${_TANGO_LINK_CURRENT_FILE_DIR}/../tango"
        INSTANCE_MODE_SHARED_OK=1
    fi
else
    if [ -d "${TANGO_ROOT}" ]; then
        TANGO_ROOT="$(cd "${TANGO_ROOT}" && pwd -P)"
        [ ! "${TANGO_ROOT}" = "${VENDORIZED_TANGO_ROOT}" ] && INSTANCE_MODE_SHARED_OK=1
    elif [ -d "${_TANGO_LINK_CURRENT_FILE_DIR}/../tango" ]; then
        TANGO_ROOT="${_TANGO_LINK_CURRENT_FILE_DIR}/../tango"
        INSTANCE_MODE_SHARED_OK=1
    fi
fi

if [ ! -d "${TANGO_ROOT}" ]; then
    [ "$TANGO_LOG_STATE" = "ON" ] && echo "ERROR @tango> tango not found, by default it is first lookup into ${_TANGO_LINK_CURRENT_FILE_DIR}/../tango OR defined its path with TANGO_ROOT"
    exit 1
fi

if [ "$sourced" = "1" ]; then
    for option in $1; do
        case "$option" in
            set-tango-root)
                export TANGO_ROOT="${TANGO_ROOT}"
                ;;
            include-stella)
                export STELLA_APP_ROOT="${_TANGO_LINK_CURRENT_FILE_DIR}"
                . "${TANGO_ROOT}/stella-link.sh" include
                ;;
            *)
                export STELLA_APP_ROOT="${_TANGO_LINK_CURRENT_FILE_DIR}"
                . "${TANGO_ROOT}/stella-link.sh" include
                ;;
        esac
    done
else
    # tango will auto load stella
    export STELLA_APP_ROOT="${_TANGO_LINK_CURRENT_FILE_DIR}"
    $TANGO_ROOT/tango --ctx "$(basename $_TANGO_LINK_CURRENT_FILE_DIR)" --ctxroot "${_TANGO_LINK_CURRENT_FILE_DIR}" $*
    #$TANGO_ROOT/tango $*
fi