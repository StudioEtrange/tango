
# Services


## Tango concepts

* A service is a containerized application (i.e sabnzbd, calibreweb, cloud9, codeserver,...), accessible through HTTP, configured and managed by tango. At core level, a service is a yml definition of a docker-compose file.
* A module is a ready-to-use service with a markdown description, a yml predefined compose file and a set of configurabl variables in an environment file *(see [modules catalogue](/pool/modules/))*
* Tango leverage services exposition mechanisms using traefik2. Tango automaticly set up all traefik2 rules and routes to provide access to services.

----
## Services management

* Launch a specific service
    ```
    ./tango up <service>
    ```

* Stop a service
    ```
    ./tango down <service>
    ```

* Get abstract info on a service
    ```
    ./tango info <service>
    ```

* A service is manageable with these commands  only
    * if a matching module was attached to the current tango context *(simple way, see [Modules](#modules) below)*.
    * OR if the service was manually defined as a default service inside a dedicated context docker-compose yml file and enabled *(advanced way, see [Services creation](#services-creation))*.

* A service managed by tango will automaticly have an HTTP and an HTTPS route setted with this format : `https://<SERVICE_SUBDOMAIN>.<TANGO_DOMAIN>:<PORT>`
    * By default `SERVICE_SUBDOMAIN` is the service name
    * `TANGO_DOMAIN` is the one specified by `TANGO_DOMAIN` variable or by command line option `--domain`
    * By default `PORT` is port of the matching network area. (The network area named 'main' by default)
    * Sample which generate https://firefox.domain.org:port on a random port
        ```
        ./tango --domain=domain.org --freeport  up firefox
        ```


----
## Modules 

* A module is a ready-to-use service with a markdown description file, a yml predefined compose file and a set of configurabl variables in an environment file and that can be managed by tango (see [modules catalogue](/pool/modules/))

* List of known modules :
    ```
    ./tango modules list
    ```

* for information about creating modules see section [Modules creation](#modules-creation).

### Attach a module

* Declare a module attached to current tango context
    * When a module is declared attached to tango, tango can manage it
    * use `--module` command line option OR variable list `TANGO_SERVICES_MODULES`
    * `--module` is a repeatable command line option
    * `--module` command line options are cumulative with variable list `TANGO_SERVICES_MODULES`
    * Syntax for `--module` and `TANGO_SERVICES_MODULES` variable list : `<module>[@<network area>][%<service dependency1>][%<service dependency2>][~<vpn id>][^<nb instances>]`
    ```
    ./tango --module cloud9 --module sabnzbd up cloud9 
    ```

* Declaration : scalable module
    * Some module can be scaled to N instance. An empty file `<module>.scalable` allow a module to be scaled
    * Syntax : `<module>[^<nb instances>]`
    ```
    ./tango --module cloud9^2 up cloud9 
    ```

* Declaration : modules dependencies
    * Modules can have other services dependencies when attached to tango. Dependencies are launched before module itself by tango.
    * Syntax : `<module>[%<service dependency1>][%<service dependency2>]`
    ```
    ./tango --module cloud9%sabnzbd%transmission up cloud9 
    ```
    * Modules dependencies are shared on all instances of the same module. It is not possible to launch one instance of a module with a set of dependencies and another instance of the module with another set of dependencies.

* Declaration : network (advanced configuration)
    * by default the service is attached to the default tango network area (named main)
    * You can set a default network area by adding service name to list variable `NETWORK_SERVICES_AREA_entrypoint_protocol` list (i.e `NETWORK_SERVICES_AREA_MAIN_HTTP+=cloud9`) in a variable file or in the dedicated module.env file.
    * Syntax : `<module>[@<network area>]`
    ```
    CLOUD9_USERNAME=tango CLOUD9_PASSWORD=tango ./tango --module cloud9 --module firefox@secondary --domain mydomain.org --freeport up
    ```

----
## Volumes definition

* Add definition of docker named volumes to `TANGO_VOLUMES` variable list
    * Syntax `<volume name>:<path|#variable path name>`
    ```
    TANGO_VOLUMES="my_named_volume_1:/workspace1 my_named_volume_2:/workspace2"

    MY_PATH=/workspace
    TANGO_VOLUMES="my_volume:#MY_PATH"
    ```

* Attach volumes to a service with `<SERVICE>_ADDITIONAL_VOLUMES` variable list
    * You can attach either a named volume or a path on the host machine to a target path inside service
    * The source and target path can be absolute path or path stored in a tango variable 
    * Syntax `<named volume|path|#variable path name>:<path|#variable path name>`
    ```
    FOO_ADDITIONAL_VOLUMES="$HOME:/workspace"

    MY_PATH=/workspace
    FOO_ADDITIONAL_VOLUMES="$HOME:#MY_PATH"

    VAR_WITH_NAMED_VOLUME=my_volume
    FOO_ADDITIONAL_VOLUMES="#VAR_WITH_NAMED_VOLUME:/workspace"
    ```

----
## Tweaking a service

* Adding specific shell environment variable inside a specific service with `<SERVICE>_ADDITIONAL_ENVVAR` variable
    * Syntax `VAR=VAL`
    ```
    FOO_ADDITIONAL_ENVVAR="A=1 B=2"
    ```

* Attach existing traefik middlewares to a service with `<SERVICE>_ADDITIONAL_MIDDLEWARES` variable list
    * Syntax `<middleware_name>[:<position>:[<position number>]]`
    * `:<position number>` : absolute position where to insert middleware in existing middlewares list already attached to service
    * `:<position>` : available values : `FIRST` or `LAST` : position where to insert middleware in existing middlewares list already attached to service
    
    ```
    FOO_ADDITIONAL_MIDDLEWARES="middleware1 middleware2:FIRST middleware3:LAST middleware4:POS:4
    ```
----
## Scaling a service

* when scaling a service, N instances are launched in parallel
    * Syntax : `<module>[^<nb instances>]`
    * Each instances have a default name in the form `<module>_instance_N`
    * Each variable of `<module>` will be duplicated N times, renaming each variable name with instance names
        * for FOO_VAR1=2 and FOO_VAR2=2 with foo scaled 2 times :
        ```
        FOO_INSTANCE_1_VAR1=2
        FOO_INSTANCE_1_VAR2=2
        FOO_INSTANCE_2_VAR1=2
        FOO_INSTANCE_2_VAR2=2
        ```

* override service instances names
    * Syntax : `<module>_INSTANCES_NAMES`
    ```
    FOO_INSTANCES_NAMES=front back
    ```
    * Each variable of FOO modules will be renamed with the instances names
        * for FOO_VAR1=2 and FOO_VAR2=2 with foo scaled 2 times :
        ```
        FOO_FRONT_VAR1=2
        FOO_FRONT_VAR2=2
        FOO_BACK_VAR1=2
        FOO_BACK_VAR2=2
        ```

----
## Plugins 

* A plugin is a script that will be executed *inside a running service* (aka inside the running service container)
    * List plugins :
    ```
    ./tango plugins list
    ```
    * see [plugins catalogue](/pool/plugins/) folder

* Each plugin may have some restrictions and may work only into some specific services

* A plugin can be declenched at each service launch OR manually with tango cli plugins commands
    * Manually execute all plugins attached to a service
        ```
        ./tango plugins exec-service <service>
        ```

    * Manually execute a plugin into all services attached
        ```
        ./tango plugins exec <plugin>
        ```
    * If the service is not running, the plugin cannot be executed

### Attach a plugin to a service

* A plugin must be attach to a service before using it

* Declare a plugin as attached to a service
    * use `--plugin` command line option OR variable list `TANGO_PLUGINS`
    * `--plugin` is a repeatable command line option
    * `--plugin` command line options are cumulative with variable list `TANGO_PLUGINS`
    * Syntax for `--plugin` and `TANGO_PLUGINS` variable list : `<plugin>[%<auto exec at launch into service1>][%!<manual exec into service2>][#arg1][#arg2]`

* Declaration : autoexecution at service launch
    * Syntax : `%<auto exec at launch into service1`
    * attach `uname` plugin to `firefox` service and auto execute it at `firefox` launch AND launch `firefox` service
        ```
        ./tango --plugin uname%firefox --module firefox --domain mydomain.org --freeport up firefox
        ```

* Declaration : manual exacution
    * Syntax : `%!<auto exec at launch into service1`
    * attach `uname` plugin to `firefox` service AND launch `firefox` service
    * THEN in second command exec all plugin attached to `firefox` service service
    ```
    ./tango --plugin uname%!firefox --module firefox --domain mydomain.org --freeport up firefox
    ./tango plugins exec-service firefox
    ```


* If plugins have data, it will be stored in `$CTX_DATA_PATH/plugins`
    
### Plugins creation

* You can create plugins and store them in a context.

* A plugin is defined by 1 executable file, follow the provided templates file and rename it with the plugin name
    * [template.md](/pool/plugins/template) : executable script

* Files of your created plugins must be placed in the `pool/plugins` folder inside your ctx root path
    ```
    $HOME/myctx
    $HOME/myctx/pool/plugins/myplugin

    ./tango --ctx myctx --ctxroot $HOME/myctx --domain mydomain.org --freeport --module firefox --plugin myplugin%firefox up firefox
    ```

* Take inspiration from [plugins catalogue](/pool/plugins/) folder.

----

## Services creation

* At high-level a service is a containerized application (i.e sabnzbd, calibreweb, cloud9, codeserver,...), accessible through HTTP, configured and managed by tango.

* At core level a service is a generated yml definition injected into a generated docker-compose file.

* There is two way to create a service that can be managed by tango
    * either [creating a module](#modules-creation) (simple way)
    * either manually [create a default service](#manually-default-services-creation) providing a yml definition and variable
    

### Modules creation

* You can create modules and store them in a context.

* A module is defined by 4 files, follow the provided template files and rename them with the module name
    * [template.md](/pool/modules/template.md) : markdown file with module description
    * [template.env](/pool/modules/template.env) : environment file with preconfigured variables for this module used in yml file.
    * [template.yml](/pool/modules/template.yml) : yml definition for docker-compose that will be integrated into generated docker-compose file. see [format](#service-yml-definition-for-docker-compose)
    * [template.scalable](/pool/modules/template.scalable) : empty file that indicates the module can be instancied multiple times

* Files of your created modules must be placed in the `pool/modules` folder inside your ctx root path
    ```
    $HOME/myctx
    $HOME/myctx/pool/modules/mymodule.md
    $HOME/myctx/pool/modules/mymodule.env
    $HOME/myctx/pool/modules/mymodule.yml
    $HOME/myctx/pool/modules/mymodule.scalable

    ./tango --ctx myctx --ctxroot $HOME/myctx --domain mydomain.org --freeport  --module mymodule up mymodule
    ```

* Take inspiration from available tango modules are located in [pool/modules](/pool/modules/) folder.

### Manually default services creation

* You can manually create services and store them directly inside a context docker-compose file.

* You have to define a yml definition for docker-compose. see [format](#service-yml-definition-for-docker-compose)

* Once defined a default service must be enabled to be manageable by tango. Add the service name to the variable list `TANGO_SERVICES_AVAILABLE`. All services in this list will be enabled unless listed in variable `TANGO_SERVICES_DISABLED`
    ```
    TANGO_SERVICES_AVAILABLE=myservice_1 myservice_2
    TANGO_SERVICES_DISABLED=myservice_2
    ```

### Service YML definition for docker-compose

* The yml definition is the same in both case : 
    * a `module.yml` file stored in context folder
    * or yml block definition inserted in the context docker-compose.yml file

* Format see [pool/modules/templates.yml](/pool/modules/template.yml)


----
## Subservices

* a subservice share with its parent service a same traefik entrypoint by default (but can be override)
* to declare a subservice use `TANGO_SUBSERVICES_ROUTER` in priority ascending order relative to each other. Each subservices priority is higher than the previous one which belong to the same parent service
* subservice name format is be : `<service>_<subservice>`


