#!/usr/bin/env bash

MODE="$1"
[ "${MODE}" = "" ] && MODE = "info"

echo "---------==---- ${TANGO_APP_NAME_CAPS} SPECIFIC INFO ----==---------"
echo Hello from ${TANGO_APP_NAME}

if [ "${MODE}" = "init" ]; then
    echo "---------==---- $TANGO_APP_NAME_CAPS SPECIFIC INIT SERVICES ----==---------"
    echo Init of ${TANGO_APP_NAME}
    echo L-- create [$APP_DATA_PATH/$WEB2_ROOT_FOLDER] {/data/$WEB2_ROOT_FOLDER}
    mkdir -p "/data/$WEB2_ROOT_FOLDER"
    echo L-- create [$APP_DATA_PATH/transmission_data] {/data/transmission_data}
    mkdir -p "/data/transmission_data"
    echo L-- create [$APP_DATA_PATH/transmission_download] {/data/transmission_download}
    mkdir -p "/data/transmission_download"
    echo L-- create [$APP_DATA_PATH/transmission_watch] {/data/transmission_watch}
    mkdir -p "/data/transmission_watch"
fi