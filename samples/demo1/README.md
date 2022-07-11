# tango sample

## prerequites

* standard linux system
* docker engine
* git
* wildcard domain targeting your current host `*.domain.org`

## content

* Show usage of
    * a service by using a single module attached to tango context
    * using only command line and shell environment variables
    * auto find free ports for both HTTP and HTTPS port to access service

* module attached to tango context
    * firefox


## commands

```
cd $HOME
git clone https://github.com/StudioEtrange/tango
cd tango
./tango install

export TANGO_DOMAIN=domain.org
export TANGO_DOMAIN=auto-nip

./tango --module firefox --freeport up 
./tango --module firefox --freeport info
./tango --module firefox --freeport down

```

## endpoints

* traefik : check URL from ./tango info traefik --module firefox --freeport
* firefox : check URL from ./tango info firefox --module firefox --freeport