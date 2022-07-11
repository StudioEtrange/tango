# tango sample

## prerequites

* standard linux system
* docker engine
* wildcard domain targeting your current host `*.domain.com`

## content

* Show usage of
    * several modules  (cloud9 & firefox)
    * modules launched in multiple instances (cloud9)
    * using only command line and environment variable, without any extra conf file
    * fixing network ports for both HTTP and HTTPS endpoints

* services activated using a tango module
    * cloud9
    * firefox

## commands

```

export TANGO_DOMAIN=domain.com

# fixing ports instead of using default 80/443 ports
export NETWORK_PORT_MAIN=44080
export NETWORK_PORT_MAIN_SECURE=44443



cd tango
./tango install

export CLOUD9_INSTANCES_LIST="user1 user2"
./tango up --module firefox --module cloud9^2
./tango info --module firefox --module cloud9^2
./tango down --module firefox --module cloud9^2
```


## endpoints

* traefik : 
    * ./tango info traefik --module firefox --module cloud9^2
    * http://traefik.domain.com:44080 https://traefik.domain.com:44443
* firefox : 
    * ./tango info firefox --module firefox --module cloud9^2
    * http://firefox.domain.com:44080 https://firefox.domain.com:44443
* cloud9 : 
    * ./tango info cloud9 --module firefox --module cloud9^2
    * http://cloud9_user1.domain.com:44080 https://cloud9_user1.domain.com:44443
    * http://cloud9_user2.domain.com:44080 https://cloud9_user2.domain.com:44443