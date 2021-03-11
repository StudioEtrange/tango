# MAIN GET API https://docs.traefik.io/operations/api
# curl -kL http://traefik.domain.com:9000/api/version
# curl -kL http://traefik.domain.com:9000/api/rawdata
#   see sample file in samples folder

# TRAEFIK configuration (from docker, file, other provider) CANNOT be updated through API
# Only settings from rest provider can be updated through rest provider api
# https://github.com/containous/traefik/blob/7928e6d0cd4c7751a14bea5f74124f8a3cb829c0/pkg/provider/rest/rest.go#L44

# REST PROVIDER API is not the MAIN API
# REST PROVIDER https://docs.traefik.io/v1.7/configuration/backends/rest/
# request sample 1 :
#           curl -kL -u tango:tango -d "{}" -X PUT https://traefik.domain.com:9000/api/providers/rest
# request sample 2 :
# there is a direct mapping from labels to json. When label is a list (like entrypoints) it is translated as a json array [ ]
# sample to add a router
#      - "traefik.http.routers.test.entrypoints=entrypoint1"
#      - "traefik.http.routers.test.rule=HostRegexp(`{subdomain:test.}{domain:domain.com}`)"
#      - "traefik.http.routers.test.service=service1@docker"
# body='
# {
#     "http": { 
#         "routers": {
#             "test" : {
#                 "entryPoints": [
#                     "entrypoint1"
#                 ],
#                 "rule": "HostRegexp(`{subdomain:test.}{domain:domain.com}`)",
#                 "service": "service1@docker"
#             }
#         }
#     }
# }
# '
# curl -d "${body}" -k -u user:password -X PUT https://traefik.domain.com:9000/api/providers/rest


__traefik_api_url() {
    TRAEFIK_INTERNAL_CONTAINER_API_URL="http://traefik/api"
    TRAEFIK_API_URL="${TRAEFIK_URI_DEFAULT_SECURE}/api"
}
__traefik_api_url


# __traefik_api_main_request "GET" "rawdata"
# NOTE : use non-hashed password here. Hashed password is used only when setting password at traefik launch
# NOTE : we CANNOT update a traefik router configuration setted from provider @docker
__traefik_api_main_request() {
    __traefik_api_url
    local __http_command="$1"
    local __request="$2"
    local __url="$TRAEFIK_API_URL"

    local __result=

    [ "${__http_command}" = "" ] && __http_command="GET"
    [ "${__http_command}" = "PUT" ] && __tango_log "ERROR" "traefik" "__traefik_api_main_request : no PUT method on main API " && return
    
    case $__http_command in
        GET ) 
            __url="${__url}"
            [ ! "${__request}" = "" ] && __url="${__url}/${__request}"
        ;;
    esac

    #__result="$(docker run --network "${TANGO_APP_NETWORK_NAME}" --rm curlimages/curl:7.70.0 curl -d "${__body}" -u "${TRAEFIK_API_USER}":"${TRAEFIK_API_PASSWORD}" -X ${__http_command} -skL "${__url}")"
    __result="$(__tango_curl -d "${__body}" -u "${TRAEFIK_API_USER}":"${TRAEFIK_API_PASSWORD}" -X ${__http_command} -skL "${__url}")"


    case $__http_command in
        GET ) 
            echo "$__result"
        ;;

    esac
    
}

# queued PUT request
GLOBAL_TRAEFIK_PUT_REQUEST_CACHE=
__traefik_api_rest_update() {
    local __request="$1"


    __tango_log "DEBUG" "traefik" "Traefik API REST store PUT request : ${__request}"

    __request="$(echo {} | jq -r "${__request}")"
    
    # merge json string
    # https://stackoverflow.com/a/36218044
    [ "${GLOBAL_TRAEFIK_PUT_REQUEST_CACHE}" = "" ] && GLOBAL_TRAEFIK_PUT_REQUEST_CACHE="${__request}" || \
        GLOBAL_TRAEFIK_PUT_REQUEST_CACHE="$(echo "${GLOBAL_TRAEFIK_PUT_REQUEST_CACHE}" "${__request}" | jq --slurp 'reduce .[] as $item ({}; . * $item)')"
}

# execute all queued PUT request to traefik REST API endpoint
__traefik_api_rest_update_launch() {
    if [ ! "${GLOBAL_TRAEFIK_PUT_REQUEST_CACHE}" = "" ]; then
        __traefik_api_rest_request "PUT" "${GLOBAL_TRAEFIK_PUT_REQUEST_CACHE}"
    fi 
}

# __traefik_api_request "PUT" {}"
__traefik_api_rest_request() {
    __traefik_api_url
    local __http_command="$1"
    local __request="$2"
    local __url="$TRAEFIK_API_URL/providers/rest"
    local __result=
    local __body=

    [ "${__http_command}" = "" ] && __http_command="PUT"
   

     case $__http_command in
        GET )
            # NOTE : maybe there is NO "GET" method implemented for rest provider
            __url="${__url}/${__request}"
        ;;
        PUT )
            __body="$(echo {} | jq -r "${__request}")"
        ;;
    esac

    #[ "${__body}" = "" ] && __result="$(docker run --network "${TANGO_APP_NETWORK_NAME}" --rm curlimages/curl:7.70.0 curl -u "${TRAEFIK_API_USER}":"${TRAEFIK_API_HASH_PASSWORD}" -X ${__http_command} -skL "${__url}")" \
    #    || __result="$(docker run --network "${TANGO_APP_NETWORK_NAME}" --rm curlimages/curl:7.70.0 curl -d "${__body}" -u "${TRAEFIK_API_USER}":"${TRAEFIK_API_PASSWORD}" -X ${__http_command} -skL "${__url}")"

    [ "${__body}" = "" ] && __result="$(__tango_curl -u "${TRAEFIK_API_USER}":"${TRAEFIK_API_HASH_PASSWORD}" -X ${__http_command} -skL "${__url}")" \
        || __result="$(__tango_curl -d "${__body}" -u "${TRAEFIK_API_USER}":"${TRAEFIK_API_PASSWORD}" -X ${__http_command} -skL "${__url}")"


    case $__http_command in
        GET ) 
            echo "$__result"
        ;;
        PUT )
            __tango_log "DEBUG" "INFO" "__traefik_api_rest_request() : PUT request result is : $__result"   
        ;;
    esac

}
