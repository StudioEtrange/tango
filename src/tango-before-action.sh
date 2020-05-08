#!/bin/bash


# ------------------- BEFORE ACTION ----------------------------

case ${ACTION} in
	install|cert|mods )
		;;
	info )
		__create_default_path "${TANGO_APP_WORK_ROOT}" "${DEFAULT_APP_WORK_PATH_TO_CREATE}"
		__create_default_path "${TANGO_DATA_PATH}" "${DEFAULT_TANGO_DATA_PATH_TO_CREATE}"
		__check_lets_encrypt_settings "warn"
		__set_certificates_all
		;;
	up|restart|stop|down )
		__create_default_path "${TANGO_APP_WORK_ROOT}" "${DEFAULT_APP_WORK_PATH_TO_CREATE}"
		__create_default_path "${TANGO_DATA_PATH}" "${DEFAULT_TANGO_DATA_PATH_TO_CREATE}"
		__check_mandatory_path
		__check_lets_encrypt_settings
		__set_certificates_all
		;;
	status|logs|shell )
		__create_default_path "${TANGO_APP_WORK_ROOT}" "${DEFAULT_APP_WORK_PATH_TO_CREATE}"
		__create_default_path "${TANGO_DATA_PATH}" "${DEFAULT_TANGO_DATA_PATH_TO_CREATE}"
		__set_certificates_all
		;;
esac
