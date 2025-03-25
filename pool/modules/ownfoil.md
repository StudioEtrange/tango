# Ownfoil

*Ownfoil is a Nintendo Switch library manager, that will also turn your library into a fully customizable and self-hosted Tinfoil Shop*

---
## Links

|description|links|
|-|-|
| code source | https://github.com/a1ex4/ownfoil |
| documentation | |
| docker image code source | https://github.com/a1ex4/ownfoil |
| docker image documentation | https://hub.docker.com/r/a1ex4/ownfoil |
| docker image registry | https://hub.docker.com/r/a1ex4/ownfoil |



---
## Quick samples

* `./tango --module ownfoil --domain domain.org --freeport up`

* `OWNFOIL_USER_ADMIN_NAME=admin OWNFOIL_USER_ADMIN_PASSWORD=admin ./tango --module ownfoil --domain domain.org --freeport up`

---
## Information

* This module is scalable to several instances.
* `SWITCH_PROD_KEYS_FILE` is optional and allow to identify switch games without renaming them
  
---
## Variables

|variable name|description|access mode|default value|sample value|
|-|-|-|-|-|
| OWNFOIL_DATA_PATH |contains ownfoil config path. Absolute path or relative path to `CTX_DATA_PATH`|R/W|`ownfoil`|`{{$HOME}}/ownfoil_data`|
| GAMES_SWITCH_LIBRARY_PATH | rom files path. Absolute path or relative path to `TANGO_CTX_WORK_ROOT` | R/W |`games_switch_library` | `/mnt/switchgames`|
| SWITCH_PROD_KEYS_FILE | optional switch prod keys file path. Absolute path | R/W | | `/mnt/switch/keys/prod.txt`|
| OWNFOIL_USER_ADMIN_NAME | manage an admin account : account name | R/W | | `admin` |
| OWNFOIL_USER_ADMIN_PASSWORD | manage an admin account : password | R/W | | `ch@ngeme` |
| OWNFOIL_USER_GUEST_NAME | manage a regular account : account name | R/W | | `guest` |
| OWNFOIL_USER_GUEST_PASSWORD | manage a regular account : password | R/W | | `ch@ngeme` |
---

## Volumes

|type|name|host path|container path|description|
|-|-|-|-|-|
|named|ownfoil_data|`OWNFOIL_DATA_PATH`|`/app/config`|ownfoil config files|
|named|games_switch_library|`GAMES_SWITCH_LIBRARY_PATH`|`/games`|games|
|bind mount||`SWITCH_PROD_KEYS_FILE`|`/app/config/keys.txt`|optional switch prod keys file path|
---

## Network

### Entrypoints

|service name|subservice name|default network area|protocol|service port|URI|description|
|-|-|-|-|-|-|-|
|ownfoil||main|HTTP/HTTPS|8465|`http://OWNFOIL_SUBDOMAIN.TANGO_DOMAIN/`|main ownfoil access point|




### Specific network area


|network area name|protocol|default port|default secure port|
|-|-|-|-|


---

## TODO

* make ownfoil url shop configurable with env var