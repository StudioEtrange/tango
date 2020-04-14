#!/usr/bin/env bash


# NOTE :
# Error AttributeError 'module' object has no attribute 'InitialSchema'
# https://github.com/clinton-hall/nzbToMedia/issues/1614
# cd "${TARGET}"
# python -c "import cleanup; cleanup.force_clean_folder('libs', cleanup.FOLDER_STRUCTURE['libs'])"
# python -c "import cleanup; cleanup.force_clean_folder('core', cleanup.FOLDER_STRUCTURE['core'])"


ADDON="nzbtomedia"
[ "$1" = "" ] && VERSION="12.1.04" || VERSION="$1"
TARGET="/data/scripts/nzbToMedia"

if find "${TARGET}" -mindepth 1 2>/dev/null | read; then
    echo "-- ${ADDON} already installed in ${TARGET}"
else
    mkdir -p "${TARGET}"
    type curl 1>&2 2>/dev/null && {
        curl -fkSL -o "/tmp/${ADDON}-${VERSION}.tar.gz" "https://github.com/clinton-hall/nzbToMedia/archive/${VERSION}.tar.gz"
    } || {
        wget "https://github.com/clinton-hall/nzbToMedia/archive/${VERSION}.tar.gz" -O "/tmp/${ADDON}-${VERSION}.tar.gz" --no-check-certificate
    }

    cd "${TARGET}"
    tar xzf "/tmp/${ADDON}-${VERSION}.tar.gz" --strip-components=1
    cp "${TARGET}/autoProcessMedia.cfg.spec" "${TARGET}/autoProcessMedia.cfg"

    # add a sh launcher to force use of python3
    # NOTE : for python3 make a launcher for nzbToSickbeard because sabnzbd use python2 and we want nzbToSickBeard use python3
    tee "${TARGET}/nzbToSickBeard.sh" << END
#!/bin/bash
_CURRENT_FILE_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
python3 \${_CURRENT_FILE_DIR}/nzbToSickBeard.py "\$@"
END
    chmod +x "${TARGET}/nzbToSickBeard.sh"

fi

echo "-- Configuration file in : ${TARGET}/autoProcessMedia.cfg"
