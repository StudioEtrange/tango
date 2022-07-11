# tango sample

## prerequites

* standard linux system
* docker engine
* wildcard domain targeting your current host `*.domain.com`

## content

* Show usage of
    * defining a tango app named 'demo4' within its own folder
    * setting a properties file for 'demo4' app settings
    * app will use its own docker compose file with one service
    * several modules (web & firefox)
    * defining two network area (named : main and admin) with fixed ports for both HTTP and HTTPS endpoint for each area
    
* services defined and actived by app's docker-compose file
    * web2

* services activated using a tango module
    * firefox


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

* traefik : 
    * ./tango info traefik --app demo4 --approot ./samples/demo4
    * http://traefik.domain.com:54080 https://traefik.domain.com:54443
* firefox : 
    * ./tango info firefox --app demo4 --approot ./samples/demo4
    * http://firefox.domain.com:44080 https://firefox.domain.com:44443
* web2 : 
    * ./tango info web2 --app demo4 --approot ./samples/demo4
    * http://web2.domain.com:44080 https://web2.domain.com:44443
