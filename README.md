# Tango 

A versatile app manager for a single docker node

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


NOTE : tango will auto install other tools like docker-compose inside of its tree folder

## Usage

### Install

* Install

    ```
    git clone https://github.com/StudioEtrange/tango
    cd tango
    ./tango install
    ```

### Minimal standalone usage

* Launch an instance with a firefox predefined service (aka a tango module)

    ```
    ./tango --module firefox --domain mydomain.org --freeport up
    ```

### Minimal application

An application is a set of services preconfigured and tied together

See samples in `samples` folder

* Create a folder for app
    ```
    mkdir $HOME/myapp
    ```

* Create a `$HOME/myapp/myapp.env` file with
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
	install : deploy this app.
	up [service [-b]] [--module module] [--plugin plugin] [--freeport]: launch all available services or one service
	down [service] [--mods mod-name] [--all]: down all services or one service. Except shared internal service when in shared mode (--all force stop shared service).
	restart [service] [--module module] [--plugin plugin] [--freeport]: restart all services or one service.
	info [--freeport] : give info. Will generate conf files and print configuration used when launching any service.
	status [service] : see service status.
	logs [service] : see service logs.
	update <service> : get last version of docker image service. Will stop service if it was running.
	shell <service> : launch a shell into a running service.
	modules|plugins list : list available modules or plugins. A module is a predefined service. A plugin is plug onto a service.
	plugins exec-service <service>|exec <plugin>: exec all plugin attached to a service OR exec a plugin into all serviced attached.

	cert <path> --domain=<domain> : generate self signed certificate for a domain into a current host folder.
    letsencrypt rm : delete generated letsencrypt cert
    vendor <path> : copy tango into another path (inside a tango folder : <path>/tango), mainly to vendorize tango into another app.


```



----
## Configuration

* You could set every tango variables through an user environment file, shell environment variables and some from command line. 

* Resolution priority order :
    * Shell environment variables
    * Command line variables
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
|APP_DATA_PATH|path on host for services conf and data files.|defined by `DATA_PATH_DEFAULT`|`../data`|

For full list see `tango.internal.env` file

### Using shell environment variables

* Set variables at tango launch or export them before launch

    ```
    TANGO_DOMAIN="mydomain.com" APP_DATA_PATH="/home/$USER/data" ./tango up
    ```

### Using environment files

* You could create a user environment file for your app to set any available variables and put it in your $HOME` or elsewhere. By default it will be looked for from your home directory

    ```
    ./tango --app myapp --approot $HOME/myapp --env /foo/bar/myapp.env up
    ```

* An environment file syntax is liked docker-compose env file syntax. It is **NOT** a shell file. Values are not evaluated.

    ```
    NETWORK_PORT_MAIN=80
    APP_DATA_PATH=../data
    TANGO_ARTEFACT_FOLDERS=/mnt/MEDIA/MOVIES /mnt/MEDIA/TV_SHOWS
    ```

* It has a special cumulative assignation sign `+=` which add values to existing variable values
    ```
        TANGO_SERVICES_AVAILABLE+=blog
    ```


### Using command line variables

* A few variable can be setted with command line (like domain, user/group id, plugins, modules). 

* Command line variables are overrided by shell environment variables and they override environment files variables. `plugin` and `module` are not overrided nor override, they are cumulative with both shell environment and environment files variables
    ```
    TANGO_PLUGINS="plugin1 plugin2" ./tango info --plugin "plugin3"
    ```




### Variables of type "PATH"

* All variables ending with `_PATH` are translated to absolute path relative to app root folder at launch

* A variable (i.e `VAR_PATH`) listed in `TANGO_PATH_LIST` will be checked for existance
    * If the value is fixed the path must exists or it will throw an error
    * If the value is empty then the default value defined by `_PATH_DEFAULT` (i.e `VAR_PATH_DEFAULT`) ending variable will be picked and the path created. `_PATH_DEFAULT` are relative to app `workspace` folder

* `APP_DATA_PATH` is a special path variable with a purpose to store and share data of services app in one unique location

* Tango generic data like letsencrypt data or traefik conf are stored in a special way depending of the app instance mode (`isolated` or `shared`). `TANGO_DATA_PATH` contains the path of these data
    * if `isolated` `TANGO_DATA_PATH` is `APP_DATA_PATH` - they are stored as subfolder of `APP_DATA_PATH`
    * if `shared` `TANGO_DATA_PATH` is a subfolder of tango `workspace` itself

* WARN : before changing path variables or instance mode (`shared` or `isolated`) attached to a volume (like `APP_DATA_PATH`) use `tango down` command to delete volume.

### Special variable : artefacts

* `TANGO_ARTEFACT_FOLDERS` is a list of artefact path. All listed artefact folders are attached to services listed in `TANGO_ARTEFACT_SERVICES` to a specified mount point in `TANGO_ARTEFACT_MOUNT_POINT`


### For Your Information about env files and tango internal mechanisms


* At each launch tango use `tango.env` and `myapp.env` files to generate
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

----
## Services administration

A service match a docker container.

### Enable/disable

* To declare a service use list `TANGO_SERVICES_AVAILABLE`
* To disable a service, use variable list `TANGO_SERVICES_DISABLED`, by default all services are enabled

* ie in user env file : 
    ```
    TANGO_SERVICES_AVAILABLE=website database
    TANGO_SERVICES_DISABLED=database
    ```

### Start/stop a service

* Launch a specific service

    ```
    ./tango up <service>
    ```

* Stop a service

    ```
    ./tango down <service>
    ```

## Adding a new service

* Steps for adding a `foo` service
    * in `docker-compose.yml` 
        * add a `foo` service block
        * add a dependency on this service into `mambo` service

    * in `file.env`
        * add a variable `FOO_VERSION=latest`
        * add service to `TANGO_SERVICES_AVAILABLE` list
        * if this service has subservices, declare subservices into `TANGO_SUBSERVICES_ROUTER` (listed in their priority ascending order)
        * if this service needs to access all artefact folders, add it to `TANGO_ARTEFACT_SERVICES`
        * choose to which logical network areas by default this service will be attached `main`, `secondary`, `admin` and add it to `NETWORK_SERVICES_AREA_MAIN`,`NETWORK_SERVICES_AREA_SECONDARY` and `NETWORK_SERVICES_AREA_ADMIN`
        * to generate an HTTPS certificate add service to `LETS_ENCRYPT_SERVICES`
        * if HTTPS redirection add service to `NETWORK_SERVICES_REDIRECT_HTTPS`
        * for time setting add service to TANGO_TIME_VOLUME_SERVICES or `TANGO_TIME_VAR_TZ_SERVICES`
        * auto created variables : 
            * `FOO_SUBDOMAIN` value `foo.`
            * `FOO_PRIORITY` and `FOO_SUBSERVICES_PRIORITY` are auto managed



----
## Modules 

* A module is a predefined ready-to-use service

* There is a list of predefined services named `module`.
    * List modules :
     ```
    ./tango modules list
    ```

* A module must be declared before using it
* To declare a module into the current app 
    * use variable list `TANGO_SERVICES_MODULES` or `--module` command line option
    * `--module` command line option is cumulative with variable list `TANGO_SERVICES_MODULES`
    * Item format of the list is `<module>[@<network area>][%<service dependency1>][%<service dependency2>][^<vpn id>]`
    * `main` network area is the default

    ```
    CLOUD9_USERNAME=tango CLOUD9_PASSWORD=tango ./tango --module cloud9 --module firefox@secondary --domain mydomain.org --freeport up
    ```

* Modules can have other services dependencies and module launch will depends on these dependencies
* Predefined modules and their available variables files are in `pool/modules` folder
* You can define your own modules in your app by putting their matching `.yml` and `.env` files in a `pool/modules` folder of the app

### Tango modules list

* cloud9
* firefox
* whoami

----
## Plugins 

* A plugin is a script that will be exececuted *into a running service*
    * List plugins :
    ```
    ./tango plugins list
    ```
* A module stay in background as a service but a plugin just execute a script and stop 

* Each plugin may have some restrictions and will work only into some specific services

* A plugin can be executed at each service launch or manually with plugins commands
    ```
    tango plugins exec-service <service>
    tango plugins exec <plugin>
    ```

    * Manually execute all plugins attached to a service
        ```
        ./tango plugins exec-service <service>
        ```

    * Manually execute a plugin into all services attached
        ```
        ./tango plugins exec <plugin>
        ```
    * If the attached service is not running, the plugin cannot be executed

* A plugin must be declared before using it
* To declare a plugin into the current app 
    * use variable list `TANGO_PLUGINS` or `--plugin` command line option
    * `--plugin` command line option is cumulative with variable list `TANGO_PLUGINS`
    * Item format of the list is `<plugin>[%<auto exec at launch into service1>][%!<manual exec into service2>][#arg1][#arg2]`

* Plugins may have data stored in `$APP_DATA_PATH/plugins`

### Plugins usage sample

* Sample that attach `uname` plugin to the start of `firefox` and launch `firefox` service module
    ```
    ./tango --plugin uname%firefox --module firefox --domain mydomain.org --freeport up firefox
    ```

* Sample that attach `uname` plugin to `firefox`, launch `firefox` service then exec all plugins attached to `firefox`
    ```
    ./tango --plugin uname%!firefox --module firefox --domain mydomain.org --freeport up firefox
    ./tango plugins exec-service firefox
    ```


* Plugin will be executed inside each attached services
* Predefined plugins are in `pool/plugins` folder
* You can define your own plugins in your app by putting executable files in a `pool/plugins` folder of the app

----
## Scripts

    * These are scripts and are executed directly into the host within the context of tango app. (Meaning they are sourced)
    * Scripts files must not have extension. They are located in `pool/scripts` folder

        * List scripts :
        ```
        ./tango scripts list
        ```
        * Manually execute a script
        ```
        ./tango scripts <script>
        ```

    * A script do not need to be declared before using it

    * There are 2 special kind of scripts which are exceptions : init & info scripts which are auto executed into a lightweight container
        * init scripts are in `pool/scripts_init`
        * all init scripts are launched by default before all services
        
        * info scripts s are in `pool/scripts_info`
        * all info scripts are launched by default when launching command `info`

----
## Network

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


### Ports and Random free port

* With `--freeport` option the port associated with each entrypoints will be randomly choosen among free TCP ports. This option override any other entrypoint ports defined with variables from shell or env files.

* Any variables values ending with `_PORT` will be excluded from the free TCP ports. (including direct access port, see below)

    ```
    ./tango --freeport --module firefox --domain=mydomain.org up
    ```
    

* `--freeport` will allocate free ports of entrypoint each times a service is started with `up` or `restart` command. These ports are saved in an internal file. When using `info` command `--freeport` will read ports from previously backup ones.

    ```
    ./tango --freeport --module firefox --domain=mydomain.org info
    ```
    

#### Direct access port

* For various purpose like debugging, you can declare a direct access HTTP port to the service to bypass traefik ang get directly to the service with variables `*_DIRECT_ACCESS_PORT`. The first port declared as `expose` in docker-compose file is mapped to its value.

    * access directly throuh http://host:7777
    ```
    MYSERVICE_DIRECT_ACCESS_PORT=7777
    ```

----
## HTTP/HTTPS configuration

### HTTPS redirection

* To enable/disable HTTP to HTTPS redirection engine, set `NETWORK_REDIRECT_HTTPS` variable
* To enable/disable HTTPS only access to each service, declare them in `NETWORK_SERVICES_REDIRECT_HTTPS` variable. An autosigned certificate will be autogenerate

* ie in user env file : 
    ```
    NETWORK_SERVICES_REDIRECT_HTTPS=traefik ombi organizr2
    ```
### Certificate with Let's encrypt

* Variable LETS_ENCRYPT control if let's encrypt (https://letsencrypt.org/) is enabled or disabled for certificate generation
    * `LETS_ENCRYPT=disable` (default value) will disable auto generation
    * `LETS_ENCRYPT=enable` will auto generate a certificate for each services declared in `LETS_ENCRYPT_SERVICES`. (All services by default)
    * `LETS_ENCRYPT=debug` will use the test server of letsencrypt to not reach rate limit (https://letsencrypt.org/fr/docs/rate-limits/)

* NOTE : when you need to fully reset generated certificate, you have to delete the `acme.json` file Use `tango letsencrypt rm` command for that.

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




### Conception design note on router order and HTTPS Redirection (tango internal mechanisms)

* To make the system of HTTPS redirection fully customisable, we use the priority rules of traefik. Each service that need to have an HTTPS redirection use it

* We cannot use the method of set redirect middleware on each routers service because each service routers may have two entrypoints and redirect middlewares dont know from which entrypoint the request come. So we use a global catch all router rule, using priority for exclude some services

*Router order algorithm*

* if global HTTPS redirection engine disabled
    * 1.will match any HTTP service router with priority ROUTER_PRIORITY_DEFAULT_VALUE (i.e:2000)
	* 2.match error router which have a priority of ROUTER_PRIORITY_ERROR_VALUE (i.e:1800)

* if global HTTPS redirection engine enabled
    * 1.match router with HTTPS router with redirection middleware with priority ROUTER_PRIORITY_HTTP_TO_HTTPS_VALUE (i.e:1000)
    * 2.match any other router including HTTP service router with their lowered priority (i.e:500)
        * amount of priority to subtract : ROUTER_PRIORITY_DEFAULT_VALUE - ROUTER_PRIORITY_HTTP_TO_HTTPS_VALUE + (ROUTER_PRIORITY_HTTP_TO_HTTPS_VALUE / 2) (i.e:1500)
	* 3.match error router which have a lowered priority too (i.e:300)

Subservices have a priority higher than their service parent. 
In TANGO_SUBSERVICES_ROUTER each subservices, listed by group of parent service, get an increasing bonus of ROUTER_PRIORITY_DEFAULT_STEP (i.e:5) priority.

i.e with HTTPS redirection engine disabled
* TANGO_SERVICES_AVAILABLE=service1 service2
* TANGO_SUBSERVICES_ROUTER=service1_subservice1 service1_subservice2 service2_subservice1
* priorities computed : service1 : 2000, servce1_subservice1 : 2005, servce1_subservice2 : 2010,  service2 : 2000, servce2_subservice1 : 2005

----
## VPN

* Declare a vpn connection with `1` as id
    ```
    VPN_1_PATH=../mambo-data/vpn/pia_ovpn_default_recommended_conf_20200509
    VPN_1_VPN_FILES=Switzerland.ovpn
    VPN_1_VPN_AUTH=user;password
    VPN_1_DNS=1
    ```
    * These settings match ones from https://github.com/StudioEtrange/openvpn-client


### Connect a service to a VPN
* You can isolate some of your services to use this vpn connection :
    ```
    VPN_1_SERVICES=<service>
    ```

* How-To check service isolation, by checking its external ip
    ```
    ./mambo shell <service>
    curl 'https://api.ipify.org?format=json'
    ```

* services connected to a vpn 
    * have env var `VPN_ID` setted with the id of the vpn
    * inherits all env var `VPN_*`
    * have all config files inside a mounted volume at `/vpn`
    * all port declaration mapping and exposed port in compose-file are removed
    * its network alias coming from service name ais replaced by network alias from `vpn_<id>` container. Meaning cannot `ping <service>` from within other service, but `ping vpn_<id>` instead
    * the service container network become : `network_mode: service:vpn_<id>` meaning its network stack is the one from `vpn_<id>` container


## GPU


* To confirm your host kernel supports the Intel Quick Sync feature, the following command can be executed on the host `lspci -v -s $(lspci | grep VGA | cut -d" " -f 1)` which should output `Kernel driver in use: i915` 
* If your Docker host also has a dedicated graphics card, the video encoding acceleration of Intel Quick Sync Video may become unavailable when the GPU is in use. 



## Side notes

* I cannot use 3.x docker compose version, while `--runtime` or `--gpus` are not supported in docker compose format (https://github.com/docker/compose/issues/6691)
