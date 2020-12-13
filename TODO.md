#  TODO 

* [X] upgrade traefik 2.1 to 2.2.x https://docs.traefik.io/migration/v2/
* [-] HTTP to HTTPS https://docs.traefik.io/routing/entrypoints/ 
    ** cannot choose a redirection on each router because the redirect apply to https but cannot choose which port when there is several entrypoint
        ** see https://www.reddit.com/r/Booksonic/comments/jsbf00/booksonic_docker_guide_detailed_for_newbie/gc14yvp/?utm_source=reddit&utm_medium=web2x&context=3 ? https://doc.traefik.io/traefik/middlewares/redirectscheme/ ==> PB : redirect http to https on which port => MUST depend on the entrypoint

* [ ] make some default configuration on entrypoint : https://doc.traefik.io/traefik/routing/entrypoints/
        http.redirection entrypoint priority ?
        tls ?

* [ ] scripts are sourced when exec => they should not be ?