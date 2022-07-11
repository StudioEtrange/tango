#  TODO 

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
            -e OVH_APPLICATION_KEY=b455ac89f5367a5d -e OVH_APPLICATION_SECRET=d07ebb5f8094cbc3ba81544d0839157e -e OVH_CONSUMER_KEY=bba4a7c01cb60af5cba8e55ba13ca641 -e OVH_ENDPOINT=ovh-eu \
            -v $(pwd)/temp:/data goacme/lego --server https://acme-staging-v02.api.letsencrypt.org/directory --email nomorgan@gmail.com --dns ovh --domains 'mozilla.chimere-harpie.org' --path /data --accept-tos --dns.resolvers 1.1.1.1:53 --dns.resolvers 8.8.8.8:53 run





* [ ] implementation of __set_priority_router_all force TANGO_SUBSERVICES_ROUTER to have same family subrouter following each other in the list - REVIEW the implementation

* [X] add by default traefik service ? its is added because traefik is a depency of all compose service
    * [ ] each time we relaunch a single service, traefik is recreated --- is this a problem ? --- use --no-recreate ?
    
* [ ] modules env file before/after app env file ?

* [X] default area network for module and services : main

* [X] upgrade traefik 2.1 to 2.2.x https://docs.traefik.io/migration/v2/
* [-] HTTP to HTTPS https://docs.traefik.io/routing/entrypoints/ 
    * cannot choose a redirection on each router because the redirect apply to https but cannot choose which port when there is several entrypoint
    * see https://www.reddit.com/r/Booksonic/comments/jsbf00/booksonic_docker_guide_detailed_for_newbie/gc14yvp/?utm_source=reddit&utm_medium=web2x&context=3 ? https://doc.traefik.io/traefik/middlewares/redirectscheme/ ==> PB : redirect http to https on which port => MUST depend on the entrypoint

* [ ] make some default configuration on entrypoint https://doc.traefik.io/traefik/routing/entrypoints/
    * http.redirection entrypoint priority ?
    * tls ?

* [ ] scripts are sourced when exec => they should not be ? => to inehrit the env var of tango context ? (which is by the way the only main purpose of this 'script' functionality) ==> DEPRECATE script usage ?

* [ ] remove script_init ? (scripts init are always launched with a predefined image) do we really need this as we used ansible in mambo and in init phase we often need to control docker itself and its not really easy to control it from inside a container ?

* [ ] Add possibility to reverse proxy to an http link instead of a service 
    * https://gist.github.com/StudioEtrange/c6bb41732063b0151adf5ef592768348

* [] Catch Error 502 while getting external IP in tango_set_context.sh
    ```TANGO_EXTERNAL_IP="$(__tango_curl -s ipinfo.io/ip)"```

* [X] error service : exclude non HTTP router in entrypoints list `TRAEFIK_ENTRYPOINTS_LIST` which is used in compose file here : `"traefik.http.routers.error.entrypoints=${TRAEFIK_ENTRYPOINTS_LIST}"`



* [ ] secure traefik headers
    * https://mediacenterz.com/ultimate-docker-home-server-avec-traefik-2-letsencrypt-et-oauth-2020/
    * https://blog.lapaire.org/update-traefik-v2-4-to-v2-5/


## Modules to create

* vaultwarden 
    * Vaultwarden is an alternative implementation of the Bitwarden server API 
    * https://github.com/BaptisteBdn/docker-selfhosted-apps/tree/main/vaultwarden

* Trillium
    * Build your personal knowledge base with Trilium Notes
    * https://github.com/zadam/trilium
    * https://github.com/BaptisteBdn/docker-selfhosted-apps/tree/main/trilium

* Seafile
    * Seafile is an open source cloud storage system with privacy protection and teamwork features. Collections of files are called libraries. Each library can be synced separately. A library can also be encrypted with a user chosen password. Seafile also allows users to create groups and easily sharing files into groups.
    * https://github.com/haiwen/seafile
    * https://github.com/BaptisteBdn/docker-selfhosted-apps/tree/main/seafile
    * https://www.seafile.com/en/home/




* linuxserver.io server images : https://fleet.linuxserver.io/

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