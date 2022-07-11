# tango sample

## prerequites

* standard linux system
* docker engine
* wildcard domain targeting your current host `*.domain.com`
* a vpn connection

## content

* Show usage of
    * a single module (firefox)
    * using only command line and environment variable, without any extra conf file
    * connect a service to a vpn
    * fixing network ports for both HTTP and HTTPS endpoints

* services activated using a tango module
    * firefox


## commands

```

export TANGO_DOMAIN=domain.com

# fixing ports instead of using default 80/443 ports
export NETWORK_PORT_MAIN=44080
export NETWORK_PORT_MAIN_SECURE=44443

# defining a vpn with ID vpn_1

VPN_1_PATH=/foo/bar/pia_ovpn_folder
VPN_1_VPN_FILES=file.ovpn
VPN_1_VPN_AUTH=*****LOGIN*****;*****PASSWORD*****
VPN_1_DNS=1

cd tango
./tango install
./tango up --module firefox~vpn_1
./tango info --module firefox~vpn_1
./tango down --module firefox~vpn_1

```

## endpoints

* traefik : 
    * ./tango info traefik --module firefox~vpn_1
    * http://traefik.domain.com:44080 https://traefik.domain.com:44443
* firefox : 
    * ./tango info firefox --module firefox~vpn_1
    * http://firefox.domain.com:44080 https://firefox.domain.com:44443