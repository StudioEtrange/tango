#!/bin/bash


# ------------------- AFTER ACTION ----------------------------

case ${ACTION} in
	info|up|down|status|init|restart )
		docker-compose rm -v -f 1>/dev/null
		;;
	cert|shell|install|logs|mods)
		;;
esac
