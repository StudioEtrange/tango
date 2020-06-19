# Standard GET API https://docs.traefik.io/operations/api
# curl -kL http://traefik.domain.com:9000/api/version
# REST API https://docs.traefik.io/v1.7/configuration/backends/rest/
# API REST PUT request sample
# curl -kL -u tango:tango -d "{}" -X PUT https://traefik.domain.com:9000/api/providers/rest


__traefik_api_url() {
    TRAEFIK_INTERNAL_API_URL="http://traefik/api"
}



__traefik_api_request() {
    local __request="$1"
    local __http_command="$2"
    local __url="$TRAEFIK_INTERNAL_API_URL"

    [ "${__http_command}" = "" ] && __http_command="GET"
    
    case $__http_command in
        GET ) __url="${__url}"
        ;;
        PUT ) __url="${__url}/providers/rest"
        ;;
    esac
    docker run --network "${TANGO_APP_NETWORK_NAME}" --rm curlimages/curl:7.70.0 curl -u ${TRAEFIK_API_USER}:${TRAEFIK_API_HASH_PASSWORD} -X ${__http_command} -skL "${__url}"
}


__traefik_api_set_auth_service() {
    local __service="$1"
    local __group_id="$2"

    # CONTINUE HERE
    # see __organizr2_add_auth_service
    # curl -kL -X GET http: //traefik.chimere-harpie.org:9000/api/http/routers
    # curl -kL -X GET http: //traefik.chimere-harpie.org:9000/api/http/middlewares

    local __midname="${__service}-auth"
    local __body="{http : {middlewares: {  } }}"
    # curl -d "{}" -k -u mambo:mambo1 -X PUT https://traefik.chimere-harpie.org:9443/api/providers/rest


    # middleware
    #  {
    #     "redirectScheme": {
    #         "scheme": "https",
    #         "port": "9443",
    #         "permanent": true
    #     },
    #     "status": "enabled",
    #     "usedBy": [
    #         "http-catchall-web_admin@docker"
    #     ],
    #     "name": "redirect-secure-web_admin@docker",
    #     "provider": "docker",
    #     "type": "redirectscheme"
    # }
}