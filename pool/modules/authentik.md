# Template

*Application template is a random application*

---
## Links

|description|links|
|-|-|
| code source | https://github.com/foo/Template |
| documentation | http://doc.template |
| docker image code source | https://github.com/linuxserver/docker-calibre-web |
| docker image documentation | https://docs.linuxserver.io/images/docker-piwigo |
| docker image registry | https://hub.docker.com/r/linuxserver/template |
|| https://ghcr.io/linuxserver/template |


---
## Quick samples

* `./tango --module calibreweb --domain domain.org --freeport up`

---
## Information

* This module will import calibre binaries through a [DOCKER_MODS](https://hub.docker.com/r/studioetrange/calibre-mods). Those binaries are used to auto create an empty calibre database `/calibreweb_db` if it does not already exists

* Default account at first launch is `admin/admin123` *(do forget me)*

* This module is scalable to several instances.

---
## Variables

|variable name|description|access mode|default value|sample value|
|-|-|-|-|-|
|CALIBREWEB_DATA_PATH|contains calibreweb config path. Absolute path or relative path to `CTX_DATA_PATH`|R/W|`calibreweb`|`{{$HOME}}/calibreweb_data`|
|CALIBREWEB_DB_PATH|contains calibre database files path. Absolute path or relative path to `EBOOKS_PATH`|R/W|`calibreweb_db`|`/mnt/nas/books`|
|EBOOKS_PATH|can be use to set a default root path for storing several calibre databases. Absolute path or relative path to `TANGO_CTX_WORK_ROOT`|R/W|`ebooks`|`/mnt/nas`|
|SHARED_VAR_CALIBREWEB_DB_LIST|list of all calibre databases docker volumes shared by all calibreweb instances|RO|`calibreweb_db:/db/calibreweb_db`||
|CALIBRE_MOD_VERSION_FIXED_VAR|import calibre binaries of this version inside calibreweb container. Used to auto create empty database and convert ebooks. [Versions list](https://hub.docker.com/r/studioetrange/calibre-mod/tags)|R/W|`v5.22.1`|`v5.22.1`|


---
## Volumes

|type|name|host path|container path|description|
|-|-|-|-|-|
|named|calibreweb_data|`CALIBREWEB_DATA_PATH`|`/config`|calibreweb config files|
|named|calibreweb_db|`CALIBREWEB_DB_PATH`|`/db/calibreweb_db`|calibre database|

---

## Network

### Entrypoints

|service name|subservice name|default network area|protocol|service port|URI|description|
|-|-|-|-|-|-|-|
|calibreweb||main|HTTP/HTTPS|8083|`http://CALIBREWEB_SUBDOMAIN.TANGO_DOMAIN/`|main calibreweb access point|
||calibreweb_kobo|main|HTTP/HTTPS|8083|`http://CALIBREWEB_SUBDOMAIN.TANGO_DOMAIN/kobo/`|dedicated access point to kobo|



### Specific network area


|network area name|protocol|default port|default secure port|
|-|-|-|-|
|zoneapi||||
|zone1||||


---

## TODO