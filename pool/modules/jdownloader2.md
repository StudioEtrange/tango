# jdownloader2

* direct download manager with GUI
* https://github.com/jlesage/docker-jdownloader-2

# howto

* To activate use : `TANGO_SERVICES_MODULES+=jdownloader2headless` or `--module=jdownloader2headless`

* NOTE to enable MyJdownloader, do it manually in jdownloader2 GUI

# volumes

| inside path | host path variables | default host path values | desc |
|-|-|-|-|
| `/config` | `CTX_DATA_PATH/JDOWNLOADER2_DATA_PATH` | `data/jdownloader2` | contains jdownloader2 config |
| `/output` | `DOWNLOAD_PATH/JDOWNLOADER2_DOWNLOAD_PATH` | `download/jdownloader2` | contains downloaded files |
