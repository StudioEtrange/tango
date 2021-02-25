# tango sample

Into demo1.docker-compose.yml and demo1.env

* services definition for
    * web2
    * whoami

## commands



```
export TANGO_DOMAIN=domain.com

cd tango
./tango install
./tango up --app demo1 --approot ./samples/demo1
./tango down --app demo1 --approot ./samples/demo1
./tango info --app demo1 --approot ./samples/demo1
./tango status --app demo1 --approot ./samples/demo1
```