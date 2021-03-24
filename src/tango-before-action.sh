#!/bin/bash


# ------------------- BEFORE ACTION ----------------------------

case ${ACTION} in
	# we need nothing
	# module should be able to be launched without any condition
	install|cert|letsencrypt|modules|services|vendor )
		;;
	
	* )
		# if we want to alter files and folder we need to at least create needed folder for actions
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __create_path_all
		__check_mandatory_path "WARN"
		__check_lets_encrypt_settings "WARN"
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __set_certificates_all
		;;
	
	# # we need everything for start services and exec plugin
	# up|restart|stop|down|plugins )
	# 	__create_path_all
	# 	__check_mandatory_path
	# 	__check_lets_encrypt_settings
	# 	[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __set_certificates_all
	# 	;;

	# # we just need a docker compose file uptodate
	# # but without blocking control because we need to launch these command even if a control is not valid
	# status|logs|shell|update|info|scripts )
	# 	__create_path_all
	# 	__check_mandatory_path "WARN"
	# 	__check_lets_encrypt_settings "WARN"
	# 	[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __set_certificates_all
	# 	;;
esac
