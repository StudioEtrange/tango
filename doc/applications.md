# Applications

## Tango concepts

* An application is the definition of a context made by a set of services, a configuration file, default services within a given folder.

* Tango can manage an application context by executing its cli command within the application concept. By default tango commands are executed in tango context itself.

* Tango will execute its command using items defined inside the application folder to generate a docker-compose file.



----
## Application management

* Switch the current tango context to a given application context
* Syntax : `--app myapp --approot $HOME/myapp`
    ```
    ./tango --app myapp --approot $HOME/myapp up
    ```

* Launch a specific service of an application
    ```
    ./tango --app myapp --approot $HOME/myapp up
    ```

* Stop all applications services
    ```
    ./tango --app myapp --approot down
    ```

* Get abstract info on the application
    ```
    ./tango --app myapp --approot down info
    ```

----

## Application creation

* An application is a context made by a set of services, a configuration file, default services within a given folder managed by tango.


* An application is defined by a tree folders and optional files, follow the provided template files and rename them with the application name
    * [app/pool/modules/](/pool/app/pool/modules/) : content modules definitions of the application
    * [app/pool/plugins/](/pool/app/pool/plugins/)  : content plugins definitions of the application
    * [app.docker-compose.yml](/pool/app/app.docker-compose.yml) : yml compose file of the application that will be included in generated docker-compose file.
    * [app.env](/pool/app/app.env) : dedicated application variables used while generating docker-compose file.

----
## Sample

* Create a `$HOME/myapp/myapp.env` variable file to set domain and attache a module by default to the application
    ```
    mkdir $HOME/myapp
    echo "TANGO_DOMAIN=domain.org" > $HOME/myapp/myapp.env
    echo "TANGO_MODULES=firefox" >> $HOME/myapp/myapp.env

    ./tango --app myapp --approot $HOME/myapp up firefox
    ```
    * in this sample, we do not have to use --module command line option, because we have already attached firefox module by listing it in `TANGO_MODULES` variable list

