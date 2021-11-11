# tango sample

## prerequites

* standard linux system
* docker engine
* wildcard domain targeting your current host `*.domain.com`

## content

* Show usage of
    * several modules
    * scaled modules
    * using only command line, without any files
    * fixing network ports

* services activated using module
    * cloud9
    * firefox

## commands

```

export TANGO_DOMAIN=domain.com

# fixing port instead of using non default 80/443 ports
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

* traefik : http://traefik.chimere-harpie.org:44080 https://traefik.chimere-harpie.org:44443
* firefox : http://firefox.chimere-harpie.org:44080 https://firefox.chimere-harpie.org:44443
* cloud9 1 : http://cloud9_user1.chimere-harpie.org:44080 https://cloud9_user1.chimere-harpie.org:44443
* cloud9 2 : http://cloud9_user2.chimere-harpie.org:44080 https://cloud9_user2.chimere-harpie.org:44443