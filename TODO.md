#  TODO 
- [TODO](#todo)
  - [Modules to add to Tango](#modules-to-add-to-tango)
  - [Catalog of docker images to turn into tango module](#catalog-of-docker-images-to-turn-into-tango-module)
  - [Various](#various)



## Modules to add to Tango

* catalog of selfhosted app : https://selfh.st/

* Hoarder
  * https://github.com/hoarder-app/hoarder
  * A self-hostable bookmark-everything app (links, notes and images) with AI-based automatic tagging and full text search

* whoogle-search
    * https://github.com/benbusby/whoogle-search
    * Get Google search results, but without any ads, javascript, AMP links, cookies, or IP address tracking. Easily deployable in one click as a Docker app, and customizable with a single config file. Quick and simple to implement as a primary search engine replacement on both desktop and mobile.

* Vaultwarden 
    * Vaultwarden is an alternative implementation of the Bitwarden server API 
    * https://github.com/BaptisteBdn/docker-selfhosted-apps/tree/main/vaultwarden
    * https://github.com/dani-garcia/vaultwarden

* Trillium
    * Build your personal knowledge base with Trilium Notes
    * https://github.com/zadam/trilium
    * https://github.com/BaptisteBdn/docker-selfhosted-apps/tree/main/trilium

* Seafile
    * Seafile is an open source cloud storage system with privacy protection and teamwork features. Collections of files are called libraries. Each library can be synced separately. A library can also be encrypted with a user chosen password. Seafile also allows users to create groups and easily sharing files into groups.
    * https://github.com/haiwen/seafile
    * https://github.com/BaptisteBdn/docker-selfhosted-apps/tree/main/seafile
    * https://www.seafile.com/en/home/

* veloren
    * Veloren is a multiplayer voxel RPG written in Rust
    * https://book.veloren.net/
    * https://veloren.net/
    * https://gitlab.com/veloren/veloren

* Gate One
  * https://github.com/liftoff/GateOne/
  * Gate One is an HTML5-powered terminal emulator and a web SSH client

* Mosh
  * https://mosh.org/
  * https://github.com/mobile-shell/mosh
  * Mosh is a remote terminal application that supports intermittent connectivity, allows roaming, and provides speculative local echo and line editing of user keystrokes.
  * How it works : The mosh program will SSH to user@host to establish the connection. SSH may prompt the user for a password or use public-key authentication to log in. From this point, mosh runs the mosh-server process (as the user) on the server machine. The server process listens on a high UDP port and sends its port number and an AES-128 secret key back to the client over SSH. The SSH connection is then shut down and the terminal session begins over UDP.


* Puter
  * https://github.com/HeyPuter/puter
  * web desktop
  * Puter is an advanced, open-source internet operating system designed to be feature-rich, exceptionally fast, and highly extensible. It can be used to build remote desktop environments or serve as an interface for cloud storage services, remote servers, web hosting platforms, and more.

* ente
  * https://github.com/ente-io/ente
  * Fully open source, End to End Encrypted alternative to Google Photos and Apple Photos
  * https://ente.io/

## Catalog of docker images to turn into tango module

* linuxserver.io server images
  * https://fleet.linuxserver.io/

* jlesage images :
  * https://jlesage.github.io/docker-apps/
  * https://github.com/jlesage?tab=repositories
    
* hotio images :
  * https://hotio.dev/containers/apprise/

* KASM : VNC server and client into Webpage
  * https://github.com/kasmtech/KasmVNC
  * https://kasmweb.com/docs/latest/index.html
  * KASM images :
      * https://github.com/kasmtech/workspaces-images
      * https://github.com/kasmtech/workspaces-core-images
      * https://hub.docker.com/u/kasmweb

* Self Hosting Guide 
    * https://github.com/mikeroyal/Self-Hosting-Guide

* jauderho dockerfiles
  * https://github.com/jauderho/dockerfiles

## Various

* [ ] pb to access through ipv6 ?
    * some doc : https://github.com/traefik/traefik/issues/8789 https://github.com/traefik/traefik/pull/9183
    * STEPS TO TRY :
        * create a docker network "traafik_network" un reseau dedié a traefik en ipv6only and with "ip6tables": true to map traefik exposed ports to docker host ipv6 adress
        * create a docker network "default_network" with ipv4only dedicated to tango services ?
        * attach traefik to the two network
        * "traafik_network" ipv6 adress can be set with only local ipv6 adress (ULA)
        * "ip6tables": true docker option when activated to manage nat port between the IPV6 docker host adress and the IPV6 container adressses 
        * https://docs.docker.com/config/daemon/ipv6/
        * docker daemon setup
            * dockerd --ipv6 --fixed-cidr-v6 fd11:2233:4455:6677::/64 --ip6tables
            OR update /etc/docker/daemon.json:
            {
                "experimental": true,
                "ipv6": true,
                "ip6tables": true,
                "fixed-cidr-v6": "fd11:2233:4455:6677::/64" #  "fixed-cidr-v6": "fd00::/80"
            }
        * docker network create -d bridge --ipv6 


* [ ] BUG when using in tango env file 
    * TEST=\
    * problem with  TEST=\ : single \ in compose env file it become TEST='\' and \' make docker compose to throw an error


* [ ] tango plugin restriction
    * each plugin can work 
        * only on some specific services
        * may require app lib
        * may require stella
        * may require some var init in tango init or mambo init
        * TODO implement restriction system on plugin, which may work only if certains criteria are ok


* [ ] migrate from docker-compose (v1.x) to "docker compose" (v2.x)
    * https://docs.docker.com/compose/cli-command-compatibility/
    * install method linux : https://github.com/docker/compose (report it to stella)

* [X] 20220819 : implement add environment to service : __add_environment_service_all()

* [X] 2022 07 31 test :
    ```
    ./tango --module portainer%dcksocketproxy%filezilla%firefox --module firefox^2~vpn_1%cloud9 --domain chimere-harpie.org --freeport gen -d
    ```

* [ ] 2022 01 30 - DNS challenge mode AND cloudflare 
    * __check_lets_encrypt_settings
    * __set_letsencrypt_service_all
    * __set_error_engine
    * ACME_CHALLENGE variables
    * [ ] cloudflare support
        * https://github.com/htpcBeginner/docker-traefik/blob/master/docker-compose-t2-web.yml
        * https://medium.com/@leandrobarral/traefik-2-setup-reverse-proxy-with-lets-encrypt-and-cloudflare-support-46d68b39ca71
        * cloudflare ssl mode list : OFF / flexible / Full / Full(strict) / Strict (SSL-Only Origin Pull) https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes
        * https://github.com/tiredofit/docker-traefik-cloudflare-companion (Docker image to automatically update Cloudflare DNS)
        * [X] 2022-06-12 : comment injecter CF_API_EMAIL CF_API_KEY into docker compose file ? each usefull variable is prefixed by ACME_VAR_
        * https://dev.to/bgalvao/traefik-lets-encrypt-cloudflare-36fj
        * https://www.grottedubarbu.fr/traefik-dns-challenge-ovh/
    * command line test : https://go-acme.github.io/lego/dns/ovh/
            mkdir temp
            docker run --user "$(id -u):$(id -g)" \
            -e OVH_APPLICATION_KEY=xxxxxxxx -e OVH_APPLICATION_SECRET=xxxxxxxx -e OVH_CONSUMER_KEY=xxxxxxxxxx -e OVH_ENDPOINT=ovh-eu \
            -v $(pwd)/temp:/data goacme/lego --server https://acme-staging-v02.api.letsencrypt.org/directory --email nomorgan@gmail.com --dns ovh --domains 'mozilla.chimere-harpie.org' --path /data --accept-tos --dns.resolvers 1.1.1.1:53 --dns.resolvers 8.8.8.8:53 run


* [ ] 2022 07 when in shared mode (TANGO_INSTANCE_MODE=shared) and launching a SAME service in two isolated context, the first launched service is deleted when launching the second
    ```
    cd $HOME
    export TANGO_INSTANCE_MODE=shared
    mkdir ctx1
    mkdir ctx2
    cd tango
    ./tango --ctx ctx1 --ctxroot $HOME/ctx1 --module firefox  --domain chimere-harpie.org --freeport up firefox
    ./tango --ctx ctx2 --ctxroot $HOME/ctx2 --module firefox  --domain chimere-harpie.org --freeport up firefox 
    ```

* [ ] implementation of __set_priority_router_all force TANGO_SUBSERVICES_ROUTER to have same family subrouter following each other in the list - REVIEW the implementation

* [X] add by default traefik service ? its is added because traefik is a depency of all compose service
    * [-] each time we relaunch a single service, traefik is recreated --- is this a problem ? --- use --no-recreate ?
    
* [ ] modules env file before/after app env file ?

* [X] default area network for module and services : main

* [X] upgrade traefik 2.1 to 2.2.x https://docs.traefik.io/migration/v2/
* [-] HTTP to HTTPS https://docs.traefik.io/routing/entrypoints/ 
    * cannot choose a redirection on each router because the redirect apply to https but cannot choose which port when there is several entrypoint
    * see https://www.reddit.com/r/Booksonic/comments/jsbf00/booksonic_docker_guide_detailed_for_newbie/gc14yvp/?utm_source=reddit&utm_medium=web2x&context=3 ? https://doc.traefik.io/traefik/middlewares/redirectscheme/ ==> PB : redirect http to https on which port => MUST depend on the entrypoint

* [ ] make some default configuration on entrypoint https://doc.traefik.io/traefik/routing/entrypoints/
    * http.redirection entrypoint priority ?
    * tls ?

* [ ] secure traefik headers and optimize traefik trafic
    * https://mediacenterz.com/ultimate-docker-home-server-avec-traefik-2-letsencrypt-et-oauth-2020/
    * https://blog.lapaire.org/update-traefik-v2-4-to-v2-5/
    * https://github.com/htpcBeginner/docker-traefik/blob/master/appdata/traefik2/rules/web/middlewares.yml.example
    * optimisation : https://github.com/brokenscripts/authentik_traefik/tree/traefik3/appdata/traefik/rules

* [ ] scripts are sourced when exec => they should not be ? => to inehrit the env var of tango context ? (which is by the way the only main purpose of this 'script' functionality) ==> DEPRECATE script usage ?

* [X] remove script_init ? (scripts init are always launched with a predefined image) do we really need this as we used ansible in mambo and in init phase we often need to control docker itself and its not really easy to control it from inside a container ?

* [ ] Add possibility to reverse proxy to an http link instead of a service 
    * https://gist.github.com/StudioEtrange/c6bb41732063b0151adf5ef592768348

* [ ] Catch Error 502 while getting external IP in tango_set_context.sh
    ```TANGO_EXTERNAL_IP="$(__tango_curl -s ipinfo.io/ip)"```

* [X] error service : exclude non HTTP router in entrypoints list `TRAEFIK_ENTRYPOINTS_LIST` which is used in compose file here : `"traefik.http.routers.error.entrypoints=${TRAEFIK_ENTRYPOINTS_LIST}"`


* [ ] network security
    * OWASP ModSecurity Core Rule Set (CRS)
        * network analyser 
        * https://coreruleset.org/
        * https://github.com/coreruleset/coreruleset
        * https://github.com/coreruleset/modsecurity-crs-docker
    * plugin traefik for OWASP ModSecurity Core Rule Set : https://github.com/acouvreur/traefik-modsecurity-plugin
    * plugin Geoblock : allow/unallow request based on geographic origin https://plugins.traefik.io/plugins/62d6ce04832ba9805374d62c/geo-block


* VPN gluetun [ ] replace https://github.com/StudioEtrange/openvpn-client with https://github.com/qdm12/gluetun
    * lib_pia_port_forward.sh lib_transmission.sh : about PIA provider remote port : https://github.com/qdm12/gluetun-wiki/blob/main/setup/options/port-forwarding.md
    * lib_tango.sh::__create_vpn() : open vpn option to get from env var : https://github.com/qdm12/gluetun-wiki/blob/main/setup/options/openvpn.md 