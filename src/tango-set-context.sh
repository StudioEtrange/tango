#!/bin/bash

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
TANGO_APP_PLUGINS_ROOT="${TANGO_APP_ROOT}/pool/plugins"
TANGO_APP_SCRIPTS_ROOT="${TANGO_APP_ROOT}/pool/scripts"


# workspace folder
TANGO_WORK_ROOT="${TANGO_ROOT}/workspace"
mkdir -p "${TANGO_WORK_ROOT}"
TANGO_APP_WORK_ROOT="${TANGO_APP_ROOT}/workspace/${TANGO_APP_NAME}"
mkdir -p "${TANGO_APP_WORK_ROOT}"



# available modules from tango
TANGO_MODULES_AVAILABLE="$(__list_items "module" "tango")"
# available plugins from tango
TANGO_PLUGINS_AVAILABLE="$(__list_items "plugin" "tango")"
# available scripts from tango
TANGO_SCRIPTS_AVAILABLE="$(__list_items "script" "tango")"
if [ "${TANGO_NOT_IN_APP}" = "1" ]; then
	TANGO_APP_ENV_FILE=
	TANGO_APP_COMPOSE_FILE=
	TANGO_APP_MODULES_ROOT=
	TANGO_APP_MODULES_AVAILABLE=
	TANGO_APP_PLUGINS_ROOT=
	TANGO_APP_PLUGINS_AVAILABLE=
	TANGO_APP_SCRIPTS_ROOT=
	TANGO_APP_SCRIPTS_AVAILABLE=
else
	# available modules from current app
	TANGO_APP_MODULES_AVAILABLE="$(__list_items "module" "app")"
	# available plugins from current app
	TANGO_APP_PLUGINS_AVAILABLE="$(__list_items "plugin" "app")"
	# available scripts from current app
	TANGO_APP_SCRIPTS_AVAILABLE="$(__list_items "script" "app")"
fi

# TANGO USER FILES 
[ ! "${COMPOSE}" = "" ] && TANGO_USER_COMPOSE_FILE="$($STELLA_API rel_to_abs_path "${COMPOSE}" "${TANGO_CURRENT_RUNNING_DIR}")"
[ ! "${ENV}" = "" ] && TANGO_USER_ENV_FILE="$($STELLA_API rel_to_abs_path "${ENV}" "${TANGO_CURRENT_RUNNING_DIR}")"

# GENERATED FILES
GENERATED_DOCKER_COMPOSE_FILE="${TANGO_APP_ROOT}/generated.${TANGO_APP_NAME}.docker-compose.yml"
GENERATED_ENV_FILE_FOR_BASH="${TANGO_APP_ROOT}/generated.${TANGO_APP_NAME}.bash.env"
GENERATED_ENV_FILE_FOR_COMPOSE="${TANGO_APP_ROOT}/generated.${TANGO_APP_NAME}.compose.env"
GENERATED_ENV_FILE_FREEPORT="${TANGO_APP_ROOT}/generated.${TANGO_APP_NAME}.freeport.env"

# follow option
[ "${FOLLOW}" = 1 ] && FOLLOW="-f " || FOLLOW=

# load app libs
for f in ${TANGO_APP_ROOT}/pool/libs/*; do
	[ -f "${f}" ] && . ${f}
done

case ${ACTION} in

	install|vendor )
		export TANGO_ALTER_GENERATED_FILES="OFF"
		;;

	* )
		type docker-compose 1>/dev/null 2>&1 || {
			echo "** ERROR : please install app first"
			exit 1
		}


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
		



		# STEP 1 ------ init modules, plugins and create first env files

		# generate bash env files
		# bash env files priority :
		# 	- user env file
		# 	- app env file
		# 	- default env file
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __create_env_for_bash

		# modules -----
		# retrieve TANGO_SERVICES_MODULES defined in env files if no shell env var exist
		if [ "${TANGO_SERVICES_MODULES}" = "" ]; then
			TANGO_SERVICES_MODULES="$(env -i bash --noprofile --norc -c ". ${GENERATED_ENV_FILE_FOR_BASH}; echo \$TANGO_SERVICES_MODULES")"
			[ ! "${TANGO_SERVICES_MODULES}" = "" ] && extracted_modules_list_from_files=1
		fi
		# some modules have been defined in env files, so we need to rebuild env files by adding modules env files
		# 			- user env file
		# 			- modules env file
		# 			- app env file
		# 			- default env file
		if [ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ]; then
			[ "${extracted_modules_list_from_files}" = "1" ] && __create_env_for_bash
		fi
		# test if some modules are declared by command line and add them
		if [ ! "${MODULE}" = "" ]; then
			TANGO_SERVICES_MODULES="${TANGO_SERVICES_MODULES} ${MODULE//:/ }"
		fi
		# filter exising modules
		[ ! "${TANGO_SERVICES_MODULES}" = "" ] && __filter_items_exists "module"


		# plugins -----
		# retrieve TANGO_PLUGINS defined in env files if no shell env var exist
		if [ "${TANGO_PLUGINS}" = "" ]; then
			TANGO_PLUGINS="$(env -i bash --noprofile --norc -c ". ${GENERATED_ENV_FILE_FOR_BASH}; echo \$TANGO_PLUGINS")"
		fi
		# test if some plugins are declared by command line and add them
		if [ ! "${PLUGIN}" = "" ]; then
			TANGO_PLUGINS="${TANGO_PLUGINS} ${PLUGIN//:/ }"
		fi
		# check plugins exist and build list and map
		[ ! "${TANGO_PLUGINS}" = "" ] && __filter_items_exists "plugin"



		# generate compose env files
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __create_env_for_docker_compose

		# fill VARIABLES_LIST declared variables from all env files
		__init_declared_variable_names
		# add variables and array list itself
		__add_declared_variables "VARIABLES_LIST"
		__add_declared_variables "ASSOCIATIVE_ARRAY_LIST"
		# add to VARIABLES_LIST declared variables from modules env files
		__add_modules_declared_variable_names

		

		# STEP 2 ------ process command line and shell env variables


		
		if [ "${DEBUG}" = "1" ]; then
			VERBOSE="1"
			TANGO_LOG_STATE="ON"
			TANGO_LOG_LEVEL="DEBUG"
		fi
		[ "${TANGO_USER_ID}" = "" ] && [ ! "${PUID}" = "" ] && TANGO_USER_ID="${PUID}"
		[ "${TANGO_GROUP_ID}" = "" ] && [ ! "${PGID}" = "" ] && TANGO_GROUP_ID="${PGID}"
		[ "${TANGO_DOMAIN}" = "" ] && [ ! "${DOMAIN}" = "" ] && TANGO_DOMAIN="${DOMAIN}"


		TANGO_FREEPORT_MODE="0"
		if [ "${FREEPORT}" = "1" ]; then
			TANGO_FREEPORT_MODE="1"
			case ${ACTION} in
				up|restart ) __pick_free_port ;;
				* ) # read previous reserved freeport from env file
					[ -f "${GENERATED_ENV_FILE_FREEPORT}" ] && . "${GENERATED_ENV_FILE_FREEPORT}"
					;;
			esac
		fi

		# add variables created at runtime or computed from command line
		__add_declared_variables "DEBUG"
		__add_declared_variables "VERBOSE"
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

		__add_declared_variables "TANGO_MODULES_AVAILABLE"
		__add_declared_variables "TANGO_MODULES_ROOT"
		__add_declared_variables "TANGO_APP_MODULES_AVAILABLE"
		__add_declared_variables "TANGO_APP_MODULES_ROOT"

		__add_declared_variables "TANGO_PLUGINS_AVAILABLE"
		__add_declared_variables "TANGO_PLUGINS_ROOT"
		__add_declared_variables "TANGO_APP_PLUGINS_AVAILABLE"
		__add_declared_variables "TANGO_APP_PLUGINS_ROOT"

		__add_declared_variables "TANGO_SCRIPTS_AVAILABLE"
		__add_declared_variables "TANGO_SCRIPTS_ROOT"
		__add_declared_variables "TANGO_APP_SCRIPTS_AVAILABLE"
		__add_declared_variables "TANGO_APP_SCRIPTS_ROOT"

		__add_declared_variables "GENERATED_ENV_FILE_FOR_COMPOSE"
		__add_declared_variables "GENERATED_ENV_FILE_FREEPORT"
		__add_declared_variables "TANGO_NOT_IN_APP"

		__add_declared_variables "TANGO_SERVICES_MODULES"
		__add_declared_variables "TANGO_SERVICES_MODULES_FULL"
		__add_declared_variables "TANGO_PLUGINS"
		__add_declared_variables "TANGO_PLUGINS_FULL"


		__add_declared_variables "TANGO_FREEPORT_MODE"

		# update env var 
		# env var values priority order :
		# 	- new and computed variables at runtime
		#	- command line
		#	- shell env variables
		# 	- user env file
		# 	- modules env file
		# 	- app env file
		# 	- default tango env file
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __update_env_files "ingest with env variables from shell and command line"
		# load env var
		# even if files have not been modified, we want to load previously saved variables
		__load_env_vars
		



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
			
		# create a list of active services and modules
		TANGO_SERVICES_ACTIVE="$($STELLA_API filter_list_with_list "${TANGO_SERVICES_AVAILABLE}" "${TANGO_SERVICES_DISABLED}")"
		__add_declared_variables "TANGO_SERVICES_ACTIVE"

		# default hardcoded user
		[ "${TANGO_USER_ID}" = "" ] && TANGO_USER_ID="$(id -u)"
		[ "${TANGO_GROUP_ID}" = "" ] && TANGO_GROUP_ID="$(id -g)"
		
		# traefik rest api password
		[ "${TRAEFIK_API_USER}" = "" ] && TRAEFIK_API_USER="tango"
		[ "${TRAEFIK_API_PASSWORD}" = "" ] && TRAEFIK_API_PASSWORD="tango"
		#TRAEFIK_API_HASH_PASSWORD=$($STELLA_API htpasswd_md5 "${TRAEFIK_API_PASSWORD}" | tr -dc  "_A-Z-a-z-0-9" | fold -w8 | head -n1)
		TRAEFIK_API_HASH_PASSWORD="$($STELLA_API htpasswd_md5 "${TRAEFIK_API_PASSWORD}")"
		#TRAEFIK_API_HASH_PASSWORD="$($STELLA_API md5 "${TRAEFIK_API_PASSWORD}")"
		__add_declared_variables "TRAEFIK_API_HASH_PASSWORD"

		# change lets encrypt behaviour
		if [ "${DEBUG}" = "1" ]; then
			[ "${LETS_ENCRYPT}" = "enable" ] && LETS_ENCRYPT="debug"
		fi


		# PATH management -----
		
		# TANGO_PATH_LIST list of generic path variables
		#   						xxx_PATH =           		provided path
		#   						xxx_PATH_DEFAULT 	  =   	default path relative to app workspace folder (TANGO_APP_WORK_ROOT)
		#   						xxx_PATH_SUBPATH_LIST = 	list of subpath variables relative to path
		# 							xxx_PATH_SUBPATH_CREATE = 	instructions to create subpath relative to path (internal variable)
		
		# APP_DATA_PATH			 			path to store data relative to app
		# APP_DATA_PATH_DEFAULT 			default path relative to app workspace folder (TANGO_APP_WORK_ROOT)
		# APP_DATA_PATH_SUBPATH_LIST		list of subpath variables relative to app data
		# APP_DATA_PATH_SUBPATH_CREATE		instructions to create subpath relative to app data (internal variable)

		# TANGO_APP_WORK_ROOT_SUBPATH_CREATE 		instructions to create subpath relative to TANGO_APP_WORK_ROOT (which is an internal variable)
		TANGO_APP_WORK_ROOT_SUBPATH_CREATE=
		
		# TANGO_DATA_PATH 					path to store data relative to internal tango services - hardcoded according to TANGO_INSTANCE_MODE (internal variable)
		# TANGO_DATA_PATH_DEFAULT			N/A (hardcoced TANGO_DATA_PATH)
		# TANGO_DATA_PATH_SUBPATH_LIST		N/A (hardcoded TANGO_DATA_PATH_SUBPATH_CREATE)
		# TANGO_DATA_PATH_SUBPATH_CREATE 	instructions to create subpath relative to tango data (internal variable) 
		TANGO_DATA_PATH_SUBPATH_CREATE=
		
		# manage generic path
		for p in ${TANGO_PATH_LIST}; do
			if [ "${!p}" = "" ]; then
				__default_path="${p}_DEFAULT"
				__path="${!__default_path}"
				# export this path will update its value inside env files
				eval "export ${p}=\"${TANGO_APP_WORK_ROOT}/${__path}\""
				TANGO_APP_WORK_ROOT_SUBPATH_CREATE="${TANGO_APP_WORK_ROOT_SUBPATH} FOLDER ${__path}"
			fi
			
			# manage subpath list
			__subpath_list="${p}_SUBPATH_LIST"
			if [ ! "${__subpath_list}" = "" ]; then
				__create_path_instructions=
				for s in ${!__subpath_list}; do
					if [ ! "${!s}" = "" ]; then
						# create subpath instruction to create subpath later in create_path_all
						__create_path_instructions="${__create_path_instructions} ${!s}"
						# export this path will update its value inside env files
						eval "export ${s}=\"${!p}/${!s}\""
					fi
				done
				# all subpath are FOLDER type
				eval "${p}_SUBPATH_CREATE=\"FOLDER ${__create_path_instructions}\""
			fi
		done

		# Tango instance mode
		case ${TANGO_INSTANCE_MODE} in
			shared )
				TANGO_INSTANCE_NAME="tango_shared"
				mkdir -p "${TANGO_WORK_ROOT}/tango_shared"
				TANGO_DATA_PATH="${TANGO_WORK_ROOT}/tango_shared"
				;;
			isolated )
				TANGO_INSTANCE_NAME="${TANGO_APP_NAME}"
				TANGO_DATA_PATH="${APP_DATA_PATH}"
				;;
		esac

		# hardocoded subpath relative to tango data
		TANGO_DATA_PATH_SUBPATH_CREATE="${TANGO_DATA_PATH_SUBPATH_CREATE} FOLDER letsencrypt traefikconfig FILE letsencrypt/acme.json traefikconfig/generated.${TANGO_APP_NAME}.tls.yml"
		TANGO_APP_NETWORK_NAME="${TANGO_INSTANCE_NAME}_default"
		GENERATED_TLS_FILE_PATH="${TANGO_DATA_PATH}/traefikconfig/generated.${TANGO_APP_NAME}.tls.yml"

		# path pointing where the tango cross-app data will be stored
		__add_declared_variables "TANGO_DATA_PATH"
		__add_declared_variables "TANGO_INSTANCE_NAME"
		#__add_declared_variables "TANGO_SHARED_DATA_PATH"
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
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __update_env_files "ingest default hardcoded values and runtime only variables"


		# STEP 4 ------ create/transform some values and create docker compose file
		
		# update path
		__translate_all_path
		# generate compose file (this also add some new variables to VARIABLES_LIST)
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __create_docker_compose_file
		
		# update env var 
		# env var values priority order :
		# 	- new and computed variables at runtime
		#	- shell env variables
		#	- command line
		# 	- user env file
		# 	- modules env file
		# 	- app env file
		# 	- default tango env file
		# 	- default values hardcoded and runtime computed
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __update_env_files "ingest created/modified/translated variables"
		# load env var
		# even if files have not been modified, we want to load previously saved variables
		__load_env_vars
	;;
esac