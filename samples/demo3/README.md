# tango sample

## prerequites

* standard linux system
* docker engine
* wildcard domain targeting your current host `*.domain.com`

## content

* Show usage of
    * defining a tango app named 'demo3' within its own folder
    * creating an app module named 'whoami' attached to this app
    * a single module (whoami)
    * auto find free ports for both HTTP and HTTPS endpoints

* services activated using an app module
    * whoami
    
## commands

```

export TANGO_DOMAIN=domain.com

# let tango find free port instead of using default 80/443 ports
export TANGO_FREEPORT="1"

cd tango
./tango install
./tango up --app demo3 --approot ./samples/demo3 --module whoami
./tango info --app demo3 --approot ./samples/demo3 --module whoami
./tango down --app demo3 --approot ./samples/demo3 --module whoami

```

## endpoints

* traefik : check URL from ./tango info traefik --app demo3 --approot ./samples/demo3 --module whoami
* whoami : check URL from ./tango info whoami --app demo3 --approot ./samples/demo3 --module whoami
