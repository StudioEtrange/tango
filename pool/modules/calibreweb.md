# calibreweb

* https://github.com/linuxserver/docker-calibre-web
* https://hub.docker.com/r/linuxserver/calibre-web
* ghcr.io : https://github.com/linuxserver/docker-calibre-web/pkgs/container/calibre-web



# howto

* To activate use : `TANGO_SERVICES_MODULES+=calibreweb` or `--module=calibreweb`
* will import calibre binaries of this version through a DOCKER_MODS (https://hub.docker.com/r/studioetrange/calibre-mods) that will auto create an empty calibre database `/calibreweb_db` if it does not already exists

# volumes

| inside path | host path variables | default host path values | desc |
|-|-|-|-|
| `/config` | `APP_DATA_PATH/CALIBREWEB_DATA_PATH` | `data/calibreweb` | contains calibreweb config |
| `//calibreweb_db` | `EBOOKS_PATH/CALIBREWEB_MEDIA_PATH` | `ebooks/calibreweb` | will contains calibre database |
