# Photoprism 

# TODO implement module and review this doc

* Application photoprism is a random application

|Categories|Links|
|-|-|
| code source | https://github.com/photoprism/photoprism |
| docker image code source | https://github.com/photoprism/photoprism/tree/develop/docker |
| docker image registry | https://hub.docker.com/r/photoprism/photoprism  |
|doc links|https://photoprism.app/|
|demo links|https://demo.photoprism.app/|


# Samples

`./tango --module photoprism --domain domain.org --freeport up`

# Entrypoints

|Service name|Default network area name|Protocol|Container port|Description|
|-|-|-|-|-|
|photoprism|main|HTTP|5800|main photoprism access point|

|Subservice name|Default network area name|Protocol|Container port|Description|
|-|-|-|-|-|
|photoprism_api|zoneapi|HTTP|28080|photoprism api access point|
|photoprism_subservice|aone1|UDP|41000|other network access point|


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
|PHOTOPRISM_DATA_PATH|photoprism|photoprism data|path|
|MEDIA_PATH|
|PHOTOPRISM_MEDIA_PATH|photoprism_media|path|

# Volumes

|Volume name| Host path | Default host path | Container mapped path | Description |
|-|-|-|-|-|
|photoprism_data|`CTX_DATA_PATH/PHOTOPRISM_DATA_PATH`|`data/photoprism`|`/config`|Photoprism data|
|photoprism_media|`MEDIA_PATH/PHOTOPRISM_MEDIA_PATH`|`media/photoprism_media`|`/media`|Photoprism medias|