# Komga

*A media server for your comics, mangas, BDs, magazines and eBooks.*

---
## Links

|description|links|
|-|-|
|code source|https://github.com/gotson/komga|
|documentation|https://komga.org/|
|docker image code source|https://github.com/gotson/komga/tree/master/komga/docker|
|docker image registry|https://hub.docker.com/r/gotson/komga|
||https://github.com/gotson/komga/pkgs/container/komga|

---
## Quick samples

* `./tango --module komga --domain domain.org --freeport up`

---
## Information

* This module is scalable to several instances.

* Memory settings : https://github.com/gotson/komga/issues/17

* TODO set env var KOMGA_CORS_ALLOWED_ORIGINS  ?
* TODO claim API to set admin account ? https://github.com/gotson/komga/blob/master/komga/docs/openapi.json#L2028
* TODO change admin password in cli ? https://komga.org/docs/guides/cli

---
## Variables

|variable name|description|access mode|default value|sample value|
|-|-|-|-|-|
|KOMGA_DATA_PATH|contains database and komga configurations. Absolute path or relative path to `CTX_DATA_PATH`|R/W|`komga`|`{{$HOME}}/komga_data`|
|KOMGA_MEDIA_PATH|contains media files. Absolute path or relative path to `EBOOKS_PATH`|R/W|`komga_media`|`/mnt/nas/comics`|
|EBOOKS_PATH|can be use to set a default root path for storing several ebooks location. Absolute path or relative path to `TANGO_CTX_WORK_ROOT`|R/W|`ebooks`|`/mnt/nas`|





---
## Volumes

|type|name|host path|container path|description|
|-|-|-|-|-|
|named|komga_data|`KOMGA_DATA_PATH`|`/config`|komga database and config files|
|named|komga_media|`KOMGA_MEDIA_PATH`|`/data`|komga media files|


---

## Network

### Entrypoints

|service name|subservice name|default network area|protocol|service port|URI|description|
|-|-|-|-|-|-|-|
|komga||main|HTTP/HTTPS|25600|`http://KOMGA_SUBDOMAIN.TANGO_DOMAIN/`|main komga access point|


