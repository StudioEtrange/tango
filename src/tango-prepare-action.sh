#!/bin/bash


if [ ! "${ACTION}" = "install" ]; then
	type docker-compose 1>/dev/null 2>&1 || {
		echo "** ERROR : please install app first"
		exit 1
	}


	# TANGO APP
	TANGO_NOT_IN_APP=
	[ "${TANGO_APP_NAME}" = "" ] && TANGO_APP_NAME="${APP}" || TANGO_APP_NAME="${TANGO_APP_NAME}"
	[ "${TANGO_APP_NAME}" = "" ] && TANGO_APP_NAME="tango" && TANGO_NOT_IN_APP=1
	TANGO_APP_NAME_CAPS="${TANGO_APP_NAME^^}"

	[ "${APPROOT}" = "" ] && TANGO_APP_ROOT="${TANGO_ROOT}" || TANGO_APP_ROOT="${APPROOT}"
	TANGO_APP_ROOT="$($STELLA_API rel_to_abs_path "${TANGO_APP_ROOT}" "${TANGO_CURRENT_RUNNING_DIR}")"

	[ "${TANGO_APP_COMPOSE_FILE}" = "" ] && TANGO_APP_COMPOSE_FILE="${TANGO_APP_ROOT}/${TANGO_APP_NAME}.docker-compose.yml"
	TANGO_APP_ENV_FILE="${TANGO_APP_ROOT}/${TANGO_APP_NAME}.env"
	TANGO_APP_COMPOSE_FILE="${TANGO_APP_ROOT}/${TANGO_APP_NAME}.docker-compose.yml"
	TANGO_APP_MODULES_ROOT="${TANGO_APP_ROOT}/pool/modules"

	# workspace folder
	TANGO_WORK_ROOT="${TANGO_ROOT}/workspace"
	mkdir -p "${TANGO_WORK_ROOT}"
	TANGO_APP_WORK_ROOT="${TANGO_APP_ROOT}/workspace"
	mkdir -p "${TANGO_APP_WORK_ROOT}"

	TANGO_MODULES="$(__list_modules "tango")"
	if [ "${TANGO_NOT_IN_APP}" = "1" ]; then
		TANGO_APP_ENV_FILE=
		TANGO_APP_COMPOSE_FILE=
		TANGO_APP_MODULES_ROOT=
		TANGO_APP_MODULES=
	else
		TANGO_APP_MODULES="$(__list_modules "app")"
	fi

	# TANGO USER FILES 
	[ ! "${COMPOSE}" = "" ] && TANGO_USER_COMPOSE_FILE="$($STELLA_API rel_to_abs_path "${COMPOSE}" "${TANGO_CURRENT_RUNNING_DIR}")"
	[ ! "${ENV}" = "" ] && TANGO_USER_ENV_FILE="$($STELLA_API rel_to_abs_path "${ENV}" "${TANGO_CURRENT_RUNNING_DIR}")"

	# GENERATED FILES
	GENERATED_DOCKER_COMPOSE_FILE="${TANGO_APP_ROOT}/generated.${TANGO_APP_NAME}.docker-compose.yml"
	GENERATED_ENV_FILE_FOR_BASH="${TANGO_APP_ROOT}/generated.${TANGO_APP_NAME}.bash.env"
	GENERATED_ENV_FILE_FOR_COMPOSE="${TANGO_APP_ROOT}/generated.${TANGO_APP_NAME}.compose.env"


	# load app libs
	for f in ${TANGO_APP_ROOT}/pool/libs/*; do
		[ -f "${f}" ] && . ${f}
	done


	# NOTE on env variables
	# 	VARIABLES_LIST store all declared variables in env files AND added variables at runtime
	#					these variables are updated inside env files
	#					it is not needed to export these variables
	
	# order priority :
	# 	- new and computed variables at runtime
	#	- shell env variables
	#	- command line
	# 	- user env file
	# 	- modules env file
	# 	- app env file
	# 	- default tango env file
	# 	- default values hardcoded and runtume computed
	

	# STEP 1 ------ init env variables

	extract_modules_list_from_files=
	# test if TANGO_SERVICES_MODULES is declared as shell env var
	if [ "${TANGO_SERVICES_MODULES}" = "" ]; then
	# test if TANGO_SERVICES_MODULES is declared with command line
		if [ ! "${ADD}" = "" ]; then
			TANGO_SERVICES_MODULES="${ADD//:/ }"
			[ "${TANGO_SERVICES_MODULES}" = "" ] && extract_modules_list_from_files=1
		fi
	fi

	# split module list defined by shell env or command line
	[ "${extract_modules_list_from_files}" = "" ] && __parse_modules_list

	# generate bash env files
	# bash env files priority :
	# 	- user env file
	# 	- app env file
	# 	- default env file
	__create_env_for_bash
	# retrieve TANGO_SERVICES_MODULES defined in env files
	if [ "${extract_modules_list_from_files}" = "1" ]; then
		TANGO_SERVICES_MODULES="$(env -i bash --noprofile --norc -c ". ${GENERATED_ENV_FILE_FOR_BASH}; echo \$TANGO_SERVICES_MODULES")"
		# modules are defined in env files, so we need to rebuild env files with new env files priority
		# 			- user env file
		# 			- modules env file
		# 			- app env file
		# 			- default env file
		if [ ! "${TANGO_SERVICES_MODULES}" = "" ]; then
			__parse_modules_list
			__create_env_for_bash
		fi
	fi
	__create_env_for_docker_compose

	# fill VARIABLES_LIST declared variables from all env files
	__get_declared_variable_names
	# add to VARIABLES_LIST declared variables from modules env files
	__add_modules_declared_variable_names


	
	# STEP 2 ------ process command line and shell env variables

	[ "${BUILD}" = "1" ] && BUILD="--build"
	[ "${DAEMON}" = "1" ] && DAEMON="-d"
	if [ "${DEBUG}" = "1" ]; then
		VERBOSE="1"
	fi
	[ "${TANGO_USER_ID}" = "" ] && [ ! "${PUID}" = "" ] && TANGO_USER_ID="${PUID}"
	[ "${TANGO_GROUP_ID}" = "" ] && [ ! "${PGID}" = "" ] &&  TANGO_GROUP_ID="${PGID}"
	[ "${TANGO_DOMAIN}" = "" ] && [ ! "${DOMAIN}" = "" ] && TANGO_DOMAIN="${DOMAIN}"

	case ${ACTION} in
		up|restart )
			if [ "${FREEPORT}" = "1" ]; then
				__free_port_list="$($STELLA_API find_free_port "6" "TCP RANGE_BEGIN 10000 RANGE_END 65000 CONSECUTIVE")"
				if [ ! "${__free_port_list}" = "" ]; then
					__free_port_list=( ${__free_port_list} )
					NETWORK_PORT_MAIN=${__free_port_list[0]}
					NETWORK_PORT_MAIN_SECURE=${__free_port_list[1]}
					NETWORK_PORT_SECONDARY=${__free_port_list[2]}
					NETWORK_PORT_SECONDARY_SECURE=${__free_port_list[3]}
					NETWORK_PORT_ADMIN=${__free_port_list[4]}
					NETWORK_PORT_ADMIN_SECURE=${__free_port_list[5]}
				fi
			fi
		;;
	esac

	
	# add variables created at runtime or computed from command line
	__add_declared_variables "TANGO_APP_NAME"
	__add_declared_variables "TANGO_APP_NAME_CAPS"

	__add_declared_variables "TANGO_ROOT"
	__add_declared_variables "TANGO_APP_ROOT"
	__add_declared_variables "TANGO_APP_WORK_ROOT"

	__add_declared_variables "TANGO_ENV_FILE"
	__add_declared_variables "TANGO_APP_ENV_FILE"
	__add_declared_variables "TANGO_USER_ENV_FILE"
	__add_declared_variables "TANGO_COMPOSE_FILE"
	__add_declared_variables "TANGO_APP_COMPOSE_FILE"
	__add_declared_variables "TANGO_USER_COMPOSE_FILE"

	__add_declared_variables "TANGO_MODULES"
	__add_declared_variables "TANGO_MODULES_ROOT"
	__add_declared_variables "TANGO_APP_MODULES"
	__add_declared_variables "TANGO_APP_MODULES_ROOT"

	__add_declared_variables "GENERATED_ENV_FILE_FOR_COMPOSE"
	__add_declared_variables "TANGO_NOT_IN_APP"
	__add_declared_variables "TANGO_SERVICES_MODULES"
	__add_declared_variables "TANGO_SERVICES_MODULES_FULL"

	# update env var 
	# env var values priority order :
	# 	- new and computed variables at runtime
	#	- command line
	#	- shell env variables
	# 	- user env file
	# 	- modules env file
	# 	- app env file
	# 	- default tango env file
	__update_env_files "ingest with env variables from shell and command line"
	# load env var
	. "${GENERATED_ENV_FILE_FOR_BASH}"


	

	# STEP 3 ------ process hardcoded default values, and computed runtime variable not fixed with command line nor shell env var nor env files

	# so priority here will become :
	# 	- new and computed variables at runtime
	#	- shell env variables
	#	- command line
	# 	- user env file
	# 	- modules env file
	# 	- app env file
	# 	- default tango env file
	# 	- default values hardcoded and runtume computed

	# add default services and active modules services to all available service list
	TANGO_SERVICES_AVAILABLE="${TANGO_SERVICES_DEFAULT} ${TANGO_SERVICES_AVAILABLE} ${TANGO_SERVICES_MODULES}"
		
	# create a list of active services
	TANGO_SERVICES_ACTIVE="$(__filter_list "${TANGO_SERVICES_AVAILABLE}" "${TANGO_SERVICES_DISABLED}")"
	__add_declared_variables "TANGO_SERVICES_ACTIVE"

	# default hardcoded user
	[ "${TANGO_USER_ID}" = "" ] && TANGO_USER_ID="$(id -u)"
	[ "${TANGO_GROUP_ID}" = "" ] && TANGO_GROUP_ID="$(id -g)"
	
	# change lets encrypt behaviour
	if [ "${DEBUG}" = "1" ]; then
		[ "${LETS_ENCRYPT}" = "enable" ] && LETS_ENCRYPT="debug"
	fi

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
			TANGO_INSTANCE_NAME="tango_shared"
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


	
	export TANGO_HOST_IP="${STELLA_HOST_IP}"
	__add_declared_variables "TANGO_HOST_IP"
	export TANGO_HOST_DEFAULT_IP="${STELLA_HOST_DEFAULT_IP}"
	__add_declared_variables "TANGO_HOST_DEFAULT_IP"
	TANGO_HOSTNAME="$(hostname)"
	__add_declared_variables "TANGO_HOSTNAME"
	if [ "${NETWORK_INTERNET_EXPOSED}" = "1" ]; then
		TANGO_EXTERNAL_IP="$(curl -s ipinfo.io/ip)"
	else
		TANGO_EXTERNAL_IP=
	fi
	__add_declared_variables "TANGO_EXTERNAL_IP"



	case ${ACTION} in
		info|up|restart )
			if [ "${NETWORK_INTERNET_EXPOSED}" = "1" ]; then
				[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_MAIN}")" = "TRUE" ] && NETWORK_PORT_MAIN_REACHABLE=1
				__add_declared_variables "NETWORK_PORT_MAIN_REACHABLE"
				[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_MAIN_SECURE}")" = "TRUE" ] && NETWORK_PORT_MAIN_SECURE_REACHABLE=1
				__add_declared_variables "NETWORK_PORT_MAIN_SECURE_REACHABLE"
				[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_SECONDARY}")" = "TRUE" ] && NETWORK_PORT_SECONDARY_REACHABLE=1
				__add_declared_variables "NETWORK_PORT_SECONDARY_REACHABLE"
				[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_SECONDARY_SECURE}")" = "TRUE" ] && NETWORK_PORT_SECONDARY_SECURE_REACHABLE=1
				__add_declared_variables "NETWORK_PORT_SECONDARY_SECURE_REACHABLE"
				[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_ADMIN}")" = "TRUE" ] && NETWORK_PORT_ADMIN_REACHABLE=1
				__add_declared_variables "NETWORK_PORT_ADMIN_REACHABLE"
				[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_ADMIN_SECURE}")" = "TRUE" ] && NETWORK_PORT_ADMIN_SECURE_REACHABLE=1
				__add_declared_variables "NETWORK_PORT_ADMIN_SECURE_REACHABLE"
			fi
		;;
	esac

	# update env var 
	# new env var values priority order :
	# 	- new and computed variables at runtime
	#	- shell env variables
	#	- command line
	# 	- user env file
	# 	- modules env file
	# 	- app env file
	# 	- default tango env file
	# 	- default values hardcoded and runtume computed
	__update_env_files "ingest default hardcoded values and runtime only variables"



	# STEP 4 ------ create/transform some values and create docker compose file
	
	# update path
	__translate_all_path
	# generate compose file (this also add some new variables to VARIABLES_LIST)
	__create_docker_compose_file
	
	# update env var 
	# env var values priority order :
	# 	- new and computed variables at runtime
	#	- shell env variables
	#	- command line
	# 	- user env file
	# 	- modules env file
	# 	- app env file
	# 	- default tango env file
	# 	- default values hardcoded and runtume computed
	__update_env_files "ingest created/modified/translated variables"
	# load env var
	. "${GENERATED_ENV_FILE_FOR_BASH}"

fi
