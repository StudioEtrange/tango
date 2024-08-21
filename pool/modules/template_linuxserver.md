# codeserver

*A template showing usage of docker image by Linuxserver.io, with codeserver as sample*

---
## Links

|description|Links|
|-|-|
| code source | https://github.com/Piwigo/Piwigo |
| documentation | http://piwigo.org/|
| docker image code source | https://github.com/linuxserver/docker-piwigo |
| docker image documentation | https://docs.linuxserver.io/images/docker-piwigo |
| docker image registry | https://fleet.linuxserver.io/image?name=linuxserver/piwigo |
|| https://hub.docker.com/r/linuxserver/piwigo |
|| https://github.com/linuxserver/docker-piwigo/pkgs/container/piwigo |

---
## Quick samples

* `./tango --module codeserver --domain domain.org --freeport up`

---
## Information

* Default account at first launch is `admin/admin123` *(do forget me)*

* This module is scalable to several instances.

---
## Variables

|variable name|description|access mode|default value|sample value|
|-|-|-|-|-|
|CODESERVER_DATA_PATH|contains codeserver config path. Absolute path or relative path to `CTX_DATA_PATH`|R/W|`codeserver`|`{{$HOME}}/codeserver_data`|
|CODESERVER_PASSWORD|Optional web gui password|R/W||`alpha123`|
|CODESERVER_SUDO_PASSWORD|If this optional variable is set, user will have sudo access in the code-server terminal with the specified password||R/W||`alpha123`|

---
## Volumes

|type|name|host path|container path|description|
|-|-|-|-|-|
|named|codeserver_data|`CODESERVER_DATA_PATH`|`/config`|codeserver config files|

---

## Network

### Entrypoints

|service name|subservice name|default network area|protocol|service port|URI|description|
|-|-|-|-|-|-|-|
|codeserver||main|HTTP/HTTPS|8443|`http://CODESERVER_SUBDOMAIN.TANGO_DOMAIN/`|main codeserver access point|



### Specific network area


|network area name|protocol|default port|default secure port|
|-|-|-|-|

