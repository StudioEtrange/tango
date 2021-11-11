#!/bin/bash


# ------------------- AFTER ACTION ----------------------------

case ${ACTION} in
	info|up|down|status|init|restart|update|plugins|shell )
		# remove all anonymous volumes
		docker-compose rm -v -f 1>/dev/null
		;;
	cert|letsencrypt|install|logs|modules|services|vendor|scripts )
		;;
esac

# exec cached traefik api rest put request
__traefik_api_rest_update_launch