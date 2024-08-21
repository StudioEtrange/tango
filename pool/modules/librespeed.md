# librespeed

*Librespeed is a very lightweight Speedtest implemented in Javascript, using XMLHttpRequest and Web Workers. No Flash, No Java, No Websocket, No Bullshit.*

---
## Links

|description|Links|
|-|-|
| code source | https://github.com/librespeed/speedtest |
| documentation| https://librespeed.org/ |
| docker image code source | https://github.com/linuxserver/docker-librespeed |
| docker image documentation | https://docs.linuxserver.io/images/docker-librespeed |
| docker image registry | https://hub.docker.com/r/linuxserver/librespeed |


---
## Quick samples

* `./tango --module librespeed --domain domain.org --freeport up`

---
## Information

* This module is scalable to several instances.

* This module do not support recording results into a database.

---
## Variables

|variable name|description|access mode|default value|sample value|
|-|-|-|-|-|
|LIBRESPEED_DATA_PATH|contains librespeed config path. Absolute path or relative path to `CTX_DATA_PATH`|R/W|`librespeed`|`{{$HOME}}/librespeed_data`|
|LIBRESPEED_PASSWORD|password to acces to stored results historic at /results/stats.php|R/W|``|`alpha123`|
|LIBRESPEED_DB_TYPE|database used by librespeed to store results|R/W|`sqlite`|`sqlite`|

---
## Volumes

|type|name|host path|container path|description|
|-|-|-|-|-|
|named|librespeed_data|`LIBRESPEED_DATA_PATH`|`/config`|librespeed config files|

---

## Network

### Entrypoints

|service name|subservice name|default network area|protocol|service port|URI|description|
|-|-|-|-|-|-|-|
|librespeed||main|HTTP/HTTPS|80|`http://LIBRESPEED_SUBDOMAIN.TANGO_DOMAIN/`|main librespeed access point|



### Specific network area


|network area name|protocol|default port|default secure port|
|-|-|-|-|

