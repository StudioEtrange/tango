

# jdownloader2headless

* direct download manager without GUI
* https://github.com/PlusMinus0/headless-jd2-docker

# howto

* To activate use : `TANGO_SERVICES_MODULES+=jdownloader2headless` or `--module=jdownloader2headless`
* This version is headless. You should use MyJdownloader on https://my.jdownloader.org/ to pilot it

# volumes

| inside path | host path variables | default host path values | desc |
|-|-|-|-|
| `/config` | `CTX_DATA_PATH/JDOWNLOADER2HEADLESS_DATA_PATH` | `data/jdownloader2` | contains jdownloader2 config |
| `/output` | `DOWNLOAD_PATH/JDOWNLOADER2HEADLESS_DOWNLOAD_PATH` | `download/jdownloader2` | contains downloaded files |
