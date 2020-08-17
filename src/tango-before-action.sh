#!/bin/bash


# ------------------- BEFORE ACTION ----------------------------

case ${ACTION} in
	install|cert|letsencrypt|modules|vendor )
		;;
	info )
		__create_path_all
		__check_lets_encrypt_settings "warn"
		__set_certificates_all
		;;
	up|restart|stop|down|plugins )
		__create_path_all
		__check_mandatory_path
		__check_lets_encrypt_settings
		__set_certificates_all
		;;
	status|logs|shell|update )
		__create_path_all
		__set_certificates_all
		;;
esac
