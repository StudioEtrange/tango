# SERVICE LIFECYCLE -----------


# start a service or all services 
# if no service specified will start all service (by starting docker compose service "tango")
# if service specified is the name of a scaled modules, all instances of this module will be launched
# OPTIONS
#		NO_EXEC_PLUGINS do not run attached plugins
#		BUILD	build image before starting
#
# TODO up --no-recreate ? 
#	each time compose file is modified the container is recreated
#	maybe we want this, because we start or restart a service after modifying a configuration
# 	if there are existing containers for a service, 
#	and the service’s configuration or image was changed after the container’s creation,
#	docker-compose up picks up the changes by stopping and recreating the containers 
#	(preserving mounted volumes). To prevent Compose from picking up changes, use the --no-recreate flag.
__service_up() {
	local __service="$1"
	local __opt="$2"

	local __build=
	local __no_exec_plugins=
	local __instances=
	for o in ${__opt}; do
		[ "$o" = "BUILD" ] &&  __build="--build"
		[ "$o" = "NO_EXEC_PLUGINS" ] && __no_exec_plugins="1"
	done

	if $STELLA_API list_contains "${TANGO_SERVICES_MODULES_SCALED}" "${__service}"; then
		__instances="${__service^^}_INSTANCES_LIST"
		__tango_log "DEBUG" "tango" "service_up : starting all instances of scaled ${__service} : ${!__instances}"
		docker-compose up -d $__build ${!__instances}
		
		for i in ${!__instances}; do
			[ ! "$__no_exec_plugins" = "1" ] && __exec_auto_plugin_all_by_service ${i}
			docker-compose logs ${i}
		done
	else
		docker-compose up -d $__build ${__service:-tango}

		if [ "${__service}" = "" ]; then
			[ ! "$__no_exec_plugins" = "1" ] && __exec_auto_plugin_service_active_all
			docker-compose logs service_init
		else
			[ ! "$__no_exec_plugins" = "1" ] && __exec_auto_plugin_all_by_service ${__service}
			docker-compose logs ${__service}
		fi
	fi

	

}

# OPTIONS
#	NO_DELETE do not delete containers just stop them 
#		NOTE : NO_DELETE will not delete any named or anonymous volumes - this might be a problem when changing volumes paths
__service_down_all() {
	local __opt="$1"


	local __no_delete=
	for o in ${__opt}; do
		[ "$o" = "NO_DELETE" ] &&  __no_delete="1"
	done

	if [ "${TANGO_INSTANCE_MODE}" = "shared" ]; then 
		if [ ! "${ALL}" = "1" ]; then
			# test if network already exist and set it as 'external' to not erase it
			if [ ! -z $(docker network ls --filter name=^${TANGO_CTX_NETWORK_NAME}$ --format="{{ .Name }}") ] ; then 
				[ "${TANGO_ALTER_GENERATED_FILES}" = "ON" ] && __set_network_as_external "default" "${TANGO_CTX_NETWORK_NAME}"
			fi
		fi

		if [ ! "${ALL}" = "1" ]; then
			# only non shared service
			docker stop $(docker ps -q $(__container_filter 'NON_STOPPED LIST_NAMES '${TANGO_CTX_NAME}'_.*'))
			[ ! "${__no_delete}" = "1" ] && docker rm $(docker ps -q $(__container_filter 'ONLY_STOPPED LIST_NAMES '${TANGO_CTX_NAME}'_.*'))
		else
			# only shared and non shared service
			if [ "${__no_delete}" = "1" ]; then
				docker stop $(docker ps -q $(__container_filter 'NON_STOPPED LIST_NAMES '${TANGO_CTX_NAME}'_.* '${TANGO_INSTANCE_NAME}'_.*'))
			else
				docker-compose down -v
			fi
		fi
	else
		if [ "${__no_delete}" = "1" ]; then
			docker stop $(docker ps -q $(__container_filter 'NON_STOPPED LIST_NAMES '${TANGO_CTX_NAME}'_.* '${TANGO_INSTANCE_NAME}'_.*'))
		else
			docker-compose down -v
		fi
	fi
}

# OPTIONS
#	NO_DELETE do not delete containers just stop them 
#		NOTE : NO_DELETE will not delete any named or anonymous volumes - this might be a problem when changing volumes paths
__service_down() {
	local __service="$1"
	local __opt="$2"

	local __no_delete=
	for o in ${__opt}; do
		[ "$o" = "NO_DELETE" ] &&  __no_delete="1"
	done

	if $STELLA_API list_contains "${TANGO_SERVICES_MODULES_SCALED}" "${__service}"; then
		__instances="${__service^^}_INSTANCES_LIST"
		__tango_log "DEBUG" "tango" "service_down : stopping all instances of scaled ${__service} : ${!__instances}"
		docker-compose stop ${!__instances}
		# TODO this delete only anonymous volume associated with the service, not named volumes
		[ ! "${__no_delete}" = "1" ] && docker-compose rm -f -v ${!__instances}
	else

		docker-compose stop ${__service}
		# TODO this delete only anonymous volume associated with the service, not named volumes
		[ ! "${__no_delete}" = "1" ] && docker-compose rm -f -v ${__service}
	fi
}

# MANAGE ENV VARIABLES AND FILES GENERATION -----------------

# load all declared variables (including associative arrays)
__load_env_vars() {
	
	# preserve some current variables
	local __d="$DEBUG"
	local __t1="$TANGO_LOG_LEVEL"
	local __t2="$TANGO_LOG_STATE"

	. "${GENERATED_ENV_FILE_FOR_BASH}"
	__load_env_associative_arrays

	export DEBUG="$__d"
	export TANGO_LOG_LEVEL="$__t1"
	export TANGO_LOG_STATE="$__t2"
	
}


# load all associative arrays
# https://stackoverflow.com/a/59157715
__load_env_associative_arrays() {
	for __array in ${ASSOCIATIVE_ARRAY_LIST}; do
		__str="declare -A $__array=\"\$__array\""
		eval $__str
	done 
}

# update env files with current declared variables in VARIABLES_LIST
__update_env_files() {
	local __text="$1"
	echo "# ------ UPDATE : update_env_files : $(date) -- ${__text}" >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"
	echo "# ------ UPDATE : update_env_files : $(date) -- ${__text}" >> "${GENERATED_ENV_FILE_FOR_BASH}"
	for __variable in ${VARIABLES_LIST}; do
		[ -z ${!__variable+x} ] || echo "${__variable}=${!__variable}" >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"
		# NOTE : we need to explicitly use "export" for variables in GENERATED_ENV_FILE_FOR_BASH because some software like ansible need to access their values
		# 		 we export variables only when update file (__update_env_files) not when file is created (__create_env_files "bash") because it easier
		[ -z ${!__variable+x} ] || echo "export ${__variable}=\"$(echo ${!__variable} | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/\\$/g')\"" >> "${GENERATED_ENV_FILE_FOR_BASH}"	
	done

	# store associative arrays
	# to load stored associative arrays from compose env file see __load_env_associative_arrays
	# https://stackoverflow.com/a/59157715
	for __array in ${ASSOCIATIVE_ARRAY_LIST}; do
		# note : use this to store array name and get its length
		declare -n array_name="$__array"
		if [ ${#array_name[@]} -gt 0 ]; then
			__content="$(printf "%q" "$(declare -p $__array | cut -d= -f2-)")"
			echo "${__array}=${__content}" >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"
			declare -p $__array >> "${GENERATED_ENV_FILE_FOR_BASH}"
		fi
	done

	
}

# extract declared variable names from various env files (tango, ctx and user env files)
__init_declared_variable_names() {
	# reset global variables values
	export VARIABLES_LIST=""
	export ASSOCIATIVE_ARRAY_LIST=""

}

# add variables names declared in an env file and add them to VARIABLES_LIST
__extract_declared_variable_names() {
	local __file="$1"

	[ -f "${__file}" ] && VARIABLES_LIST="${VARIABLES_LIST} $(sed -e '/^[[:space:]]*$/d' -e '/^[#]\+.*$/d' -e 's/^\([^=+]*\)+\?=\(.*\)$/\1/g' "${__file}")"
	VARIABLES_LIST="$($STELLA_API list_filter_duplicate "${VARIABLES_LIST}")"
}




# add variables to variables list to be stored in env files
__add_declared_variables() {
	VARIABLES_LIST="${VARIABLES_LIST} $1"
}

# add associative array to arrays list to be stored in env files
__add_declared_associative_array() {
	ASSOCIATIVE_ARRAY_LIST="${ASSOCIATIVE_ARRAY_LIST} ${1}"
}



# generate an env file from various env files (tango, ctx, modules and user env files) 
# 		__target bash : generate a bash file to be sourced (GENERATED_ENV_FILE_FOR_BASH)
# 		__target docker_compose : generate an env file to be used as env-file in environment section of docker compose file (GENERATED_ENV_FILE_FOR_COMPOSE)
# __target : bash | docker_compose
# __source_list : user, modules, ctx, default -- will create env file by adding in order thoses source file (ascending priority order)
#				default ascending priority order is 'default ctx modules user', so default env var have lowest priority
__create_env_files() {
	local __target="$1"
	local __source_list="$2"

	[ "${__source_list}" = "" ] && __source_list="default ctx modules user"

	local __file=
	local __instances_list=
	local __modules_list=
	local __scaled_modules_processed=
	case $__target in
		bash )
			__file="${GENERATED_ENV_FILE_FOR_BASH}"
		;;
		docker_compose )
			__file="${GENERATED_ENV_FILE_FOR_COMPOSE}"
		;;
	esac

	__tango_log "DEBUG" "tango" "create_env_files for $__target : init ${__file} with theses source files order : $__source_list"


	echo "# ------ CREATE : __create_env_files for $__target : $(date)" > "${__file}"

	for o in ${__source_list}; do

		case $o in 

			default )	
				# add default tango env file
				__tango_log "DEBUG" "tango" "create_env_files for $__target : add default tango env file ${TANGO_ENV_FILE}"
				cat <(echo \# --- PART FROM default tango env file ${TANGO_ENV_FILE}) <(echo) <(echo) "${TANGO_ENV_FILE}" <(echo) >> "${__file}"
			;;

			ctx )
				# add ctx env file
				if [ -f "${TANGO_CTX_ENV_FILE}" ]; then 
					__tango_log "DEBUG" "tango" "create_env_files for $__target : add ctx env file ${TANGO_CTX_ENV_FILE}"
					cat <(echo \# --- PART FROM ctx env file ${TANGO_CTX_ENV_FILE}) <(echo) <(echo) "${TANGO_CTX_ENV_FILE}" <(echo) >> "${__file}"
				fi
			;;

			modules )
				# add modules env files for scaled modules
				__modules_list="${TANGO_SERVICES_MODULES}"
				__scaled_modules_processed=
				if [ ! "$TANGO_SERVICES_MODULES_SCALED" = "" ]; then
					__tango_log "DEBUG" "tango" "create_env_files for $__target : add modules env files for scaled modules : $TANGO_SERVICES_MODULES_SCALED"
					for m in ${TANGO_SERVICES_MODULES_SCALED}; do
						__instances_list="${m^^}_INSTANCES_LIST"

						for i in ${!__instances_list}; do
							# ctx modules overrides tango modules
							if [ -f "${TANGO_CTX_MODULES_ROOT}/${m}.env" ]; then
								__tango_log "DEBUG" "tango" "create_env_files for $__target : ctx module ${m} instance ${i} : add env file : ${TANGO_CTX_MODULES_ROOT}/${m}.env"
								# we replace all ocurrence of module name with an instance name
								# except into lines containing FIXED_VAR expression anywhere
								# except expression beginngin with SHARED_VAR_
								# use sed implementation of negative lookbehind https://stackoverflow.com/a/26110465
								#sed -e "/FIXED_VAR/!s/${m}\([^a-zA-Z0-9]*\)/${i}\1/g" -e "/FIXED_VAR/!s/${m^^}\([^a-zA-Z0-9]*\)/${i^^}\1/g" <(echo \# --- PART FROM modules env file ${TANGO_CTX_MODULES_ROOT}/${m}.env) <(echo) <(echo) "${TANGO_CTX_MODULES_ROOT}/${m}.env" <(echo) >> "${__file}"
								sed -E "{/FIXED_VAR/! {s/#/##/g; s/(SHARED_VAR_)(${m})/\1_#_/g; s/(SHARED_VAR_)(${m^^})/\1-#-/g; s/${m}([^a-zA-Z0-9]*)/${i}\1/g; s/${m^^}([^a-zA-Z0-9]*)/${i^^}\1/g; s/(SHARED_VAR_)_#_/\1${m}/g; s/(SHARED_VAR_)-#-/\1${m^^}/g; s/##/#/g} }" <(echo \# --- PART FROM module env file ${TANGO_CTX_MODULES_ROOT}/${m}.env) <(echo) <(echo) "${TANGO_CTX_MODULES_ROOT}/${m}.env" <(echo) >> "${__file}"
							else
								if [ -f "${TANGO_MODULES_ROOT}/${m}.env" ]; then
									__tango_log "DEBUG" "tango" "create_env_files for $__target : tango module ${m} instance ${i} : add env file : ${TANGO_MODULES_ROOT}/${m}.env"
									# we replace all ocurrence of module name with instance name
									# except into lines containing FIXED_VAR expression anywhere
									# except expression beginngin with SHARED_VAR_
									# use sed implementation of negative lookbehind https://stackoverflow.com/a/26110465
									#sed -e "/FIXED_VAR/!s/${m}\([^a-zA-Z0-9]*\)/${i}\1/g" -e "/FIXED_VAR/!s/${m^^}\([^a-zA-Z0-9]*\)/${i^^}\1/g" <(echo \# --- PART FROM modules env file ${TANGO_MODULES_ROOT}/${m}.env) <(echo) <(echo) "${TANGO_MODULES_ROOT}/${m}.env" <(echo) >> "${__file}"
									sed -E "{/FIXED_VAR/! {s/#/##/g; s/(SHARED_VAR_)(${m})/\1_#_/g; s/(SHARED_VAR_)(${m^^})/\1-#-/g; s/${m}([^a-zA-Z0-9]*)/${i}\1/g; s/${m^^}([^a-zA-Z0-9]*)/${i^^}\1/g; s/(SHARED_VAR_)_#_/\1${m}/g; s/(SHARED_VAR_)-#-/\1${m^^}/g; s/##/#/g} }"  <(echo \# --- PART FROM module env file ${TANGO_MODULES_ROOT}/${m}.env) <(echo) <(echo) "${TANGO_MODULES_ROOT}/${m}.env" <(echo) >> "${__file}"
								else
									__tango_log "DEBUG" "tango" "create_env_files for $__target : scaled module $m do not have an env file (${TANGO_CTX_MODULES_ROOT}/${m}.env nor ${TANGO_MODULES_ROOT}/${m}.env do not exists) might be an error"
								fi
							fi
							__scaled_modules_processed="${__scaled_modules_processed} ${i}"
						done
					done
					# remove from list scaled modules already processed
					__modules_list="$($STELLA_API filter_list_with_list "${__modules_list}" "${__scaled_modules_processed}")"
				fi

				# add modules env files
				__tango_log "DEBUG" "tango" "create_env_files for $__target : add modules env files for modules : ${__modules_list}"
				for s in ${__modules_list}; do
					# ctx modules overrides tango modules
					if [ -f "${TANGO_CTX_MODULES_ROOT}/${s}.env" ]; then
						__tango_log "DEBUG" "tango" "create_env_files for $__target : ctx module ${s} : add env file : ${TANGO_CTX_MODULES_ROOT}/${s}.env"
						cat <(echo \# --- PART FROM module env file ${TANGO_CTX_MODULES_ROOT}/${s}.env) <(echo) <(echo) "${TANGO_CTX_MODULES_ROOT}/${s}.env" <(echo) >> "${__file}"
					else
						if [ -f "${TANGO_MODULES_ROOT}/${s}.env" ]; then
							__tango_log "DEBUG" "tango" "create_env_files for $__target : tango module ${s} : add env file : ${TANGO_MODULES_ROOT}/${s}.env"
							cat <(echo \# --- PART FROM module env file ${TANGO_MODULES_ROOT}/${s}.env) <(echo) <(echo) "${TANGO_MODULES_ROOT}/${s}.env" <(echo) >> "${__file}"
						else
							__tango_log "DEBUG" "tango" "create_env_files for $__target : module $s do not have an env file (${TANGO_CTX_MODULES_ROOT}/${s}.env nor ${TANGO_MODULES_ROOT}/${s}.env do not exists) maybe abnormal or not"
						fi
					fi
				done
			;;

			user )
				# add user env file
				if [ -f "${TANGO_USER_ENV_FILE}" ]; then
					__tango_log "DEBUG" "tango" "create_env_files for $__target : add user env file ${TANGO_USER_ENV_FILE}"
					cat <(echo \# --- PART FROM user env file ${TANGO_USER_ENV_FILE}) <(echo) <(echo) "${TANGO_USER_ENV_FILE}" <(echo) >> "${__file}"
				fi
			;;
		esac
	done

	# process special notations
	__parse_env_file "${__file}"

	if [ "$__target" = "bash" ]; then
		# add quote for variable bash support
		sed -i -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/\\$/g' "${__file}"
		sed -i 's/^\([a-zA-Z0-9_-]*\)=\(.*\)$/\1=\"\2\"/g' "${__file}"
	fi

}



# remove commentary 
# manage += : cumulative assignation
# manage ?= : init value of not already assigned variable (within file or in env var) with a value 
# manage != : erase value of an already assigned variable (within file or in env var) with another value
__parse_env_file() {
	local _file="$1"

	__tango_log "DEBUG" "tango" "parse_env_file : ${_file}"
	local _temp=$(mktmp)

	awk -F= '
	BEGIN {
	}

	# catch !=
	/^[^=#]*!=/ {
		key=substr($1, 1, length($1)-1);
		if (arr[key]) arr[key]=$2;
		else if(ENVIRON[key]) arr[key]=$2;
		
		print key"="arr[key];
		next;
	}

	# catch ?=
	/^[^=#]*\?=/ {
		key=substr($1, 1, length($1)-1);
		if (arr[key]) arr[key]=arr[key];
		else if(ENVIRON[key]) arr[key]=ENVIRON[key];
		else arr[key]=$2;
		print key"="arr[key];
		next;
	}

	# catch +=
	/^[^=#]*\+=/ {
		key=substr($1, 1, length($1)-1);
		if (arr[key]) arr[key]=arr[key] " " $2;
		else if(ENVIRON[key]) arr[key]=ENVIRON[key] " " $2;
		else arr[key]=$2;
		print key"="arr[key];
		next;
	}

	# catch =
	/^[^=#]*=/ {
		arr[$1]=$2;
		print $0;
		next;
	}

	/.*/ {
		print $0;
		next;
	}
	
	END {
	}
	' "${_file}" > "${_temp}"
	cat "${_temp}" > "${_file}"
	rm -f "${_temp}"
	
	__substitute_env_var_in_file "$1"
	__substitute_key_in_file "$1"
}


# https://gist.github.com/StudioEtrange/152e7bd0ac278b175663d11ab5db5d81

# In any text or configuration file substitute a key with its own value, if its value is assigned earlier in the file and the key is referenced with {{key}}
# This could be used on any text file, i.e an .ini file or a docker-compose env file
# The mechanism works like in shell script variable syntax in some ways : assignation, declaration, resolution order and comment symbol (#)
#   Usage : substitute_var_env_file "<file_path>"
#   Input file content:
#			N=10
#			The number is {{N}}
#			# FOO={{N}}
#			A=1
#			B={{A}}
#			C={{B}}
#			X={{Y}}
#			Y=4
#			X={{Y}}
#   Result file content:
#			N=10
#			# The number is 10
#			# FOO=10
#			A=1
#			B=1
#			C=1
#			X={{Y}}
#			Y=4
#			X=4
__substitute_key_in_file() {

	local _file="$1"

	local _temp=$(mktmp)

	awk --traditional -F= '

 		function parsekey(str) {
			# if there is a value assignation to a key into this string
			# update val array
			if (match(str,/^([^=#]*)=/)) {
            	tmp=substr(str, RSTART, RLENGTH-1);
                val[tmp]=substr(str, RSTART+RLENGTH);
            }
			
		}

		# fill the key array which contains all existing key
		/^[^=#]*=/ {
			# FNR=NR only when reading first file
			if (FNR==NR) {
				key[$1]=1;
				next;
			}
		}
		/.*/ {
			# FNR=NR only when reading first file
			if (FNR==NR) {
				next;
			}
		}
	
		# this block is triggered at each line only if not bypassed by next
		# so this block is really triggered only when reading second file
		{
			for (k in key) {
				# transform any reference to the keyy in current line into its value, if it has a known value
				# key[] list all existing keys in file
				# val[] list only key which have a known value
				if (k in val) {
					# we replace any reference to the key with its value with gsub in current line
					gsub("{{"k"}}", val[k]);			
				}
			}
			# re-parse the current line to find any value assignation to a key
			parsekey($0);
			print $0;
		} 

		' "${_file}" "${_file}" > "${_temp}"
		cat "${_temp}" > "${_file}"
		rm -f "${_temp}"
}

# replace in a file exported environnement variable in the form {{$variable}}
# NOTE : authorized char as shell variable name : [a-zA-Z_]+[a-zA-Z0-9_]* https://stackoverflow.com/a/2821201
# WARN : env var must have been exported (with export command) to be used here
__substitute_env_var_in_file() {

	local _file="$1"

	local _temp=$(mktmp)

	awk '
		/{{\$[a-zA-Z_]+[a-zA-Z0-9_]*}}/ {
				if (match($0,/{{\$[a-zA-Z_]+[a-zA-Z0-9_]*}}/)) {
						tmp=substr($0,RSTART+3,RLENGTH-5)
                        if (tmp in ENVIRON) gsub("{{\\$"tmp"}}",ENVIRON[tmp],$0);
                        else gsub("{{\\$"tmp"}}","{{MISSING_"tmp"}}",$0)
				}
		}

		/.*/ {
				print $0;
		}
	'  "${_file}" > "${_temp}"
	cat "${_temp}" > "${_file}"
	rm -f "${_temp}"
}



# generate docker compose file
__create_docker_compose_file() {
	rm -f "${GENERATED_DOCKER_COMPOSE_FILE}"

	# concatenate compose files starting with tango compose file
	# NOTE : do not explode anchors here, we need to keep anchor &default-vpn, because we add vpn sections later and we need &default-vpn still exists
	cp -f "${TANGO_COMPOSE_FILE}" "${GENERATED_DOCKER_COMPOSE_FILE}"

	
	# manage traefik entrypoint
	__add_entrypoints_all


	# ctx compose file
	[ -f "${TANGO_CTX_COMPOSE_FILE}" ] && yq m -i -a=append -- "${GENERATED_DOCKER_COMPOSE_FILE}" <(yq r --explodeAnchors "${TANGO_CTX_COMPOSE_FILE}")

	# user compose file
	[ -f "${TANGO_USER_COMPOSE_FILE}" ] && yq m -i -a=append -- "${GENERATED_DOCKER_COMPOSE_FILE}" <(yq r --explodeAnchors "${TANGO_USER_COMPOSE_FILE}")


	# define network area
	__set_network_area_all

	# add module to compose file and set module to a default logical area network
	__set_module_all

	# declare all active service depending on traefik AND as a "tango" depdency in compose file
	__set_active_services_all

	# manage times volume
	__set_time_all
	
	# attach all services to entrypoints and set services to a default area network
	__set_entrypoints_service_all
	# attach all subservices to entrypoints
	__set_entrypoints_subservice_all

	# set routers parameters
	__set_routers_info_service_all
	__set_priority_router_all

	__set_redirect_https_service_all
	
	# set priority for error router after to override default setted values for any service
	__set_error_engine
	__add_service_direct_port_access_all

	# environnment var management
	# add specific env var inside service
	__add_environment_service_all
	# attach generated env compose file to services
	__add_generated_env_file_all
	__add_gpu_all

	# volume management
	__add_volume_definition_all
	__add_volume_artefact_all
	__add_volume_pool_and_plugins_data_all
	__add_volume_service_all

	# traefik middleware management
	__add_middleware_service_all


	# certifacte management
	__set_letsencrypt_service_all
	
	# vpn management
	__create_vpn_all
	# do this after other compose modification 	
	# because it remove some network definition
	# and because some methods above add service to VPN_x_SERVICES
	__set_vpn_service_all


	__tango_log "INFO" "tango" "Active services and subservices : ${TANGO_SERVICES_ACTIVE} ${TANGO_SUBSERVICES_ROUTER_ACTIVE}"

}


# translate all relative path to absolute
__translate_path() {

	
	if [ ! "${TANGO_ARTEFACT_FOLDERS}" = "" ]; then
		__tmp=
		for f in ${TANGO_ARTEFACT_FOLDERS}; do
			f="$($STELLA_API rel_to_abs_path "${f}" "${TANGO_CTX_WORK_ROOT}")"
			__tmp="${__tmp} ${f}"
		done
		export TANGO_ARTEFACT_FOLDERS="$($STELLA_API trim "${__tmp}")"
	fi

	if [ ! "${TANGO_CERT_FILES}" = "" ]; then
		__tmp=
		for f in ${TANGO_CERT_FILES}; do
			f="$($STELLA_API rel_to_abs_path "${f}" "${TANGO_CTX_WORK_ROOT}")"
			__tmp="${__tmp} ${f}"
		done
		export TANGO_CERT_FILES="$($STELLA_API trim "${__tmp}")"
	fi

	if [ ! "${TANGO_KEY_FILES}" = "" ]; then
		__tmp=
		for f in ${TANGO_KEY_FILES}; do
			f="$($STELLA_API rel_to_abs_path "${f}" "${TANGO_CTX_WORK_ROOT}")"
			__tmp="${__tmp} ${f}"
		done
		export TANGO_KEY_FILES="$($STELLA_API trim "${__tmp}")"
	fi

	# TODO REMOVE THIS USELESS
	# at this step all path variable managed by tango through TANGO_PATH_LIST (and sublist) should be already absolute
	for __variable in ${VARIABLES_LIST}; do
		case ${__variable} in
			*_PATH) 
				#if [ ! "${!__variable}" = "" ]; then
					case ${!__variable} in
						/*);;
						*)
							__tango_log "WARN" "tango" "not absolute path variable found : ${__variable} [${!__variable}]. Maybe not managed by tango ? If you want to, add it to TANGO_PATH_LIST"
						;;
					esac
					
					# convert to absolute USELESS ?
					#export ${__variable}="$($STELLA_API rel_to_abs_path "${!__variable}" "${TANGO_CTX_ROOT}")"
				#fi
			;;
		esac
	done

}




# MANAGE FEATURES FOR ALL CONTAINTERS -----------------

# declare all active service depending on traefik AND as a "tango" depdency in compose file
__set_active_services_all() {
	for s in ${TANGO_SERVICES_ACTIVE}; do
		if __check_docker_compose_service_exist "${s}"; then
			__add_service_dependency "tango" "${s}"
			if [ "${TANGO_SERVICES_DEPENDS_ON_TRAEFIK}" = "ON" ]; then
				case ${s} in
					traefik|error );;
					*)	__add_service_dependency "${s}" "traefik";;
				esac
			fi
		else
			__tango_log "WARN" "tango" "unknow service ${s} declared in TANGO_SERVICES_ACTIVE"
		fi
	done
}

__set_vpn_service_all() {

	local _tmp=
	local _id=
	for v in ${VPN_SERVICES_LIST}; do
		_tmp="${v^^}_SERVICES"
		_id="${v/#*_}"
		for s in ${!_tmp}; do
			__check_docker_compose_service_exist "${s}" && __set_vpn_service "${s}" "${_id}" "${v}" || __tango_log "WARN" "tango" "unknow service ${s} declared in ${_tmp}"
		done

	done
}



__create_vpn_all() {

	__add_declared_variables "VPN_SERVICES_LIST"
	# NOTE : +4/-4 is for bybass 'VPN_'
	for _id in $(compgen -A variable | awk 'match($0,/VPN_[0-9]+/) {print substr($0,RSTART+4,RLENGTH-4)}' | sort | uniq); do
		__create_vpn ${_id}
		__add_service_dependency "vpn" "vpn_${_id}"
		export VPN_SERVICES_LIST="${VPN_SERVICES_LIST} vpn_${_id}"
	done

}


__set_certificates_all() {
	# empty file
	echo -n "" > "${GENERATED_TLS_FILE_PATH}"

	local i=0
	for p in ${TANGO_CERT_FILES}; do
		yq w -i -- "${GENERATED_TLS_FILE_PATH}" "tls.certificates[$i].certFile" "${p}"
		__add_volume_mapping_service "traefik" "${p}:${p}"
		(( i++ ))
	done

	i=0
	for k in ${TANGO_KEY_FILES}; do
		yq w -i -- "${GENERATED_TLS_FILE_PATH}" "tls.certificates[$i].keyFile" "${k}"
		__add_volume_mapping_service "traefik" "${k}:${k}"
		(( i++ ))
	done
}







# attach existing volumes to compose service
# use <SERVICE>_ADDITIONAL_VOLUMES variable <named volume|path|#variable path name>:<path|#variable path name>[:ro|rw]
__add_volume_service_all() {
	local _t=
	local _mapping_service=
	for _s in $(compgen -A variable | grep _ADDITIONAL_VOLUMES$); do
		_s="${_s%_ADDITIONAL_VOLUMES}"
		if __check_docker_compose_service_exist "${_s,,}"; then
			_t="${_s}_ADDITIONAL_VOLUMES"
			for _v in ${!_t}; do
				__parse_item "volume" "${_v}" "_VOLUME"

				[ ! "${_VOLUME_OUTSIDE_PATH}" = "" ] && _mapping_service="${_VOLUME_OUTSIDE_PATH}:"
				if [ ! "${_VOLUME_OUTSIDE_PATH_VARIABLE}" = "" ]; then
					_mapping_service="\${${_VOLUME_OUTSIDE_PATH_VARIABLE}}:"
					# add variable name to variables list passed in env file, because it can be initialized out of tango
					__add_declared_variables "${_VOLUME_OUTSIDE_PATH_VARIABLE}"
				fi

				[ ! "${_VOLUME_INSIDE_PATH}" = "" ] && _mapping_service="${_mapping_service}${_VOLUME_INSIDE_PATH}"
				if [ ! "${_VOLUME_INSIDE_PATH_VARIABLE}" = "" ]; then
					_mapping_service="${_mapping_service}\${${_VOLUME_INSIDE_PATH_VARIABLE}}"
					# add variable name to variables list passed in env file, because it can be initialized out of tango
					__add_declared_variables "${_VOLUME_INSIDE_PATH_VARIABLE}"
				fi

				[ ! "${_VOLUME_MODE}" = "" ] && _mapping_service="${_mapping_service}:${_VOLUME_MODE}"
				
				__add_volume_mapping_service "${_s,,}" "${_mapping_service}"

				__tango_log "DEBUG" "tango" "add_volume_service_all : attach volume : ${_v} to compose service : ${_s,,}."
			done
		else
			__tango_log "WARN" "tango" "add_volume_service_all : service compose ${_s,,} declared with ${_s}_ADDITIONAL_VOLUMES do not exist."
		fi
	done
}





# create named volumes. path is defined by a variable name
# use TANGO_VOLUMES=<named volume>:<path|#variable path name>
__add_volume_definition_all() {
	local _t=
	for _v in ${TANGO_VOLUMES}; do
		__parse_item "volume" "${_v}" "_VOLUME"
		__tango_log "DEBUG" "tango" "add_volume_definition_all : create volume : ${_v}"
		
		if [ ! "${_VOLUME_OUTSIDE_PATH_VARIABLE}" = "" ]; then
			__tango_log "ERROR" "tango" "add_volume_definition_all : error in TANGO_VOLUMES ${_v}. Syntax is  TANGO_VOLUMES=<named volume>:<path|#variable path name>"
			exit 1
		fi

		if [ ! "${_VOLUME_INSIDE_PATH}" = "" ]; then
			__add_volume_definition_by_value "${_VOLUME_OUTSIDE_PATH}" "${_VOLUME_INSIDE_PATH}"
		else 
			if [ ! "${_VOLUME_INSIDE_PATH_VARIABLE}" = "" ]; then
				__add_volume_definition_by_variable "${_VOLUME_OUTSIDE_PATH}" "${_VOLUME_INSIDE_PATH_VARIABLE}"
			fi
		fi
	done
}



# attach middlewares to services
# use <SERVICE>_ADDITIONAL_MIDDLEWARES variable with : as separator for priority (FOO_ADDITIONAL_MIDDLEWARES="midd1:LAST midd2 midd3:POS:4")
# :FIRST or :LAST(default) or POS:N 
__add_middleware_service_all() {
	local _t=
	#local __midd=
	for _s in $(compgen -A variable | grep _ADDITIONAL_MIDDLEWARES$); do
		_s="${_s%_ADDITIONAL_MIDDLEWARES}"
		if __check_docker_compose_service_exist "${_s,,}"; then
			_t="${_s}_ADDITIONAL_MIDDLEWARES"
			for _v in ${!_t}; do
				#__midd=(${_v//:/ })
				__parse_item "middleware" "${_v}" "_MIDDLEWARE"
				#__attach_middleware_to_service "${_s,,}" "${__midd[0]}" "${__midd[1]} ${__midd[2]}"
				__attach_middleware_to_service "${_s,,}" "${_MIDDLEWARE_NAME}" "${_MIDDLEWARE_POSITION} ${_MIDDLEWARE_POS_NUMBER}"
				__tango_log "DEBUG" "tango" "add_middleware_service_all : attach middleware : ${_v} to compose service : ${_s,,}."
			done
		else
			__tango_log "WARN" "tango" "add_middleware_service_all : service compose ${_s,,} declared with ${_s}_ADDITIONAL_MIDDLEWARES do not exist."
		fi
	done
}

# additional environment variable in compose file for each services
# NOTE in general case we add variable inside all services just by using __add_declared_variable
# but those variables are shared by all services. If we want different values for each service of a variable we need to add them
# through compose env file
# use <SERVICE>_SPECIFIC_ENVVAR variable
__add_environment_service_all() {

	local _t=
	for _s in $(compgen -A variable | grep _SPECIFIC_ENVVAR$); do
		_s="${_s%_SPECIFIC_ENVVAR}"
		if __check_docker_compose_service_exist "${_s,,}"; then
			_t="${_s}_SPECIFIC_ENVVAR"
			for _e in ${!_t}; do
				yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${_s,,}.environment[+]" "${_e}"
			done
		else
			__tango_log "WARN" "tango" "add_environment_service_all : service compose ${_s,,} declared with ${_s}_SPECIFIC_ENVVAR  do not exist."
		fi
	done




}

# add a artefact_xxx named volume defintion
# attach this artefact_xxx named volume to a /$TANGO_ARTEFACT_MOUNT_POINT/xxxx folder to each service listed in TANGO_ARTEFACT_SERVICES
__add_volume_artefact_all() {
	for f in ${TANGO_ARTEFACT_FOLDERS}; do
		f="$($STELLA_API rel_to_abs_path "${f}" "${TANGO_CTX_ROOT}")"
		target="$(basename "${f}")"
		if [ -f "${f}" ]; then 
			__tango_log "WARN" "tango" "[${f}] is a file, not mounted inside folder {${TANGO_ARTEFACT_MOUNT_POINT}}"
		else
			[ ! -d "${f}" ] && __tango_log "INFO" "tango" "[${f}] is not an existing directory and will be auto created."
			__name="$($STELLA_API md5 "${f}")"
			__add_volume_definition_by_value "artefact_${__name}" "${f}"
			for s in $TANGO_ARTEFACT_SERVICES; do
				__check_docker_compose_service_exist "${s}" && __add_volume_mapping_service "${s}" "artefact_${__name}:${TANGO_ARTEFACT_MOUNT_POINT}/${target}"
				# NOTE : do not print WARN because a warn is printed for each artefact folder for each undefined services
				#	|| echo "** WARN : unknow ${s} service declared in TANGO_ARTEFACT_SERVICES"
				
			done
			__tango_log "DEBUG" "tango" "[${f}] will be mapped to {${TANGO_ARTEFACT_MOUNT_POINT}/${target}}"
		fi
	done
}

# attach generated env compose file to services
__add_generated_env_file_all() {
	for s in ${TANGO_SERVICES_ACTIVE}; do
		__add_generated_env_file ${s}
	done
}

# add pool volume and plugins_data to each service
__add_volume_pool_and_plugins_data_all() {

	# add default pool folder
	for s in ${TANGO_SERVICES_ACTIVE}; do
		__add_volume_mapping_service "${s}" "${TANGO_ROOT}/pool:/pool/tango"
		__add_volume_mapping_service "${s}" "${PLUGINS_DATA_PATH}:/plugins_data"
	done
	__add_volume_mapping_service "service_info" "${TANGO_ROOT}/pool:/pool/tango"
	__add_volume_mapping_service "service_info" "${PLUGINS_DATA_PATH}:/plugins_data"
	__add_volume_mapping_service "service_init" "${TANGO_ROOT}/pool:/pool/tango"
	__add_volume_mapping_service "service_init" "${PLUGINS_DATA_PATH}:/plugins_data"

	# add pool ctx folder if it exists 
	if [ ! "${TANGO_NOT_IN_ANY_CTX}" = "1" ]; then
		if [ -d "${TANGO_CTX_ROOT}/pool" ]; then
			for s in ${TANGO_SERVICES_ACTIVE}; do
				__add_volume_mapping_service "${s}" "${TANGO_CTX_ROOT}/pool:/pool/${TANGO_CTX_NAME}"
			done
			__add_volume_mapping_service "service_info" "${TANGO_CTX_ROOT}/pool:/pool/${TANGO_CTX_NAME}"
			__add_volume_mapping_service "service_init" "${TANGO_CTX_ROOT}/pool:/pool/${TANGO_CTX_NAME}"
		fi
	fi



}

# add gpu to all container that need its
# NVIDIA | INTEL_QUICKSYNC
__add_gpu_all() {
	for s in $(compgen -A variable | grep _GPU$); do
		gpu="${!s}"
		if [ ! "${gpu}" = "" ]; then
			service="${s%_GPU}"
			service="${service,,}"
			__check_docker_compose_service_exist "${service}" && __add_gpu "${service}" "${gpu}" || __tango_log "WARN" "tango" "unknow service ${service} declared in ${s}"
		fi
	done
}

# set timezone to containers which need it
__set_time_all() {

	for s in $TANGO_TIME_VOLUME_SERVICES; do
		__check_docker_compose_service_exist "${s}" && __add_volume_for_time "$s" || __tango_log "WARN" "tango" "unknow service ${s} declared in TANGO_TIME_VOLUME_SERVICES"
	done

	for s in $TANGO_TIME_VAR_TZ_SERVICES; do
		__check_docker_compose_service_exist "${s}" && __add_tz_var_for_time "$s" || __tango_log "WARN" "tango" "unknow service ${s} declared in TANGO_TIME_VAR_TZ_SERVICES"
	done

}



# https://doc.traefik.io/traefik/https/acme/
__set_letsencrypt_service_all() {
	local __cloudflare_ip
	
	case ${LETS_ENCRYPT} in
		enable|debug )
			for serv in ${LETS_ENCRYPT_SERVICES}; do
				__add_letsencrypt_service "${serv}"
			done

			if [ "${LETS_ENCRYPT}" = "debug" ]; then
				__tango_log "INFO" "tango" "Letsencrypt certificate generation is in debug mode to avoid ban"
				__tango_log "INFO" "tango" "check generated certificates in $LETS_ENCRYPT_DATA_PATH"

				# set letsencrypt debug server if needed
				yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--certificatesresolvers.tango.acme.caserver=${LETS_ENCRYPT_SERVER_DEBUG}"
			fi
			__tango_log "INFO" "tango" "ACME protocol use ${ACME_CHALLENGE} challenge to valid letsencrypt certificates"

			case ${ACME_CHALLENGE} in
				HTTP )
					
					yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--certificatesresolvers.tango.acme.httpchallenge=true"
					# The entrypoint MUST use the default 'main' network area
					yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--certificatesresolvers.tango.acme.httpchallenge.entrypoint=entry_main_http"
				;;
				DNS )
					__tango_log "INFO" "tango" "ACME protocol ask ${ACME_DNS_PROVIDER} dns provider to valid letsencrypt certificates"
					yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--certificatesresolvers.tango.acme.dnschallenge=true"
					yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--certificatesresolvers.tango.acme.dnschallenge.provider=${ACME_DNS_PROVIDER}"
					yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--certificatesresolvers.tango.acme.dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53"
					
							
					case ${ACME_DNS_PROVIDER} in
						
						cloudflare)
							
							# get ipv4 cloudflare ip - TODO do we need to get ipv6 ip and allow them ?
							__cloudflare_ip=$(__tango_curl -fkSLs "https://www.cloudflare.com/ips-v4" | tr '\n' ',')

							# To delay DNS check and reduce LE hitrate
							yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--certificatesresolvers.tango.acme.dnschallenge.delayBeforeCheck=90"
							
							for e in ${TRAEFIK_ENTRYPOINTS_HTTP_LIST//,/ }; do
								case $e in
									*_secure)
										# Allow these IPs to set the X-Forwarded-* headers - Cloudflare IPs: https://www.cloudflare.com/ips/
										yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--entrypoints.$e.forwardedHeaders.trustedIPs=${__cloudflare_ip}"
									;;
								esac
							done 
						;;

						* )
						 	# To delay DNS check and reduce LE hitrate
							yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--certificatesresolvers.tango.acme.dnschallenge.delayBeforeCheck=10"
						;;
					esac
				;;
			esac
		;;
	esac
}



__set_routers_info_service_all() {

	
	local area
	local name
	local proto
	local internal_port
	local secure_port
	local __service
	local __port
	local __entrypoints=
	local __entrypoint_default=
	local __var=
	local __subdomain=
	local __hostname=
	local __subservice_flag=
	local __address=
	local __uri=
	local __parent=
	local __router_list=
	local __fill_info=

	__tango_log "DEBUG" "tango" "set_routers_info_service_all : setting routers information (port, subdomain, hostname, address, uri)"

	for __service in ${TANGO_SERVICES_AVAILABLE} SUBSERVICES_DELIMITER ${TANGO_SUBSERVICES_ROUTER}; do
		
		__subdomain=
		__hostname=
		__address=
		__port=
		__uri=

		if [ "${__service}" = "SUBSERVICES_DELIMITER" ]; then
			# we iter inside subservice list
			__subservice_flag="1"
			continue
		fi

	

		__entrypoints="${__service^^}_ENTRYPOINTS"
		__entrypoints="${!__entrypoints}"
		__entrypoint_default="${__service^^}_ENTRYPOINT_DEFAULT"
		__entrypoint_default="${!__entrypoint_default}"

		if [ "${__subservice_flag}" = "1" ]; then
			__parent="$(__get_subservice_parent "${__service}")"
			__router_list="${__parent^^}_ROUTERS_LIST"
			__router_list="${!__router_list} ${__service}"
			eval "export ${__parent^^}_ROUTERS_LIST=\"${__router_list}\""
			__add_declared_variables "${__parent^^}_ROUTERS_LIST"
		else
			if ! __check_traefik_router_exist ${__service}; then
				__tango_log "DEBUG" "tango" "set_routers_info_service_all : ${__service} not have any traefik router defined in compose file. May have only subservices."
				eval "export ${__service^^}_ROUTERS_LIST=\"\""
				__add_declared_variables "${__service^^}_ROUTERS_LIST"
			else
				eval "export ${__service^^}_ROUTERS_LIST=\"${__service}\""
				__add_declared_variables "${__service^^}_ROUTERS_LIST"
			fi
		fi


		# service URI hostname form : <SUBDOMAIN>[<TANGO_SUBDOMAIN_SUFFIX_SEPARATOR><TANGO_SUBDOMAIN_SUFFIX>]<TANGO_SUBDOMAIN_SEPARATOR><TANGO_DOMAIN>
		if [ ! "${__entrypoints}" = "" ]; then
			__var="${__service^^}_SUBDOMAIN"
			if [ -z ${!__var+x} ]; then
				if [ "${__subservice_flag}" = "1" ]; then
					# by default each router of a subservice have its parent service name as subdomin name value
					__subdomain="$(__get_subservice_parent "${__service}")"
				else
					# by default each router of a service have the service name as subdomin name value
					__subdomain="${__service}"
				fi
				if [ ! "${TANGO_SUBDOMAIN_SUFFIX}" = "" ]; then
					__subdomain="${__subdomain}${TANGO_SUBDOMAIN_SUFFIX_SEPARATOR}${TANGO_SUBDOMAIN_SUFFIX}"
				fi

				#eval "export ${__service^^}_SUBDOMAIN=${__subdomain}"
				__add_declared_variables "${__service^^}_SUBDOMAIN"
			else
				__subdomain="${!__var}"
				if [ ! "${TANGO_SUBDOMAIN_SUFFIX}" = "" ]; then
					__subdomain="${__subdomain}${TANGO_SUBDOMAIN_SUFFIX_SEPARATOR}${TANGO_SUBDOMAIN_SUFFIX}"
					#eval "export ${__service^^}_SUBDOMAIN=${__subdomain}"
				fi
			fi

			if [ "${TANGO_DOMAIN}" = '.*' ]; then
				__hostname="${__subdomain}" 
			else
				__hostname="${__subdomain}${TANGO_SUBDOMAIN_SEPARATOR}${TANGO_DOMAIN}"
				__subdomain="${__subdomain}${TANGO_SUBDOMAIN_SEPARATOR}"
			fi
			
			eval "export ${__service^^}_SUBDOMAIN=${__subdomain}"

			#[ "${TANGO_DOMAIN}" = '.*' ] && __hostname="${__subdomain}" || __hostname="${__subdomain}${TANGO_SUBDOMAIN_SEPARATOR}${TANGO_DOMAIN}"
			eval "export ${__service^^}_HOSTNAME=${__hostname}"
			__add_declared_variables "${__service^^}_HOSTNAME"

			__tango_log "DEBUG" "tango" "service : ${__service} - entrypoints : ${__entrypoints} - subdomain : ${__subdomain} - hostname : ${__hostname}"
		else
			__tango_log "DEBUG" "tango" "service : ${__service} is not attached to any entrypoint"
		fi

		__fill_info="1"
		if ! __check_traefik_router_exist ${__service}; then
			if [ "${__subservice_flag}" = "1" ]; then 
				__tango_log "WARN" "tango" "set_routers_info_service_all : subservice ${__service} not have any traefik router defined in compose file. It may be an error."
			else
				__fill_info=
			fi
		fi

		if [ "${__fill_info}" = "1" ]; then
			for e in ${__entrypoints//,/ }; do
				area="$(__get_network_area_name_from_entrypoint "${e}")"

				__port="NETWORK_PORT_${area^^}"
				__port="${!__port}"
				eval "export ${__service^^}_PORT_${area^^}=${__port}"
				__add_declared_variables "${__service^^}_PORT_${area^^}"

				[ "${__port}" = "" ] && __address="${__hostname}" || __address="${__hostname}:${__port}"
				eval "export ${__service^^}_ADDRESS_${area^^}=${__address}"
				__add_declared_variables "${__service^^}_ADDRESS_${area^^}"

				proto="NETWORK_SERVICES_AREA_${area^^}_PROTO"
				proto="${!proto}"

				eval "export ${__service^^}_PROTO_${area^^}=${proto}"
				__add_declared_variables "${__service^^}_PROTO_${area^^}"

				case $proto in
					http ) __uri="http://${__address}" ;;
					tcp ) __uri="tcp://${__address}" ;;
					udp ) __uri="udp://${__address}" ;;
					* )	__uri="unknow://${__address}" ;;
				esac
				eval "export ${__service^^}_URI_${area^^}=${__uri}"
				__add_declared_variables "${__service^^}_URI_${area^^}"

				if [ "$e" = "${__entrypoint_default}" ]; then
					eval "export ${__service^^}_URI_DEFAULT=${__uri}"
					__add_declared_variables "${__service^^}_URI_DEFAULT"
				fi

				secure_port="NETWORK_SERVICES_AREA_${area^^}_INTERNAL_SECURE_PORT"
				secure_port="${!secure_port}"
				if [ ! "${secure_port}" = "" ] ; then
					__port="NETWORK_PORT_${area^^}_SECURE"
					__port="${!__port}"
					eval "export ${__service^^}_PORT_${area^^}_SECURE=${__port}"
					__add_declared_variables "${__service^^}_PORT_${area^^}_SECURE"

					[ "${__port}" = "" ] && __address="${__hostname}" || __address="${__hostname}:${__port}"
					eval "export ${__service^^}_ADDRESS_${area^^}_SECURE=${__address}"
					__add_declared_variables "${__service^^}_ADDRESS_${area^^}_SECURE"
					
					case $proto in
						http ) __uri="https://${__address}" ;;
						tcp ) __uri="tcp://${__address}" ;;
						udp ) __uri="tcp://${__address}" ;;
						* )	__uri="unknow://${__address}" ;;
					esac
					eval "export ${__service^^}_URI_${area^^}_SECURE=${__uri}"
					__add_declared_variables "${__service^^}_URI_${area^^}_SECURE"

					if [ "$e" = "${__entrypoint_default}" ]; then
						eval "export ${__service^^}_URI_DEFAULT_SECURE=${__uri}"
						__add_declared_variables "${__service^^}_URI_DEFAULT_SECURE"
					fi
				fi
			done
		fi
	done
}

# Define network areas into compose file
# Each network area have traefik entrypoint with a name, a protocol an internal port and an optional associated entrypoint
# The associated entrypoint have same name with postfix _secure is mainly used to declare an alternative HTTPS entrypoint to a HTTP entrypoint
# NETWORK_SERVICES_AREA_LIST=main|tcp|80|443 secondary|tcp|8000|8443 test|udp|41000 
__add_entrypoints_all() {
	
	#local __area_main_done=
	for area in ${NETWORK_SERVICES_AREA_LIST}; do
		IFS="|" read -r name proto internal_port secure_port <<<$(echo ${area})
		__add_entrypoint "$name" "$proto" "$internal_port" "$secure_port"
		#[ "$name" = "main" ] && __area_main_done=1
		__add_declared_variables "NETWORK_SERVICES_AREA_${name^^}"
	done

	# add by default the definition of main network area if not defined in list
	# if [ ! "$__area_main_done" = "1" ]; then
	# 	__add_entrypoint "main" "http" "80" "443"
	# 	NETWORK_SERVICES_AREA_LIST="main|http|80|443 $NETWORK_SERVICES_AREA_LIST"
	# 	__add_declared_variables "NETWORK_SERVICES_AREA_MAIN"
	# fi

}

# __add_entrypoint "test" "udp" "41000"
# 		"--entrypoints.entry_test_udp=true"
#	    "--entrypoints.entry_test_udp.address=:41000/udp"
# __add_entrypoint "second" "tcp" "8000"
# 		"--entrypoints.entry_main_tcp=true"
#	    "--entrypoints.entry_main_tcp.address=:8000/tcp"
# __add_entrypoint "main" "http" "80" "443"
# 		"--entrypoints.entry_main_http=true"
#	    "--entrypoints.entry_main_http.address=:80/tcp"
# 		"--entrypoints.entry_main_http_secure=true"
#	    "--entrypoints.entry_main_http_secure.address=:443/tcp"
__add_entrypoint() {
	local __name="$1"
	local __proto="$2"
	local __internal_port="$3"
	local __associated_entrypoint="$4" # optional
	
	local __real_proto
	
	case ${__proto} in
		http|tcp )
			__real_proto="tcp"
		;;
		udp )
			__real_proto="udp"
		;;
	esac

	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--entrypoints.entry_${__name}_${__proto}=true"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--entrypoints.entry_${__name}_${__proto}.address=:${__internal_port}/${__real_proto}"
	export TRAEFIK_ENTRYPOINTS_LIST="$TRAEFIK_ENTRYPOINTS_LIST entry_${__name}_${__proto}"
	# add port mapping to traefik
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.ports[+]" "\${NETWORK_PORT_${__name^^}}:$__internal_port/${__real_proto}"
	__add_declared_variables "NETWORK_PORT_${__name^^}"
	
	case ${__proto} in
		http )
			export TRAEFIK_ENTRYPOINTS_HTTP_LIST="$TRAEFIK_ENTRYPOINTS_HTTP_LIST entry_${__name}_${__proto}"
			if [ ! "$__associated_entrypoint" = "" ]; then
				yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--entrypoints.entry_${__name}_${__proto}_secure=true"
				yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--entrypoints.entry_${__name}_${__proto}_secure.address=:${__associated_entrypoint}/${__real_proto}"
				export TRAEFIK_ENTRYPOINTS_LIST="$TRAEFIK_ENTRYPOINTS_LIST entry_${__name}_${__proto}_secure"
				export TRAEFIK_ENTRYPOINTS_HTTP_LIST="$TRAEFIK_ENTRYPOINTS_HTTP_LIST entry_${__name}_${__proto}_secure"
				# add port mapping to traefik
				yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.ports[+]" "\${NETWORK_PORT_${__name^^}_SECURE}:$__associated_entrypoint/${__real_proto}"
				__add_declared_variables "NETWORK_PORT_${__name^^}_SECURE"
			fi
		;;
	esac

	TRAEFIK_ENTRYPOINTS_LIST="$($STELLA_API trim ${TRAEFIK_ENTRYPOINTS_LIST})"
	TRAEFIK_ENTRYPOINTS_LIST="${TRAEFIK_ENTRYPOINTS_LIST// /,}"
	__add_declared_variables "TRAEFIK_ENTRYPOINTS_LIST"

	TRAEFIK_ENTRYPOINTS_HTTP_LIST="$($STELLA_API trim ${TRAEFIK_ENTRYPOINTS_HTTP_LIST})"
	TRAEFIK_ENTRYPOINTS_HTTP_LIST="${TRAEFIK_ENTRYPOINTS_HTTP_LIST// /,}"
	__add_declared_variables "TRAEFIK_ENTRYPOINTS_HTTP_LIST"
	
}


__set_network_area_all() {
	
	for area in ${NETWORK_SERVICES_AREA_LIST}; do
		IFS="|" read -r name proto internal_port secure_port <<<$(echo ${area})

		eval "export NETWORK_SERVICES_AREA_${name^^}_PROTO=${proto}"
		__add_declared_variables "NETWORK_SERVICES_AREA_${name^^}_PROTO"
		eval "export NETWORK_SERVICES_AREA_${name^^}_INTERNAL_PORT=${internal_port}"
		__add_declared_variables "NETWORK_SERVICES_AREA_${name^^}_INTERNAL_PORT"
		eval "export NETWORK_SERVICES_AREA_${name^^}_INTERNAL_SECURE_PORT=${secure_port}"
		__add_declared_variables "NETWORK_SERVICES_AREA_${name^^}_INTERNAL_SECURE_PORT"
	done

	
}

# attach all services to entrypoint
__set_entrypoints_service_all() {

	local var
	local __active_service_list="${TANGO_SERVICES_ACTIVE}"

	for area in ${NETWORK_SERVICES_AREA_LIST}; do
		IFS="|" read -r name proto internal_port secure_port <<<$(echo ${area})

		var="NETWORK_SERVICES_AREA_${name^^}"

		# assign each declared service or subservice attached to this area
		for s in ${!var}; do
			__tango_log "DEBUG" "tango" "set_entrypoints_service_all : ${s} is attached to network area : ${name}"
			__set_entrypoint_service "${s}" "${name}"
			__active_service_list="$($STELLA_API filter_list_with_list "${__active_service_list}" "${s}")"
		done
	done

	# exclude services that are not by default attached to a default network area
	__active_service_list="$($STELLA_API filter_list_with_list "${__active_service_list}" "${NETWORK_SERVICES_AREA_DEFAULT_EXCLUDE}")"
	__tango_log "DEBUG" "tango" "set_entrypoints_service_all : services ${__active_service_list} will be attached to a default network area (except ones in NETWORK_SERVICES_AREA_DEFAULT_EXCLUDE:$NETWORK_SERVICES_AREA_DEFAULT_EXCLUDE)"
	# assign remaining services (not subservices) to a default network area
	for s in ${__active_service_list}; do
		if ! __check_traefik_router_exist ${s}; then
			__tango_log "DEBUG" "tango" "set_entrypoints_service_all : ${s} not have any traefik router defined in compose file. May have only subservices. We attach it to a network area, its subservices may use these values as default."
		fi
			var="NETWORK_SERVICES_AREA_${NETWORK_SERVICES_AREA_DEFAULT^^}"
			eval "export ${var}=\"${s} ${!var}\""
			__set_entrypoint_service "${s}" "${NETWORK_SERVICES_AREA_DEFAULT}"
			__tango_log "DEBUG" "tango" "set_entrypoints_service_all : ${s} is attached to default network area : ${NETWORK_SERVICES_AREA_DEFAULT}"
		#fi
	done


}


# parse subservice list to attach each subservice to its parent entrypoint (if parents have an entrypoint and if not already attached)
# note : by default each subservice have the same entrypoint than its parent service
__set_entrypoints_subservice_all() {
	local var
	local parent
	local parent_entrypoints_list
	local parent_entrypoint_default

	__tango_log "DEBUG" "tango" "set_entrypoints_subservice_all : assign subservices list : ${TANGO_SUBSERVICES_ROUTER}"
	for s in ${TANGO_SUBSERVICES_ROUTER}; do

		parent=$(__get_subservice_parent "$s")
		__tango_log "DEBUG" "tango" "L-- set_entrypoints_subservice_all : service ${s} parent service : ${parent}"



		parent_entrypoints_list="${parent^^}_ENTRYPOINTS"
		parent_entrypoints_list="${!parent_entrypoints_list}"
		parent_entrypoint_default="${parent^^}_ENTRYPOINT_DEFAULT"
		parent_entrypoint_default="${!parent_entrypoint_default}"
		var="${s^^}_ENTRYPOINTS"
		# subservice not attached to an entrypoint so attached to the same as its parent
		if [ "${!var}" = "" ]; then
			if [ ! "${parent_entrypoints_list}" = "" ]; then
				eval "export ${var}=${parent_entrypoints_list}"
				__add_declared_variables "${var}"
				eval "export ${s^^}_ENTRYPOINT_DEFAULT=${parent_entrypoint_default}"
				__add_declared_variables "${s^^}_ENTRYPOINT_DEFAULT"
				__tango_log "DEBUG" "tango" "L-- set_entrypoints_subservice_all : assign subservice : ${s} to its parent entrypoints : ${parent_entrypoints_list}"
			fi

			var="${s^^}_ENTRYPOINTS_SECURE"
			parent_entrypoints_list="${parent^^}_ENTRYPOINTS_SECURE"
			parent_entrypoints_list="${!parent_entrypoints_list}"
			parent_entrypoint_default="${parent^^}_ENTRYPOINT_DEFAULT_SECURE"
			parent_entrypoint_default="${!parent_entrypoint_default}"

			if [ ! "${parent_entrypoints_list}" = "" ]; then
				eval "export ${var}=${parent_entrypoints_list}"
				__add_declared_variables "${var}"

				__tango_log "DEBUG" "tango" "L-- set_entrypoints_subservice_all : assign subservice : ${s} to its parent secure entrypoints : ${parent_entrypoints_list}"
				
				eval "export ${s^^}_ENTRYPOINT_DEFAULT_SECURE=${parent_entrypoint_default}"
				__add_declared_variables "${s^^}_ENTRYPOINT_DEFAULT_SECURE"
			fi
		


		else
			__tango_log "DEBUG" "tango" "L-- set_entrypoints_subservice_all : subservice : ${s} was already assigned to its own entrypoints : ${!var}"
		fi

		
	done
}

__set_priority_router_all() {
	
	local __default_priority=${ROUTER_PRIORITY_DEFAULT_VALUE}
	local __priority=

	local __current_parent=
	local __previous_parent
	local __current_offset=0
	
	__tango_log "DEBUG" "tango" "set_priority_router_all : set priority for declared subservices : ${TANGO_SUBSERVICES_ROUTER}"
	# for each declared subservices
	for s in ${TANGO_SUBSERVICES_ROUTER}; do

		__current_parent="$(__get_subservice_parent "${s}")"
		if [ ! "${__current_parent}" = "" ]; then
			if [ "${__current_parent}" = "${__previous_parent}" ]; then
				# same parent service, get a priority bonus
				__priority=$(( __priority + ROUTER_PRIORITY_DEFAULT_STEP ))
				__set_priority_router "${s}" "${__priority}"
			else
				# set first surbservice of a parent service
				__priority=$(( __default_priority + ROUTER_PRIORITY_DEFAULT_STEP ))
				__set_priority_router "${s}" "${__priority}"
			fi
		fi
		__previous_parent="${__current_parent}"
	done


	
	# affect priority to other services
	__tango_log "DEBUG" "tango" "set_priority_router_all : set priority for other services : ${TANGO_SERVICES_AVAILABLE}"
	for s in ${TANGO_SERVICES_AVAILABLE}; do
		__set_priority_router "${s}" "${__default_priority}"
	done
}


# HTTP to HTTPS redirect routers - catch all request and redirect to secure entrypoint with HTTPS scheme if it is not the case
# NOTE : we cannot use the method of set redirect middleware on each routers service because each service routers
#        may have two entrypoints and middlewares dont know from which entrypoint the request come.
#        So we use a global catch all router rule, using priority for exclude some services
# NOTE : a redirect middleware will be dynamicly attached on each of these http-catchall-web_* routers
__set_redirect_https_service_all() {
	case ${NETWORK_REDIRECT_HTTPS} in
		enable )
			# create catchall routers
			for area in ${NETWORK_SERVICES_AREA_LIST}; do
				IFS="|" read -r name proto internal_port secure_port <<<$(echo ${area})
				if [ "$proto" = "http" ]; then
					if [ ! "$secure_port" = "" ]; then
						# catch HTTP request on entry_xxx_tcp and entry_xxx_tcp_secure entrypoint
						yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.labels[+]" "traefik.http.routers.http-catchall-entry_${name}_${proto}.entrypoints=entry_${name}_${proto},entry_${name}_${proto}_secure"
						yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.labels[+]" "traefik.http.routers.http-catchall-entry_${name}_${proto}.rule=HostRegexp(\`{host:.+}\`)"
						yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.labels[+]" "traefik.http.routers.http-catchall-entry_${name}_${proto}.priority=\${ROUTER_PRIORITY_HTTP_TO_HTTPS_VALUE}"
						# catch HTTPS request on entry_xxx_tcp only entrypoint (no need to catch HTTPS on entry_xxx_tcp_secure)
						yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.labels[+]" "traefik.http.routers.http-catchall-entry_${name}_${proto}_secure.entrypoints=entry_${name}_${proto}"
						yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.labels[+]" "traefik.http.routers.http-catchall-entry_${name}_${proto}_secure.rule=HostRegexp(\`{host:.+}\`)"
						yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.labels[+]" "traefik.http.routers.http-catchall-entry_${name}_${proto}_secure.priority=\${ROUTER_PRIORITY_HTTP_TO_HTTPS_VALUE}"
						yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.labels[+]" "traefik.http.routers.http-catchall-entry_${name}_${proto}_secure.tls=true"
						
						# - "traefik.http.routers.http-catchall-entry_admin_tcp.entrypoints=entry_admin_tcp,entry_admin_tcp_secure"
						# - "traefik.http.routers.http-catchall-entry_admin_tcp.rule=HostRegexp(`{host:.+}`)"
						# - "traefik.http.routers.http-catchall-entry_admin_tcp.priority=${ROUTER_PRIORITY_HTTP_TO_HTTPS_VALUE}"

						# - "traefik.http.routers.http-catchall-entry_admin_tcp_secure.entrypoints=entry_admin_tcp"
						# - "traefik.http.routers.http-catchall-entry_admin_tcp_secure.rule=HostRegexp(`{host:.+}`)"
						# - "traefik.http.routers.http-catchall-entry_admin_tcp_secure.priority=${ROUTER_PRIORITY_HTTP_TO_HTTPS_VALUE}"
						# - "traefik.http.routers.http-catchall-entry_admin_tcp_secure.tls=true"
						
						# declare HTTP to HTTPS redirect middlewares
						yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.labels[+]" "traefik.http.middlewares.redirect-entry_${name}_${proto}_secure.redirectscheme.scheme=https"
						yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.labels[+]" "traefik.http.middlewares.redirect-entry_${name}_${proto}_secure.redirectscheme.permanent=true"
						yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.labels[+]" "traefik.http.middlewares.redirect-entry_${name}_${proto}_secure.redirectscheme.port=\${NETWORK_PORT_${name^^}_SECURE}"
						
						# - "traefik.http.middlewares.redirect-entry_main_tcp_secure.redirectscheme.scheme=https"
						# - "traefik.http.middlewares.redirect-entry_main_tcp_secure.redirectscheme.permanent=true"
						# - "traefik.http.middlewares.redirect-entry_main_tcp_secure.redirectscheme.port=${NETWORK_PORT_MAIN_SECURE}"

						# add middleware to catchall routers
						yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.labels[+]" "traefik.http.routers.http-catchall-entry_${name}_${proto}.middlewares=redirect-entry_${name}_${proto}_secure@docker"
						yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.labels[+]" "traefik.http.routers.http-catchall-entry_${name}_${proto}_secure.middlewares=redirect-entry_${name}_${proto}_secure@docker"	

						#   - traefik.http.routers.http-catchall-entry_main_tcp.middlewares=redirect-entry_main_tcp_secure@docker
						#   - traefik.http.routers.http-catchall-entry_main_tcp_secure.middlewares=redirect-entry_main_tcp_secure@docker
					fi
				fi
			done

			for s in ${NETWORK_SERVICES_REDIRECT_HTTPS}; do
				__set_redirect_https_service "${s}"
			done
		;;
		* )
		;;
	esac

	
}


__add_service_direct_port_access_all() {
	for s in $(compgen -A variable | grep _DIRECT_ACCESS_PORT$); do
		port="${!s}"
		if [ ! "${port}" = "" ]; then
			service="${s%_DIRECT_ACCESS_PORT}"
			service="${service,,}"
			
			if __check_docker_compose_service_exist "${service}"; then
				port_inside="$(yq r "${GENERATED_DOCKER_COMPOSE_FILE}" services.$service.expose[0])"
				if [ ! "${port_inside}" = "" ]; then
					__tango_log "INFO" "tango" "Setting direct access to $service port (bypass reverse proxy) : mapping $port to $port_inside"
					yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.$service.ports[+]" "$port:$port_inside"
				else
					__tango_log "WARN" "tango" "can not set direct access to $service through $port : Unknown inside port to map to. Inside port must be declared as first port in expose section."
				fi
			else
				__tango_log "WARN" "tango" "unknow service ${service} declared in ${s}"
			fi
		fi
	done
}

# ITEMS MANAGEMENT (an item is a module or a plugin) -----------------------------------------

__set_module_all() {


	__tango_log "DEBUG" "tango" "set_module_all : process scaled modules list : ${TANGO_SERVICES_MODULES_SCALED}"
	local __module_instances_list_full=
	local __instances_names_list_processed=

	# NOTE : we cannot use TANGO_SERVICES_MODULES_SCALED_FULL because __set_module need the instance name not the module name
	for m in ${TANGO_SERVICES_MODULES_SCALED}; do
		__module_instances_list_full="${m^^}_INSTANCES_LIST_FULL"
		__instances_names_list_processed="${__instances_names_list_processed} ${!__module_instances_list_full}"
		for i in ${!__module_instances_list_full}; do
			__set_module "$i" "${m}"
		done
	done

	
	# remove from list scaled modules already processed
	local __array_list_full=( $($STELLA_API filter_list_with_list "${TANGO_SERVICES_MODULES_FULL}" "${TANGO_SERVICES_MODULES_SCALED_FULL}") )
	__tango_log "DEBUG" "tango" "set_module_all : process other modules : ${__array_list_full[*]}"
	for m in ${__array_list_full[*]}; do
		__set_module "${m}"
	done
	__instances_names_list_processed="${__instances_names_list_processed} ${TANGO_SERVICES_MODULES_SCALED}"

	# TODO CONTINUE HERE : TANGO_SERVICES_MODULES_SCALED contents should be added to TANGO_SERVICES_MODULES (and in cascade to TANGO_SERVICES_AVAILABLE and TANGO_SERVICES_ACTIVE) so that when calling create_env_file dependencies env file are also included (and dependencies module also became TANGO_SERVICES_DEPENDS_ON_TRAEFIK)
	# process modules dependencies not already processed
	local __array_list_dep=( $($STELLA_API filter_list_with_list "${TANGO_SERVICES_MODULES_LINKS}" "${__instances_names_list_processed}") )
	__tango_log "DEBUG" "tango" "set_module_all : process dependencies modules : ${__array_list_dep[*]}"
	for m in ${__array_list_dep[*]}; do
		__set_module "${m}"
	done
}

__set_module() {
	local __module="$1"
	# optional - name of the module which have been scaled
	local __original_module_scaled="$2"

	__tango_log "DEBUG" "tango" "set_module : process module declared with this form : ${__module}"

	__parse_item "module" "${__module}" "_MODULE"
	__tango_log "DEBUG" "tango" "set_module : parse module name : ${_MODULE_NAME}"
	__module="${_MODULE_NAME}"
	local __owner="${_MODULE_OWNER}"

	if [ ! ${__original_module_scaled} = "" ]; then
		__parse_item "module" "${__original_module_scaled}" "_ORIGINAL"
		__tango_log "DEBUG" "tango" "set_module : parse original module name : ${_ORIGINAL_NAME}"
		 __owner="${_ORIGINAL_OWNER}"
	fi

	# add yml to docker compose file
	case ${__owner} in
		CTX )
			__tango_log "DEBUG" "tango" "set_module : ${__module} is an ctx module"
			if [ "$__original_module_scaled" = "" ]; then
				yq m -i -a=append -- "${GENERATED_DOCKER_COMPOSE_FILE}" <(yq r --explodeAnchors "${TANGO_CTX_MODULES_ROOT}/${_MODULE_NAME}.yml")
			else
				# we replace all ocurrence of module name with an instance name
				# except into lines containing FIXED_VAR expression anywhere
				# and except expression beginning with SHARED_VAR_
				# use sed implementation of negative lookbehind https://stackoverflow.com/a/26110465
				__tango_log "DEBUG" "tango" "set_module : ${__module} is an instance of scaled module : $_ORIGINAL_NAME"
				#yq m -i -a=append -- "${GENERATED_DOCKER_COMPOSE_FILE}" <(yq r --explodeAnchors "${TANGO_CTX_MODULES_ROOT}/${_ORIGINAL_NAME}.yml" | sed -e "/FIXED_VAR/!s/${_ORIGINAL_NAME}\([^a-zA-Z0-9]*\)/${_MODULE_NAME}\1/g" -e "/FIXED_VAR/!s/${_ORIGINAL_NAME^^}\([^a-zA-Z0-9]*\)/${_MODULE_NAME^^}\1/g")
				yq m -i -a=append -- "${GENERATED_DOCKER_COMPOSE_FILE}" <(yq r --explodeAnchors "${TANGO_CTX_MODULES_ROOT}/${_ORIGINAL_NAME}.yml" | sed -E "{/FIXED_VAR/! {s/#/##/g; s/(SHARED_VAR_)(${_ORIGINAL_NAME})/\1_#_/g; s/(SHARED_VAR_)(${_ORIGINAL_NAME^^})/\1-#-/g; s/${_ORIGINAL_NAME}([^a-zA-Z0-9]*)/${_MODULE_NAME}\1/g; s/${_ORIGINAL_NAME^^}([^a-zA-Z0-9]*)/${_MODULE_NAME^^}\1/g; s/(SHARED_VAR_)_#_/\1${_ORIGINAL_NAME}/g; s/(SHARED_VAR_)-#-/\1${_ORIGINAL_NAME^^}/g; s/##/#/g} }")
			fi
		;;
		TANGO )
			__tango_log "DEBUG" "tango" "set_module : ${__module} is a tango module"
			if [ "$__original_module_scaled" = "" ]; then
				yq m -i -a=append -- "${GENERATED_DOCKER_COMPOSE_FILE}" <(yq r --explodeAnchors "${TANGO_MODULES_ROOT}/${_MODULE_NAME}.yml")
			else
				# we replace all ocurrence of module name with an instance name
				# except into lines containing FIXED_VAR expression anywhere
				# and except expression beginning with SHARED_VAR_
				# use sed implementation of negative lookbehind https://stackoverflow.com/a/26110465
				__tango_log "DEBUG" "tango" "set_module : ${__module} is an instance of scaled module : $_ORIGINAL_NAME"
				#yq m -i -a=append -- "${GENERATED_DOCKER_COMPOSE_FILE}" <(yq r --explodeAnchors "${TANGO_MODULES_ROOT}/${_ORIGINAL_NAME}.yml" | sed -e "/FIXED_VAR/!s/${_ORIGINAL_NAME}\([^a-zA-Z0-9]*\)/${_MODULE_NAME}\1/g" -e "/FIXED_VAR/!s/${_ORIGINAL_NAME^^}\([^a-zA-Z0-9]*\)/${_MODULE_NAME^^}\1/g")
				yq m -i -a=append -- "${GENERATED_DOCKER_COMPOSE_FILE}" <(yq r --explodeAnchors "${TANGO_MODULES_ROOT}/${_ORIGINAL_NAME}.yml" | sed -E "{/FIXED_VAR/! {s/#/##/g; s/(SHARED_VAR_)(${_ORIGINAL_NAME})/\1_#_/g; s/(SHARED_VAR_)(${_ORIGINAL_NAME^^})/\1-#-/g; s/${_ORIGINAL_NAME}([^a-zA-Z0-9]*)/${_MODULE_NAME}\1/g; s/${_ORIGINAL_NAME^^}([^a-zA-Z0-9]*)/${_MODULE_NAME^^}\1/g; s/(SHARED_VAR_)_#_/\1${_ORIGINAL_NAME}/g; s/(SHARED_VAR_)-#-/\1${_ORIGINAL_NAME^^}/g; s/##/#/g} }")
			fi
		;;
	esac

	# entrypoint
	# NOTE : _MODULE_NETWORK_AREA is setted by __parse_item
	local __area=
	local __area_services=
	# module is attached to a network via its form <module>[@<network area>]
	if [ ! "${_MODULE_NETWORK_AREA}" = "" ]; then
		__tango_log "DEBUG" "tango" "set_module : network area declared : $_MODULE_NETWORK_AREA"

		# detect if module is attached to some network area through variable declaration NETWORK_SERVICES_AREA_*
		for a in ${NETWORK_SERVICES_AREA_LIST}; do
			IFS="|" read -r name proto internal_port secure_port <<<$(echo ${a})
			__area_services="NETWORK_SERVICES_AREA_${name^^}"
			if $STELLA_API list_contains "${!__area_services}" "${__module}"; then
				__tango_log "DEBUG" "tango" "set_module : ${__module} dettach from network area : $name"
				eval "export ${__area_services}=\"$($STELLA_API filter_list_with_list "${!__area_services}" "${__module}")\""
			fi
		done
		

		__area_services="NETWORK_SERVICES_AREA_${_MODULE_NETWORK_AREA^^}"
		eval "export ${__area_services}=\"${!__area_services} ${__module}\""
		__tango_log "DEBUG" "tango" "set_module : ${__module} is now attached to network area : $_MODULE_NETWORK_AREA"

	else
		__tango_log "DEBUG" "tango" "set_module : no network area in ${__module} form declaration"
		if ! __check_traefik_router_exist ${__module}; then
			__tango_log "DEBUG" "tango" "set_module : ${__module} not have any traefik router defined in compose file. May have only subservices. We attach it to a network area, its subservices may use these values as default."
		fi
		# check if module is attached to some network area through variable declaration NETWORK_SERVICES_AREA_*
		for a in ${NETWORK_SERVICES_AREA_LIST}; do
			IFS="|" read -r name proto internal_port secure_port <<<$(echo ${a})
			__area_services="NETWORK_SERVICES_AREA_${name^^}"
			if $STELLA_API list_contains "${!__area_services}" "${__module}"; then
				__area="${name}"
				__tango_log "DEBUG" "tango" "set_module : ${__module} is declared being attached to network area : $name through variable : ${__area_services}"
			fi
		done
		# if there is no attached network area, attach to the default one
		if [ "$__area" = "" ]; then
			__area="${NETWORK_SERVICES_AREA_DEFAULT}"
			__tango_log "DEBUG" "tango" "set_module : ${__module} is now attached to the default tango network area : $__area"
			__area_services="NETWORK_SERVICES_AREA_${__area^^}"
			eval "export ${__area_services}=\"${!__area_services} ${_MODULE_NAME}\""
		fi
					
		#fi
	fi	

	# dependencies
	__tango_log "DEBUG" "tango" "set_module : ${__module} declared depends on : ${_MODULE_LINKS}"
	local __dep_disabled="$($STELLA_API filter_list_with_list "${_MODULE_LINKS}" "${TANGO_SERVICES_DISABLED}" "FILTER_KEEP")"
	[ -n "${__dep_disabled}" ] && __tango_log "WARN" "tango" "when this module ${__module} is enabled, these dependencies will be enabled even they were explicity disabled : ${__dep_disabled}"
	for d in ${_MODULE_LINKS}; do
		__add_service_dependency "${__module}" "${d,,}"
	done

	# vpn
	local _vpn=
	__tango_log "DEBUG" "tango" "set_module : ${__module} declared to be attached to vpn id : ${_MODULE_VPN_ID}"
	if [ ! "${_MODULE_VPN_ID}" = "" ]; then 
		_vpn="${_MODULE_VPN_ID^^}_SERVICES" && eval "export ${_vpn}=\"${!_vpn} ${__module}\""
	fi

}

# get a list of instances name for a scaled item
# for a module named 'mod' with MOD_INSTANCES_LIST="foo bar"
#		__get_scaled_item_instances_list "mod" "4"   --> "foo bar mod_instance_3 mod_instance_4"
#		__get_scaled_item_instances_list "mod" "1"   --> "foo"
__get_scaled_item_instances_list() {
	local __item_name="$1"
	local __instances_nb="$2"

	local __instances_list=
	local __list=
	local __size=0
	local __nb=

	if [ "${__instances_nb}" -le 0 ]; then
		echo -n
	else
		# predefined instances list
		__instances_list="${__item_name^^}_INSTANCES_LIST"
		__instances_list="${!__instances_list}"

		for i in ${__instances_list}; do ((__size ++)); done
		if [ ${__instances_nb} -gt ${__size} ]; then
			
			__nb=$(( __instances_nb - ${__size} ))
			for i in $(seq $((__size+1)) $((__size+__nb)) ); do
				__instances_list="${__instances_list} ${__item_name}_instance_${i}"
			done
			__instances_list="$($STELLA_API trim "${__instances_list}")"
			echo -n "${__instances_list}"
		else
			__nb=0
			for i in ${__instances_list}; do
				__list="${__list} ${__item_name}_${i}"
				((__nb++))
				[ ${__nb} -eq ${__instances_nb} ] && break
			done
			__list="$($STELLA_API trim "${__list}")"
			echo -n "${__list}"
		fi
	fi

}

# exec all plugins programmed to auto exec at launch of all active service
__exec_auto_plugin_service_active_all() {
	local __plugin
	for s in ${TANGO_SERVICES_ACTIVE}; do
		__exec_auto_plugin_all_by_service ${s}
	done
}

# exec all plugins programmed to auto exec at launch of a service
__exec_auto_plugin_all_by_service() {
	local __service="$1"
	local __plugins="${TANGO_PLUGINS_BY_SERVICE_FULL_AUTO_EXEC[$__service]}"

	if [ ! "${__plugins}" = "" ]; then
		for p in ${__plugins}; do			
			__exec_plugin "${__service}" "${p}"
		done
	fi
}

# exec all plugins attached to a service
__exec_plugin_all_by_service() {
	local __service="$1"
	local __plugins="${TANGO_PLUGINS_BY_SERVICE_FULL[$__service]}"

	if [ ! "${__plugins}" = "" ]; then
		for p in ${__plugins}; do 
			__exec_plugin "${__service}" "${p}"
		done
	fi
}


# exec a plugin into all attached service
__exec_plugin_into_services() {
	local __plugin="$1"
	local __services="${TANGO_SERVICES_BY_PLUGIN_FULL[$__plugin]}"

	if [ ! "${__services}" = "" ]; then
		for s in ${__services}; do 
			__exec_plugin "${s}" "${__plugin}"
		done
	fi
}



# execute a plugin into a service context
__exec_plugin() {
	local __service="$1"
	local __plugin="$2"

	local __instances=

	__parse_item "plugin" "${__plugin}" "PLUGIN"

	# case : module have been scaled
	if $STELLA_API list_contains "${TANGO_SERVICES_MODULES_SCALED}" "${__service}"; then
		__tango_log "INFO" "tango" "    Plugin execution : ${PLUGIN_NAME}"
		__tango_log "INFO" "tango" "      with args list : ${PLUGIN_ARG_LIST}"
		__tango_log "INFO" "tango" " into scaled service : ${__service}"
		__instances="${__service^^}_INSTANCES_LIST"
		for i in ${!__instances}; do
			__tango_log "INFO" "tango" "            instance : ${i}"
			docker-compose exec --user ${TANGO_USER_ID}:${TANGO_GROUP_ID} ${i} /bin/sh -c '[ "'${PLUGIN_OWNER}'" = "CTX" ] && /pool/'${TANGO_CTX_NAME}'/plugins/'${PLUGIN_NAME}' '${PLUGIN_ARG_LIST}' || /pool/tango/plugins/'${PLUGIN_NAME}' '${PLUGIN_ARG_LIST}
		done
	else

		__tango_log "INFO" "tango" "Plugin execution : ${PLUGIN_NAME}"
		__tango_log "INFO" "tango" "  with args list : ${PLUGIN_ARG_LIST}"
		__tango_log "INFO" "tango" "	into service : ${__service}"

		docker-compose exec --user ${TANGO_USER_ID}:${TANGO_GROUP_ID} ${__service} /bin/sh -c '[ "'${PLUGIN_OWNER}'" = "CTX" ] && /pool/'${TANGO_CTX_NAME}'/plugins/'${PLUGIN_NAME}' '${PLUGIN_ARG_LIST}' || /pool/tango/plugins/'${PLUGIN_NAME}' '${PLUGIN_ARG_LIST}
	fi
}


# cumulate items activated through command line AND shell environment variable
# if item was activated twice through environnment variable AND command line
# keeping only command line declaration which override the other
# type : module | plugin
__add_item_declaration_from_cmdline() {
	local __type="${1}"

	local __list_full=
	local __cmd_line_option=
	local __list_names_from_cmd_line=
	local __name=
	local __result_list=
	case ${__type} in
		module )
			__list_full="${TANGO_SERVICES_MODULES}"
			__tango_log "DEBUG" "tango" "add_item_declaration_from_cmdline : TANGO_SERVICES_MODULES : $TANGO_SERVICES_MODULES"
			__cmd_line_option="${MODULE//:/ }"
			__tango_log "DEBUG" "tango" "add_item_declaration_from_cmdline : cmd_line_option : $__cmd_line_option "
		;;
		plugin )
			__list_full="${TANGO_PLUGINS}"
			__tango_log "DEBUG" "tango" "add_item_declaration_from_cmdline : TANGO_PLUGINS : $TANGO_PLUGINS"
			__cmd_line_option="${PLUGIN//:/ }"
			__tango_log "DEBUG" "tango" "add_item_declaration_from_cmdline : cmd_line_option : $__cmd_line_option"
		;;
	esac

	__list_names_from_cmd_line="$(echo "${__cmd_line_option//:/ }" | sed -e 's/[@%\^#~][^ ]* */ /g')"
	__result_list="${__cmd_line_option}"
	for m in ${__list_full}; do
		case ${__type} in
			module ) __name="$(echo $m | sed 's,^\([^@%\^~]*\).*$,\1,')" ;;
			plugin ) __name="$(echo $m | sed 's,^\([^#%]*\).*$,\1,')" ;;
		esac
		if ! $STELLA_API list_contains "${__list_names_from_cmd_line}" "${__name}"; then
			__result_list="${__result_list} ${m}"
		else
			__tango_log "WARN" "tango" "${__type} ${__name} was activated twice through variable and command line. Picking command line activation : ${m}."
		fi
	done

	__tango_log "DEBUG" "tango" "add_item_declaration_from_cmdline : result_list : $__result_list "
	case ${__type} in
		module )
			TANGO_SERVICES_MODULES="${__result_list}"
		;;
		plugin )
			TANGO_PLUGINS="${__result_list}"
		;;
	esac
}

# filter and scale existing items
#  - split item list between full list and name list
#  - build associative array for mapping service and plugin that are attached to 
#  - parse scaled module and fix modules list
# type : module | plugin
__filter_and_scale_items() {

	local __type="${1}"

	__tango_log "DEBUG" "tango" "filter_and_scale_items ${__type}s"

	local __list_full=
	local __list_names=
	local __ctx_folder=
	local __tango_folder=
	local __file_ext=
	local __list_dep=
	case ${__type} in
		module )
			__list_full="${TANGO_SERVICES_MODULES}"
			__ctx_folder="${TANGO_CTX_MODULES_ROOT}"
			__tango_folder="${TANGO_MODULES_ROOT}"
			__file_ext='.yml'
		;;

		plugin )
			__list_full="${TANGO_PLUGINS}"
			__ctx_folder="${TANGO_CTX_PLUGINS_ROOT}"
			__tango_folder="${TANGO_PLUGINS_ROOT}"
			__file_ext=
		;;
	
	esac

	__list_names="$(echo "${__list_full}" | sed -e 's/[@%~\^#][^ ]* */ /g')"


	# filter existing items
	local __name
	local __full
	local __var
	local __d
	local __array_list_names=( $__list_names )
	local __array_list_full=( $__list_full )
	local __list_instances_names=
	__list_full=

	for index in ${!__array_list_names[*]}; do
	
		__item_exists=
		__item_scalable=
		__name="${__array_list_names[$index]}"
		__full="${__array_list_full[$index]}"
		# look for an existing item file in current ctx
		if [ -f "${__ctx_folder}/${__name}${__file_ext}" ]; then
			__item_exists="1"
			[ -f "${__ctx_folder}/${__name}.scalable" ] && __item_scalable="1"
		else
			# look for an existing item file in tango folder
			if [ -f "${__tango_folder}/${__name}${__file_ext}" ]; then
				__item_exists="1"
				[ -f "${__tango_folder}/${__name}.scalable" ] && __item_scalable="1"
			fi
		fi



		if [ "${__item_exists}" = "1" ]; then
			
			case ${__type} in
				plugin )
					__parse_item "plugin" "${__array_list_full[$index]}" "PLUGIN"
					for s in ${PLUGIN_LINKS}; do
						TANGO_PLUGINS_BY_SERVICE_FULL["${s}"]="${TANGO_PLUGINS_BY_SERVICE_FULL[$s]} ${__full}"
						TANGO_SERVICES_BY_PLUGIN_FULL["${__name}"]="${TANGO_SERVICES_BY_PLUGIN_FULL[${__name}]} ${s}"
					done
					for s in ${PLUGIN_LINKS_AUTO_EXEC}; do
						TANGO_PLUGINS_BY_SERVICE_FULL_AUTO_EXEC["${s}"]="${TANGO_PLUGINS_BY_SERVICE_FULL_AUTO_EXEC[$s]} ${__full}"
					done
					__list_instances_names="${__list_instances_names} ${__name}"
					__list_full="${__list_full} ${__full}"
				;;

				module )
					__parse_item "module" "${__array_list_full[$index]}" "MODULE"
					# test if this module is scaled to nb instances
					if [ ! "$MODULE_INSTANCES_NB" = "" ]; then
						
						if [ "${__item_scalable}" = "1" ]; then
							eval "export ${__name^^}_IS_SCALABLE=1"
							__add_declared_variables "${__name^^}_IS_SCALABLE"

							TANGO_SERVICES_MODULES_SCALED="${TANGO_SERVICES_MODULES_SCALED} ${__name}"
							TANGO_SERVICES_MODULES_SCALED_FULL="${TANGO_SERVICES_MODULES_SCALED_FULL} ${__name}${MODULE_EXTENDED_DEF}"

							__var="$(__get_scaled_item_instances_list "${__name}" "$MODULE_INSTANCES_NB")"
							eval "export ${__name^^}_INSTANCES_LIST=\"${__var}\""
							__add_declared_variables "${__name^^}_INSTANCES_LIST"
							eval "export ${__name^^}_INSTANCES_NB=${MODULE_INSTANCES_NB}"
							__add_declared_variables "${__name^^}_INSTANCES_NB"
							
							# dependencies : cumulate with dependencies declared with variable _LINKS
							if [ -n "${MODULE_LINKS}" ]; then
								for i in ${__var}; do
									eval "export ${i^^}_LINKS=\"${MODULE_LINKS} ${i^^}_LINKS\""
									__add_declared_variables "${i^^}_LINKS"
								done
							fi

							__list_instances_names="${__list_instances_names} ${__var}"
							__var="${__var// /$MODULE_WITHOUT_SCALE_EXTENDED_DEF }"
							eval "export ${__name^^}_INSTANCES_LIST_FULL=\"${__var}${MODULE_WITHOUT_SCALE_EXTENDED_DEF}\""
							__add_declared_variables "${__name^^}_INSTANCES_LIST_FULL"
							
							__list_full="${__list_full} ${__name}"
							__list_full="${__list_full}${MODULE_EXTENDED_DEF}"

							__tango_log "DEBUG" "tango" "filter_and_scale_items : module ${__name} is scaled to ${MODULE_INSTANCES_NB} instances"
						else
							__tango_log "ERROR" "tango" "Trying to scale ${__name} to ${MODULE_INSTANCES_NB}, but this module have not be designed to be scaled (no ${__name}.scalable file found)."
							exit 1
						fi
					else
						__list_instances_names="${__list_instances_names} ${__name}"
						__list_full="${__list_full} ${__full}"

						# dependencies : cumulate with dependencies declared with variable _LINKS TODO CONTINUE HERE
						__d="${__name^^}_LINKS"
						[ -n "${MODULE_LINKS}" ] && eval "export ${__name^^}_LINKS=\"${MODULE_LINKS} ${!__d}\""
						__add_declared_variables "${__name^^}_LINKS"
					fi
					__list_dep="${__list_dep} ${MODULE_LINKS}"
				;;
			esac
			
		else
			__tango_log "WARN" "tango" "${__type} ${__name} not found."
		fi
	done



	# FULL list conserve existing items in full declarative format
	# standard list conserve existing items with only intances names
	case ${__type} in
		module )
			TANGO_SERVICES_MODULES_LINKS="$($STELLA_API list_filter_duplicate "${__list_dep}")"
			TANGO_SERVICES_MODULES_FULL="${__list_full}"
			TANGO_SERVICES_MODULES="${__list_instances_names}"

			#__recursive_module_links "${TANGO_SERVICES_MODULES_LINKS}"
			#exit TODO CONTINUE HERE

			__tango_log "DEBUG" "tango" "filter_and_scale_items : existing modules full format list : ${TANGO_SERVICES_MODULES_FULL}"
			__tango_log "DEBUG" "tango" "filter_and_scale_items : existing modules instances names : ${TANGO_SERVICES_MODULES}"
			__tango_log "DEBUG" "tango" "filter_and_scale_items : modules which are dependencies of others : ${TANGO_SERVICES_MODULES_LINKS}"
			
		;;
		plugin )
			TANGO_PLUGINS_FULL="${__list_full}"
			TANGO_PLUGINS="${__list_instances_names}"
			__tango_log "DEBUG" "tango" "filter_and_scale_items : existing plugins full format list : ${TANGO_PLUGINS_FULL}"
			__tango_log "DEBUG" "tango" "filter_and_scale_items : existing plugins : ${TANGO_PLUGINS}"
		;;
	esac

}

# TODO CONTINUE HERE
# __process_dependencies() {
# 	__tango_log "DEBUG" "tango" "__process_dependencies"

# }

# A=1
# __recursive_module_links() {
# 	local __list="$1"
# 	local __sublist=
# 	local __linked=

# 	for m in ${__list}; do
# 		__linked="${m^^}_LINKS"
# 		echo ${__linked}
# 		for d in ${!__linked}; do
# 		echo $d
# 			__sublist="${__sublist} $d"
# 		done
# 	done
# 	((A++))
# 	[ $A -gt 2 ] && echo "${__list} ${__sublist}" || echo "${__list} ${__sublist} $(__recursive_module_links "${__sublist}")"
# }

# type : module | plugin | middleware | volume | ports
# item format :
#	 	<module>[@<network area>][%<service dependency1>][%<service dependency2>][^nb instance][~<vpn id>]
#		<plugin>[%<auto exec at launch into service1>][%!<manual exec into service2>][#arg1][#arg2]
#		<middleware_name>[:<position>:[<position number>]]
#		<network area>@<port>[@<secure port>]
#		<named volume|path|#variable path name>:<path|#variable path name>[:ro|rw]
#				ex : FOO_ADDITIONAL_VOLUMES=calibredb_books:/books /foo:#INTERNAL_PRESS_PATH:ro
#					 TANGO_VOLUMES=calibredb_press:#PRESS_PATH volume:#VOLUME_PATH
# __result_prefix : variable prefix to store result
__parse_item() {
	local __type="$1"
	local __item="$2"
	local __result_prefix="$3"

	local __ctx_folder=
	local __tango_folder=
	local __file_ext=

	# item name and extended part
	local __name=
	local __ext=
	local __wo_scale_ext=

	# name
	eval ${__result_prefix}_NAME=
	# extended part of item definition (everything except name)
	eval ${__result_prefix}_EXTENDED_DEF=

	case ${__type} in

		plugin)
			# item is in CTX or TANGO folder
			eval ${__result_prefix}_OWNER=
			# arguments list to pass to item
			eval ${__result_prefix}_ARG_LIST=
			# links list : attach point for plugin to services that will be executed at launch
			eval ${__result_prefix}_LINKS_AUTO_EXEC=
			# links list : services dependencies for module OR attach point for plugin (with auto exec at launch or not)
			eval ${__result_prefix}_LINKS=
		;;
		module)
			# extended part of module definition (everything except name AND nb instances)
			eval ${__result_prefix}_WITHOUT_SCALE_EXTENDED_DEF=
			# item is in CTX or TANGO folder
			eval ${__result_prefix}_OWNER=
			# scale module to nb instances
			eval ${__result_prefix}_INSTANCES_NB=
			# network area to bind item to
			eval ${__result_prefix}_NETWORK_AREA=
			# links list : services dependencies for module OR attach point for plugin (with auto exec at launch or not)
			eval ${__result_prefix}_LINKS=
			# vpn id to bind item to
			eval ${__result_prefix}_VPN_ID=
		;;
		port)
			# ports
			eval ${__result_prefix}_PORT=
			eval ${__result_prefix}_SECURE_PORT=
		;;
		middleware)
			# middleware relative position
			eval ${__result_prefix}_POSITION=
			# middleware absolute position
			eval ${__result_prefix}_POS_NUMBER=
		;;
		volume)
			# volume paths
			eval ${__result_prefix}_OUTSIDE_PATH=
			eval ${__result_prefix}_INSIDE_PATH=
			# volume paths variables names
			eval ${__result_prefix}_OUTSIDE_PATH_VARIABLE=
			eval ${__result_prefix}_INSIDE_PATH_VARIABLE=
			# rw/ro modes
			eval ${__result_prefix}_MODE=
		;;

	esac



	case ${__type} in 
		plugin)
			__name="$(echo $__item | sed 's,^\([^#%]*\).*$,\1,')"
			eval ${__result_prefix}_NAME="${__name}"
			__ext="$(echo $__item | sed 's,^\([^#%]*\)\(.*\)$,\2,')"
			eval ${__result_prefix}_EXTENDED_DEF="${__ext}"
		;;

		module)
			__name="$(echo $__item | sed 's,^\([^~@%\^]*\).*$,\1,')"
			eval ${__result_prefix}_NAME="${__name}"
			__ext="$(echo $__item | sed 's,^\([^~@%\^]*\)\(.*\)$,\2,')"
			eval ${__result_prefix}_EXTENDED_DEF="${__ext}"
			__wo_scale_ext="$(echo $__item | sed -e 's,^\([^~@%\^]*\)\(.*\)$,\2,' -e 's,\^[^~@#%]*,,')"
			eval ${__result_prefix}_WITHOUT_SCALE_EXTENDED_DEF="${__wo_scale_ext}"
			;;


		volume)

			if [ ! -z "${__item##*:*}" ]; then
				__tango_log "ERROR" "tango" "parse_item : error while parsing volume definition ${__item}. Syntax : <named volume|path|#variable path name>:<path|#variable path name>[:ro|rw]"
				exit 1
			fi
			__item=(${__item//:/ })


			# volume path variable name
			# symbol : #
			local __variable_path_name=
		
			if [ -z "${__item[0]##*#*}" ]; then
				__variable_path_name="${__item[0]//#/}"
				eval ${__result_prefix}_OUTSIDE_PATH_VARIABLE="${__variable_path_name}"
			else
				eval ${__result_prefix}_OUTSIDE_PATH="${__item[0]}"
			fi
			if [ -z "${__item[1]##*#*}" ]; then
				__variable_path_name="${__item[1]//#/}"
				eval ${__result_prefix}_INSIDE_PATH_VARIABLE="${__variable_path_name}"
			else
				eval ${__result_prefix}_INSIDE_PATH="${__item[1]}"
			fi

			if [ -n "${__item[2]}" ]; then
				eval ${__result_prefix}_MODE="${__item[2]}"
			fi
		
			;;

		port)
			__item=(${__item//@/ })
			__name="${__item[0]}"
			eval ${__result_prefix}_NAME="${__name}"
			__ext="${__item[1]}"
			[ ! "${__item[2]}" = "" ] && __ext="${__ext}@${__item[2]}"
			eval ${__result_prefix}_EXTENDED_DEF="${__ext}"

			eval ${__result_prefix}_PORT="${__item[1]}"
			eval ${__result_prefix}_SECURE_PORT="${__item[2]}"
			;;

		middleware)
			__item=(${__item//:/ })
			__name="${__item[0]}"
			eval ${__result_prefix}_NAME="${__name}"
			__ext="${__item[1]}"
			[ ! "${__item[2]}" = "" ] && __ext="${__ext}:${__item[2]}"
			eval ${__result_prefix}_EXTENDED_DEF="${__ext}"
			
			eval ${__result_prefix}_POSITION="${__item[1]}"
			eval ${__result_prefix}_POS_NUMBER="${__item[2]}"
			;;
	esac
	

	case ${__type} in


		plugin|module)
			
			if [ "${__type}" = "plugin" ]; then
				# item arg list
				# symbol : #
				if [ -z "${__item##*#*}" ]; then
					local __arg_list="$(echo $__item | sed 's,^[^#]*#\([^%@\^]*\).*$,\1,')"
					__arg_list="${__arg_list//#/ }"
					eval ${__result_prefix}_ARG_LIST='"'${__arg_list}'"'
				fi
			fi


			if [ "${__type}" = "module" ]; then
				# network area
				# symbol : @
				if [ -z "${__item##*@*}" ]; then
					local __network_area="$(echo $__item | sed 's,^.*@\([^~%#\^]*\).*$,\1,')"
					eval ${__result_prefix}_NETWORK_AREA="${__network_area}"
				fi
			fi

			# links list : service dependency or attach point list
			# symbol : %
			if [ -z "${__item##*%*}" ]; then
				local __service_dependency_list="$(echo $__item | sed 's,^[^%]*%\([^~@#\^]*\).*$,\1,')"
				__service_dependency_list="${__service_dependency_list//%/ }"
				local __tmp_list=
				local __tmp_list_exec=
				case ${__type} in 
					plugin)
						for d in ${__service_dependency_list}; do
							if [ "${d:0:1}" = "!" ]; then
								# do not auto exec at launch
								__tmp_list="${__tmp_list} ${d//\!/}"
							else
								__tmp_list="${__tmp_list} ${d}"
								__tmp_list_exec="${__tmp_list_exec} ${d}"
							fi
						done
						eval ${__result_prefix}_LINKS='"'${__tmp_list}'"'
						eval ${__result_prefix}_LINKS_AUTO_EXEC='"'${__tmp_list_exec}'"'
					;;
					module)
						eval ${__result_prefix}_LINKS='"'${__service_dependency_list}'"'
					;;
				esac
				
			fi

			if [ "${__type}" = "module" ]; then
				# nb instances
				# symbol : ^
				if [ -z "${__item##*^*}" ]; then
					local __instances_nb="$(echo $__item | sed 's,^.*\^\([^~@#%]*\).*$,\1,')"
					eval ${__result_prefix}_INSTANCES_NB="${__instances_nb}"
				fi
			fi

			if [ "${__type}" = "module" ]; then
				# vpn id
				# symbol : ~
				if [ -z "${__item##*~*}" ]; then
					local __vpn_id="$(echo $__item | sed 's,^.*\~\([^@#%\^]*\).*$,\1,')"
					eval ${__result_prefix}_VPN_ID="${__vpn_id}"
				fi
			fi

			# determine item owner
			case ${__type} in
				plugin) 
					__ctx_folder="${TANGO_CTX_PLUGINS_ROOT}"
					__tango_folder="${TANGO_PLUGINS_ROOT}"
					__file_ext=''
				;;
				module) 
					__ctx_folder="${TANGO_CTX_MODULES_ROOT}"
					__tango_folder="${TANGO_MODULES_ROOT}"
					__file_ext='.yml'
					;;
			esac

			# we have already test item exists in filter_and_scale_items
			# so item is either in CTX folder or TANGO folder
			if [ -f "${__ctx_folder}/${__name}${__file_ext}" ]; then
				eval ${__result_prefix}_OWNER="CTX"
			else
				eval ${__result_prefix}_OWNER="TANGO"
			fi
		;;
	esac

}

# list available modules or plugins or scripts
# type : module | plugin | script
# mode : all (default) | ctx | tango
__list_items() {
	local __type="${1}"
	local __mode="${2:-all}"

	local __ctx_folder=
	local __tango_folder=
	local __file_ext=
	case ${__type} in
		module ) __ctx_folder="${TANGO_CTX_MODULES_ROOT}"; __tango_folder="${TANGO_MODULES_ROOT}"; __file_ext='*.yml';;
		plugin ) __ctx_folder="${TANGO_CTX_PLUGINS_ROOT}"; __tango_folder="${TANGO_PLUGINS_ROOT}"; __file_ext='*';;
		script ) __ctx_folder="${TANGO_CTX_SCRIPTS_ROOT}"; __tango_folder="${TANGO_SCRIPTS_ROOT}"; __file_ext='*';;
	esac

	local __result=""
	case ${__mode} in
		all ) __do_ctx=1; __do_tango=1;;
		ctx ) __do_ctx=1; __do_tango=0;;
		tango ) __do_ctx=0; __do_tango=1;;
	esac

	 
	if [ "${__do_ctx}" = "1" ]; then
		if ! $STELLA_API "is_dir_empty" "${__ctx_folder}"; then
			for f in ${__ctx_folder}/*; do
				case $f in
					$__file_ext )	__result="${__result} $(basename $f | sed s/.yml//)";;
				esac
			done
		fi
	fi
	if [ "${__do_tango}" = "1" ]; then
		if ! $STELLA_API "is_dir_empty" "${__tango_folder}"; then
			for f in ${__tango_folder}/*; do
				case $f in
					$__file_ext )	__result="${__result} $(basename $f | sed s/.yml//)";;
				esac
			done
		fi
	fi

	$STELLA_API list_filter_duplicate "${__result}"
}




# FEATURES MANAGEMENT ------------------------

__print_info_services() {
	local __services_list="$1"
	local __info=""
	local __list=""

	local __services_scaled="$($STELLA_API filter_list_with_list "${__services_list}" "${TANGO_SERVICES_MODULES_SCALED}" "FILTER_KEEP")"
	if [ ! "${__services_scaled}" = "" ]; then
		__services_list="$($STELLA_API filter_list_with_list "${__services_list}" "${TANGO_SERVICES_MODULES_SCALED}" "FILTER_REMOVE")"
		for service in ${__services_scaled}; do
			__instances="${service^^}_INSTANCES_LIST"
			__list="${__list} ${!__instances}"
		done
		__services_list="${__services_list} ${__list}"
	fi



	echo "---------==---- ABSTRACT INFO ----==---------"

	for service in ${__services_list}; do
		rlist="${service^^}_ROUTERS_LIST"
		for r in ${!rlist}; do
			__var=${r^^}_URI_DEFAULT
			__urls="${!__var}"
			__var=${r^^}_URI_DEFAULT_SECURE
			__urls="${!__var} ${__urls}"
			__info="$__info \n \x1b(0\x74\x1b(B ${service} | $([ ! "${r}" = "${service}" ] && printf ${r}) | ${__urls}"
		done
	done
	if [ ! "$__info" = "" ]; then
		printf " \x1b(0\x6c\x1b(B SERVICE | SUBSERVICE ROUTER | DEFAULT URIs \n ${__info}" | $STELLA_API format_table "CELL_DELIMITER \x1b(0\x78\x1b(B SEPARATOR |"
	fi
}

__print_info_services_vpn() {
	local __vpn_list="$1"

	# "vpn" means all vpn services
	[ "${__vpn_list}" = "vpn" ] && __vpn_list="${VPN_SERVICES_LIST}"

	echo "---------==---- VPN ----==---------"
	echo "* VPN Services"
	echo "L-- vpn list : ${VPN_SERVICES_LIST}"
	echo "L-- check dns leaks :  https://dnsleaktest.com/"
	
	for v in ${__vpn_list}; do
		echo "* VPN Infos"
		echo "L-- vpn id : ${v}"
		for var in $(compgen -A variable | grep ^${v^^}_); do
			case ${var} in
				*PASSWORD*|*AUTH* ) echo "  + ${var}=*****";;
				* ) echo "  + ${var}=${!var}";;
			esac
		done
		printf "  * external ip : "
		__compose_exec "${v}" "set -- curl -s ipinfo.io/ip"
		echo ""
	done
}

__set_error_engine() {

	__tango_log "DEBUG" "tango" "set_error_engine"

	__set_priority_router "error" "${ROUTER_PRIORITY_ERROR_VALUE}"
	case ${NETWORK_REDIRECT_HTTPS} in
		enable )
			# lower error router priority
			__set_redirect_https_service "error"
			;;
	esac


	
	# a wild card domain is by default attached to https error router (error-secure.tls.domains[0].main=*.${TANGO_DOMAIN:-.*}")
	# the code below add a certificate generation for this wild card domain
	# But if we use HTTP challenge we cannot generate a wild card domain, it must be in DNS challenge only
	# NOTE that all dns provider do not support wild card domain, so dnschallenge shall fail
	# TODO : disable this because useless ?
	# case ${LETS_ENCRYPT} in
	# 	enable|debug )
	# 		case ${ACME_CHALLENGE} in
	# 			HTTP )
	# 				__tango_log "DEBUG" "tango" "do not generate a *.domain.org certificate because we use HTTP challenge"
	# 			;;
	# 			DNS )
	# 				__tango_log "DEBUG" "tango" "generate a *.domain.org certificate because we use DNS challenge"
	# 				__add_letsencrypt_service "error"
	# 			;;
	# 		esac
	# 	;;
	# esac
	

}

__pick_free_port() {
	local __free_port_list=
	local __exclude=

	# exclude direct access port AND any variable ending with _PORT (for service_PORT variable)
	for p in $(compgen -A variable | grep _PORT$); do
		p="${!p}"
		[[ ${p} =~ ^[0-9]+$ ]] && __exclude="${__exclude} ${p}"
	done
	[ ! "${__exclude}" = "" ] && __exclude="EXCLUDE_LIST_BEGIN ${__exclude} EXCLUDE_LIST_END"

	local __nb_port=0
	for area in ${NETWORK_SERVICES_AREA_LIST}; do
		IFS="|" read -r name proto internal_port secure_port <<<$(echo ${area})
		(( __nb_port ++ ))
		[ ! "$secure_port" = "" ] && (( __nb_port ++ ))
	done

	__tango_log "INFO" "tango" "Tango will pick $__nb_port ports and assign them to entrypoints."
	__tango_log "DEBUG" "tango" "pick_free_port : looking for $__nb_port free ports"
	__free_port_list="$($STELLA_API find_free_port "$__nb_port" "TCP RANGE_BEGIN 10000 RANGE_END 65000 CONSECUTIVE ${__exclude}")"

	__tango_log "DEBUG" "tango" "pick_free_port : found : ${__free_port_list}"

	if [ ! "${__free_port_list}" = "" ]; then
		__free_port_list=( ${__free_port_list} )
		
		local i=0
		for area in ${NETWORK_SERVICES_AREA_LIST}; do
			IFS="|" read -r name proto internal_port secure_port <<<$(echo ${area})
			
			eval NETWORK_PORT_${name^^}=${__free_port_list[$i]}
			echo "NETWORK_PORT_${name^^}=${__free_port_list[$i]}" > "${GENERATED_ENV_FILE_FREEPORT}"
			(( i ++ ))
			if [ ! "$secure_port" = "" ]; then
				eval NETWORK_PORT_${name^^}_SECURE=${__free_port_list[$i]}
				echo "NETWORK_PORT_${name^^}_SECURE=${__free_port_list[$i]}" >> "${GENERATED_ENV_FILE_FREEPORT}"
				(( i ++ ))
			fi
		done
	fi
}

# service_name : attach vpn to a service_name
# vpn_id : integer id of vpn
# vpn_service_name : vpn docker service
__set_vpn_service() {
 	local __service_name="$1"
	local __vpn_id="$2"
 	local __vpn_service_name="$3"

	__tango_log "INFO" "tango" "VPN : attach $__service_name to $__vpn_service_name"
	yq d -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.networks"
	yq d -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.expose"
	yq d -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.ports"

	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.network_mode" "service:${__vpn_service_name}"

	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.environment[+]" "VPN_ID=${__vpn_id}"

	# add volume from vpn service to get conf files into /vpn
	__add_volume_from_service "${__service_name}" "${__vpn_service_name}"

	__add_service_dependency "${__service_name}" "${__vpn_service_name}"

}



__create_vpn() {
	local __vpn_id="$1"
	
	local _tmp=
	local __service_name="vpn_${__vpn_id}"


	_tmp="VPN_${__vpn_id}_PATH"
	local __folder="${!_tmp}"
	_tmp="VPN_${__vpn_id}_VPN_FILES"
	local __vpn_files="${!_tmp}"
	_tmp="VPN_${__vpn_id}_VPN"
	local __vpn="${!_tmp}"
	_tmp="VPN_${__vpn_id}_VPN_AUTH"
	local __vpn_auth="${!_tmp}"
	_tmp="VPN_${__vpn_id}_DNS"
	local __dns="${!_tmp}"
	_tmp="VPN_${__vpn_id}_CERT_AUTH"
	local __cert_auth="${!_tmp}"
	_tmp="VPN_${__vpn_id}_CIPHER"
	local __cipher="${!_tmp}"
	_tmp="VPN_${__vpn_id}_MSS"
	local __mss="${!_tmp}"
	_tmp="VPN_${__vpn_id}_ROUTE"
	local __route="${!_tmp}"
	_tmp="VPN_${__vpn_id}_ROUTE6"
	local __route6="${!_tmp}"
	# !!merge <<: default-vpn
	yq w -i "${GENERATED_DOCKER_COMPOSE_FILE}" --makeAlias "services.${__service_name}.<<" "default-vpn" 
	#yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.<<" default-vpn
	# need tweak '*default-vpn' yaml anchor while this issue exist in yq : https://github.com/mikefarah/yq/issues/377
	#sed -i 's/[^&]default-vpn/ \*default-vpn/' "${GENERATED_DOCKER_COMPOSE_FILE}"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.container_name" '${TANGO_INSTANCE_NAME}_'${__service_name}
	[ "${__folder}" ] && __add_volume_mapping_service "${__service_name}" "${__folder}:/vpn"
	[ "${__vpn_files}" ] && yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.environment[+]" "VPN_FILES=${__vpn_files}"
	[ "${__vpn}" ] && yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.environment[+]" "VPN=${__vpn}"
	[ "${__vpn_auth}" ] && yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.environment[+]" "VPN_AUTH=${__vpn_auth}"
	[ "${__dns}" ] && yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.environment[+]" "DNS=${__dns}"
	[ "${__cert_auth}" ] && yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.environment[+]" "CERT_AUTH=${__cert_auth}"
	[ "${__cipher}" ] && yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.environment[+]" "CIPHER=${__cipher}"
	[ "${__mss}" ] && yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.environment[+]" "MSS=${__mss}"
	[ "${__route}" ] && yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.environment[+]" "ROUTE=${__route}"
	[ "${__route6}" ] && yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.environment[+]" "ROUTE6=${__route6}"

	export TANGO_TIME_VOLUME_SERVICES="${TANGO_TIME_VOLUME_SERVICES} ${__service_name}"

	__tango_log "DEBUG" "tango" "create vpn $__service_name using file $__vpn_files"
}

# NOTE : check a docker compose service exist (not a subservice)
__check_docker_compose_service_exist() {
	local __service="$1"
	
	[ "${__service}" = "" ] && return 1
	[ ! -z "$(yq r -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service}.image")" ]
	return $?
}


# if service is a subservice return parent service
# return empty if service is not a subservice
# usage sample :
#	local __parent="$(__get_subservice_parent "${__service}")"
#	[ "${__parent}" = "" ] && __parent="${__service}"
__get_subservice_parent() {
	local __service="$1"
	if $STELLA_API list_contains "${TANGO_SUBSERVICES_ROUTER}" "${__service}"; then
		for s in ${TANGO_SERVICES_AVAILABLE}; do
			case ${__service} in
				${s}_* ) echo "${s}"; return ;;
			esac
		done
	fi
}


# return area name associated to an entrypoint
# i.e : entry_main_http or entry_main_http_secure => return main
__get_network_area_name_from_entrypoint() {
	local __entrypoint="$1"
	local result="${__entrypoint,,}"

	# remove entry_
	result="${result##entry_}"
	# remove _secure
	result="${result%%_secure}"
	# remove _proto
	result="${result%_*}"

	echo ${result}
}

# a service (aka a docker compose service) may exist but may not have a default traefik associated router with the same name
# i.e a service may have only associated subservice with router for them but no router for the service name itself
__check_traefik_router_exist() {
	local __service="$1"

	[ ! -z "$(sed -n 's/^[^#]*traefik\.[^.]*\.routers\.'${__service}'\.service=.*$/\0/p' "${GENERATED_DOCKER_COMPOSE_FILE}")" ]
	return $?
}


__check_traefik_router_have_secured_version() {
	local __service="$1"

	__check_traefik_router_exist "${__service}-secure"
	return $?
}


__add_gpu() {
	local __service="$1"
	local __opt="$2"

	__opt_intel_quicksync=0
	__opt_nvidia=0
	for o in $__opt; do
		[ "${o}" = "INTEL_QUICKSYNC" ] && __opt_intel_quicksync=1
		[ "${o}" = "NVIDIA" ] && __opt_nvidia=1
	done

	if [ "${__opt_intel_quicksync}" = "1" ]; then
		[ -d "/dev/dri" ] && yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service}.devices[+]" "/dev/dri:/dev/dri"
	fi

	if [ "${__opt_nvidia}" = "1" ]; then
		yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service}.environment[+]" "NVIDIA_VISIBLE_DEVICES=all"
		yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service}.environment[+]" "NVIDIA_DRIVER_CAPABILITIES=compute,video,utility"
		yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service}.runtime" "nvidia"
	fi
}



__add_tz_var_for_time() { 
	local __service="$1"

	if [ -f "/etc/timezone" ]; then
		TZ="$(cat /etc/timezone)"
		yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service}.environment[+]" "TZ=${TZ}"
	fi
}


# attach generated env compose file to a service
__add_generated_env_file() {
	local __service="$1"

	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service}.env_file[+]" "${GENERATED_ENV_FILE_FOR_COMPOSE}"
}


__add_service_dependency() {
	local __service="$1"
	local __dependency="$2"

	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service}.depends_on[+]" "${__dependency}"
}

__add_volume_for_time() {
	local __service="$1"
	
	# add these volumes only if files exists
	[ -f "/etc/timezone" ] && __add_volume_mapping_service "${__service}" "/etc/timezone:/etc/timezone:ro"
	[ -f "/etc/localtime" ] && __add_volume_mapping_service "${__service}" "/etc/localtime:/etc/localtime:ro"
}


# attach a middleware to a service and its optional secured version in compose file
# It will add middleware to secured version ONLY if secured version exists
# option FIRST or LAST(default) or POS N (N start at 1 for first position) for middleware position
# __attach_middleware_to_service "airdcppweb" "error-middleware" "LAST" add : - "traefik.http.routers.airdcppweb-secure.middlewares=error-middleware"
__attach_middleware_to_service() {
	local __service="$1"
	local __middleware_name="$2"
	local __opt="$3"
	
	if __check_traefik_router_have_secured_version "${__service}"; then
		__opt="SECURE $__opt"
	fi

	__tango_log "DEBUG" "tango" "attach middleware : $__middleware_name to service : $__service with options : $__opt"
	__modify_services_middlewares "$__service" "$__middleware_name" "ADD $__opt"
}


# remove an attached middleware to a service and its secured version in compose file
# It will remove middleware to secured version ONLY if secured version exists
# __detach_middleware_from_service "airdcppweb" "error-middleware" remove line - "traefik.http.routers.airdcppweb-secure.middlewares=error-middleware"
__detach_middleware_from_service() {
	local __service="$1"
	local __middleware_name="$2"

	local __opt=
	if __check_traefik_router_have_secured_version "${__service}"; then
		__opt="SECURE $__opt"
	fi

	__tango_log "DEBUG" "tango" "detach middleware : $__middleware_name from service : $__service with options : $__opt"
	__modify_services_middlewares "$__service" "$__middleware_name" "REMOVE $__opt"
}


__modify_services_middlewares() {
	local __service="$1"
	local __middleware_name="$2"
	local __opt="$3"

	local __pos="LAST"
	local __action="ADD"
	local __secure=
	local __flag_pos=

	if ! __check_traefik_router_exist "$__service"; then
		__tango_log "WARN" "tango" "modify_services_middlewares : SKIP $__service do not exist"
		return
	fi
	for o in ${__opt}; do
		[ "${__flag_pos}" = "1" ] && __pos="$o" && __flag_pos="0" && continue
		case $o in
			ADD|REMOVE )
				__action="$o"
			;;

			LAST|FIRST )
				__pos="$o"
			;;
			SECURE )
				__secure="1"
			;;
			POS )
				__flag_pos="1"
			;;
		esac
	done

	local __middlewares_list=
	local __middlewares_list_secure=
	local __parent=
	local __done=
	local __temp_list=
	local __temp_list_secure=
	# extract actual middlewares values
	__middlewares_list="$(sed -n -e 's/^[^#]*traefik\.http\.routers\.'${__service}'\.middlewares=\(.*\)["]*$/\1/p' "${GENERATED_DOCKER_COMPOSE_FILE}" | sed -e 's/[",]/ /g')"
	[ "$__secure" = "1" ] && __middlewares_list_secure="$(sed -n -e 's/^[^#]*traefik\.http\.routers\.'${__service}'-secure\.middlewares=\(.*\)["]*$/\1/p' "${GENERATED_DOCKER_COMPOSE_FILE}" | sed -e 's/[",]/ /g')"

	case $__action in

		ADD )
			__middlewares_list="$($STELLA_API filter_list_with_list "$__middlewares_list" "$__middleware_name")"
			__middlewares_list="$($STELLA_API trim "${__middlewares_list}")"
			if [ "$__secure" = "1" ]; then
				__middlewares_list_secure="$($STELLA_API filter_list_with_list "$__middlewares_list_secure" "$__middleware_name")"
				__middlewares_list_secure="$($STELLA_API trim "${__middlewares_list_secure}")"
			fi

			case ${__pos} in
				LAST )
					__middlewares_list="${__middlewares_list} ${__middleware_name}"
					__middlewares_list_secure="${__middlewares_list_secure} ${__middleware_name}"
				;;

				FIRST )
					__middlewares_list="${__middleware_name} ${__middlewares_list}"
					__middlewares_list_secure="${__middleware_name} ${__middlewares_list_secure}"
				;;
				# POS N (N start at 1 for first position)
				[0-9]* )
					i=1
					for m in ${__middlewares_list}; do
						if [ $i -eq $__pos ]; then 
							__temp_list="${__temp_list} ${__middleware_name} ${m}"
							__done="1"
						else
							__temp_list="${__temp_list} ${m}"
						fi
						(( i++ ))
					done
					if [ "${__done}" = "1" ]; then
						__middlewares_list="${__temp_list}"
					else
						__middlewares_list="${__middlewares_list} ${__middleware_name}"
					fi
					__middlewares_list="$($STELLA_API trim "${__middlewares_list}")"

					if [ "$__secure" = "1" ]; then
						i=1
						for m in ${__middlewares_list_secure}; do
							if [ $i -eq $__pos ]; then 
								__temp_list_secure="${__temp_list_secure} ${__middleware_name} ${m}"
								__done="1"
							else
								__temp_list_secure="${__temp_list_secure} ${m}"
							fi
							(( i++ ))
						done
						if [ "${__done}" = "1" ]; then
							__middlewares_list_secure="${__temp_list_secure}"
						else
							__middlewares_list_secure="${__middlewares_list_secure} ${__middleware_name}"
						fi
						__middlewares_list_secure="$($STELLA_API trim "${__middlewares_list_secure}")"
					fi
				;;
			esac
		;;

		REMOVE )
			__middlewares_list="$($STELLA_API filter_list_with_list "$__middlewares_list" "$__middleware_name")"
			__middlewares_list="$($STELLA_API trim "${__middlewares_list}")"
			if [ "$__secure" = "1" ]; then
				__middlewares_list_secure="$($STELLA_API filter_list_with_list "$__middlewares_list_secure" "$__middleware_name")"
				__middlewares_list_secure="$($STELLA_API trim "${__middlewares_list_secure}")"
			fi
		;;
	esac

	__middlewares_list="${__middlewares_list// /,}"
	# remove previous value
	sed -i -e '/^[^#]*traefik\.http\.routers\.'${__service}'\.middlewares=/d' "${GENERATED_DOCKER_COMPOSE_FILE}"
	# set new value
	__parent="$(__get_subservice_parent "${__service}")"
	[ "${__parent}" = "" ] && __parent="${__service}"
	[ ! "${__middlewares_list}" = "" ] && yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__parent}.labels[+]" "traefik.http.routers.${__service}.middlewares=${__middlewares_list}"

	if [ "$__secure" = "1" ]; then
		__middlewares_list_secure="${__middlewares_list_secure// /,}"
		# remove previous value
		sed -i -e '/^[^#]*traefik\.http\.routers\.'${__service}'-secure\.middlewares=/d' "${GENERATED_DOCKER_COMPOSE_FILE}"
		# set new value
		[ ! "${__middlewares_list_secure}" = "" ] && yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__parent}.labels[+]" "traefik.http.routers.${__service}-secure.middlewares=${__middlewares_list_secure}"
	fi
}

__add_letsencrypt_service() {
	local __service="$1"

	# subservice support
	local __parent="$(__get_subservice_parent "${__service}")"

	[ "${__parent}" = "" ] && __parent="${__service}"
	if __check_docker_compose_service_exist "${__parent}"; then
		yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__parent}.labels[+]" "traefik.http.routers.${__service}-secure.tls.certresolver=tango"
	else
		__tango_log "WARN" "tango" "unknow service ${__parent} declared in LETS_ENCRYPT_SERVICES"
	fi
}

# attach an entrypoint to a service or a subservice as well to the secured version of the entrypoint
# it will update a list of entrypoint for the service
# __service : service name
# __network_area : area name
# __set_entrypoint_service "web1" "main"
__set_entrypoint_service() {
	local __service="$1"
	local __network_area_name="$2"
	

	local __secure_port
	local __var
	local __previous
	local __proto

	__tango_log "DEBUG" "tango" "set_entrypoint_service : service : ${__service} network_area : ${__network_area_name}"

	[ "${__network_area_name}" = "" ] && return

	__proto="NETWORK_SERVICES_AREA_${__network_area_name^^}_PROTO"
	__proto="${!__proto}"
	__var="${__service^^}_ENTRYPOINTS"
	if [ ! "${!__var}" = "" ]; then
		__previous=",${!__var}"
	else
		# first entrypoint attached to a service is the default one
		__add_declared_variables "${__service^^}_ENTRYPOINT_DEFAULT"
		eval "export ${__service^^}_ENTRYPOINT_DEFAULT=entry_${__network_area_name}_${__proto}"
	fi
	__tango_log "DEBUG" "tango" "L-- set_entrypoint_service : assign service : ${s} to entrypoint : entry_${__network_area_name}_${__proto}"
	eval "export ${__var}=entry_${__network_area_name}_${__proto}${__previous}"
	__add_declared_variables "${__var}"
	

	__secure_port="NETWORK_SERVICES_AREA_${__network_area_name^^}_INTERNAL_SECURE_PORT"
	if [ ! "${!__secure_port}" = "" ]; then
		__proto="NETWORK_SERVICES_AREA_${__network_area_name^^}_PROTO"
		__proto="${!__proto}"
		__var="${__service^^}_ENTRYPOINTS_SECURE"
		if [ ! "${!__var}" = "" ]; then
			__previous=",${!__var}"
		else
			# first entrypoint attached to a service is the default one
			__add_declared_variables "${__service^^}_ENTRYPOINT_DEFAULT_SECURE"
			eval "export ${__service^^}_ENTRYPOINT_DEFAULT_SECURE=entry_${__network_area_name}_${__proto}_secure"
		fi
		__tango_log "DEBUG" "tango" "L-- set_entrypoint_service : assign service : ${s} to entrypoint : entry_${__network_area_name}_${__proto}_secure"
		eval "export ${__var}=entry_${__network_area_name}_${__proto}_secure${__previous}"
		__add_declared_variables "${__var}"
	fi

}

# set a priority for a traefik router
__set_priority_router() {
	local __service="$1"
	local __priority="$2"

	__service="${__service^^}"

	local __var="${__service}_PRIORITY"

	eval "export ${__var}=${__priority}"
	__add_declared_variables "${__var}"

	__tango_log "DEBUG" "tango" "set priority : ${__priority} to traefik router : ${__service}"
	
}

# change rule priority of a service to be overriden by the http-catchall rule which have a prority of ROUTER_PRIORITY_HTTP_TO_HTTPS_VALUE
__set_redirect_https_service() {
	local __service="$1"
	
	__service="${__service^^}"

	__tango_log "DEBUG" "tango" "set_redirect_https_service : change rule priority of ${__service} to be overriden by the http-catchall redirect to https rule"

	# determine how much priority we have to lower the router
	local __lower_http_router_priority_value="$(( ROUTER_PRIORITY_DEFAULT_VALUE - ROUTER_PRIORITY_HTTP_TO_HTTPS_VALUE + (ROUTER_PRIORITY_HTTP_TO_HTTPS_VALUE / 2) ))"
	# exemple : (( 2000 - 1000 + (1000/2) )) --> 1500 - this is the amount to subtract to an HTTP router priority
	


	local __var="${__service}_PRIORITY"
	__var=${!__var}
	__var="$(($__var - $__lower_http_router_priority_value))"
	__set_priority_router "${__service}" "${__var}" 
	# DEPRECATED : technique was to add a middleware redirect rule for each service
	# add only once ',' separator to compose file only if there is other middlewars declarated 
	# ex : "traefik.http.routers.sabnzbd.middlewares=${SABNZBD_REDIRECT_HTTPS}sabnzbd-stripprefix"
	# sed -i 's/\(.*\)\${'$__service'_REDIRECT_HTTPS}\([^,].\+\)\"$/\1\${'$__service'_REDIRECT_HTTPS},\2\"/g' "${GENERATED_DOCKER_COMPOSE_FILE}"
}

# add a volume to a service
# format <volume|path>:<path>
__add_volume_mapping_service() {
	local __service="$1"
	local __mapping="$2"
	
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service}.volumes[+]" "${__mapping}"
}

__add_volume_from_service() {
	local __service="$1"
	local __from_service="$2"
	
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service}.volumes_from[+]" "${__from_service}"
}


__add_volume_definition_by_value() {
	local __name="$1"
	local __path="$2"

	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "volumes.${__name}.driver" "local"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "volumes.${__name}.name" "\${TANGO_CTX_NAME}_${__name}"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "volumes.${__name}.driver_opts.type" "none"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "volumes.${__name}.driver_opts.o" "bind"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "volumes.${__name}.driver_opts.device" "${__path}"
}

# add a volume with path defined by a variable name
__add_volume_definition_by_variable() {
	local __name="$1"
	local __variable="$2"

	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "volumes.${__name}.driver" "local"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "volumes.${__name}.name" "\${TANGO_CTX_NAME}_${__name}"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "volumes.${__name}.driver_opts.type" "none"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "volumes.${__name}.driver_opts.o" "bind"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "volumes.${__name}.driver_opts.device" "\${${__variable}}"

	# add variable name to variables list passed in env file, because it can be initialized out of tango when using TANGO_CREATE_VOLUMES
	__add_declared_variables "${__variable}"

}


__set_network_as_external() {
	local __name="$1"
	local __full_name="$2"

	yq d -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "networks.${__name}.name"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "networks.${__name}.external.name" "${__full_name}"
}




# DOCKER ---------------------------------

# docker client available
__is_docker_client_available() {
	type docker &>/dev/null
	return $?
}

__container_is_healthy() {
    local state="$(docker inspect -f '{{ .State.Health.Status }}' $1 2>/dev/null)"
    local return_code=$?
	
    if [ ! ${return_code} -eq 0 ]; then
        exit ${RETURN_ERROR}
    fi
    if [ "${state}" = "healthy" ]; then
        return 0
    else
        return 1
    fi
}


__container_is_running() {
    local state="$(docker inspect -f '{{ .State.Status }}' $1 2>/dev/null)"
    local return_code=$?
	
    if [ ! ${return_code} -eq 0 ]; then
        exit ${RETURN_ERROR}
    fi
    if [ "${state}" = "running" ]; then
        return 0
    else
        return 1
    fi
}


# exec a command inside a running container
# sammple : __compose_exec "${TARGET}" "set -- /bin/sh" "1"
__compose_exec() {
	local __name="$1"
	local __cmd="$2"
	local __isroot="$3"

	if [ "$__name" = "" ]; then
		__tango_log "ERROR" "tango" "${__name} can not be empty."
		exit 1
	fi

	# process command
	#__tango_log "DEBUG" "tango" "Command to evaluate : ${__cmd}"
	if [ "${__cmd}" = "" ]; then
		__tango_log "ERROR" "tango" "You must provide a command to execute."
		exit 1
	fi

	eval "${__cmd}"

	local _tmp="$@"
	#__tango_log "DEBUG" "tango" "Command evaluated : ${_tmp}"
	if [ "${_tmp}" = "" ]; then
		__tango_log "ERROR" "tango" "You must provide a command to execute."
		exit 1
	fi

	if [ "$__isroot" = "1" ]; then
		docker-compose exec --user 0:0 "${__name}" "$@"
	else
		docker-compose exec --user ${TANGO_USER_ID}:${TANGO_GROUP_ID} "${__name}" "$@"
	fi

}


# OPTIONS
# filter user
#		can be empty or "all" to list all container
# filter status options
# 		NON_RUNNING, NON_STOPPED, ONLY_RUNNING, ONLY_STOPPED are exclusive (can not be cumulated with any other filters)
#		RUNNING, STOPPED can be cumulated
#		NON_RUNNING is the same than ONLY_STOPPED
#		NON_STOPPED is the same than ONLY_RUNNING
#		LIST_NAMES name1 name2 name3  : will include filter which have these names
# sample
#		${DOCKER_CMD} ps -a $(__container_filter "ONLY_RUNNING") --format "{{.Names}}#{{.Status}}#{{.Image}}"
__container_filter() {
	local __opt="$1"

	local __opt_running=
	local __opt_non_running=
	local __opt_only_running=
	local __opt_stopped=
	local __opt_non_stopped=
	local __opt_only_stopped=
	local __flag_names=
	local __names_list=
	for o in ${__opt}; do
		[ "$o" = "RUNNING" ] && __opt_running="1" && __opt_non_running="0" && __opt_only_running="0" && __opt_non_stopped="0" && __opt_only_stopped="0" && __flag_names=
		[ "$o" = "NON_RUNNING" ] && __opt_running="0" && __opt_stopped="0" && __opt_non_running="1" && __opt_only_running="0" && __opt_non_stopped="0" && __opt_only_stopped="0" && __flag_names=
		[ "$o" = "ONLY_RUNNING" ] && __opt_running="0" && __opt_stopped="0" && __opt_non_running="0" && __opt_only_running="1" && __opt_non_stopped="0" && __opt_only_stopped="0" && __flag_names=
		[ "$o" = "STOPPED" ] && __opt_stopped="1" && __opt_non_running="0" && __opt_only_running="0" && __opt_non_stopped="0" && __opt_only_stopped="0" && __flag_names=
		[ "$o" = "NON_STOPPED" ] && __opt_running="0" && __opt_stopped="0" && __opt_non_running="0" && __opt_only_running="0" && __opt_non_stopped="1" && __opt_only_stopped="0" && __flag_names=
		[ "$o" = "ONLY_STOPPED" ] && __opt_running="0" && __opt_stopped="0" && __opt_non_running="0" && __opt_only_running="0" && __opt_non_stopped="0" && __opt_only_stopped="1" && __flag_names=
		[ "$__flag_names" = "1" ] && __names_list="$__names_list $o"
		[ "$o" = "LIST_NAMES" ] && __flag_names=1
	done

	local __filter_default="--filter=label=${TANGO_INSTANCE_NAME}.managed=true"

	local __filter_names=
	if [ ! "${__names_list}"  = "" ]; then
		__names_list="$($STELLA_API trim "${__names_list}")"
		__filter_names="--filter=name=^/$(echo -n ${__names_list} | sed -e 's/ /$|^\//g')$"
	fi

	local __filter_status=
	[ "$__opt_running" = "1" ] && __filter_status="${__filter_status} --filter=status=running"
	[ "$__opt_stopped" = "1" ] && __filter_status="${__filter_status} --filter=status=exited --filter=status=created"
	[ "$__opt_non_running" = "1" ] && __filter_status="--filter=status=exited --filter=status=created"
	[ "$__opt_only_running" = "1" ] && __filter_status="--filter=status=running"
	[ "$__opt_non_stopped" = "1" ] && __filter_status="--filter=status=running"
	[ "$__opt_only_stopped" = "1" ] && __filter_status="--filter=status=exited --filter=status=created"



	echo "${__filter_default} ${__filter_names} ${__filter_status}"
}


docker-compose() {
	# NOTE we need to specify project directory because when launching from an other directory, docker compose seems to NOT auto load .env file
	case ${TANGO_INSTANCE_MODE} in
		shared ) 
			__tango_log "DEBUG" "tango" "COMPOSE_IGNORE_ORPHANS=1 docker-compose ${DOCKER_COMPOSE_LOG} -f "${GENERATED_DOCKER_COMPOSE_FILE}" --env-file "${GENERATED_ENV_FILE_FOR_COMPOSE}" --project-name "${TANGO_INSTANCE_NAME}" --project-directory "${TANGO_CTX_ROOT}" "$@""
			COMPOSE_IGNORE_ORPHANS=1 command docker-compose ${DOCKER_COMPOSE_LOG} -f "${GENERATED_DOCKER_COMPOSE_FILE}" --env-file "${GENERATED_ENV_FILE_FOR_COMPOSE}" --project-name "${TANGO_INSTANCE_NAME}" --project-directory "${TANGO_CTX_ROOT}" "$@"
			;;
		* ) 
			__tango_log "DEBUG" "tango" "COMPOSE_IGNORE_ORPHANS=1 docker-compose ${DOCKER_COMPOSE_LOG} -f "${GENERATED_DOCKER_COMPOSE_FILE}" --env-file "${GENERATED_ENV_FILE_FOR_COMPOSE}" --project-name "${TANGO_CTX_NAME}" --project-directory "${TANGO_CTX_ROOT}" "$@""
			COMPOSE_IGNORE_ORPHANS=1 command docker-compose ${DOCKER_COMPOSE_LOG} -f "${GENERATED_DOCKER_COMPOSE_FILE}" --env-file "${GENERATED_ENV_FILE_FOR_COMPOSE}" --project-name "${TANGO_CTX_NAME}" --project-directory "${TANGO_CTX_ROOT}" "$@"
			;;
	esac
	
}

# VARIOUS -----------------

# generate a string to be used as header Authentification: Basic
__base64_basic_authentification() {
	local __user="$1"
	local __password="$2"

	python -c 'import base64;print(base64.b64encode(b"'$__user':'$__password'").decode("ascii"))'
}

# launch a curl command from a docker image in priority if docker is available or from curl from host if not
# within the current tango network context
__tango_curl() {
	if __is_docker_client_available; then
		local __id="$TANGO_CTX_NAME_$($STELLA_API md5 "$@")"
		docker stop ${__id} 1>&2 2>/dev/null
		docker rm ${__id} 1>&2 2>/dev/null
		# TODO use $PROXY inside docker run command
		[ ! "$STELLA_HTTP_PROXY" = "" ] && PROXY="-e HTTP_PROXY=${STELLA_HTTP_PROXY} -e HTTPS_PROXY=${STELLA_HTTPS_PROXY} -e http_proxy=${STELLA_HTTP_PROXY} -e https_proxy=${STELLA_HTTPS_PROXY} -e NO_PROXY=${NO_PROXY} -e no_proxy=${no_proxy}"
		# NOTE TODO : At this point network TANGO_CTX_NETWORK_NAME may not exists yet
		if docker run --name ${__id} --user "${TANGO_USER_ID}:${TANGO_GROUP_ID}" --network "${TANGO_CTX_NETWORK_NAME}" --rm curlimages/curl:7.70.0 "$@"; then
			docker rm ${__id} 1>&2 2>/dev/null
		else
			docker rm ${__id} 1>&2 2>/dev/null
			type curl &>/dev/null && curl "$@"
		fi
	else
		type curl &>/dev/null && curl "$@"
	fi
}

# launch a git command from a docker image in priority if docker is available or from git from host if not
__tango_git() {
	if __is_docker_client_available; then
		# https://hub.docker.com/r/alpine/git
		docker run --user "${TANGO_USER_ID}:${TANGO_GROUP_ID}" --network "${TANGO_CTX_NETWORK_NAME}" --rm -it -v $(pwd):/git alpine/git:latest "$@"
	else
		type git &>/dev/null && git "$@"
	fi
}

# set an attribute value of a node selected by an xpath expression
# 	__xml_replace_attribute_value "Preferences.xml" "/Preferences" "Preferences" "TranscoderTempDirectory" "/transode"
# 	xidel Preferences.xml --silent --xml --xquery3 'let $selected := /Preferences return transform(/,function($e) { if ($selected[$e is .]) then <Preferences>{$e/attribute() except $e/@TranscoderTempDirectory, attribute TranscoderTempDirectory { "/transcode" },$e/node()}</Preferences> else $e })'
# http://x-query.com/pipermail/talk/2013-December/004266.html
__xml_set_attribute_value() {
	local __file="$1"
	local __xpath_selector="$2"
	local __node_name="$3"
	local __attribute_name="$4"
	local __attribute_value="$5"


	xidel "${__file}" --silent --xml --xquery3 'let $selected := '${__xpath_selector}' return transform(/,function($e) { if ($selected[$e is .]) then <'${__node_name}'>{$e/attribute() except $e/@'${__attribute_name}', attribute '${__attribute_name}' { "'${__attribute_value}'" },$e/node()}</'${__node_name}'> else $e })' > "${__file}.new"
	rm -f "${__file}"
	mv "${__file}.new" "${__file}"
}

# get an attribute value 
#		__xml_get_attribute_value "Preferences.xml" "/Preferences/@PlexOnlineToken"
__xml_get_attribute_value() {
	local __file="$1"
	local __xpath_selector="$2"

	xidel "${__file}" --silent --extract "${__xpath_selector}"
}


# simple extract value in an ini file
# support	key=value and key = value
__ini_get_key_value() {
	local __file="$1"
	local __key="$2"

	if [ ! -z $__key ]; then
		if [ -f "${__file}" ]; then
	        cat "${__file}" | sed -e 's,'$__key'[[:space:]]*=[[:space:]]*,'$__key'=,g' | awk 'match($0,/^'$__key'=.*$/) {print substr($0, RSTART+'$(( ${#__key} + 1 ))',RLENGTH);}'
    	fi            
	fi
}


# parse path variables and instruct creation order
#   						xxx_PATH =           		provided path
#   						xxx_PATH_SUBPATH_LIST = 	list of subpath variables relative to path
# 							xxx_PATH_SUBPATH_CREATE = 	instructions to create subpath relative to path (internal variable)
__manage_path() {
	local __var_path="$1"
	# if __var_path is not defined, default folder name will have __default_root as root folder
	local __default_root="$2"
	[ "${__default_root}" = "" ] && __default_root="TANGO_CTX_WORK_ROOT"
	# __var_path MUST BE be a subfolder relative to this root
	local __relative_root="$3"

	local __new_rel_path=
	local __default_path=
	local __path=
	local __subpath_list=

	local __tmp=

	__tango_log "DEBUG" "tango" "manage_path : ${__var_path} var path"

	__add_declared_variables "${__var_path}"

	# if xxx_PATH not setted
	if [ "${!__var_path}" = "" ]; then
			__path="${__var_path,,}"
			__tango_log "WARN" "tango" "manage_path : ${__var_path} do not have any value setted, use ${__path} as default value"
			__tmp="${__default_root}_SUBPATH_CREATE"
			eval "${__tmp}=\"${!__tmp} FOLDER $(echo ${__path} | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/\\$/g') \""
			# export this path will update its value inside env files
			eval "export ${__var_path}=\"${!__default_root}/${__path}\""
			__tango_log "DEBUG" "tango" "manage_path : ${__var_path} not setted : will create folder defined with default name \""${__path}\"" under ${__default_root} [${!__var_path}]"
	else

		
		case ${!__var_path} in
			# if setted xxx_PATH is absolute path => NOTHING TO DO, but an absolute path must exist as it will not be created
			/*)
				TANGO_MANDATORY_PATH_LIST="${TANGO_MANDATORY_PATH_LIST} ${__var_path}"
				__tango_log "DEBUG" "tango" "manage_path : ${__var_path} [${!__var_path}] is an absolute path and must exists"
							# and may be or not a subfolder of parent path ${__default_root} [${__default_root}]"
				# # a declared parent path BUT an absolute path as value ==> check path is relative to intended root and create it if so
				# __tango_log "DEBUG" "WARN" "manage_path : ${__var_path} have an absolute path form : [${!__var_path}] but should have a relativce path form, relative to ${__default_root}"
				# # absolute path but shoud be relative path of $__default_root
				# # check if it is an absolute path which is relative to root
				# if [ "$($STELLA_API is_logical_subpath "${!__default_root}" "${!__var_path}")" = "TRUE" ]; then
				# 	__new_rel_path="$($STELLA_API abs_to_rel_path "${!__var_path}" "${!__default_root}")"
				# 	# reconvert to a relative path 
				# 	# NOTE : we need this because we have not updated generated files AND load its value 
				# 	#		 then all relative path MAY have been converted to absolute values with __translate_all_path INSTEAD of staying relative values
				# 	__tmp="${__default_root}_SUBPATH_CREATE"
				# 	eval "${__tmp}=\"${!__tmp} FOLDER $(echo ${__new_rel_path} | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/\\$/g') \""
				# 	eval "export ${__var_path}=\"${!__default_root}/${__new_rel_path}\""
				# 	__tango_log "DEBUG" "tango" "manage_path : ${__var_path} will be created under ${__default_root} as [${!__var_path}]"
				# else
				# 	# if not ignore this subpath creation
				# 	__tango_log "ERROR" "tango" "manage_path : ${__var_path} should be a subfolder of ${__default_root} but is not, will not manage this absolute path."
				# fi
			
			;;

			# if setted xxx_PATH is a relative path
			*)
				# just create folder relative to __default_root
				__tmp="${__default_root}_SUBPATH_CREATE"
				eval "${__tmp}=\"${!__tmp} FOLDER $(echo ${!__var_path} | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/\\$/g') \""
				# export this path will update its value inside env files
				eval "export ${__var_path}=\"${!__default_root}/${!__var_path}\""
				__tango_log "DEBUG" "tango" "manage_path : ${__var_path} will be created under ${__default_root} [${!__var_path}]"
			;;
		esac
	fi

	# manage subpath lists
	__subpath_list="${__var_path}_SUBPATH_LIST"
	for s in ${!__subpath_list}; do
		__manage_path "$s" "$__var_path"
	done
	

}

# create all path according to _SUBPATH_CREATE variables content
# see __create_path
__create_path_all() {
	local __create_path_instructions=
	local __root=

	__tango_log "INFO" "tango" "Managing paths creation"
	# force to create first these root folders before all other that might be subfolders
	if [ ! "${TANGO_CTX_WORK_ROOT_SUBPATH_CREATE}" = "" ]; then
		__tango_log "DEBUG" "tango" "create_path_all : parse TANGO_CTX_WORK_ROOT_SUBPATH_CREATE instructions"
		__create_path "${TANGO_CTX_WORK_ROOT}" "${TANGO_CTX_WORK_ROOT_SUBPATH_CREATE}"
		__tango_log "DEBUG_NO_HEADER_BEGINNING_NEWLINE" "" ""
	fi
	if [ ! "${TANGO_DATA_PATH_SUBPATH_CREATE}" = "" ]; then
		__tango_log "DEBUG" "tango" "create_path_all : parse TANGO_DATA_PATH_SUBPATH_CREATE instructions"
		__create_path "${TANGO_DATA_PATH}" "${TANGO_DATA_PATH_SUBPATH_CREATE}"
		__tango_log "DEBUG_NO_HEADER_BEGINNING_NEWLINE" "" ""
	fi

	# create others folders
	for p in $(compgen -A variable | grep _SUBPATH_CREATE$); do
		[ "$p" = "TANGO_CTX_WORK_ROOT_SUBPATH_CREATE" ] && continue
		[ "$p" = "TANGO_DATA_PATH_SUBPATH_CREATE" ] && continue
		__tango_log "DEBUG" "tango" "create_path_all : instructions of ${p}"
		__create_path_instructions="${!p}"

		if [ ! "${__create_path_instructions}" = "" ]; then
			__root="${p%_SUBPATH_CREATE}"
			[ ! "${!__root}" = "" ] && __create_path "${!__root}" "${__create_path_instructions}" && __tango_log "DEBUG_BEGINNING_NEWLINE_NO_HEADER" "" ""
		fi
	done
	if [ ! "${DEBUG}" = "1" ]; then
		__tango_log "INFO_BEGINNING_NEWLINE_NO_HEADER" "" ""
	fi
}

# create various sub folder and files if not exist
# using TANGO_USER_ID
# root must exist
# format example : __create_path "/path" "FOLDER foo bar FILE foo/file.txt FOLDER letsencrypt traefikconfig FILE letsencrypt/acme.json traefikconfig/generated.${TANGO_CTX_NAME}.tls.yml"
__create_path() {
	local __root="$1"
	local __list="$2"

	 
	local __folder=
	local __file=

	# we do not want to alter filesystem (files & folder)
	[ "$TANGO_ALTER_GENERATED_FILES" = "OFF" ] && return
	
	if [ ! -d "${__root}" ]; then
		__tango_log "ERROR" "tango" "create_path : root path ${__root} do not exist"
		return
	fi

	__tango_log "DEBUG" "tango" "create_path : ROOT=${__root} INSTRUCTIONS=${__list}"
	local cpt=0
	eval "__list=( ${__list} )"
	for p in "${__list[@]}"; do
	#for p in ${__list}; do
		[ "${p}" = "FOLDER" ] && __folder=1 && __file= && continue
		[ "${p}" = "FILE" ] && __folder= && __file=1 && continue
		__path="${__root}/${p}"
		# NOTE : on some case chown throw an error, it might be ignored
		if [ "${__folder}" = "1" ]; then
			printf '.'
			if [ ! -d "${__path}" ]; then
				__msg=$(docker run -it --rm --user ${TANGO_USER_ID}:${TANGO_GROUP_ID} -v "${__root}":"/foo" ${TANGO_SHELL_IMAGE} bash -c "mkdir -p \"/foo/${p}\" && chown ${TANGO_USER_ID}:${TANGO_GROUP_ID} \"/foo/${p}\"")
				[ ! "${__msg}" = "" ] && __tango_log "DEBUG_BEGINNING_NEWLINE" "tango" "create_path : docker run msg : ${__msg}"
				# wait more time if not created yet
				cpt=0
				printf '.'
				while [ ! -d "$__path" ]
				do
					printf '.'
					sleep 1
					(( cpt++ ))
					if [ $cpt -gt 10 ]; then
						__tango_log "ERROR_BEGINNING_NEWLINE" "tango" "Error while creating folder $__path"
						exit 1
					fi
				done
			fi
			printf '\b*'
		fi
		if [ "${__file}" = "1" ]; then
			printf '.'
			if [ ! -f "${__path}" ]; then
				__msg=$(docker run -it --rm --user ${TANGO_USER_ID}:${TANGO_GROUP_ID} -v "${__root}":"/foo" ${TANGO_SHELL_IMAGE} bash -c "touch \"/foo/${p}\" && chown ${TANGO_USER_ID}:${TANGO_GROUP_ID} \"/foo/${p}\"")
				[ ! "${__msg}" = "" ] && __tango_log "DEBUG_BEGINNING_NEWLINE" "tango" "create_path : docker run msg : ${__msg}"
				# wait more time if not created yet
				cpt=0
				printf '.'
				while [ ! -f "$__path" ]
				do
					printf '.'
					sleep 1
					(( cpt++ ))
					if [ $cpt -gt 10 ]; then
						__tango_log "ERROR_BEGINNING_NEWLINE" "tango" "create_path : error while creating file $__path"
						exit 1
					fi
				done
			fi
			printf '\b*'
		fi
	done
}





# test if mandatory paths exists
# __mode : NON_BLOCKING|BLOCKING (default)
__check_mandatory_path() {
	local __mode="$1"
	__log="ERROR"
	[ "${__mode}" = "NON_BLOCKING" ] && __log="WARN"
	__tango_log "DEBUG" "tango" "check_mandatory_path TANGO_MANDATORY_PATH_LIST : $TANGO_MANDATORY_PATH_LIST"
	for p in ${TANGO_MANDATORY_PATH_LIST}; do
		if [ ! -d "${!p}" ]; then
			__tango_log "$__log" "tango" "Mandatory path ${p} [${!p}] do not exist"
			[ ! "${__mode}" = "NON_BLOCKING" ] && exit 1
		fi
	done 

	if [ ! "${TANGO_ARTEFACT_FOLDERS}" = "" ]; then
		__tango_log "DEBUG" "tango" "check_mandatory_path TANGO_ARTEFACT_FOLDERS : $TANGO_ARTEFACT_FOLDERS"
		for f in ${TANGO_ARTEFACT_FOLDERS}; do
			if [ ! -d "${f}" ]; then
				__tango_log "$__log" "tango" "Mandatory declared artefact folder [${f}] do not exist"
				[ ! "${__mode}" = "NON_BLOCKING" ] && exit 1
			fi
		done
	fi
}


# __mode : NON_BLOCKING|BLOCKING (default)
__check_lets_encrypt_settings() {
	local __mode="$1"
	local __exit=

	__log="ERROR"
	[ "${__mode}" = "NON_BLOCKING" ] && __log="WARN"


 	case ${LETS_ENCRYPT} in
    	enable|debug ) 
			[ "${LETS_ENCRYPT_MAIL}" = "" ] && __tango_log "$__log" "tango" "You have to specify a mail as identity into LETS_ENCRYPT_MAIL variable when using let's encrypt." && __exit=1
			[ "${TANGO_DOMAIN}" = '.*' ] && __tango_log "$__log" "tango" "You cannot use a generic domain (.*) setted by TANGO_DOMAIN when using let's encrypt. Set TANGO_DOMAIN variables or --domain comand line option with other value." && __exit=1
			[ "${TANGO_DOMAIN}" = "" ] && __tango_log "$__log" "tango" "You have to set a domain with TANGO_DOMAIN variable or --domain comand line option when using let's encrypt." && __exit=1

			case ${ACME_CHALLENGE} in
				HTTP )
					[ ! "${NETWORK_PORT_MAIN}" = "80" ] && __tango_log "$__log" "tango" "main area network HTTP port is not 80 but ${NETWORK_PORT_MAIN}. You need to use DNS challenge for let's encrypt. Set ACME_CHALLENGE variable." && __exit=1
					[ ! "${NETWORK_PORT_MAIN_SECURE}" = "443" ] && __tango_log "$__log" "tango" "main area network HTTPS port is not 443 but ${NETWORK_PORT_MAIN_SECURE}. You need to use DNS challenge for let's encrypt. Set ACME_CHALLENGE variables" && __exit=1
				;;
			esac	
		;;
	esac

	[ ! "${__mode}" = "NON_BLOCKING" ] && [ "${__exit}" = "1" ] && exit 1
}


# this function protect tango for variable used in __tango_log_internal
__tango_log() {
	( LOG_STATE=$TANGO_LOG_STATE; __log_internal "$@" )
}

# level of log (INFO, WARN, ERROR, ASK)
#		the level can have suffices to modify the printing of log
#			_NO_HEADER : disable print of domain and level
#			_BEGINNING_NEWLINE : start by printing a new line before the message
#		i.e 
#			__log_internal "DEBUG_NO_HEADER_BEGINNING_NEWLINE" "" "" # will print only a new line
#			__log_internal "DEBUG_BEGINNING_NEWLINE" "category" "test" # will print a new line then "category@level" then "test" message
# domain is a string to indicate some sort of "category"
# remaning parameters are the message to print
__log_internal() {
	local __level="$1"
	local __domain="$2"
	shift 2
	local __msg="$@"

	if [ "$LOG_STATE" = "ON" ]; then
		_print="0"

		
		local _beginning_new_line="0"
		local _no_header="0"
		while [[ "${__level}" =~ _BEGINNING_NEWLINE|_NO_HEADER ]]; do
			case ${__level} in
				*_BEGINNING_NEWLINE* ) _beginning_new_line="1"; __level="${__level//_BEGINNING_NEWLINE}";;
				*_NO_HEADER* ) _no_header="1"; __level="${__level//_NO_HEADER}";;
			esac
		done

		local _color=
		local _no_color_for_msg="1"
		case ${__level} in
				INFO )
					_color="clr_bold clr_green"
				;;
				WARN )
					_color="clr_bold"
				;;
				ERROR )
					_color="clr_bold clr_red"
					_no_color_for_msg="0"
				;;
				DEBUG )
					_color="clr_bold clr_cyan"
				;;
				ASK )
					_color="clr_bold clr_blue"
				;;
		esac

		case $TANGO_LOG_LEVEL in
			INFO )
				case ${__level} in
					INFO|WARN|ERROR|ASK ) _print="1"
					;;
				esac
				;;
			WARN )
				case ${__level} in
					WARN|ERROR|ASK ) _print="1"
					;;
				esac
			;;
			ERROR )
				case ${__level} in
					ERROR|ASK ) _print="1"
					;;
				esac
			;;
			DEBUG )
				case ${__level} in
					INFO|WARN|ERROR|DEBUG|ASK ) _print="1"
					;;
				esac
			;;
		esac

		if [ "${_print}" = "1" ]; then
			# start by printing a newline
			if [ "${_beginning_new_line}" = "1" ]; then
				printf "\n";
			fi

			# nothing to print more
			if [ "${_no_header}" = "1" ]; then
				if [ "${__msg}" = "" ]; then
					return
				fi
			fi


			case ${__level} in
				# add spaces for tab alignment
				INFO|WARN ) __level="${__level} ";;
				ASK ) __level="${__level}  ";;
			esac
			

			if [ "${_color}" = "" ]; then
				if [ "${_no_header}" = "0" ]; then
					echo "${__level}@${__domain}> ${__msg}"
				else
					echo "${__msg}"
				fi
			else
				if [ "${_no_color_for_msg}" = "1" ]; then
					if [ "${_no_header}" = "0" ]; then
						${_color} -n "${__level}@${__domain}> "; clr_reset "${__msg}"
					else
						clr_reset "${__msg}"
					fi
				else
					if [ "${_no_header}" = "0" ]; then
						${_color} "${__level}@${__domain}> ${__msg}"
					else
						${_color} "${__msg}"
					fi
				fi
			fi
		fi
	fi
}

# trash any output
__tango_log_run_without_output() {
	local __domain="$1"
	shift 1
	if [ "${TANGO_LOG_STATE}" = "ON" ]; then
		if [ "${TANGO_LOG_LEVEL}" = "DEBUG" ]; then
			#echo "DEBUG>" $@
			__tango_log "DEBUG" "$__domain" "$@"
		fi
	fi

	if [ "${TANGO_LOG_LEVEL}" = "DEBUG" ]; then
		"$@"
	else
		"$@" 1>/dev/null
	fi
}

# usefull when attachin tty (1>/dev/null make terminal disappear)
__tango_log_run_with_output() {
	local __domain="$1"
	shift 1
	if [ "${TANGO_LOG_STATE}" = "ON" ]; then
		if [ "${TANGO_LOG_LEVEL}" = "DEBUG" ]; then
			#echo "DEBUG>" $@
			__tango_log "DEBUG" "$__domain" "$@"
		fi
	fi
	"$@"
}
