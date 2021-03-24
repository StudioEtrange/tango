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

		# modules -----
		# test if some modules are declared by command line and add them
		# so --module option is cumulative with TANGO_SERVICES_MODULES
		[ "${TANGO_SERVICES_MODULES}" = "" ] && tango_services_modules_env_var_empty=1
		if [ ! "${MODULE}" = "" ]; then
			TANGO_SERVICES_MODULES="${TANGO_SERVICES_MODULES} ${MODULE//:/ }"
		fi

		# generate bash env file
		# bash env files priority :
		# 	- user env file
		# 	- app env file
		# 	- default env file
		# if TANGO_SERVICES_MODULES exists as env var or --module option was used then modules env files are processed whith __create_env_for_bash call and the order is instead
		# 			- user env file
		# 			- modules env file
		# 			- app env file
		# 			- default env file
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __create_env_for_bash

		# if TANGO_SERVICES_MODULES exist in any env files but not as env var we need to recreate __create_env_for_bash 
		# because TANGO_SERVICES_MODULES value in env files was not used when we first call __create_env_for_bash
		if [ "${tango_services_modules_env_var_empty}" = "1" ]; then
			# reinit value of TANGO_SERVICES_MODULES with value from env files
			__tmp_services_modules="$(env -i bash --noprofile --norc -c ". ${GENERATED_ENV_FILE_FOR_BASH}; echo \$TANGO_SERVICES_MODULES")"
			# did we found any TANGO_SERVICES_MODULES value in any env files
			if [ ! "${__tmp_services_modules}" = "" ]; then
				rebuild_env_for_bash=1
				TANGO_SERVICES_MODULES="${__tmp_services_modules}"
				# dont forget to update TANGO_SERVICES_MODULES value with --module option
				if [ ! "${MODULE}" = "" ]; then
					TANGO_SERVICES_MODULES="${TANGO_SERVICES_MODULES} ${MODULE//:/ }"
				fi
			fi
		fi
		# some modules have been defined in one of env files but not as env var
		# so we need to rebuild bash env file
		# 			- user env file
		# 			- modules env file
		# 			- app env file
		# 			- default env file
		if [ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ]; then
			if [ "${rebuild_env_for_bash}" = "1" ]; then
				__create_env_for_bash
			fi
		fi

		# filter exising modules
		[ ! "${TANGO_SERVICES_MODULES}" = "" ] && __filter_items_exists "module"


		# plugins -----
		# retrieve TANGO_PLUGINS defined among all env files
		# but only if no shell env var exist because TANGO_PLUGINS declared as env var override any TANGO_PLUGINS declared in any env files
		if [ "${TANGO_PLUGINS}" = "" ]; then
			TANGO_PLUGINS="$(env -i bash --noprofile --norc -c ". ${GENERATED_ENV_FILE_FOR_BASH}; echo \$TANGO_PLUGINS")"
		fi
		# test if some plugins are declared by command line and add them
		# so --plugin option is cumulative with TANGO_PLUGINS
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
		
		# add default subservices
		TANGO_SUBSERVICES_ROUTER="${TANGO_SUBSERVICES_ROUTER_DEFAULT} ${TANGO_SUBSERVICES_ROUTER}"

		# add default network http redirect to https
		NETWORK_SERVICES_REDIRECT_HTTPS="${NETWORK_SERVICES_REDIRECT_HTTPS_DEFAULT} ${NETWORK_SERVICES_REDIRECT_HTTPS}"

		# add default lets encrypted services list
		LETS_ENCRYPT_SERVICES="${LETS_ENCRYPT_SERVICES_DEFAULT} ${LETS_ENCRYPT_SERVICES}"

		# add default to time lists
		TANGO_TIME_VOLUME_SERVICES="${TANGO_TIME_VOLUME_SERVICES_DEFAULT} ${TANGO_TIME_VOLUME_SERVICES}"
		TANGO_TIME_VAR_TZ_SERVICES="${TANGO_TIME_VAR_TZ_SERVICES_DEFAULT} ${TANGO_TIME_VAR_TZ_SERVICES}"

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
		__tango_log "DEBUG" "tango" "path management -- list of path to manage : TANGO_PATH_LIST=${TANGO_PATH_LIST}"

		for p in ${TANGO_PATH_LIST}; do
			__tango_log "DEBUG" "tango" "       -L manage $p"
			# if xxx_PATH not setted, will create TANGO_APP_WORK_ROOT/xxx_PATH_DEFAULT
			if [ "${!p}" = "" ]; then
				__default_path="${p}_DEFAULT"
				__path="${!__default_path}"
				__tango_log "DEBUG" "tango" "                -L $p not setted : will create folder ${p}_DEFAULT=$__path under TANGO_APP_WORK_ROOT=${TANGO_APP_WORK_ROOT}"
				# export this path will update its value inside env files
				eval "export ${p}=\"${TANGO_APP_WORK_ROOT}/${__path}\""
				TANGO_APP_WORK_ROOT_SUBPATH_CREATE="${TANGO_APP_WORK_ROOT_SUBPATH_CREATE} FOLDER ${__path}"
			fi

			# manage subpath lists
			__subpath_list="${p}_SUBPATH_LIST"
			__tango_log "DEBUG" "tango" "                -L manage subpath list of $p : ${__subpath_list}=${!__subpath_list}"
			if [ ! "${!__subpath_list}" = "" ]; then
				__create_path_instructions=
				for s in ${!__subpath_list}; do
					if [ ! "${!s}" = "" ]; then
						case ${!s} in
							/*)
								# absolute path but shoud be relative path
								# check if it is an absolute path which is relative to root
								if [ "$($STELLA_API is_logical_subpath "${!p}" "${!s}")" = "TRUE" ]; then
									__new_rel_path="$($STELLA_API abs_to_rel_path "${!s}" "${!p}")"
									# reconvert to a relative path 
									# NOTE : we need this because we have not updated generated files AND load its value 
									#		 then all relative path have been converted to absoluve values INSTEAD of being relative values
									eval "export ${s}=\"${__new_rel_path}\""
								fi
								# if not ignore this subpath creation
								__ignore="1"
							;;
						esac
						if [ ! "$__ignore" = "1" ]; then
							# create subpath instruction to create subpath later in create_path_all
							__create_path_instructions="${__create_path_instructions} ${!s}"
							# export this path will update its value inside env files
							eval "export ${s}=\"${!p}/${!s}\""
						fi
						__ignore=""
					fi
				done
				# all subpath are FOLDER type
				__tango_log "DEBUG" "tango" "                -L will create ${__create_path_instructions} as subpath of $p"
				eval "${p}_SUBPATH_CREATE=\"FOLDER ${__create_path_instructions}\""
			fi
		done

		# Tango instance mode
		case ${TANGO_INSTANCE_MODE} in
			shared )
				TANGO_INSTANCE_NAME="tango_shared"
				mkdir -p "${TANGO_WORK_ROOT}/tango_shared"
				TANGO_DATA_PATH="${TANGO_WORK_ROOT}/tango_shared"
				__tango_log "DEBUG" "tango" "Traefik is in shared mode between several app"
				__tango_log "DEBUG" "tango" "        L [TANGO_INSTANCE_NAME=$TANGO_INSTANCE_NAME]"
				__tango_log "DEBUG" "tango" "        L [TANGO_DATA_PATH=$TANGO_DATA_PATH]"
				__tango_log "DEBUG" "tango" "        L [APP_DATA_PATH=$APP_DATA_PATH]"
				;;
			isolated )
				TANGO_INSTANCE_NAME="${TANGO_APP_NAME}"
				TANGO_DATA_PATH="${APP_DATA_PATH}"
				__tango_log "DEBUG" "tango" "This traefik instance is dedicated to current app ${TANGO_APP_NAME}, so TANGO_DATA_PATH=APP_DATA_PATH"
				__tango_log "DEBUG" "tango" "        L [TANGO_INSTANCE_NAME=$TANGO_INSTANCE_NAME]"
				__tango_log "DEBUG" "tango" "        L [TANGO_DATA_PATH=$TANGO_DATA_PATH]"
				__tango_log "DEBUG" "tango" "        L [APP_DATA_PATH=$APP_DATA_PATH]"
				;;
		esac

		TANGO_APP_NETWORK_NAME="${TANGO_INSTANCE_NAME}_default"
		__tango_log "DEBUG" "tango" "        L [TANGO_APP_NETWORK_NAME=$TANGO_APP_NETWORK_NAME]"

		# hardcoded subpath relative to tango data path
		LETS_ENCRYPT_DATA_PATH="${TANGO_DATA_PATH}/letsencrypt"
		TRAEFIK_CONFIG_DATA_PATH="${TANGO_DATA_PATH}/traefikconfig"
		TANGO_DATA_PATH_SUBPATH_CREATE="${TANGO_DATA_PATH_SUBPATH_CREATE} FOLDER letsencrypt traefikconfig FILE letsencrypt/acme.json traefikconfig/generated.${TANGO_APP_NAME}.tls.yml"
		GENERATED_TLS_FILE_PATH="${TANGO_DATA_PATH}/traefikconfig/generated.${TANGO_APP_NAME}.tls.yml"
		
		PLUGINS_DATA_PATH="${APP_DATA_PATH}/plugins"
		__tango_log "DEBUG" "tango" "        L [PLUGINS_DATA_PATH=$PLUGINS_DATA_PATH]"
		APP_DATA_PATH_SUBPATH_CREATE="${APP_DATA_PATH_SUBPATH_CREATE} FOLDER plugins"
		__tango_log "DEBUG" "tango" "Add hardcoded paths instructions to create letsencrypt, traefik config and plugins data folders"
		__tango_log "DEBUG" "tango" "        L TANGO_DATA_PATH_SUBPATH_CREATE=$TANGO_DATA_PATH_SUBPATH_CREATE"
		__tango_log "DEBUG" "tango" "        L APP_DATA_PATH_SUBPATH_CREATE=$APP_DATA_PATH_SUBPATH_CREATE"

		# path pointing where the tango cross-app data will be stored
		__add_declared_variables "TANGO_DATA_PATH"
		__add_declared_variables "TANGO_INSTANCE_NAME"
		__add_declared_variables "GENERATED_TLS_FILE_PATH"
		__add_declared_variables "TANGO_APP_NETWORK_NAME"
		__add_declared_variables "PLUGINS_DATA_PATH"
		__add_declared_variables "LETS_ENCRYPT_DATA_PATH"
		__add_declared_variables "TRAEFIK_CONFIG_DATA_PATH"


		
		export TANGO_HOST_IP="${STELLA_HOST_IP}"
		__add_declared_variables "TANGO_HOST_IP"
		export TANGO_HOST_DEFAULT_IP="${STELLA_HOST_DEFAULT_IP}"
		__add_declared_variables "TANGO_HOST_DEFAULT_IP"
		TANGO_HOSTNAME="$(hostname)"
		__add_declared_variables "TANGO_HOSTNAME"
		if [ "${NETWORK_INTERNET_EXPOSED}" = "1" ]; then
			# TODO CATCH HTTP ERROR like 502
			TANGO_EXTERNAL_IP="$(curl -s ipinfo.io/ip)"
		else
			TANGO_EXTERNAL_IP=
		fi
		__add_declared_variables "TANGO_EXTERNAL_IP"



		case ${ACTION} in
			info|up|restart )
				if [ "${NETWORK_INTERNET_EXPOSED}" = "1" ]; then

					for area in ${NETWORK_SERVICES_AREA_LIST}; do
						IFS="|" read -r name proto internal_port secure_port <<<$(echo ${area})
						v1="NETWORK_PORT_${name^^}"
						[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${!v1}")" = "TRUE" ] && eval NETWORK_PORT_${name^^}_REACHABLE=1
						__add_declared_variables "NETWORK_PORT_${name^^}_REACHABLE"
						if [ ! "$secure_port" = "" ]; then
							v2="NETWORK_PORT_${name^^}_SECURE"
							[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${!v1}")" = "TRUE" ] && eval NETWORK_PORT_${name^^}_SECURE_REACHABLE=1
							__add_declared_variables "NETWORK_PORT_${name^^}_SECURE_REACHABLE"
						fi
						#[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_MAIN}")" = "TRUE" ] && NETWORK_PORT_MAIN_REACHABLE=1
						#__add_declared_variables "NETWORK_PORT_MAIN_REACHABLE"
						# [ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_MAIN_SECURE}")" = "TRUE" ] && NETWORK_PORT_MAIN_SECURE_REACHABLE=1
						# __add_declared_variables "NETWORK_PORT_MAIN_SECURE_REACHABLE"
						# [ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_SECONDARY}")" = "TRUE" ] && NETWORK_PORT_SECONDARY_REACHABLE=1
						# __add_declared_variables "NETWORK_PORT_SECONDARY_REACHABLE"
						# [ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_SECONDARY_SECURE}")" = "TRUE" ] && NETWORK_PORT_SECONDARY_SECURE_REACHABLE=1
						# __add_declared_variables "NETWORK_PORT_SECONDARY_SECURE_REACHABLE"
						# [ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_ADMIN}")" = "TRUE" ] && NETWORK_PORT_ADMIN_REACHABLE=1
						# __add_declared_variables "NETWORK_PORT_ADMIN_REACHABLE"
						# [ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${NETWORK_PORT_ADMIN_SECURE}")" = "TRUE" ] && NETWORK_PORT_ADMIN_SECURE_REACHABLE=1
						# __add_declared_variables "NETWORK_PORT_ADMIN_SECURE_REACHABLE"

					done
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
		# but preserving DEBUG flag
		__load_env_vars
	;;
esac