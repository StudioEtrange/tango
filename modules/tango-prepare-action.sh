#!/bin/bash


if [ ! "${ACTION}" = "install" ]; then
	type docker-compose 1>/dev/null 2>&1 || {
		echo "** ERROR : please install app first"
		exit 1
	}


	# TANGO APP
	[ "${TANGO_APP_NAME}" = "" ] && TANGO_APP_NAME="${APP}"
	TANGO_APP_NAME_CAPS="${TANGO_APP_NAME^^}"
	[ "${APPROOT}" = "" ] && TANGO_APP_ROOT="${TANGO_ROOT}" || TANGO_APP_ROOT="${APPROOT}"
	TANGO_APP_ROOT="$($STELLA_API rel_to_abs_path "${TANGO_APP_ROOT}" "${TANGO_CURRENT_RUNNING_DIR}")"
	[ "${TANGO_APP_COMPOSE_FILE}" = "" ] && TANGO_APP_COMPOSE_FILE="${TANGO_APP_ROOT}/${TANGO_APP_NAME}.docker-compose.yml"
	TANGO_APP_ENV_FILE="${TANGO_APP_ROOT}/${TANGO_APP_NAME}.env"
	TANGO_APP_COMPOSE_FILE="${TANGO_APP_ROOT}/${TANGO_APP_NAME}.docker-compose.yml"

	# workspace folder
	TANGO_WORK_ROOT="${TANGO_ROOT}/workspace"
	mkdir -p "${TANGO_WORK_ROOT}"
	TANGO_APP_WORK_ROOT="${TANGO_APP_ROOT}/workspace"
	mkdir -p "${TANGO_APP_WORK_ROOT}"

	# TODO review ? app name can be empty ?
	# if approot empty => current running dir
	# if app empty => app name = tango-app ? APP_WORK_ROOT=workspace/tango-app ?
	# if app empty => app and user compose/env file are ? warn conflict with tango compose/env file
	[ "${TANGO_APP_ENV_FILE}" = "${TANGO_ENV_FILE}" ] && TANGO_APP_ENV_FILE=
	[ "${TANGO_APP_COMPOSE_FILE}" = "${TANGO_COMPOSE_FILE}" ] && TANGO_APP_COMPOSE_FILE=

	# TANGO APP USER FILES 
	TANGO_USER_COMPOSE_FILE="$($STELLA_API rel_to_abs_path "${COMPOSE}" "${TANGO_CURRENT_RUNNING_DIR}")"
	TANGO_USER_ENV_FILE="$($STELLA_API rel_to_abs_path "${ENV}" "${TANGO_CURRENT_RUNNING_DIR}")"

	# GENERATED FILES
	GENERATED_DOCKER_COMPOSE_FILE="${TANGO_APP_ROOT}/generated.${TANGO_APP_NAME}.docker-compose.yml"
	GENERATED_ENV_FILE_FOR_BASH="${TANGO_APP_ROOT}/generated.${TANGO_APP_NAME}.bash.env"
	GENERATED_ENV_FILE_FOR_COMPOSE="${TANGO_APP_ROOT}/generated.${TANGO_APP_NAME}.compose.env"


	# load app libs
	for f in ${TANGO_APP_ROOT}/pool/libs/*; do
		[ -f "${f}" ] && . ${f}
	done


	# set variables list
	__get_declared_variable_names

	[ "${BUILD}" = "1" ] && BUILD="--build"
	[ "${DAEMON}" = "1" ] && DAEMON="-d"
	if [ "${DEBUG}" = "1" ]; then
		VERBOSE="1"
		#DOCKER_COMPOSE_LOG="--verbose"
	fi

	# generate env files
	# so priority here become :
	# 	- user env file
	# 	- app env file
	# 	- default env file
	__create_env_for_docker_compose
	__create_env_for_bash
	. "${GENERATED_ENV_FILE_FOR_BASH}"


	# load variables 
	# so priority here become :
	#	- shell env variables
	# 	- user env file
	# 	- app env file
	# 	- default env file
	__update_env_files "ingest from shell env variables"
	. "${GENERATED_ENV_FILE_FOR_BASH}"


	# set environment variables from command line
	# so priority here become :
	#	- command line
	#	- shell env variables
	# 	- user env file
	# 	- app env file
	# 	- default env file
	[ ! "${PUID}" = "" ] && export TANGO_USER_ID="${PUID}"
	[ ! "${PGID}" = "" ] && export TANGO_GROUP_ID="${PGID}"
	[ ! "${DOMAIN}" = "" ] && export TANGO_DOMAIN="${DOMAIN}"
	if [ "${DEBUG}" = "1" ]; then
		[ "${LETS_ENCRYPT}" = "enable" ] && export LETS_ENCRYPT="debug"
	fi

	

	__add_declared_variables "TANGO_APP_NAME"
	__add_declared_variables "TANGO_APP_NAME_CAPS"
	__add_declared_variables "TANGO_APP_ROOT"
	__add_declared_variables "TANGO_APP_ENV_FILE"
	__add_declared_variables "TANGO_APP_COMPOSE_FILE"
	__add_declared_variables "TANGO_APP_WORK_ROOT"
	__add_declared_variables "GENERATED_ENV_FILE_FOR_COMPOSE"

	__update_env_files "ingest variables from command line"

	# set environment variables with hardcoded default values and fixed default path
	# so priority here become :
	#	- command line
	#	- shell env variables
	# 	- user env file
	# 	- app env file
	# 	- default env file
	# 	- default values hardcoded


	# default hardcoded user
	[ "${TANGO_USER_ID}" = "" ] && export TANGO_USER_ID="$(id -u)"
	[ "${TANGO_GROUP_ID}" = "" ] && export TANGO_GROUP_ID="$(id -g)"
	
	__add_declared_variables "TANGO_ROOT"
	

	# determine various path to create
	# create folder under TANGO_DATA_PATH
	DEFAULT_TANGO_DATA_PATH_TO_CREATE=
	# create folder under TANGO_APP_WORK_ROOT
	DEFAULT_APP_WORK_PATH_TO_CREATE=
	
	# set default path if needed
	for p in ${TANGO_PATH_LIST}; do
		if [ "${!p}" = "" ]; then
			__default_var_name="${p}_DEFAULT"
			__subpath="${!__default_var_name}"
			# export this path will update its value inside env files
			eval "export ${p}=${TANGO_APP_WORK_ROOT}/${__subpath}"
			DEFAULT_APP_WORK_PATH_TO_CREATE="${DEFAULT_APP_WORK_PATH_TO_CREATE} FOLDER ${__subpath}"
		fi
	done

	# Tango instance mode
	case ${TANGO_INSTANCE_MODE} in
		shared )
			TANGO_SHARED_DATA_PATH="${TANGO_WORK_ROOT}"
			TANGO_INSTANCE_NAME="tango"
			TANGO_DATA_PATH="${TANGO_SHARED_DATA_PATH}"		
			;;
		isolated )
			TANGO_SHARED_DATA_PATH=
			TANGO_INSTANCE_NAME="${TANGO_APP_NAME}"
			TANGO_DATA_PATH="${DATA_PATH}"
			;;
	esac

	DEFAULT_TANGO_DATA_PATH_TO_CREATE="${DEFAULT_TANGO_DATA_PATH_TO_CREATE} FOLDER letsencrypt traefikconfig FILE letsencrypt/acme.json traefikconfig/generated.${TANGO_APP_NAME}.tls.yml"
	TANGO_APP_NETWORK_NAME="${TANGO_INSTANCE_NAME}_default"
	GENERATED_TLS_FILE_PATH="${TANGO_DATA_PATH}/traefikconfig/generated.${TANGO_APP_NAME}.tls.yml"

	__add_declared_variables "TANGO_INSTANCE_NAME"
	# data of generic service like tango
	__add_declared_variables "TANGO_DATA_PATH"
	# path to shared tango data
	__add_declared_variables "TANGO_SHARED_DATA_PATH"
	__add_declared_variables "GENERATED_TLS_FILE_PATH"
	__add_declared_variables "TANGO_APP_NETWORK_NAME"



	__update_env_files "ingest variables and path with default hardcoded or fixed values  and instance mode variables"

	# add some environment variables created at runtime
	# so priority here become :
	#	- command line
	#	- shell env variables
	# 	- user env file
	# 	- app env file
	# 	- default env file
	# 	- default values hardcoded
	# 	- runtime only variables
	export TANGO_HOST_IP="${STELLA_HOST_IP}"
	__add_declared_variables "TANGO_HOST_IP"
	export TANGO_HOST_DEFAULT_IP="${STELLA_HOST_DEFAULT_IP}"
	__add_declared_variables "TANGO_HOST_DEFAULT_IP"
	export TANGO_HOSTNAME="$(hostname)"
	__add_declared_variables "TANGO_HOSTNAME"
	if [ "${NETWORK_INTERNET_EXPOSED}" = "1" ]; then
		export TANGO_EXTERNAL_IP="$(curl -s ipinfo.io/ip)"
	else
		export TANGO_EXTERNAL_IP=
	fi
	__add_declared_variables "TANGO_EXTERNAL_IP"

	# add default services to all available service list
	TANGO_SERVICES_AVAILABLE="${TANGO_SERVICES_DEFAULT} ${TANGO_SERVICES_AVAILABLE}"
	# create a list of active services
	export TANGO_SERVICES_ACTIVE="$(__filter_list "${TANGO_SERVICES_AVAILABLE}" "${TANGO_SERVICES_DISABLED}")"
	__add_declared_variables "TANGO_SERVICES_ACTIVE"

	case ${ACTION} in
		info|up|restart )
			if [ "${NETWORK_INTERNET_EXPOSED}" = "1" ]; then
				[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_MAIN}")" = "TRUE" ] && export NETWORK_PORT_MAIN_REACHABLE=1
				__add_declared_variables "NETWORK_PORT_MAIN_REACHABLE"
				[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_MAIN_SECURE}")" = "TRUE" ] && export NETWORK_PORT_MAIN_SECURE_REACHABLE=1
				__add_declared_variables "NETWORK_PORT_MAIN_SECURE_REACHABLE"
				[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_SECONDARY}")" = "TRUE" ] && export NETWORK_PORT_SECONDARY_REACHABLE=1
				__add_declared_variables "NETWORK_PORT_SECONDARY_REACHABLE"
				[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_SECONDARY_SECURE}")" = "TRUE" ] && export NETWORK_PORT_SECONDARY_SECURE_REACHABLE=1
				__add_declared_variables "NETWORK_PORT_SECONDARY_SECURE_REACHABLE"
				[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_ADMIN}")" = "TRUE" ] && export NETWORK_PORT_ADMIN_REACHABLE=1
				__add_declared_variables "NETWORK_PORT_ADMIN_REACHABLE"
				[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_ADMIN_SECURE}")" = "TRUE" ] && export NETWORK_PORT_ADMIN_SECURE_REACHABLE=1
				__add_declared_variables "NETWORK_PORT_ADMIN_SECURE_REACHABLE"
			fi
		;;
	esac


	__update_env_files "ingest new runtime only variables"



	# update some loaded variables
	# so priority here become :
	# 	- new and updated variables at runtime
	#	- command line
	#	- shell env variables
	# 	- user env file
	# 	- app env file
	# 	- default env file
	# 	- default values hardcoded
	# 	- runtime only variables
	__translate_all_path
	# generate compose file (this also add some new variables to VARIABLES_LIST)
	__create_docker_compose_file
	__update_env_files "ingest created/modified variables"

	. "${GENERATED_ENV_FILE_FOR_BASH}"

fi
