# Standard GET API https://docs.traefik.io/operations/api
# curl -kL http://traefik.domain.com:9000/api/version
# curl -kL http://traefik.domain.com:9000/api/rawdata



# REST API https://docs.traefik.io/v1.7/configuration/backends/rest/
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
    TRAEFIK_INTERNAL_API_URL="http://traefik/api"
}


# __traefik_api_request "GET" "rawdata"
# __traefik_api_request "PUT" "{}"
__traefik_api_request() {
    local __http_command="$1"
    local __request="$2"
    local __url="$TRAEFIK_INTERNAL_API_URL"

    local __body=

    [ "${__http_command}" = "" ] && __http_command="GET"
    
    case $__http_command in
        GET ) 
            __url="${__url}"
            [ ! "${__request}" = "" ] && __url="${__url}/${__request}"
        ;;
        PUT ) 
            __url="${__url}/providers/rest"
            __body="${__request}"
        ;;
    esac

    [ "${__body}" = "" ] && docker run --network "${TANGO_APP_NETWORK_NAME}" --rm curlimages/curl:7.70.0 curl -u ${TRAEFIK_API_USER}:${TRAEFIK_API_HASH_PASSWORD} -X ${__http_command} -skL "${__url}" \
        || docker run --network "${TANGO_APP_NETWORK_NAME}" --rm curlimages/curl:7.70.0 curl -d "${__body}" -u ${TRAEFIK_API_USER}:${TRAEFIK_API_HASH_PASSWORD} -X ${__http_command} -skL "${__url}"
}
