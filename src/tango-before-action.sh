#!/bin/bash


# ------------------- BEFORE ACTION ----------------------------




case ${ACTION} in
	# we need nothing
	install|cert|modules|services|vendor )
		;;
	
	up|restart)
		if [ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ]; then
			__create_path_all
			__fix_letsencrypt_permission
			__check_mandatory_path "BLOCKING"
			__check_lets_encrypt_settings "BLOCKING"
			__set_certificates_all
		else
			__check_mandatory_path "NON_BLOCKING"
			__check_lets_encrypt_settings "NON_BLOCKING"
		fi
	;;
	* )
		# if we want to alter files and folder we need to at least create needed folder for actions
		if [ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ]; then
			__create_path_all
			__fix_letsencrypt_permission
			__check_mandatory_path "NON_BLOCKING"
			__check_lets_encrypt_settings "NON_BLOCKING"
			__set_certificates_all
	
		else
			__check_mandatory_path "NON_BLOCKING"
			__check_lets_encrypt_settings "NON_BLOCKING"
		fi
		;;
	
esac
