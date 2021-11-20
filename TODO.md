#  TODO 

* [ ] implementation of __set_priority_router_all force TANGO_SUBSERVICES_ROUTER to have same family subrouter following each other in the list - REVIEW implementation

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

* [ ] cloudflare support
    * https://github.com/tiredofit/docker-traefik-cloudflare-companion
    * https://mediacenterz.com/parametres-cloudflare-pour-traefik-docker-ddns-cnames-et-tweaks/
    * https://mediacenterz.com/ultimate-docker-home-server-avec-traefik-2-letsencrypt-et-oauth-2020/
    * https://github.com/htpcBeginner/docker-traefik/blob/master/docker-compose-t2-web.yml

* [ ] secure traefik headers
    * https://mediacenterz.com/ultimate-docker-home-server-avec-traefik-2-letsencrypt-et-oauth-2020/
    * https://blog.lapaire.org/update-traefik-v2-4-to-v2-5/