# romvault


A template showing usage of docker image by jlesage, with romvault as sample

* romvault is a rom manager
* https://hub.docker.com/r/jlesage/romvault
* http://www.romvault.com/ 

# howto

* To activate use : `TANGO_SERVICES_MODULES+=romvault` or `--module=romvault`

# volumes

| inside path | host path variables | default host path values | desc |
|-|-|-|-|
| `/config` | `CTX_DATA_PATH/ROMVAULT_DATA_PATH` | `data/romvault` | contains romvault config |