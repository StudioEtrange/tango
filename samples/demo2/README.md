# tango sample

## content

Into demo2.docker-compose.yml and demo2.env

* services definition for
    * web2
    * whoami
    * firefox

* usage declaration of tango predefined module cloud9

## commands

```

export TANGO_DOMAIN=domain.com

cd tango
./tango install
./tango up --app demo2 --approot ./samples/demo2
./tango down --app demo2 --approot ./samples/demo2
./tango info --app demo2 --approot ./samples/demo2
./tango status --app demo2 --approot ./samples/demo2
```