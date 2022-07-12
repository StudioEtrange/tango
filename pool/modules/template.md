# Template

* Application template is a random application

|Categories|Links|
|-|-|
| code source | https://github.com/foo/Template |
| docker image code source | https://github.com/foo/docker-template |
| docker image registry | https://hub.docker.com/r/linuxserver/template  |
||https://gcr.com/linuxserver/template|
|doc links|http://doc.template|

# Samples

`./tango --module template --domain domain.org --freeport up`

# Entrypoints

|Service name|Default network area name|Protocol|Container port|Description|
|-|-|-|-|-|
|template|main|HTTP|5800|main template access point|

|Subservice name|Default network area name|Protocol|Container port|Description|
|-|-|-|-|-|
|template_api|zoneapi|HTTP|28080|template api access point|
|template_subservice|aone1|UDP|41000|other network access point|


# Specific network area


|Network area name|Protocol|Default port|Default secure port|
|-|-|-|-|
|zoneapi||||
|zone1||||


# Variables

|Name|Defaut value|Description|
|-|-|-|
|FOO|1|foo|
|WIDTH|1280|width|
|HEIGHT|768|height|
|TEMPLATE_DATA_PATH|template|template data|path|
|MEDIA_PATH|
|TEMPLATE_MEDIA_PATH|template_media|path|

# Volumes

|Volume name| Host path | Default host path | Container mapped path | Description |
|-|-|-|-|-|
|template_data|`CTX_DATA_PATH/TEMPLATE_DATA_PATH`|`data/template`|`/config`|Template data|
|template_media|`MEDIA_PATH/TEMPLATE_MEDIA_PATH`|`media/template_media`|`/media`|Template medias|