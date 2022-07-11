# tango sample

## prerequites

* standard linux system
* docker engine
* wildcard domain targeting your current host `*.domain.com`

## content

* Show usage of
    * a single module (firefox)
    * using only command line and environment variable, without any extra conf file
    * let use default ports (80/443) for both HTTP and HTTPS endpoint
    * auto generate a valid https certificate with letsencrypt

* services activated using a tango module
    * firefox


## commands

```

export TANGO_DOMAIN=domain.com
# active lets encrypt in debug mode to avoid lets encrypt rate limit. In real situation use 'enable' value instead of 'debug'
export LETS_ENCRYPT=debug
export LETS_ENCRYPT_SERVICES=firefox
export LETS_ENCRYPT_MAIL=no@no.com

# by default letsencrypt will use an HTTP challenge method to generate valid https certificate, which is possible only when using default ports (80/443) for both HTTP and HTTPS endpoints


cd tango
./tango install
./tango up --module firefox --freeport
./tango info --module firefox --freeport
./tango down --module firefox --freeport

```

## endpoints

* traefik : check URL from ./tango info traefik --module firefox --freeport
* firefox : check URL from ./tango info firefox --module firefox --freeport