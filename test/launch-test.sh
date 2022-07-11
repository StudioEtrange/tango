#!/bin/bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "${BASH_SOURCE[1]}" )" && pwd )"

STELLA_LOG_STATE="OFF"
. "$_CURRENT_FILE_DIR/stella-link.sh" include

$STELLA_API require "bats" "bats"

# location of tango framework
TANGO_ROOT="${_CURRENT_FILE_DIR}/.."
# load tango init
. "${TANGO_ROOT}/src/tango-init.sh"

function test_launch_bats() {
	local domain="$1"

  local _v=$(mktmp)
  declare >"$_v"
  declare -f >>"$_v"

	__BATS_STELLA_DECLARE="$_v" bats --verbose-run "$STELLA_APP_ROOT/test_$domain.bats"

  rm -f "$_v"
}





case $1 in
  all|"" )
    test_launch_bats common
    ;;
  * )
    test_launch_bats $1
    ;;
esac





