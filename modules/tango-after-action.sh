#!/bin/bash


# ------------------- AFTER ACTION ----------------------------

case ${ACTION} in
	info|init|up|restart|stop|down|status )
		docker-compose rm -v -f 1>/dev/null
		;;
esac
