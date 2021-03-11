#  TODO 

* [X] upgrade traefik 2.1 to 2.2.x https://docs.traefik.io/migration/v2/
* [-] HTTP to HTTPS https://docs.traefik.io/routing/entrypoints/ 
    ** cannot choose a redirection on each router because the redirect apply to https but cannot choose which port when there is several entrypoint
        ** see https://www.reddit.com/r/Booksonic/comments/jsbf00/booksonic_docker_guide_detailed_for_newbie/gc14yvp/?utm_source=reddit&utm_medium=web2x&context=3 ? https://doc.traefik.io/traefik/middlewares/redirectscheme/ ==> PB : redirect http to https on which port => MUST depend on the entrypoint

* [ ] make some default configuration on entrypoint : https://doc.traefik.io/traefik/routing/entrypoints/
        http.redirection entrypoint priority ?
        tls ?

* [ ] scripts are sourced when exec => they should not be ? => to inehrit the env var of tango context ? (which is by the way the only main purpose of this 'script' functionality)

* [ ] remove script_init ? (scripts init are always launched with a predefined image) do we really need this as we used ansible in mambo and in init phase we often need to control docker itself and its not really easy to control it from inside a container ?

* [ ] create a dynamic traefik route to a specified link : https://gist.github.com/StudioEtrange/c6bb41732063b0151adf5ef592768348

* [] tango_set_context.sh : TODO CATCH >HTTP ERROR like 502
		if [ "${NETWORK_INTERNET_EXPOSED}" = "1" ]; then

			TANGO_EXTERNAL_IP="$(curl -s ipinfo.io/ip)"