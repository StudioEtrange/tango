# Tango 

* A versatile app manager for a single docker node

* Define an app as a group of services
* Support configurable services
* Configurable through env variables or env file

* Support Let's encrypt for HTTPS certificate generation
* Highly based on traefik2 for internal routing
* Support gpu device mount for services


## Requirements

* bash 4
* git
* docker


NOTE : tango will auto install other tools like docker-compose

## Usage

### Install

* Install

    ```
    git clone https://github.com/StudioEtrange/tango
    cd tango
    ./tango install
    ```

### Minimal standalone usage

* Launch an instance with firefox predefined service

    ```
    ./tango --add firefox --domain mydomain.org --freeport up
    ```

### Minimal application

See samples in `samples` folder

* Create a folder for app
    ```
    mkdir $HOME/myapp
    ```

* Create a `myapp.env` file with
    ```
    TANGO_DOMAIN=mydomain.com
    ```

* Launch
    ```
    ./tango up --app myapp --approot $HOME/myapp
    ```

* Info
    ```
    ./tango info --app myapp --approot $HOME/myapp
    ``

* Stop all
    ```
    ./tango down
    ```



## Available Commands

```
	install : deploy this app
	init addons : install and init addons only if any addons declared in current app.
	up [service [-d][-b]] [--add mod-name] [--freeport]: launch all available services or one service
	down [service] [--mods mod-name] [--all]: down all services or one service. Except shared internal service when in shared mode (-all force stop shared service).
	restart [service [-d]] [--add mod-name] [--freeport]: restart all services or one service.
	info [--freeport] : give info. Will generate conf files and print configuration used when launching any service.
	status [service] : see service status.
	logs [service] : see service logs.
	shell <service> : launch a shell into a running service.
	mods : list available modules for use as a service.
	cert <path> --domain=<domain> : generate self signed certificate for a domain into a current host folder.

```




## Configuration

* You could set every tango variables through a user environment file, shell environment variables and some from command line. 

* Resolution priority order :
    * Command line variables
    * Shell environment variables
    * User environment file variables
    * Modules environment file variables
    * Current app environment file variables
    * Default tango environment file variables

### Standard variables


|NAME|DESC|DEFAULT VALUE|SAMPLE VALUE|
|-|-|-|-|
|TANGO_DOMAIN|domain used to access tango. It is a regexp. `.*` stands for any domain or host ip.|`.*`|`mydomain.com`|
|TANGO_USER_ID|unix user which will run services and acces to files.|current user : `id -u`|`1000`|
|TANGO_GROUP_ID|unix group which will run services and acces to files.|current group : `id -g`|`1000`|
|TANGO_SERVICES_AVAILABLE|list of available services|-|``|
|DATA_PATH|path on host for services conf and data files.|defined by `DATA_PATH_DEFAULT`|`../data`|

For full list see `tango.internal.env` file

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

### Artefacts

* `TANGO_ARTEFACT_FOLDERS` is a list of artefact path. All listed artefact folders are attached to services listed in `TANGO_ARTEFACT_SERVICES` to a specified mount point in `TANGO_ARTEFACT_MOUNT_POINT`

### Using an environment file

* You could create a user environment file for your app to set any available variables and put it everywhere. By default it will be looked for from your home directory

    ```
    ./tango --app myapp --approot $HOME/myapp --env /foo/bar/myapp.env up
    ```

* An environment file syntax is liked docker-compose env file syntax. It is **NOT** a shell file. Values are not evaluated.


    ```
    NETWORK_PORT_MAIN=80
    DATA_PATH=../data
    TANGO_ARTEFACT_FOLDERS=/mnt/MEDIA/MOVIES /mnt/MEDIA/TV_SHOWS
    ```

* It has a special cumulative assignation sign `+=` which add values to existing variable values
    ```
        TANGO_SERVICES_AVAILABLE+=blog
    ```


### Using shell environment variables

* Set variables at tango launch or export them before launch

    ```
    TANGO_DOMAIN="mydomain.com" DATA_PATH="/home/$USER/data" ./tango up
    ```


### For Your Information about env files - internal mechanisms


* At each launch tango use `tango.env` and `myapp.env` file files to generate
    * `generated.myapp.compose.env` file used by docker-compose
    * `generated.myapp.bash.env` file used by shell scripts


* You may know that a `compose.env` file is read by docker-compose to replace any variable present in docker-compose file anywhere in the file but NOT for define shell environment variable inside running container ! 


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
            - generated.myapp.compose.env
        command: >
            bash -c "echo from docker compose : $NETWORK_PORT_MAIN from running container env variable : $$NETWORK_PORT_MAIN"
    ```

## Service administration

### Enable/disable

* To declare a service use list `TANGO_SERVICES_AVAILABLE`
* To enable/disable a service, use variable list `TANGO_SERVICES_AVAILABLE`

* ie in user env file : 
    ```
    TANGO_SERVICES_AVAILABLE=website database
    TANGO_SERVICES_DISABLED=database
    ```

### Start/stop a service

* Launch a specific service

    ```
    ./tango up <service> [-d]
    ```

* Stop a service

    ```
    ./tango down <service>
    ```

## Modules 

* There is a list of predefined services named `module`.
    * List modules :
     ```
    ./tango mods
    ```

* To activate a module into the current app 
    * use variable list `TANGO_SERVICES_MODULES` or `--add` command line option
    * The list format is `<name>[@<network area>]`
    * `main` network area is the default

    ```
    CLOUD9_USERNAME=mambo CLOUD9_PASSWORD=mambo ./tango --add cloud9 --add firefox@secondary --domain mydomain.org --freeport up
    ```

## Network Configuration

### Logical area

* Tango have 3 logical areas. `main`, `secondary` and `admin`. Each of them have a HTTP entrypoint and a HTTPS entrypoint. 
* So you can separate each service on different area according to your needs by opening/closing your router settings


* A service can be declared into several logical areas

### Available areas and entrypoints

|logical area|entrypoint name|protocol|default port|variable|
|-|-|-|-|-|
|main|web_main|HTTP|80|NETWORK_PORT_MAIN|
|main|web_main_secure|HTTPS|443|NETWORK_PORT_MAIN_SECURE|
|secondary|web_secondary|HTTP|8000|NETWORK_PORT_SECONDARY|
|secondary|web_secondary_secure|HTTPS|8443|NETWORK_PORT_SECONDARY_SECURE|
|admin|web_admin|HTTP|9000|NETWORK_PORT_ADMIN|
|admin|web_admin_secure|HTTPS|9443|NETWORK_PORT_ADMIN_SECURE|

### Sample usage

* With these logical areas, you could setup different topology.

* Example : if service `ombi` and `medusa` must be access only through `organirz2` split services on different logical area and open your router port only for `main` area (HTTP/HTTPS port)
    ```
    TANGO_SERVICES_ENTRYPOINT_MAIN=organizr2
    TANGO_SERVICES_ENTRYPOINT_SECONDARY=ombi medusa sabnzbd
    ```

### Ports

#### Random free port

* With `--freeport` option the port associated with each entrypoints will be randomly choosen among free TCP ports. This option override any other entrypoint ports defined with variables from shell or env files.

* Any variables values ending with `_PORT` will be excluded from the free TCP ports. (including direct access port, see below)

    ```
    ./tango --add firefox --domain=mydomain.org --freeport up
    ```
    

* `--freeport` will allocate free ports of entrypoint each times a service is started with `up` or `restart` command. These ports are saved in an internal file. When using `info` command `--freeport` will read ports from previously backup ones.

    ```
    ./tango --add firefox --domain=mydomain.org --freeport info
    ```
    

#### Direct access port


* For various purpose like debugging, you can declare a direct access HTTP port to the service to bypass traefik ang get directly to the service with variables `*_DIRECT_ACCESS_PORT`. The first port declared as `expose` in docker-compose file is mapped to its value.

    * access directly throuh http://host:7777
    ```
    MYSERVICE_DIRECT_ACCESS_PORT=7777
    ```


## HTTP/HTTPS Configuration

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
    * By default tango uses the `HTTP Challenge` which *requires* port 80/443 to be opened (https://docs.traefik.io/user-guides/docker-compose/acme-http/). 
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

## Tango addons


* declare used addons

    * ie in user env file : 
        ```
        TANGO_ADDONS=addon_name#version
        ```

* install addons
    ```
    ./tango init addons
    ```


## Side notes

* I cannot use 3.x docker compose version, while `--runtime` or `--gpus` are not supported in docker compose format (https://github.com/docker/compose/issues/6691)

## Links

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

    * test leaks : https://dnsleaktest.com/

    * sample with openvpn server https://gist.github.com/darth-veitcher/93acda9617bab3e1de0264cebf4637fc

    * free vpn for test https://pilovali.nl/free-vpn/
    
    * UI
        * qomui - Qt - openvpn client conf management  https://github.com/corrad1nho/qomui