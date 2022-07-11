# tango sample

## prerequites

* standard linux system
* docker engine
* wildcard domain targeting your current host `*.domain.com`

## content

* Show usage of
    * a single module (cloud9)
    * using only command line and environment variable, without any extra conf file
    * create named volumes
    * add bind mount volumes 
    * inject environment variable into module
    * auto find free ports for both HTTP and HTTPS endpoints

* services activated using a tango module
    * cloud9


## commands

```

export TANGO_DOMAIN=domain.com

# let tango find free port instead of using default 80/443 ports
export TANGO_FREEPORT="1"

export TANGO_VOLUMES="vol1#VOL1_PATH vol2:$HOME"
export VOL1_PATH="/tmp"

export MY_INTERNAL_HOME="/internal_home"
export CLOUD9_ADDITIONAL_VOLUMES="$HOME:/workspace vol1:/bar vol2#MY_INTERNAL_HOME"
export CLOUD9_SPECIFIC_ENVVAR="A=1 B=2"

cd tango
./tango install
./tango up --module cloud9
./tango info --module cloud9
./tango down --module cloud9

```
* Env var : Inside cloud9 two env vars `A` and `B` have values, check them through cloud9 terminal
## Notes on volumes

* Named volumes
    * One volume named `vol1` is created pointing to `/tmp` on host because of `vol1#VOL1_PATH`
    * One volume named `vol2` is created pointing to `$HOME` on host because of `vol2:$HOME`

* Volumes mapping
    * Inside cloud9 `/workspace` is mapped to `$HOME` on host because of `$HOME:/workspace`
    * Inside cloud9 `/bar` is mapped to `/tmp` on host because of `vol1:/bar`
    * Inside cloud9 `/internal_home` is mapped to `$HOME` on host because of `vol2#MY_INTERNAL_HOME`


    
    