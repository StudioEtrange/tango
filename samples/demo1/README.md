# tango sample

## prerequites

* standard linux system
* docker engine
* wildcard domain targeting your current host `*.domain.com`
## content

* Show usage of
    * single module
    * using only command line, without any files
    * auto find free ports

* services activated using module
    * firefox


## commands

```

export TANGO_DOMAIN=domain.com

cd tango
./tango install
./tango up --module firefox --freeport
./tango info --module firefox --freeport
./tango down --module firefox --freeport

```

## endpoints

* traefik : check IP from ./tango info
* firefox : check IP from ./tango info