# Uptimekuma

* A fancy self-hosted monitoring tool.
* Monitoring uptime for HTTP(s) / TCP / HTTP(s) Keyword / Ping / DNS Record / Push / Steam Game Server / Docker Containers.

|Categories|Links|
|-|-|
| code source | https://github.com/louislam/uptime-kuma |
| docker image code source | https://github.com/louislam/uptime-kuma/tree/master/docker |
| docker image registry | https://hub.docker.com/r/louislam/uptime-kuma|
|doc links| https://uptime.kuma.pet/ |

# Samples

`./tango --module uptimekuma --domain domain.org --freeport up`

# Entrypoints

|Service name|Default network area name|Protocol|Container port|Description|
|-|-|-|-|-|
|uptimekuma|main|HTTP|3001|main uptimekuma access point|



# Specific network area



# Variables

|Name|Defaut value|Description|
|-|-|-|
|UPTIMEKUMA_DATA_PATH|uptimekuma|uptimekuma data path|


# Volumes

|Volume name| Host path | Default host path | Container mapped path | Description |
|-|-|-|-|-|
|uptimekuma_data|`CTX_DATA_PATH/UPTIMEKUMA_DATA_PATH`|`data/uptimekuma`|`/app/data`|Uptimekuma data|