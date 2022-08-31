# Context

## Tango concepts

* Tango can manage different contexts. It has a default 'tango'.

* A context is a set of services, a configuration file, default services within a given folder.

* Tango can manage a context by executing its cli command on it. By default tango commands are executed in tango context itself.


----
## Contexts management

* Switch the current tango context to a given context
* Syntax : `--ctx myctx --ctxroot $HOME/myctx`
    ```
    ./tango --ctx myctx --ctxroot $HOME/myctx up
    ```

* Launch a specific service of a context
    ```
    ./tango --ctx myctx --ctxroot $HOME/myctx up
    ```

* Stop all context services
    ```
    ./tango --ctx myctx --ctxroot down
    ```

* Get abstract info on the ctxlication
    ```
    ./tango --ctx myctx --ctxroot down info
    ```

----

## Context creation

* A context is made by a set of services, a configuration file, default services within a given folder managed by tango.


* A context is defined by a tree folders and optional files, follow the provided template files and rename them with the context name
    * [ctx/pool/modules/](/pool/ctx/pool/modules/) : modules definitions of the context
    * [ctx/pool/plugins/](/pool/ctx/pool/plugins/)  : plugins definitions of the context
    * [ctx.docker-compose.yml](/pool/ctx/ctx.docker-compose.yml) : yml compose file of the context that will be included (and merged) in generated docker-compose file.
    * [ctx.env](/pool/ctx/ctx.env) : dedicated context variables used while generating docker-compose file.

----
## Sample

* Create a `$HOME/myctx/myctx.env` variable file to set domain and set some modules attached by default to this context
    ```
    mkdir $HOME/myctx
    echo "TANGO_DOMAIN=domain.org" > $HOME/myctx/myctx.env
    echo "TANGO_MODULES=firefox" >> $HOME/myctx/myctx.env

    ./tango --ctx myctx --ctxroot $HOME/myctx up firefox
    ```
    * in this sample, we do not have to use --module command line option, because we have already attached firefox module by listing it in `TANGO_MODULES` variable list

