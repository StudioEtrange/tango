# filezilla

* https://github.com/jlesage/docker-filezilla
* https://hub.docker.com/r/jlesage/filezilla

# howto

* To activate use : `TANGO_SERVICES_MODULES+=filezilla` or `--module=filezilla`


# volumes

| inside path | host path variables | default host path values | desc |
|-|-|-|-|
| `/config` | `CTX_DATA_PATH/CALIBREWEB_DATA_PATH` | `data/filezilla` | contains filezilla config |
| `/storage` | `FILEZILLA_HOSTFILES_PATH` | `$(pwd)` | underlying host files seen by default in filezilla left panel |
