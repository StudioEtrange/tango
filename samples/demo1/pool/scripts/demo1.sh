#!/usr/bin/env bash

MODE="$1"
[ "${MODE}" = "" ] && MODE = "info"

echo "---------==---- ${TANGO_APP_NAME_CAPS} SPECIFIC INFO ----==---------"
echo Hello from ${TANGO_APP_NAME}

if [ "${MODE}" = "init" ]; then
    echo "---------==---- $TANGO_APP_NAME_CAPS SPECIFIC INIT SERVICES ----==---------"
    echo Init of ${TANGO_APP_NAME}
    echo L-- create [$APP_DATA_PATH/$WEBROOT] {/data/$WEBROOT}
    mkdir -p "/data/$WEBROOT"
fi