#!/bin/bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"


# stella framework log
[ "$STELLA_LOG_STATE" = "" ] && STELLA_LOG_STATE="OFF"
[ "$STELLA_LOG_LEVEL" = "" ] && STELLA_LOG_LEVEL="INFO"
# tangp logs
[ "$TANGO_LOG_STATE" = "" ] && TANGO_LOG_STATE="ON"
[ "$TANGO_LOG_LEVEL" = "" ] && TANGO_LOG_LEVEL="INFO"
# note : $STELLA_API set_log_level_app is not yet available
STELLA_APP_LOG_STATE="$TANGO_LOG_STATE"
STELLA_APP_LOG_LEVEL="$TANGO_LOG_LEVEL"


. "${_CURRENT_FILE_DIR}/tango-link.sh" "set-tango-root include-stella"

"$TANGO_ROOT/tango" --ctx "$(basename $_CURRENT_FILE_DIR)" --ctxroot "${_CURRENT_FILE_DIR}" $*
    
 