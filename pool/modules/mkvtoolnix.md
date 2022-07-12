# mkvtoolnix

* MKVToolNix is a set of tools to create, alter and inspect mkv files.
* https://hub.docker.com/r/jlesage/mkvtoolnix
* https://github.com/jlesage/docker-mkvtoolnix

# howto

* To activate use : `TANGO_SERVICES_MODULES+=mkvtoolnix` or `--module=mkvtoolnix`

# volumes

| inside path | host path variables | default host path values | desc |
|-|-|-|-|
| `/config` | `CTX_DATA_PATH/MKVTOOLNIX_DATA_PATH` | `data/mkvtoolnix` | contains mkvtoolnix config |