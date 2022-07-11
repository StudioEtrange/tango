# template

* https://hub.docker.com/r/linuxserver/template
* https://github.com/foo/Template

# howto

* To activate use : `TANGO_SERVICES_MODULES+=template` or `--module=template`


# volumes

| inside path | host path variables | default host path values | desc |
|-|-|-|-|
| `/config` | `APP_DATA_PATH/ROMVAULT_DATA_PATH` | `data/romvault` | contains romvault config |