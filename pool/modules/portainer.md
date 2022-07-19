# Portainer

* Portainer Community Edition is a lightweight service delivery platform for containerized applications that can be used to manage Docker, Swarm, Kubernetes and ACI environments.

|Categories|Links|
|-|-|
| code source | https://github.com/portainer/portainer |
| docker image code source | https://github.com/portainer/portainer/tree/develop/build/linux |
| docker image registry | https://hub.docker.com/r/portainer/portainer-ce |
| doc links| https://docs.portainer.io/ |

# Samples

`./tango --module portainer --domain domain.org --freeport up`

# Entrypoints

|Service name|Default network area name|Protocol|Container port|Description|
|-|-|-|-|-|
|portainer|main|HTTP|5800|main portainer access point|



# Variables

|Name|Defaut value|Description|
|-|-|-|
|PORTAINER_DATA_PATH|portainer|portainer data|path|


# Volumes

|Volume name| Host path | Default host path | Container mapped path | Description |
|-|-|-|-|-|
|portainer_data|`CTX_DATA_PATH/PORTAINER_DATA_PATH`|`data/portainer`|`/config`|Portainer data|


# 