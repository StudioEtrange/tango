# tango sample

## prerequites

* standard linux system
* docker engine
* wildcard domain targeting your current host `*.domain.com`

## content

* Show usage of
    * single module
    * using only command line, without any files
    * connect a service to a vpn
    * fixing network ports

* services activated using module
    * firefox


## commands

```

export TANGO_DOMAIN=domain.com

# using non default 80/443 ports
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

* traefik : http://traefik.chimere-harpie.org:44080 https://traefik.chimere-harpie.org:44443
* firefox : http://firefox.chimere-harpie.org:44080 https://firefox.chimere-harpie.org:44443