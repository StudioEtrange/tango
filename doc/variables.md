

# Configuration and environment variables

* You could set every tango variables through environment files or shell environment variables and some from command line. 

* Tango use this resolution descending priority order for declared variables
    * Shell environment variables
    * Command line variables
    * User environment file variables
    * Modules environment file variables
    * Current context environment file variables
    * Default tango environment file variables


## Standard variables


|NAME|DESC|DEFAULT VALUE|SAMPLE VALUE|
|-|-|-|-|
|TANGO_DOMAIN|domain used to access tango. It is a regexp. `.*` stands for any domain or host ip.|`.*`|`mydomain.org`|
|TANGO_USER_ID|unix user which will run services and acces to files.|current user : `id -u`|`1000`|
|TANGO_GROUP_ID|unix group which will run services and acces to files.|current group : `id -g`|`1000`|
|CTX_DATA_PATH|path on host for services configuration and data files.|`$(pwd)/workspace/tango/data`. |`/myctx/data`|
|TANGO_USER_ID|unix user which will run services and acces to files.|current user : `id -u`|`1000`|

For full list see `tango.internal.env` file

## Using shell environment variables

* Set shell environment variables and export them before launch

    ```
    export TANGO_DOMAIN="mydomain.org" 
    export CTX_DATA_PATH="/home/$USER/data" 
    ./tango info
    ```

## Using environment files


* An environment file syntax is liked docker-compose env file syntax. It is **NOT** a shell file. Values are not evaluated. 

    ```
    NETWORK_PORT_MAIN=80
    CTX_DATA_PATH=../data
    TANGO_ARTEFACT_FOLDERS=/mnt/MEDIA/MOVIES /mnt/MEDIA/TV_SHOWS
    ```

* For each context, you can create a context environment file, named like the context name and which will be automaticly read from context folder

    ```
    echo "TANGO_DOMAIN=mydomain.org" > $HOME/myctx/myctx.env
    ./tango info --ctx myctx --ctxroot $HOME/myctx
    ```

* You could also create an user environment file, which can override the context environment file. By default it will be read from $HOME and named like the context name. If you use it with  By default it will be looked for from your home directory

    ```
    echo "TANGO_DOMAIN=mydomain.org" > $HOME/myctx.env
    ./tango info --ctx myctx --ctxroot $HOME/myctx
    ```

    * You can also specify a path to the user environment file
        ```
        echo "TANGO_DOMAIN=mydomain.org" > /foo/bar/myotherfile.env
        ./tango info --ctx myctx --ctxroot $HOME/myctx --env /foo/bar/myotherfile.env
        ```

* Special cumulative assignation sign `+=` which add values to previously declared variable values somewhere BEFORE in environment files OR else through a shell environnement variable. Each value will be separated with a space character.
    ```
    FOO_LIST=value1
    FOO_LIST+=value2
    ```
    * At this position while reading env file FOO_LIST value is "value1 value2"
    

* Special default assignation sign `?=` which assign a value only if no value was already assigned to the variable somewhere BEFORE in environment files NOR as a shell environnement variable
    ```
    FOO=foo
    FOO?=bar
    ```
    * At this position while reading env file FOO value is "foo"
    
* variable declared within one file can be reused with `{{var}}` as value later in the file.
    ```
    A=1
    B={{A}}
    ```
    * At this position while reading env file B value is "1"

* Special switch assignation sign `!=` which erase non empty values of previously declared variable values somewhere BEFORE in environment files OR else through a shell environnement variable. Each value will be separated with a space character.
    ```
    SWITCH=ON
    SWITCH!=value1
    ```
    * At this position while reading env file SWITCH value is "value1"


    
* External and exported environnment variable can be used with `{{$var}}` as value
    ```
    H={{$HOME}}
    I={{$VAR}}
    P={{$WORKING_DIR}}
    ```
    * H value is $HOME (i.e "/home/john")
    * I value is $VAR, empty if $VAR is undefined
    * P is $WORKING_DIR value ($WORKING_DIR is a special tango env var which is the working directory from where tango was launched.)



## Using command line variables

* A few variables can be setted with command line (like domain, user/group id, plugins, modules) using option syntax like `--domain`

* Priority order betwen variables and command line
    * Command line variables are overrided by shell environment variables
    * Command line variables (and shell environment variables) override environment files variables
        ```
        echo "TANGO_DOMAIN=domain.org" > $HOME/myctx.env
        TANGO_DOMAIN="domain.dev" ./tango info --ctx myctx --ctxroot $HOME/myctx --domain domain.org 
        
        # Tango will use domain.dev
        ```
    * Exception for `--plugin`, `--module` and `--port` are cumulative with both shell environment and environment files variables. But they override any variable defined in any variable file or through shell environment variables.
        ```
        echo "TANGO_PLUGINS=plugin0" > $HOME/myctx.env
        TANGO_PLUGINS="plugin1 plugin2" ./tango info --ctx myctx --ctxroot $HOME/myctx --plugin plugin3

        # Tango will use plugin0, plugin1, plugin2 and plugin3
        ```




## Variables of type "PATH"


* Variables ending with `_PATH` are path variables.

* Tango can manage a list of paths on host. Each managed path is fully evaluated into absolute path and can be created if not existing. `TANGO_PATH_LIST` list variable path name to manage, each of them can have their own subfolder list in the form of `<parent_name>_SUBPATH_LIST`
    ```
    TANGO_PATH_LIST=FOO_PATH BAR_PATH
    BAR_PATH_SUBPATH_LIST=VAR_PATH
    ```

* Each declared path variable in those kind of lists 
    * can have as value an absolute path, a relative path or be empty
    * can have a known parent path (if listed in `PARENT_PATH_SUBPATH_LIST`) or an unknow parent (if listed in `TANGO_PATH_LIST`)

* Each declared path variable with an absolute path value must exists before launching tango
* Each declared path variable with a relative path value will be auto created if missing

* Each declared path variable are turned into absolute path at runtime following these path evaluation rules
    * if variable path is an absolute path, then this absoluted path is used as is
    * if variable path is a relative path, it will be relative to its parent path. If parent is unknown, `$TANGO_CTX_WORK_ROOT` is used as default parent path
    * if variable path have an unknow parenthave an empty value,  its value will be the lower cased name of <variable_name> (`foo_path` for `FOO_PATH`)
        
        

* Path rules matrix

    |-|UNKNOWN PARENT|KNOWN PARENT|MISSING PATH BLOCKING|MISSING PATH CREATED|
    |-|-|-|-|-|
    |**`FOO_PATH` is an absolute path**|absolute host path : `$FOO_PATH`|*should not be possible, a subfolder must be a relative path to its parent*|YES|NO|
    |**`FOO_PATH` is a relative path**|relative to ctx workspace : `$TANGO_CTX_WORK_ROOT/$VAR_PATH`|relative to parent path : `$PARENT_PATH/$FOO_PATH`|NO|YES|



* Samples

        ```
        export TANGO_PATH_LIST="FOO_PATH"
        export FOO_PATH="/foo"
        ./tango up --freeport
        # if /foo do not exist, it will throw an error and stop 

        export TANGO_PATH_LIST="FOO_PATH"
        export FOO_PATH=
        ./tango up --freeport
        # a subfolder `$(pwd)/workspace/tango/foo_path` will be created if not already exists

        export TANGO_PATH_LIST="FOO_PATH"
        export FOO_PATH=
        export FOO_PATH_SUBPATH_LIST="BAR_PATH"
        export BAR_PATH="bar"
        ./tango up --freeport
        
        # a subfolder `$(pwd)/workspace/foo_path` will be created and a subfolder `$(pwd)/workspace/foo/bar`

        export TANGO_PATH_LIST="FOO_PATH"
        export FOO_PATH=
        export FOO_PATH_SUBPATH_LIST="BAR_PATH"
        export BAR_PATH=
        ./tango up --freeport
        # a subfolder `$(pwd)/workspace/foo_path` will be created and a subfolder `$(pwd)/workspace/foo/bar_path`

        ```


* List of some default computed path variables at runtime

    |VARIABLE|DESC|DEFAULT VALUE|
    |-|-|-|
    |`TANGO_CTX_ROOT`|current context full path. The default context is tango itself|-|
    |`TANGO_CTX_WORK_ROOT`|current ctx workspace full path.| `$TANGO_CTX_ROOT/workspace/$TANGO_CTX_NAME`|
    |`CTX_DATA_PATH`|current ctx data path.| `$TANGO_CTX_WORK_ROOT/data`|
    |`TANGO_DATA_PATH`|tango internal data path.| `$CTX_DATA_PATH`|
    |`WORKING_DIR`|dir from where tango have been launched.| `equals $(pwd) before launching command`|




* `CTX_DATA_PATH` is a special path variable with a purpose to store and share data of the current context services in one unique location. It s added to TANGO_PATH_LIST if not already done. Its default definition is
    ```
    TANGO_PATH_LIST=CTX_DATA_PATH
    CTX_DATA_PATH=data
    ```

* `TANGO_DATA_PATH` is a special path variable wich store generic tango data like letsencrypt data or traefik conf. Its value depends of tango instance mode (`isolated` or `shared`)
    * if `isolated` (the default mode) `TANGO_DATA_PATH` equals `CTX_DATA_PATH` - they are stored as subfolder of `CTX_DATA_PATH`
    * if `shared` `TANGO_DATA_PATH` is a subfolder of tango `workspace` itself




* `TANGO_ARTEFACT_FOLDERS` is a special list of folder path named `artefacts`. Those listed folders are all absolute. Listed artefacts are attached to each service in read write mode listed in `TANGO_ARTEFACT_SERVICES`. (Same for services listed in `TANGO_ARTEFACT_SERVICES_READONLY` but in read only mode). The mount point into service is defined by `TANGO_ARTEFACT_MOUNT_POINT` (`/artefact` by default) concatened to the deepest tree folder name.
Artefact folder is an easy way to quick unite several folders into the same root inside a container
    * `TANGO_ARTEFACT_FOLDERS=/mnt/media/movies /foo/bar/tv /flu/bar/music` will be mounted under `/artefact/movies`, `/artefact/tv` and `/artefact/music` into each service



## Design notes about env files and tango internal mechanisms


* At each launch tango use `tango.env` and `myctx.env` files to generate
    * `generated.myctx.compose.env` file used by docker-compose
    * `generated.myctx.bash.env` file used by shell scripts


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
            - generated.myctx.compose.env
        command: >
            bash -c "echo from docker compose : $NETWORK_PORT_MAIN from running container env variable : $$NETWORK_PORT_MAIN"
    ```
