#!/bin/bash


# ------------------- BEFORE ACTION ----------------------------

case ${ACTION} in
	# we need nothing
	# module soulb be able to be launched without any condition
	install|cert|letsencrypt|modules|services|vendor )
		;;
	
	# we need everything for start services and exec plugin
	up|restart|stop|down|plugins )
		__create_path_all
		__check_mandatory_path
		__check_lets_encrypt_settings
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __set_certificates_all
		;;

	# we just need a docker compose file uptodate
	# but without blocking control because we need to launch these command even if a control is not valid
	status|logs|shell|update|info|scripts )
		__create_path_all
		__check_mandatory_path "warn"
		__check_lets_encrypt_settings "warn"
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __set_certificates_all
		;;
esac
