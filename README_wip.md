# Tango 

* A versatile app manager for a single docker node

* Support configurable services
* Configurable through env variables or env file

* Support Let's encrypt for HTTPS certificate generation
* Highly based on traefik2 for internal routing
* Support gpu device mount for services



## REQUIREMENTS

* bash 4
* git
* docker



NOTE : mambo will auto install other tools like docker-compose



## USAGE


### First steps
* Install

    ```
    git clone https://github.com/StudioEtrange/mambo
    cd tango
    ./tango install
    ```

* First initialization

    ```
    PLEX_USER="no@no.com" PLEX_PASSWORD="****" ./mambo init
    ```


### Minimal configuration

* Create a `mambo.env` file with
    ```
    PLEX_USER=no@no.com
    PLEX_PASSWORD=****
    TANGO_DOMAIN=mydomain.com
    ```

* For HTTPS only access, add 
    ```
    LETS_ENCRYPT=enable
    LETS_ENCRYPT_MAIL=no@no.com

    NETWORK_SERVICES_REDIRECT_HTTPS=traefik ombi sabnzbd tautulli medusa
    ```

* Launch
    ```
    ./mambo up -f mambo.env
    ```


* Stop all
    ```
    ./mambo down
    ```

## AVAILABLE COMMANDS

```
L     install : deploy this app
L     init [--claim] : init services. Do it once before launch. - will stop plex --claim : will force to claim server even it is already registred
L     up [service [-d]] : launch all mambo services or one service
L     down [service] : down all mambo services or one service
L     restart [service [-d]] : restart all mambo services or one service
L     info : give info on Mambo. Will generate conf files and print configuration used when launching any service.
L     status [service] : see status
L     logs [service] : see logs
L     shell <service> : launch a shell into a running service
```




## MAMBO CONFIGURATION

* You could set every mambo variables through a user environment file, shell environment variables and some from command line. 


* All existing variables are listed in `tango.default.env`

* Resolution priority order :
    * Command line variables
    * Shell environment variables
    * User environment file variables
    * Default configuration file variables
    * Default values from mambo itself




### Standard variables


|NAME|DESC|DEFAULT VALUE|SAMPLE VALUE|
|-|-|-|-|
|TANGO_DOMAIN|domain used to access mambo. It is a regexp. `.*` stands for any domain or host ip.|`.*`|`mydomain.com`|
|TANGO_USER_ID|unix user which will run services and acces to files.|current user : `id -u`|`1000`|
|TANGO_GROUP_ID|unix group which will run services and acces to files.|current group : `id -g`|`1000`|
|TANGO_ARTEFACT_FOLDERS|list of paths on host that contains media files. Relative path to mambo app path|-|`/mnt/MEDIA/MOVIES /mnt/MEDIA/TV_SHOWS`|
|DATA_PATH|path on host for services conf and data files. Relative to mambo app path.|`./mambo/workspace/data`|`../data`|
|DOWNLOAD_PATH|path on host for downloaded files. Relative to mambo app path.|`./mambo/workspace/download`|`../download`|
|PLEX_USER|your plex account|-|`no@no.com`|
|PLEX_PASSWORD|your plex password|-|`mypassword`|



### PATH variables

* All variables ending with `_PATH` are translated to absolute path relative to app root folder at launch

* A variable (i.e `VAR_PATH`) listed in `TANGO_PATH_LIST` will be checked for existance
    * If the value is fixed the path must exists or it will throw an error
    * If the value is empty then the default value defined by `_PATH_DEFAULT` (i.e `VAR_PATH_DEFAULT`) ending variable will be picked and the path created. `_PATH_DEFAULT` are relative to app `workspace` folder

* `DATA_PATH` is a special path variable with a purpose to store and share data of services in one unique location

* Tango specific data like letsencrypt data or traefik conf are stored in a special way depending of the app instance mode (`isolated` or `shared`)
    * if `isolated` they are stored as subfolder of `DATA_PATH`
    * if `shared` they are stored as subfolder of tango `workspace` itself (not in the app `DATA_PATH`)

* WARN : before changing path variables or instance mode (`shared` or `isolated`) attached to a volume (like `DATA_PATH`) use `tango down` command to delete volume.

### Artefact

* `TANGO_ARTEFACT_FOLDERS` is a list of artefact path. All listed artefact folders are attached to services listed in `TANGO_ARTEFACT_SERVICES` to a specified mount point in `TANGO_ARTEFACT_MOUNT_POINT`

### Using a user environment file

* You could create a user environment file (default name : `mambo.env`) to set any available variables and put it everywhere. By default it will be looked for from your home directory

    ```
    ./mambo -f mambo.env up
    ```

* By default, mambo will look for any existing user environment file into `$HOME/mambo.env`

* A user environment file syntax is liked docker-compose env file syntax. It is **NOT** a shell file. Values are not evaluated.


    ```
    NETWORK_PORT_MAIN=80
    DATA_PATH=../mambo-data
    DOWNLOAD_PATH=../mambo-download
    TANGO_ARTEFACT_FOLDERS=/mnt/MEDIA/MOVIES /mnt/MEDIA/TV_SHOWS
    ```


### Using shell environment variables

* Set variables at mambo launch or export them before launch

    ```
    TANGO_DOMAIN="mydomain.com" DATA_PATH="/home/$USER/mambo-data" ./mambo up
    ```


### For Your Information about env files - internal mechanisms


* At each launch mambo use `tango.default.env` file and your conf file (`mambo.env`) files to generate
    * `.env` file used by docker-compose
    * `bash.env` file used by mambo shell scripts


* You may know that a `.env` file is read by docker-compose by default to replace any variable present in docker-compose file anywhere in the file but NOT for define shell environment variable inside running container ! 


    ```
    test:
        image: bash:4.4.23
        command: >
            bash -c "echo from docker compose : $NETWORK_PORT_MAIN from running container env variable : $$NETWORK_PORT_MAIN"
    ```

    * This above only show NETWORK_PORT_MAIN value but $$NETWORK_PORT_MAIN (with double dollar to not have docker-compose replace the value) is empty unless you add this :

    ```
    test:
        image: bash:4.4.23
        env_file:
            - .env
        command: >
            bash -c "echo from docker compose : $NETWORK_PORT_MAIN from running container env variable : $$NETWORK_PORT_MAIN"
    ```

## SERVICE ADMINISTRATION

### Enable/disable

* To enable/disable a service, use variable `SERVICE_*`
    * to enable use the service name as value 
    * to disable add `_disable` to service name

* ie in user env file : 
    ```
    SERVICE_OMBI=ombi
    SERVICE_SABNZBD=sabnzbd_disable
    ```

### Start/stop a service

* Launch a specific service

    ```
    ./mambo up <service> [-d]
    ```

* Stop a service

    ```
    ./mambo down <service>
    ```

## NETWORK CONFIGURATION

### Logical area

* Tango have 3 logical areas. `main`, `secondary` and `admin`. Each of them have a HTTP entrypoint and a HTTPS entrypoint. 
* So you can separate each service on different area according to your needs by opening/closing your router settings

* By default
    * all services are on `main` area, so accessible throuh ports 80/443 (ie: http://ombi.mydomain.com)
    * traefik admin services are on `main` area, so accessible throuh ports 30443 (only, no HTTP for traefik admin) (ie: http://traefik.mydomain.com)

* A service can be declared into several logical area

### Available areas and entrypoints

|logical area|entrypoint name|protocol|default port|variable|
|-|-|-|-|-|
|main|web_main|HTTP|80|NETWORK_PORT_MAIN|
|main|web_main_secure|HTTPS|443|NETWORK_PORT_MAIN_SECURE|
|secondary|web_secondary|HTTP|20000|NETWORK_PORT_SECONDARY|
|secondary|web_secondary_secure|HTTPS|20443|NETWORK_PORT_SECONDARY_SECURE|
|admin|web_admin|HTTP|30000|NETWORK_PORT_ADMIN|
|admin|web_admin_secure|HTTPS|30443|NETWORK_PORT_ADMIN_SECURE|

### Sample usage

* With these logical areas, you could setup different topology.

* Example : if `ombi` and `medusa` must be access only through `organirz2` split services on different logical area and open your router port only for `main` area (HTTP/HTTPS port)
    ```
    MAMBO_SERVICES_ENTRYPOINT_MAIN=organizr2
    MAMBO_SERVICES_ENTRYPOINT_SECONDARY=ombi medusa sabnzbd
    ```

### Direct access port for debuging purpose


* For debugging, you can declare a direct access HTTP port to the service without using traefik with variables `*_DIRECT_ACCESS_PORT`. The first port declared as exposed in docker-compose file is mapped to its value.

    * access directly throuh http://host:7777
    ```
    OMBI_DIRECT_ACCESS_PORT=7777
    ```


## HTTP/HTTPS CONFIGURATION

### HTTPS redirection

* To enable/disable HTTPS only access to each service, declare them in `NETWORK_SERVICES_REDIRECT_HTTPS` variable. An autosigned certificate will be autogenerate
    * NOTE : some old plex client do not support HTTPS (like playstation 3) so plex might be exclude from this variable

* ie in user env file : 
    ```
    NETWORK_SERVICES_REDIRECT_HTTPS=traefik ombi organizr2
    ```

### Certificate with Let's encrypt

* Variable LETS_ENCRYPT control if let's encrypt (https://letsencrypt.org/) is enabled or disabled for certificate generation
    * `LETS_ENCRYPT=disable` (default value) will disable auto generation
    * `LETS_ENCRYPT=enable` will auto generate a certificate for each services declared in `LETS_ENCRYPT_SERVICES`. (All services by default)
    * `LETS_ENCRYPT=debug` will use the test server of letsencrypt to not reach rate limit (https://letsencrypt.org/fr/docs/rate-limits/)
    
### Let's encrypt and non default port for main area

* If you change the network ports of main area to other ports than 80/443, you have to use change the letsencrypt method from `HTTP Challenge` to `DNS Challenge`
    * By default Mambo uses the `HTTP Challenge` which *requires* port 80/443 to be opened (https://docs.traefik.io/user-guides/docker-compose/acme-http/). 
    * Otherwise you need to configure API to access to your DNS provider to set the `DNS Challenge` (https://docs.traefik.io/user-guides/docker-compose/acme-dns/)

* How-to : in your user conf file
    * Set `LETS_ENCRYPT_CHALLENGE` to `DNS`
    * Set `LETS_ENCRYPT_CHALLENGE_DNS_PROVIDER` with your provider name 
    * Add needed variables for your providers. Consult https://docs.traefik.io/https/acme/#providers for details

    ```
        LETS_ENCRYPT_CHALLENGE=DNS
        LETS_ENCRYPT_CHALLENGE_DNS_PROVIDER=ovh
        OVH_ENDPOINT=xxx
        OVH_APPLICATION_KEY=xxx
        OVH_APPLICATION_SECRET=xxx
        OVH_CONSUMER_KEY=xxx
    ```


## GPU


### Information

* To confirm your host kernel supports the Intel Quick Sync feature, the following command can be executed on the host `lspci -v -s $(lspci | grep VGA | cut -d" " -f 1)` which should output `Kernel driver in use: i915` 
* If your Docker host also has a dedicated graphics card, the video encoding acceleration of Intel Quick Sync Video may become unavailable when the GPU is in use. 
* If your computer has an NVIDIA GPU, please install the latest Latest NVIDIA drivers for Linux to make sure that Plex can use your NVIDIA graphics card for video encoding (only) when Intel Quick Sync Video becomes unavailable.




## ADDING A SERVICE

* Steps for adding a `foo` service
    * in `docker-compose.yml` 
        * add a `foo` service
        * add a dependency on this service into `mambo` service
    * in `tango.default.env`
        * add a variable `FOO_VERSION=latest`
        * add a variable `SERVICE_FOO=foo`
        * if this service needs to access all media folders, add it to `TANGO_ARTEFACT_SERVICES`
        * choose to which logical areas by default this service will be attached `main`, `secondary`, `admin` and add it to `NETWORK_SERVICES_AREA_MAIN`,`NETWORK_SERVICES_AREA_SECONDARY` and `NETWORK_SERVICES_AREA_ADMIN`
        * if this service has subservices, declare subservices into `TANGO_SUBSERVICES`
        * add a `FOO_DIRECT_ACCESS_PORT` empty variable
    * in `mambo`
        * add time management in `__set_time_all`
        * add `foo` in command line argument in `TARGET` choices

## SIDE NOTES

* I tried my best to stick to docker-compose file features and write less bash code. But very quickly I gave up, docker-compose files is very bad when dealing with conf and env var.
* I cannot use 3.x docker compose version, while `--runtime` or `--gpus` are not supported in docker compose format (https://github.com/docker/compose/issues/6691)

## LINKS

* Traefik2
    * Traefik1 forward auth and keycloak https://geek-cookbook.funkypenguin.co.nz/ha-docker-swarm/traefik-forward-auth/keycloak/
    * Traefik2 reverse proxy + reverse an external url : https://blog.eleven-labs.com/fr/utiliser-traefik-comme-reverse-proxy/
    * Traefik1 and oauth2 proxy https://geek-cookbook.funkypenguin.co.nz/reference/oauth_proxy/

* Let's encrypt
    * challenge types : https://letsencrypt.org/fr/docs/challenge-types/

* Backup solutions
    * https://geek-cookbook.funkypenguin.co.nz/recipes/duplicity/
    * https://rclone.org/
        * rclone desktop browser : https://github.com/kapitainsky/RcloneBrowser
        * rclone desktop browser on docker with VNC : https://github.com/romancin/rclonebrowser-docker
    * https://github.com/restic/restic

* VPN
    * dperson openvpn client
        * https://github.com/dperson/openvpn-client
        * https://hub.docker.com/r/dperson/openvpn-client/

    * sample with openvpn server https://gist.github.com/darth-veitcher/93acda9617bab3e1de0264cebf4637fc

    * UI
        * qomui - Qt - openvpn client conf management  https://github.com/corrad1nho/qomui