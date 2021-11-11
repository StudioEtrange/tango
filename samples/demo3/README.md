# tango sample

## prerequites

* standard linux system
* docker engine
* wildcard domain targeting your current host `*.domain.com`
* auto find free ports

## content

* Show usage of
    * defining a tango app with its own folder
    * defining an app module named whoami

* services activated
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

* traefik : http://traefik.chimere-harpie.org:44080 https://traefik.chimere-harpie.org:44443
* whoami : http://whoami.chimere-harpie.org:44080 https://whoami.chimere-harpie.org:44443
