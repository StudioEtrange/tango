# tango sample

## prerequites

* standard linux system
* docker engine
* wildcard domain targeting your current host `*.domain.com`

## content

* Show usage of
    * defining a tango app with its own folder
    * using its own docker compose file with one services
    * single module
    * defining two network area (main and admin) with fixed ports
    
* services defined by app's docker-compose file
    * web2

* services activated
    * web2
    * firefox (using tango module)


## commands

```

export TANGO_DOMAIN=domain.com

cd tango
./tango install
./tango up --app demo4 --approot ./samples/demo4
./tango info --app demo4 --approot ./samples/demo4
./tango status --app demo4 --approot ./samples/demo4
./tango down --app demo4 --approot ./samples/demo4

```



## endpoints

* traefik : http://traefik.chimere-harpie.org:54080 https://traefik.chimere-harpie.org:54443
* firefox : http://firefox.chimere-harpie.org:44080 https://firefox.chimere-harpie.org:44443
* web2 : http://web2.chimere-harpie.org:44080 https://web2.chimere-harpie.org:44443
