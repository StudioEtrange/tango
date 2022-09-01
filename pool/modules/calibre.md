# calibre

* Calibre is a desktop e-book manager. This module sets up the calibre desktop app and makes its interface available via a web browser.

* calibre url
    * https://github.com/kovidgoyal/calibre

* docker image
    * https://github.com/linuxserver/docker-calibre
    * ghcr.io : https://github.com/linuxserver/docker-calibre/pkgs/container/calibre

* versions list : https://hub.docker.com/r/linuxserver/calibre/tags


# volumes

| inside path | host path variables | default host path values | desc |
|-|-|-|-|
| `/config` | `CTX_DATA_PATH/CALIBRE_DATA_PATH` | `data/calibre` | path folder contains calibre config |
| `/calibre_db/default` | `EBOOKS_PATH/CALIBRE_DB_PATH` | `ebooks/calibre_db` | calibre default database files |

# how-to

## sample 
 
`TANGO_DOMAIN="domain.com" ./tango up calibre --module=calibre`

## import calibre database from calibreweb

* You can have calibre database used by calibreweb module instance used aswell into calibre module instance

    * To enable this feature specify calibreweb module before calibre in TANGO_SERVICES_MODULES or in --module option
    * in your env file, define this variable CALIBRE_ADDITIONAL_VOLUMES={{SHARED_VAR_CALIBREWEB_DB_LIST}}

`TANGO_DOMAIN="domain.com" CALIBRE_ADDITIONAL_VOLUMES="{{SHARED_VAR_CALIBREWEB_DB_LIST}}" ./tango up --module=calibreweb^3 --module=calibre^2`