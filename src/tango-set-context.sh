#!/bin/bash

if [ "${ACTION}" = "info" ]; then
	TANGO_LOG_STATE="ON"
	TANGO_LOG_LEVEL="WARN"
fi


if [ "${DEBUG}" = "1" ]; then
	TANGO_LOG_STATE="ON"
	TANGO_LOG_LEVEL="DEBUG"
fi

# TANGO CTX
TANGO_NOT_IN_ANY_CTX=
[ "${TANGO_CTX_NAME}" = "" ] && TANGO_CTX_NAME="${CTX}" || TANGO_CTX_NAME="${TANGO_CTX_NAME}"
[ "${TANGO_CTX_NAME}" = "" ] && TANGO_CTX_NAME="tango" && TANGO_NOT_IN_ANY_CTX=1
TANGO_CTX_NAME_CAPS="${TANGO_CTX_NAME^^}"

[ "${CTXROOT}" = "" ] && TANGO_CTX_ROOT="${TANGO_ROOT}" || TANGO_CTX_ROOT="${CTXROOT}"
TANGO_CTX_ROOT="$($STELLA_API rel_to_abs_path "${TANGO_CTX_ROOT}" "${TANGO_CURRENT_RUNNING_DIR}")"

[ "${TANGO_CTX_COMPOSE_FILE}" = "" ] && TANGO_CTX_COMPOSE_FILE="${TANGO_CTX_ROOT}/${TANGO_CTX_NAME}.docker-compose.yml"
TANGO_CTX_ENV_FILE="${TANGO_CTX_ROOT}/${TANGO_CTX_NAME}.env"
TANGO_CTX_COMPOSE_FILE="${TANGO_CTX_ROOT}/${TANGO_CTX_NAME}.docker-compose.yml"
TANGO_CTX_MODULES_ROOT="${TANGO_CTX_ROOT}/pool/modules"
TANGO_CTX_PLUGINS_ROOT="${TANGO_CTX_ROOT}/pool/plugins"
#TANGO_CTX_SCRIPTS_ROOT="${TANGO_CTX_ROOT}/pool/scripts"


# workspace folder
TANGO_WORK_ROOT="${TANGO_ROOT}/workspace"
mkdir -p "${TANGO_WORK_ROOT}"
TANGO_CTX_WORK_ROOT="${TANGO_CTX_ROOT}/workspace/${TANGO_CTX_NAME}"
mkdir -p "${TANGO_CTX_WORK_ROOT}"


# available modules from tango
TANGO_MODULES_AVAILABLE="$(__list_items "module" "tango")"
# available plugins from tango
TANGO_PLUGINS_AVAILABLE="$(__list_items "plugin" "tango")"
# available scripts from tango
#TANGO_SCRIPTS_AVAILABLE="$(__list_items "script" "tango")"
if [ "${TANGO_NOT_IN_ANY_CTX}" = "1" ]; then
	TANGO_CTX_ENV_FILE=
	TANGO_CTX_COMPOSE_FILE=
	TANGO_CTX_MODULES_ROOT=
	TANGO_CTX_MODULES_AVAILABLE=
	TANGO_CTX_PLUGINS_ROOT=
	TANGO_CTX_PLUGINS_AVAILABLE=
	TANGO_CTX_SCRIPTS_ROOT=
	TANGO_CTX_SCRIPTS_AVAILABLE=
else
	# available modules from current ctx
	TANGO_CTX_MODULES_AVAILABLE="$(__list_items "module" "ctx")"
	# available plugins from current ctx
	TANGO_CTX_PLUGINS_AVAILABLE="$(__list_items "plugin" "ctx")"
	# available scripts from current ctx
	#TANGO_CTX_SCRIPTS_AVAILABLE="$(__list_items "script" "ctx")"
fi

# TANGO USER FILES 
[ ! "${COMPOSE}" = "" ] && TANGO_USER_COMPOSE_FILE="$($STELLA_API rel_to_abs_path "${COMPOSE}" "${TANGO_CURRENT_RUNNING_DIR}")"
[ ! "${ENV}" = "" ] && TANGO_USER_ENV_FILE="$($STELLA_API rel_to_abs_path "${ENV}" "${TANGO_CURRENT_RUNNING_DIR}")"

# GENERATED FILES
GENERATED_DOCKER_COMPOSE_FILE="${TANGO_CTX_ROOT}/generated.${TANGO_CTX_NAME}.docker-compose.yml"
GENERATED_ENV_FILE_FOR_BASH="${TANGO_CTX_ROOT}/generated.${TANGO_CTX_NAME}.bash.env"
GENERATED_ENV_FILE_FOR_COMPOSE="${TANGO_CTX_ROOT}/generated.${TANGO_CTX_NAME}.compose.env"
GENERATED_ENV_FILE_FREEPORT="${TANGO_CTX_ROOT}/generated.${TANGO_CTX_NAME}.freeport.env"

# follow option
[ "${FOLLOW}" = 1 ] && FOLLOW="-f " || FOLLOW=

# load ctx libs
for f in ${TANGO_CTX_ROOT}/pool/libs/*; do
	[ -f "${f}" ] && . ${f}
done

case ${ACTION} in

	install|vendor )
		export TANGO_ALTER_GENERATED_FILES="OFF"
		;;

	* )
		type docker-compose 1>/dev/null 2>&1 || {
			echo "** ERROR : please install tango first with ./tango install command"
			exit 1
		}


		# NOTE on env variables
		# 	VARIABLES_LIST store all declared variables in env files AND added variables at runtime
		#					these variables are updated inside env files
		#					it is not needed to export these variables
		
		# order priority at the end will be :
		# 	- new and computed variables at runtime
		#	- shell env variables
		#	- command line
		# 	- user env file
		# 	- modules env file
		# 	- ctx env file
		# 	- default tango env file
		# 	- default values hardcoded and runtume computed
		



		# STEP 1 ------ init modules, plugins and create first env files
		# fill VARIABLES_LIST declared variables from all env files
		__init_declared_variable_names
		# add variables and array list itself
		__add_declared_variables "VARIABLES_LIST"
		__add_declared_variables "ASSOCIATIVE_ARRAY_LIST"

		
		__check_modules_definition

		# create bash env file using only user, ctx and default files
		# bash env files priority :
		# 	- user env file
		# 	- ctx env file
		# 	- default env file
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __create_env_files "bash" "default ctx user"

		# modules -----
		# extract declared services modules from user, ctx and default env files
		# only if no shell environement variable TANGO_SERVICES_MODULES was defined
		# 	take value from TANGO_SERVICES_MODULES_ORIGINAL_VAR which contains non scaled TANGO_SERVICES_MODULES original values (without command line values) from a previous launch (usefull when TANGO_ALTER_GENERATED_FILES is OFF)
		#   OR from TANGO_SERVICES_MODULES
		if [ "${TANGO_SERVICES_MODULES}" = "" ]; then
			# read value from TANGO_SERVICES_MODULES_ORIGINAL_VAR
			TANGO_SERVICES_MODULES="$(env -i bash --noprofile --norc -c ". ${GENERATED_ENV_FILE_FOR_BASH}; [ \"\$TANGO_SERVICES_MODULES_ORIGINAL_VAR\" = \"\" ] && echo \$TANGO_SERVICES_MODULES || echo \$TANGO_SERVICES_MODULES_ORIGINAL_VAR")"
		else
			# store original TANGO_SERVICES_MODULES shell environment variable
			TANGO_SERVICES_MODULES_ORIGINAL_VAR="${TANGO_SERVICES_MODULES}"
		fi

		# cumulate modules declared by --module AND variable TANGO_SERVICES_MODULES into TANGO_SERVICES_MODULES
		# at this point TANGO_SERVICES_MODULES can come from external shell environment variable OR user, ctx or default env files
		# --module option is cumulative with TANGO_SERVICES_MODULES but if a module is declared through both, command line declaration override the other
		if [ ! "${MODULE}" = "" ]; then
			__add_item_declaration_from_cmdline "module"
		fi
		






		# get modules dependencies information 

		# we need to extract modules dependencies declared with _MODULE_DEPENDENCIES from shell, user, ctx, and default environment variables :
		# first, we save modules dependencies list from shell environment variables
		__save_modules_links_shell_env_var="$(declare -p | grep _MODULE_DEPENDENCIES=)"
		# second, we need to extract modules dependencies declared with _MODULE_DEPENDENCIES variables
		#  from 
		# 			- user env file
		# 			- ctx env file
		# 			- default env file
		eval "$(env -i bash --noprofile --norc -c ". ${GENERATED_ENV_FILE_FOR_BASH}; declare -p | grep _MODULE_DEPENDENCIES=")"
		# third, we erase values with values from shell environment variables
		eval "${__save_modules_links_shell_env_var}"


		# load all modules dependencies declared with .deps files
		__load_modules_dependencies

			


		
		# get scaling information of modules 

		# we need to extract modules instances names list from shell, user, ctx and default environment variables
		# before __parse_and_scale_modules_declaration for eventually scaled modules to come

		# first, we save modules instances list from shell environment variables
		__save_instances_list_shell_env_var="$(declare -p | grep _INSTANCES_NAMES=)"
		# second, we extract modules instances list names from
		# 			- user env file
		# 			- ctx env file
		# 			- default env file
		eval "$(env -i bash --noprofile --norc -c ". ${GENERATED_ENV_FILE_FOR_BASH}; declare -p | grep _INSTANCES_NAMES=")"
		# third, we erase values with value from shell environment variables
		eval "${__save_instances_list_shell_env_var}"


		# parse and scale module list
		__parse_and_scale_modules_declaration

		# process all module dependencies 
		__process_modules_dependencies


		if [ ! "$TANGO_SERVICES_MODULES" = "" ]; then
			# take care of modules env files by recreating bash env file using user, ctx, modules and default files after having scaled modules and processed modules dependencies
			# bash env files priority :
			# 			- user env file
			# 			- modules env file
			# 			- ctx env file
			# 			- default env file
			[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __create_env_files "bash" "default ctx modules user"		
		fi












		# plugins -----
		# retrieve TANGO_PLUGINS defined among all env files
		# but only if no shell environment variable exist because TANGO_PLUGINS declared as shell environment variable override any TANGO_PLUGINS declared in any env files
		if [ "${TANGO_PLUGINS}" = "" ]; then
			TANGO_PLUGINS="$(env -i bash --noprofile --norc -c ". ${GENERATED_ENV_FILE_FOR_BASH}; echo \$TANGO_PLUGINS")"
		fi
		# test if some plugins are declared by command line and add them
		# so --plugin option is cumulative with TANGO_PLUGINS
		# but if a plugin is declared through both, command line declaration override the other
		if [ ! "${PLUGIN}" = "" ]; then
			__add_item_declaration_from_cmdline "plugin"
		fi
		# check plugins exist and build list and map
		[ ! "${TANGO_PLUGINS}" = "" ] && __parse_plugins_declaration
		


	
		# ports ------
		# test if some ports are declared by command line
		# parse for each network area if a value is setted
		# --port option override NETWORK_PORT_area_name variable and shell environment variable
		if [ ! "${PORT}" = "" ]; then
			PORT="${PORT//:/ }"
			for p in ${PORT}; do
				__parse_item "port" "${p}" "_port"
				__net_area_port="NETWORK_PORT_${_port_NAME^^}"
				if [ ! "${_port_PORT}" = "" ]; then
					eval ${__net_area_port}="${_port_PORT}"
					__add_declared_variables "${__net_area_port}"
				fi
				__net_area_port_secure="NETWORK_PORT_${_port_NAME^^}_SECURE"
				if [ ! "${_port_SECURE_PORT}" = "" ]; then
					eval ${__net_area_port_secure}="${_port_SECURE_PORT}"
					__add_declared_variables "${__net_area_port_secure}"
				fi
			done
		fi




		# ----
		# generate compose env files
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __create_env_files "docker_compose"

		# add to VARIABLES_LIST all variables cumulated from default, ctx, modules and user env file
		__extract_declared_variable_names "${GENERATED_ENV_FILE_FOR_COMPOSE}"
		

		

		# STEP 2 ------ process command line and shell environment variables


		[ "${TANGO_USER_ID}" = "" ] && [ ! "${PUID}" = "" ] && TANGO_USER_ID="${PUID}"
		[ "${TANGO_GROUP_ID}" = "" ] && [ ! "${PGID}" = "" ] && TANGO_GROUP_ID="${PGID}"
		[ "${TANGO_DOMAIN}" = "" ] && [ ! "${DOMAIN}" = "" ] && TANGO_DOMAIN="${DOMAIN}"

		# process picking free port
		__add_declared_variables "TANGO_FREEPORT"
		if [ ! "${TANGO_FREEPORT}" = "1" ]; then
			TANGO_FREEPORT=
			if [ "${FREEPORT}" = "1" ]; then
				TANGO_FREEPORT="1"
			fi
		fi
		
		# add variables created at runtime or computed from command line
		__add_declared_variables "DEBUG"
		
		__add_declared_variables "TANGO_CTX_NAME"
		__add_declared_variables "TANGO_CTX_NAME_CAPS"

		__add_declared_variables "TANGO_ROOT"
		__add_declared_variables "TANGO_CTX_ROOT"
		__add_declared_variables "TANGO_CTX_WORK_ROOT"
		__add_declared_variables "WORKING_DIR"
		
		__add_declared_variables "TANGO_ENV_FILE"
		__add_declared_variables "TANGO_CTX_ENV_FILE"
		__add_declared_variables "TANGO_USER_ENV_FILE"
		__add_declared_variables "TANGO_COMPOSE_FILE"
		__add_declared_variables "TANGO_CTX_COMPOSE_FILE"
		__add_declared_variables "TANGO_USER_COMPOSE_FILE"

		__add_declared_variables "TANGO_MODULES_AVAILABLE"
		__add_declared_variables "TANGO_MODULES_ROOT"
		__add_declared_variables "TANGO_CTX_MODULES_AVAILABLE"
		__add_declared_variables "TANGO_CTX_MODULES_ROOT"

		__add_declared_variables "TANGO_PLUGINS_AVAILABLE"
		__add_declared_variables "TANGO_PLUGINS_ROOT"
		__add_declared_variables "TANGO_CTX_PLUGINS_AVAILABLE"
		__add_declared_variables "TANGO_CTX_PLUGINS_ROOT"

		__add_declared_variables "TANGO_SCRIPTS_AVAILABLE"
		__add_declared_variables "TANGO_SCRIPTS_ROOT"
		__add_declared_variables "TANGO_CTX_SCRIPTS_AVAILABLE"
		__add_declared_variables "TANGO_CTX_SCRIPTS_ROOT"

		__add_declared_variables "GENERATED_ENV_FILE_FOR_COMPOSE"
		__add_declared_variables "GENERATED_ENV_FILE_FREEPORT"
		__add_declared_variables "TANGO_NOT_IN_ANY_CTX"

		# contains list of modules instances names (including scaled modules)
		__add_declared_variables "TANGO_SERVICES_MODULES"
		# contains list of modules in full definition format
		__add_declared_variables "TANGO_SERVICES_MODULES_FULL"
		# contains list of modules names which are linked dependencies
		__add_declared_variables "TANGO_SERVICES_MODULES_LINKED"
		# contains list of modules names which have been scaled to a number of instances >1
		__add_declared_variables "TANGO_SERVICES_MODULES_SCALED"
		# contains original TANGO_SERVICES_MODULES variable from environment files (not from command line)
		__add_declared_variables "TANGO_SERVICES_MODULES_ORIGINAL_VAR"
		__add_declared_variables "TANGO_PLUGINS"
		__add_declared_variables "TANGO_PLUGINS_FULL"


		# add all variables beginning with ACME_VAR_
		for var in $(compgen -A variable | grep ^ACME_VAR_); do
			__add_declared_variables "${var}"
		done
		
		# update env var 
		# __update_env_files will update all values using current shell environment variables and values from command line
		# env var values priority order will be:
		#	- shell env variables
		#	- command line
		# 	- user env file
		# 	- modules env file
		# 	- ctx env file
		# 	- default tango env file
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __update_env_files "ingest with env variables from shell and command line"
		# load env var
		# even if files have not been modified, we want to load previously saved variables
		__load_env_vars


		# STEP 3 ------ process hardcoded default values, and computed runtime variable not fixed with command line nor shell env var nor env files

		# so priority here will become :
		# 	- computed new variables at runtime
		#	- shell env variables
		#	- command line
		# 	- user env file
		# 	- modules env file
		# 	- ctx env file
		# 	- default tango env file
		# 	- hardcoded and runtime computed default values


		

		# add default services and active modules services to all available service list
		TANGO_SERVICES_AVAILABLE="$($STELLA_API list_filter_duplicate "${TANGO_SERVICES_DEFAULT} ${TANGO_SERVICES_AVAILABLE} ${TANGO_SERVICES_MODULES}")"
		# add default subservices
		TANGO_SUBSERVICES_ROUTER="$($STELLA_API list_filter_duplicate "${TANGO_SUBSERVICES_ROUTER_DEFAULT} ${TANGO_SUBSERVICES_ROUTER}")"
		# add default network http redirect to https
		NETWORK_SERVICES_REDIRECT_HTTPS="$($STELLA_API list_filter_duplicate "${NETWORK_SERVICES_REDIRECT_HTTPS_DEFAULT} ${NETWORK_SERVICES_REDIRECT_HTTPS}")"

		# add default lets encrypted services list
		LETS_ENCRYPT_SERVICES="$($STELLA_API list_filter_duplicate "${LETS_ENCRYPT_SERVICES_DEFAULT} ${LETS_ENCRYPT_SERVICES}")"

		# add default to time lists
		TANGO_TIME_VOLUME_SERVICES="$($STELLA_API list_filter_duplicate "${TANGO_TIME_VOLUME_SERVICES_DEFAULT} ${TANGO_TIME_VOLUME_SERVICES}")"
		TANGO_TIME_VAR_TZ_SERVICES="$($STELLA_API list_filter_duplicate "${TANGO_TIME_VAR_TZ_SERVICES_DEFAULT} ${TANGO_TIME_VAR_TZ_SERVICES}")"

		# create a list of active services and modules
		TANGO_SERVICES_ACTIVE="$($STELLA_API filter_list_with_list "${TANGO_SERVICES_AVAILABLE}" "${TANGO_SERVICES_DISABLED}")"
		__add_declared_variables "TANGO_SERVICES_ACTIVE"

		# create a list of active subservices (which parent are services or modules)
		TANGO_SUBSERVICES_ROUTER_ACTIVE=
		for s in $TANGO_SUBSERVICES_ROUTER; do
			__parent="$(__get_subservice_parent "${s}")"
			[ "${__parent}" = "" ] && __parent="${s}"
			if $STELLA_API list_contains "$TANGO_SERVICES_ACTIVE" "$__parent"; then
				TANGO_SUBSERVICES_ROUTER_ACTIVE="$TANGO_SUBSERVICES_ROUTER_ACTIVE $s"
			fi
		done
		__add_declared_variables "TANGO_SUBSERVICES_ROUTER_ACTIVE"

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

		# manage subdomain suffix
		if [ "${TANGO_SUBDOMAIN_SUFFIX}" = "" ]; then
			case ${TANGO_SUBDOMAIN_SUFFIX_MODE} in
				hash)
					TANGO_SUBDOMAIN_SUFFIX="$($STELLA_API generate_machine_id "tango" | fold -w20 | head -n1)"
				;;
				random)
					TANGO_SUBDOMAIN_SUFFIX="$($STELLA_API generate_password 8 "[:alnum:]")"
				;;
			esac
		fi

		# letsencrypt and ACME management -----
		# change lets encrypt behaviour
		if [ "${DEBUG}" = "1" ]; then
			[ "${LETS_ENCRYPT}" = "enable" ] && LETS_ENCRYPT="debug"
		fi

		# create and set variable value without ACME_ at the beginning of the name
		# to match variable name list from https://doc.traefik.io/traefik/https/acme/
		for var in $(compgen -A variable | grep ^ACME_VAR_); do
			__add_declared_variables "${var/ACME_VAR_}"
			eval "export ${var/ACME_VAR_}=\"${!var}\""
		done



		# PATH management -----
		
		# TANGO_PATH_LIST list of generic path variables

		# CTX_DATA_PATH			 			path to store data relative to ctx
		# CTX_DATA_PATH_DEFAULT 			default path relative to ctx workspace folder (TANGO_CTX_WORK_ROOT)
		# CTX_DATA_PATH_SUBPATH_LIST		list of subpath variables relative to ctx data
		# CTX_DATA_PATH_SUBPATH_CREATE		instructions to create subpath relative to ctx data (internal variable)

		# TANGO_CTX_WORK_ROOT_SUBPATH_CREATE 		instructions to create subpath relative to TANGO_CTX_WORK_ROOT (which is an internal variable)
		TANGO_CTX_WORK_ROOT_SUBPATH_CREATE=
		
		# TANGO_DATA_PATH 					path to store data relative to internal tango services - hardcoded according to TANGO_INSTANCE_MODE (internal variable)
		# TANGO_DATA_PATH_DEFAULT			N/A (hardcoced TANGO_DATA_PATH)
		# TANGO_DATA_PATH_SUBPATH_LIST		N/A (hardcoded TANGO_DATA_PATH_SUBPATH_CREATE)
		# TANGO_DATA_PATH_SUBPATH_CREATE 	instructions to create subpath relative to tango data (internal variable) 
		TANGO_DATA_PATH_SUBPATH_CREATE=

		# manage generic path
		# add CTX_DATA_PATH variable name to TANGO_PATH_LIST
		TANGO_PATH_LIST="CTX_DATA_PATH ${TANGO_PATH_LIST}"
		TANGO_PATH_LIST="$($STELLA_API list_filter_duplicate "${TANGO_PATH_LIST}")"

		__tango_log "DEBUG" "tango" "path management -- list of path variables to manage : ${TANGO_PATH_LIST} (defined by TANGO_PATH_LIST)"
		for p in $TANGO_PATH_LIST; do
			__manage_path "$p" "TANGO_CTX_WORK_ROOT"
		done

		# Tango instance mode
		case ${TANGO_INSTANCE_MODE} in
			shared )
				TANGO_INSTANCE_NAME="tango_shared"
				mkdir -p "${TANGO_WORK_ROOT}/tango_shared"
				TANGO_DATA_PATH="${TANGO_WORK_ROOT}/tango_shared"
				__tango_log "DEBUG" "tango" "SHARED TRAEFIK : Traefik is in shared mode between several tango context"
				__tango_log "DEBUG" "tango" "    L [TANGO_INSTANCE_NAME=$TANGO_INSTANCE_NAME]"
				__tango_log "DEBUG" "tango" "    L [TANGO_DATA_PATH=$TANGO_DATA_PATH]"
				__tango_log "DEBUG" "tango" "    L [CTX_DATA_PATH=$CTX_DATA_PATH]"
				;;
			isolated )
				TANGO_INSTANCE_NAME="${TANGO_CTX_NAME}"
				TANGO_DATA_PATH="${CTX_DATA_PATH}"
				__tango_log "DEBUG" "tango" "ISOLATED TRAEFIK : This traefik instance is dedicated to current context ${TANGO_CTX_NAME}, so TANGO_DATA_PATH=CTX_DATA_PATH"
				__tango_log "DEBUG" "tango" "    L [TANGO_INSTANCE_NAME=$TANGO_INSTANCE_NAME]"
				__tango_log "DEBUG" "tango" "    L [TANGO_DATA_PATH=$TANGO_DATA_PATH]"
				__tango_log "DEBUG" "tango" "    L [CTX_DATA_PATH=$CTX_DATA_PATH]"
				;;
		esac

		TANGO_CTX_NETWORK_NAME="${TANGO_INSTANCE_NAME}_default"
		__tango_log "DEBUG" "tango" "    L [TANGO_CTX_NETWORK_NAME=$TANGO_CTX_NETWORK_NAME]"

		# hardcoded subpath relative to tango data path
		LETS_ENCRYPT_DATA_PATH="${TANGO_DATA_PATH}/letsencrypt"
		LETS_ENCRYPT_TEST_DATA_PATH="${TANGO_DATA_PATH}/letsencrypt-test"
		TRAEFIK_CONFIG_DATA_PATH="${TANGO_DATA_PATH}/traefikconfig"
		TANGO_DATA_PATH_SUBPATH_CREATE="${TANGO_DATA_PATH_SUBPATH_CREATE} FOLDER letsencrypt letsencrypt-test traefikconfig FILE letsencrypt/acme.json traefikconfig/generated.${TANGO_CTX_NAME}.tls.yml"
		GENERATED_TLS_FILE_PATH="${TANGO_DATA_PATH}/traefikconfig/generated.${TANGO_CTX_NAME}.tls.yml"
		
		PLUGINS_DATA_PATH="${CTX_DATA_PATH}/plugins"
		__tango_log "DEBUG" "tango" "    L [PLUGINS_DATA_PATH=$PLUGINS_DATA_PATH]"
		CTX_DATA_PATH_SUBPATH_CREATE="${CTX_DATA_PATH_SUBPATH_CREATE} FOLDER plugins"
		__tango_log "DEBUG" "tango" "ADD hardcoded paths instructions to create letsencrypt, traefik config and plugins data folders"
		__tango_log "DEBUG" "tango" "    L TANGO_DATA_PATH_SUBPATH_CREATE=$TANGO_DATA_PATH_SUBPATH_CREATE"
		__tango_log "DEBUG" "tango" "    L CTX_DATA_PATH_SUBPATH_CREATE=$CTX_DATA_PATH_SUBPATH_CREATE"


		# check and turn to absolute path some path variable
		__translate_path

		# path pointing where the tango cross-ctx data will be stored
		__add_declared_variables "TANGO_DATA_PATH"
		__add_declared_variables "TANGO_INSTANCE_NAME"
		__add_declared_variables "GENERATED_TLS_FILE_PATH"
		__add_declared_variables "TANGO_CTX_NETWORK_NAME"
		__add_declared_variables "PLUGINS_DATA_PATH"
		__add_declared_variables "LETS_ENCRYPT_DATA_PATH"
		__add_declared_variables "LETS_ENCRYPT_TEST_DATA_PATH"
		__add_declared_variables "TRAEFIK_CONFIG_DATA_PATH"


		# NETWORK ---------


		export TANGO_HOST_IP="${STELLA_HOST_IP}"
		__add_declared_variables "TANGO_HOST_IP"
		export TANGO_HOST_DEFAULT_IP="${STELLA_HOST_DEFAULT_IP}"
		__add_declared_variables "TANGO_HOST_DEFAULT_IP"
		TANGO_HOSTNAME="$(hostname)"
		__add_declared_variables "TANGO_HOSTNAME"
		if [ "${NETWORK_INTERNET_EXPOSED}" = "1" ]; then
			TANGO_EXTERNAL_IP="$(__tango_curl --connect-timeout 2 -skL ipinfo.io/ip)"
			__tango_log "INFO" "tango" "Declared being exposed on internet, external IP detected : $TANGO_EXTERNAL_IP"
		else
			__tango_log "DEBUG" "tango" "Not declared as exposed on internet."
			TANGO_EXTERNAL_IP=
		fi
		__add_declared_variables "TANGO_EXTERNAL_IP"


		# override domain value
		TANGO_DOMAIN_FEATURE=
		__add_declared_variables "TANGO_DOMAIN_FEATURE"
		if [ "${TANGO_DOMAIN}" = "auto-nip" ]; then
			if [ ! "${NETWORK_INTERNET_EXPOSED}" = "1" ]; then
				__tango_log "ERROR" "tango" "Your current tango context is declared not beeing exposed to internet. You can not use auto-nip domain name feature. To declare your current tango context exposed to internet change variable value NETWORK_INTERNET_EXPOSED to 1"
				exit 1
			fi
		fi

		case $TANGO_DOMAIN in
			auto-nip)
				__tango_log "INFO" "tango" "auto-nip feature for domain name enabled."
				TANGO_DOMAIN_FEATURE="auto-nip"
				if [ "${TANGO_EXTERNAL_IP}" = "" ]; then
					__tango_log "ERROR" "tango" "Can not auto determine your external internet ip. Try to use auto-nip-lan domain name feature OR get your own domain name !."
					exit 1
				else
					TANGO_DOMAIN="${TANGO_EXTERNAL_IP//./-}.nip.io"
				fi
				__tango_log "INFO" "tango" "Domain is auto set to $TANGO_DOMAIN"
				TANGO_SUBDOMAIN_SEPARATOR="-"
				_s="$($STELLA_API get_ip_from_hostname ${TANGO_DOMAIN})"
				case ${_s} in
					${TANGO_EXTERNAL_IP})
						__tango_log "INFO" "tango" "$TANGO_DOMAIN is solved as your external IP address ${TANGO_EXTERNAL_IP}"
						;;
					"")
						__tango_log "WARN" "tango" "DNS request on $TANGO_DOMAIN do not return any result. Maybe your DNS configuration is protected against DNS rebind. Try to use auto-nip-lan mode OR get your own domain name !"
						;;
					*)
						__tango_log "WARN" "tango" "DNS request on $TANGO_DOMAIN return ${_s} which is different from your external IP address ${TANGO_EXTERNAL_IP}."
						;;
				esac
				
			;;

			auto-nip-lan)
				__tango_log "INFO" "tango" "auto-nip-lan feature for domain name enabled."
				TANGO_DOMAIN_FEATURE="auto-nip-lan"
				TANGO_DOMAIN="${TANGO_HOST_DEFAULT_IP//./-}.nip.io"
				__tango_log "INFO" "tango" "Domain is auto set to $TANGO_DOMAIN"
				TANGO_SUBDOMAIN_SEPARATOR="-"
				_s="$($STELLA_API get_ip_from_hostname ${TANGO_DOMAIN})"
				case ${_s} in
					${TANGO_HOST_DEFAULT_IP})
						__tango_log "INFO" "tango" "$TANGO_DOMAIN is solved as your local IP address ${TANGO_HOST_DEFAULT_IP}"
						;;
					"")
						__tango_log "WARN" "tango" "DNS request on $TANGO_DOMAIN do not return any result. Maybe your DNS configuration is protected against DNS rebind. Try to use auto-ip domain name feature OR get your own domain name !"
						;;
					*)
						__tango_log "WARN" "tango" "DNS request on $TANGO_DOMAIN return ${_s} which is different from your local IP address ${TANGO_HOST_DEFAULT_IP}."
						;;
				esac
			;;
		esac


		NETWORK_SERVICES_AREA_LIST="$($STELLA_API list_filter_duplicate "${NETWORK_SERVICES_AREA_LIST}")"
		__area_main_done=
		for area in ${NETWORK_SERVICES_AREA_LIST}; do
			IFS="|" read -r name proto internal_port secure_port <<<$(echo ${area})
			[ "$name" = "main" ] && __area_main_done=1
		done
		# add by default the definition of main network area if not defined in NETWORK_SERVICES_AREA_LIST
		if [ ! "$__area_main_done" = "1" ]; then
			NETWORK_SERVICES_AREA_LIST="${NETWORK_SERVICES_AREA_MAIN_DEFAULT} ${NETWORK_SERVICES_AREA_LIST}"
			__add_declared_variables "NETWORK_SERVICES_AREA_MAIN"
		fi

		# process picking free port
		if [ "${TANGO_FREEPORT}" = "1" ]; then
			case ${ACTION} in
				gen|up|restart ) 
					__pick_free_port
					;;
				* ) # read previous reserved freeport from env file
					[ -f "${GENERATED_ENV_FILE_FREEPORT}" ] && . "${GENERATED_ENV_FILE_FREEPORT}"
					;;
			esac
		fi

		case ${ACTION} in
			gen|info|up|restart )
				__port_list=""
				for area in ${NETWORK_SERVICES_AREA_LIST}; do
					IFS="|" read -r name proto internal_port secure_port <<<$(echo ${area})
					v0="NETWORK_PORT_${name^^}"
					if [ -n "${!v0}" ]; then
						__tango_log "INFO" "tango" "${name} area network port for protocol $proto is : ${!v0}"
						__port_list="${__port_list} ${!v0}"
						[ "${NETWORK_INTERNET_EXPOSED}" = "1" ] && [ ! "${TANGO_EXTERNAL_IP}" = "" ] && [ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${!v0}")" = "TRUE" ] && eval NETWORK_PORT_${name^^}_REACHABLE=1						
					else
						__tango_log "WARN" "tango" "${name} area network do not have a port defined. Set it with option --port ${name}@port[@secured_port] OR variable : ${v0}"
					fi
					__add_declared_variables "NETWORK_PORT_${name^^}_REACHABLE"

					if [ ! "$secure_port" = "" ]; then
						v0s="NETWORK_PORT_${name^^}_SECURE"
						if [ -n "${!v0s}" ]; then
							__tango_log "INFO" "tango" "${name} area network secured port for protocol $proto is : ${!v0s}"
							__port_list="${__port_list} ${!v0s}"
							[ "${NETWORK_INTERNET_EXPOSED}" = "1" ] && [ ! "${TANGO_EXTERNAL_IP}" = "" ] && [ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${!v0s}")" = "TRUE" ] && eval NETWORK_PORT_${name^^}_SECURE_REACHABLE=1
						else
							__tango_log "WARN" "tango" "${name} area network do not have a secured port defined. Set it with with option --port ${name}@port@secured_port OR variable : ${v0s}"
						fi
						__add_declared_variables "NETWORK_PORT_${name^^}_SECURE_REACHABLE"
					fi
				done
				if [ "${NETWORK_INTERNET_EXPOSED}" = "1" ]; then
					if [ ! "${TANGO_DOMAIN_FEATURE}" = "auto-lan-nip" ]; then
						__port_list="$($STELLA_API trim ${__port_list})"
						if [ ! "${__port_list}" = "" ]; then
							__tango_log "INFO" "tango" "If you are on a local network with a router, do not forget to forward ports ${__port_list// / and } to your tango host IP ${TANGO_HOST_DEFAULT_IP}"
							[ "${TANGO_FREEPORT}" = "1" ] && __tango_log "INFO" "tango" "When using freeport option this is a common mistake as port change at each services launch."
						fi
					fi
				fi
			;;
		esac

		# case ${ACTION} in
		# 	gen|info|up|restart )
		# 		if [ "${NETWORK_INTERNET_EXPOSED}" = "1" ]; then

		# 			for area in ${NETWORK_SERVICES_AREA_LIST}; do
		# 				IFS="|" read -r name proto internal_port secure_port <<<$(echo ${area})
		# 				v1="NETWORK_PORT_${name^^}"
		# 				[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${!v1}")" = "TRUE" ] && eval NETWORK_PORT_${name^^}_REACHABLE=1
		# 				__add_declared_variables "NETWORK_PORT_${name^^}_REACHABLE"
		# 				if [ ! "$secure_port" = "" ]; then
		# 					v2="NETWORK_PORT_${name^^}_SECURE"
		# 					[ "$(__check_tcp_port_open "${TANGO_EXTERNAL_IP}" "${!v2}")" = "TRUE" ] && eval NETWORK_PORT_${name^^}_SECURE_REACHABLE=1
		# 					__add_declared_variables "NETWORK_PORT_${name^^}_SECURE_REACHABLE"
		# 				fi
		# 			done
		# 		fi
		# 	;;
		# esac

		# update env var 
		# new env var values priority order :
		# 	- computed new variables at runtime
		#	- shell env variables
		#	- command line
		# 	- user env file
		# 	- modules env file
		# 	- ctx env file
		# 	- default tango env file
		# 	- hardcoded and runtime computed default values
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __update_env_files "ingest default hardcoded values and runtime only variables"


		# STEP 4 ------ create/transform some values and create docker compose file

		# generate compose file (this also add some new variables to VARIABLES_LIST)
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __create_docker_compose_file
		
		# update env var 
		# env var values priority order :
		# 	- computed new variables at runtime
		#	- shell env variables
		#	- command line
		# 	- user env file
		# 	- modules env file		
		# 	- ctx env file
		# 	- default tango env file
		# 	- hardcoded and runtime computed default values
		[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __update_env_files "ingest created/modified/translated variables"
		# load env var
		# even if files have not been modified, we want to load previously saved variables
		__load_env_vars
	;;
esac
