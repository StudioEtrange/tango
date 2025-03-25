
# MANAGE ENV VARIABLES AND FILES GENERATION -----------------

# load all declared variables in current shell environment (including associative arrays)
__load_env_vars() {
	
	# preserve some current variables
	local __d="$DEBUG"
	local __t1="$TANGO_LOG_LEVEL"
	local __t2="$TANGO_LOG_STATE"
	local __t3="$STELLA_LOG_LEVEL"
	local __t4="$STELLA_LOG_STATE"

	. "${GENERATED_ENV_FILE_FOR_BASH}"

	__load_env_associative_arrays

	export DEBUG="$__d"
	export TANGO_LOG_LEVEL="$__t1"
	export TANGO_LOG_STATE="$__t2"
	export STELLA_LOG_LEVEL="$__t3"
	export STELLA_LOG_STATE="$__t4"
	#$STELLA_API set_log_level_app "$__t1"
	#$STELLA_API set_log_state_app "$__t2"
	export STELLA_APP_LOG_LEVEL="$__t1"
	export STELLA_APP_LOG_STATE="$__t2"
	
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
	local __mode="$2"
	__tango_log "DEBUG" "tango" "update_env_files bash and docker_compose env files : with current setted variables in VARIABLES_LIST"

	[ ! "${__mode}" = "silent" ] && echo "# ------ UPDATE : update_env_files : $(date) -- ${__text}" >> "${GENERATED_ENV_FILE_FOR_COMPOSE}" \
								|| echo "# ------ UPDATE" >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"
	[ ! "${__mode}" = "silent" ] && echo "# ------ UPDATE : update_env_files : $(date) -- ${__text}" >> "${GENERATED_ENV_FILE_FOR_BASH}" \
								|| echo "# ------ UPDATE" >> "${GENERATED_ENV_FILE_FOR_BASH}"
	for __variable in ${VARIABLES_LIST}; do
		# NOTE : since docker-compose v2 env file syntax have changed
		#		it requires values with $ to be quoted, so we quote each value
		# 		https://deploy-preview-13474--docsdocker.netlify.app/compose/env-file/#syntax-rules
		[ -z ${!__variable+x} ] || echo "${__variable}='${!__variable}'" >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"
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
			echo "${__array}='${__content}'" >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"
			declare -p $__array >> "${GENERATED_ENV_FILE_FOR_BASH}"
		fi
	done


	# # remove single compose quote before processing env file
	# sed -i "s/^\([a-zA-Z0-9_-]*\)='\(.*\)'$/\1=\2/g" "${GENERATED_ENV_FILE_FOR_COMPOSE}"

	# # process special assignment notations
	# __process_assignation_env_file "${GENERATED_ENV_FILE_FOR_COMPOSE}"
	# # process {{$var}}
	# __substitute_env_var_in_file "${GENERATED_ENV_FILE_FOR_COMPOSE}"
	# # process {{var}}
	# __substitute_key_in_file "${GENERATED_ENV_FILE_FOR_COMPOSE}"

	# # add quote for compose env file 2.x support
	# # https://deploy-preview-13474--docsdocker.netlify.app/compose/env-file/#syntax-rules
	# sed -i "s/^\([a-zA-Z0-9_-]*\)=\(.*\)$/\1='\2'/g" "${GENERATED_ENV_FILE_FOR_COMPOSE}"



	# # remove double bash quote before processing env file
	# sed -i 's/^\([a-zA-Z0-9_-]*\)=\"\(.*\)\"$/\1=\2/g' "${GENERATED_ENV_FILE_FOR_BASH}"

	# # process special assignment notations
	# __process_assignation_env_file "${GENERATED_ENV_FILE_FOR_BASH}"
	# # process {{$var}}
	# __substitute_env_var_in_file "${GENERATED_ENV_FILE_FOR_BASH}"
	# # process {{var}}
	# __substitute_key_in_file "${GENERATED_ENV_FILE_FOR_BASH}"
	
	# # add quote for variable bash support
	# sed -i 's/^\([a-zA-Z0-9_-]*\)=\(.*\)$/\1=\"\2\"/g' "${GENERATED_ENV_FILE_FOR_BASH}"

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

	[ -f "${__file}" ] && VARIABLES_LIST="${VARIABLES_LIST} $(sed -nE 's/^([^#=]*)=(.*)$/\1/gp' "${__file}")"
	VARIABLES_LIST="$($STELLA_API list_filter_duplicate "${VARIABLES_LIST}")"
}


# extract a list of variable that use a cumulative sign (+=)
__extract_variable_names_with_cumulative_assignment() {
	local __file="$1"

	[ -f "${__file}" ] && sed -nE 's/^([^#=]*)\+=.*$/\1/gp' "${__file}"
}




# add variables to variables list to be stored in env files
__add_declared_variables() {
	VARIABLES_LIST="${VARIABLES_LIST} $1"
}

# add associative array to arrays list to be stored in env files
__add_declared_associative_array() {
	ASSOCIATIVE_ARRAY_LIST="${ASSOCIATIVE_ARRAY_LIST} ${1}"
}



# generate env files for bash or docker compose from various env files (tango, ctx, modules and user env files) 
# 		__target bash : generate a bash file to be sourced (GENERATED_ENV_FILE_FOR_BASH)
# 		__target docker_compose : generate an env file to be used as env-file in environment section of docker compose file (GENERATED_ENV_FILE_FOR_COMPOSE)
# __target : bash | docker_compose
# __source_list : possible values : user, modules, ctx, default -- will create env file by adding in ascending priority order of this list
#				default ascending priority order is 'default ctx modules user', so default env var have lowest priority
#				NOTE : by default modules env file have higher priority than context env env file. 
#					This is needed because instead in context env file we would have to always use special notation (+= ?=) to cumulate settings with the modules env files and not override them
#					which is a non natural way of writing a context env file. (even if the logical priority ascending order should be 'default modules ctx user')
#					(i.e using LETS_ENCRYPT_SERVICES= in a context env file would have override all LETS_ENCRYPT_SERVICES+= defined in all module env files if context env file have higher priority )
#					So in module env files we must use special notation (?= +=) to not override context env value
__create_env_files() {
	local __target="$1"
	local __source_list="$2"

	[ "${__source_list}" = "" ] && __source_list="default ctx user modules"

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


	echo "# ------ CREATE : create_env_files for $__target : $(date)" > "${__file}"

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
								# except expression beginning with SHARED_VAR_
								# use sed implementation of negative lookbehind https://stackoverflow.com/a/26110465
								#sed -e "/FIXED_VAR/!s/${m}\([^a-zA-Z0-9]*\)/${i}\1/g" -e "/FIXED_VAR/!s/${m^^}\([^a-zA-Z0-9]*\)/${i^^}\1/g" <(echo \# --- PART FROM modules env file ${TANGO_CTX_MODULES_ROOT}/${m}.env) <(echo) <(echo) "${TANGO_CTX_MODULES_ROOT}/${m}.env" <(echo) >> "${__file}"
								sed -E "{/FIXED_VAR/! {s/#/##/g; s/(SHARED_VAR_)(${m})/\1_#_/g; s/(SHARED_VAR_)(${m^^})/\1-#-/g; s/${m}([^a-zA-Z0-9]*)/${i}\1/g; s/${m^^}([^a-zA-Z0-9]*)/${i^^}\1/g; s/(SHARED_VAR_)_#_/\1${m}/g; s/(SHARED_VAR_)-#-/\1${m^^}/g; s/##/#/g} }" <(echo \# --- PART FROM module env file ${TANGO_CTX_MODULES_ROOT}/${m}.env) <(echo) <(echo) "${TANGO_CTX_MODULES_ROOT}/${m}.env" <(echo) >> "${__file}"
							else
								if [ -f "${TANGO_MODULES_ROOT}/${m}.env" ]; then
									__tango_log "DEBUG" "tango" "create_env_files for $__target : tango module ${m} instance ${i} : add env file : ${TANGO_MODULES_ROOT}/${m}.env"
									# we replace all ocurrence of module name with an instance name
									# except into lines containing FIXED_VAR expression anywhere
									# except expression beginning with SHARED_VAR_
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




	if [ "$__target" = "bash" ]; then
		sed -i -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/\\$/g' "${__file}"
	fi
	
	# process special assignment notations
	__process_assignation_env_file "${__file}"
	# process {{$var}}
	__substitute_env_var_in_file "${__file}"
	# process {{var}}
	__substitute_key_in_file "${__file}"

	
	# add quote for variable bash support
	if [ "$__target" = "bash" ]; then
		sed -i 's/^\([a-zA-Z0-9_-]*\)=\(.*\)$/\1=\"\2\"/g' "${__file}"
	fi
	# add quote for compose env file 2.x support
	if [ "$__target" = "docker_compose" ]; then
		# https://deploy-preview-13474--docsdocker.netlify.app/compose/env-file/#syntax-rules
		# Compose V2 rely on godotenv library which has been designed to align with Ruby's implementation of dotEnv support,
		sed -i "s/^\([a-zA-Z0-9_-]*\)=\(.*\)$/\1='\2'/g" "${__file}"
	fi


}


# TODO function NOT USED
# generate env files for bash or docker compose from all variables env files (default tango env file, ctx env file, modules env files and user env files)
# 	__target : bash | docker_compose
#	__source_list : define stacking order to define a descending priority order
#				    default descending priority order is : 'user ctx modules default', so default tango env var have the lowest priority
# to process these data we need to group variable assigment type into several layers
__create_env_files_new() {
	local __target="$1"
	local __source_list="$2"
	[ "${__source_list}" = "" ] && __source_list="user ctx modules default"

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

	__init_env_file "${__file}" "${__source_list}"

	__parse_env_file "${__file}"





	# add quote for variable bash support and escape some characters
	if [ "$__target" = "bash" ]; then
		sed -i -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/\\$/g' "${__file}"
		sed -i 's/^\([a-zA-Z_]+[a-zA-Z0-9_]*\)=\(.*\)$/\1=\"\2\"/g' "${__file}"
	fi
	# add quote for compose env file 2.x support
	if [ "$__target" = "docker_compose" ]; then
		# https://deploy-preview-13474--docsdocker.netlify.app/compose/env-file/#syntax-rules
		# Compose V2 rely on godotenv library which has been designed to align with Ruby's implementation of dotEnv support,
		sed -i "s/^\([a-zA-Z_]+[a-zA-Z0-9_]*\)=\(.*\)$/\1='\2'/g" "${__file}"
	fi


}


# TODO __target not defined
__init_env_file() {
	local __file="$1"
	local __source_list="$2"
	
	touch "${__file}"


	local __comment_variables=
	for o in ${__source_list}; do

		case $o in 

			default )
				# add default tango env file
				__tango_log "DEBUG" "tango" "create_env_files for $__target : add default tango env file ${TANGO_ENV_FILE}"
				if [ -f "${TANGO_ENV_FILE}" ]; then 
					cat <(echo \# --- LAYER DEFAULT) >> "${__file}"
					if [ -s "${TANGO_ENV_FILE}" ]; then
						# catch VAR=, +=, !=, ?= expression
						__default_defined_variables="$(sed -nE "{s/^([a-zA-Z_]+[a-zA-Z0-9_]*)[\?\+\!]?=.*$/\0/gp}" "${TANGO_ENV_FILE}")"
						# catch dynamic variable {{VAR}} (not env variable {{$VAR}}
						#__default_dynamic_variables="$(sed -nE "{/^[ ]*#/! { s/.*\{\{([a-zA-Z_]+[a-zA-Z0-9_]*)\}\}.*/\1/gp } }" "${TANGO_ENV_FILE}")"
						# comment defined variables with = when previously already assigned with a =
						sed -E "{s/^("${__comment_variables}")=.*$/#\0/g}" <(echo "${__default_defined_variables}") >> "${__file}"

						# catch VAR= variable
						__default_assigned_variables="$(sed -nE "{s/^([a-zA-Z_]+[a-zA-Z0-9_]*)=.*$/\1/gp}" "${TANGO_ENV_FILE}")"
						[ ! "${__default_assigned_variables}" = "" ] && __comment_variables="$($STELLA_API trim "${__comment_variables}|${__default_assigned_variables}" | tr '\n' '|')"
					fi
				fi

			;;

			ctx )
				# add ctx env file
				if [ -f "${TANGO_CTX_ENV_FILE}" ]; then 
					__tango_log "DEBUG" "tango" "create_env_files for $__target : add ctx env file ${TANGO_CTX_ENV_FILE}"
					cat <(echo \# --- LAYER CONTEXT) >> "${__file}"
					if [ -s "${TANGO_CTX_ENV_FILE}" ]; then
						# catch VAR=, +=, !=, ?= expression
						__ctx_defined_variables="$(sed -nE "{s/^([a-zA-Z_]+[a-zA-Z0-9_]*)[\?\+\!]?=.*$/\0/gp}" "${TANGO_CTX_ENV_FILE}")"
						# catch dynamic variable {{VAR}} (not env variable {{$VAR}}
						#__ctx_dynamic_variables="$(sed -nE "{/^[ ]*#/! { s/.*\{\{([a-zA-Z_]+[a-zA-Z0-9_]*)\}\}.*/\1/gp } }" "${TANGO_CTX_ENV_FILE}")"
						# comment defined variables with = when previously already assigned with a =
						sed -E "{s/^("${__comment_variables}")=.*$/#\0/g}" <(echo "${__ctx_defined_variables}") >> "${__file}"

						# catch VAR= variable
						__ctx_assigned_variables="$(sed -nE "{s/^([a-zA-Z_]+[a-zA-Z0-9_]*)=.*$/\1/gp}" "${TANGO_CTX_ENV_FILE}")"
						[ ! "${__ctx_assigned_variables}" = "" ] && __comment_variables="$($STELLA_API trim "${__comment_variables}|${__ctx_assigned_variables}" | tr '\n' '|')"
					fi
				fi
			;;

			modules )
				# add modules env files for scaled modules
				__modules_list="${TANGO_SERVICES_MODULES}"
				__scaled_modules_processed=
				local _f=
				if [ ! "$TANGO_SERVICES_MODULES_SCALED" = "" ]; then
					__tango_log "DEBUG" "tango" "create_env_files for $__target : add modules env files for scaled modules : $TANGO_SERVICES_MODULES_SCALED"
					for m in ${TANGO_SERVICES_MODULES_SCALED}; do
						__instances_list="${m^^}_INSTANCES_LIST"

						for i in ${!__instances_list}; do
							# ctx modules overrides tango modules
							if [ -f "${TANGO_CTX_MODULES_ROOT}/${m}.env" ]; then
								_f="${TANGO_CTX_MODULES_ROOT}/${m}.env"
							else
								if [ -f "${TANGO_MODULES_ROOT}/${m}.env" ]; then 
									_f="${TANGO_MODULES_ROOT}/${m}.env"
								else
									__tango_log "DEBUG" "tango" "create_env_files for $__target : scaled module $m do not have an env file (${TANGO_CTX_MODULES_ROOT}/${m}.env nor ${TANGO_MODULES_ROOT}/${m}.env do not exists) might be an error"
								fi
							fi

							__tango_log "DEBUG" "tango" "create_env_files for $__target : module ${m} instance ${i} : add env file : ${_f}"
							# we replace all ocurrence of module name with an instance name
							# except into lines containing FIXED_VAR expression anywhere
							# except expression beginning with SHARED_VAR_
							# use sed implementation of negative lookbehind https://stackoverflow.com/a/26110465
							cat <(echo \# --- LAYER MODULE_${m^^}) >> "${__file}"
							[ -s "${_f}" ] && sed -E "{/FIXED_VAR/! {s/#/##/g; s/(SHARED_VAR_)(${m})/\1_#_/g; s/(SHARED_VAR_)(${m^^})/\1-#-/g; s/${m}([^a-zA-Z0-9]*)/${i}\1/g; s/${m^^}([^a-zA-Z0-9]*)/${i^^}\1/g; s/(SHARED_VAR_)_#_/\1${m}/g; s/(SHARED_VAR_)-#-/\1${m^^}/g; s/##/#/g} }" <(echo -n) "${_f}" >> "${__file}"
													
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
						_f="${TANGO_CTX_MODULES_ROOT}/${s}.env"
					else
						if [ -f "${TANGO_MODULES_ROOT}/${s}.env" ]; then 
							_f="${TANGO_MODULES_ROOT}/${s}.env"
						else
							__tango_log "DEBUG" "tango" "create_env_files for $__target : module $s do not have an env file (${TANGO_CTX_MODULES_ROOT}/${s}.env nor ${TANGO_MODULES_ROOT}/${s}.env do not exists) might be an error"
						fi
					fi
					__tango_log "DEBUG" "tango" "create_env_files for $__target : module ${s} : add env file : ${_f}.env"
					cat <(echo \# --- LAYER MODULE_${s^^}) >> "${__file}"
					[ -s "${_f}" ] && cat <"${_f}" >> "${__file}"
				done
			;;

			user )
				# add user env file
				if [ -f "${TANGO_USER_ENV_FILE}" ]; then
					__tango_log "DEBUG" "tango" "create_env_files for $__target : add user env file ${TANGO_USER_ENV_FILE}"
					cat <(echo \# --- LAYER USER) >> "${__file}"
					if [ -s "${TANGO_USER_ENV_FILE}" ]; then
						# catch VAR=, +=, !=, ?= expression
						__user_defined_variables="$(sed -nE "{s/^([a-zA-Z_]+[a-zA-Z0-9_]*)[\?\+\!]?=.*$/\0/gp}" "${TANGO_USER_ENV_FILE}")"
						# catch dynamic variable {{VAR}} (not env variable {{$VAR}}
						#__user_dynamic_variables="$(sed -nE "{/^[ ]*#/! { s/.*\{\{([a-zA-Z_]+[a-zA-Z0-9_]*)\}\}.*/\1/gp } }" "${TANGO_USER_ENV_FILE}")"
						# comment defined variables with = when previously already assigned with a =
						sed -E "{s/^("${__comment_variables}")=.*$/#\0/g}" <(echo "${__user_defined_variables}") >> "${__file}"

						# catch VAR= variable
						__user_assigned_variables="$(sed -nE "{s/^([a-zA-Z_]+[a-zA-Z0-9_]*)=.*$/\1/gp}" "${TANGO_USER_ENV_FILE}")"
						[ ! "${__user_assigned_variables}" = "" ] && __comment_variables="$($STELLA_API trim "${__comment_variables}|${__user_assigned_variables}" | tr '\n' '|')"
					fi
				fi
			;;
		esac
	done


	# get all cumulated variables and init them
	# TODO : do we copy in LAYER INIT any strict affectation (=) when a cumulated variable is implied ?
	local __cumulated_variables="$(sed -nE "{s/^([a-zA-Z_]+[a-zA-Z0-9_]*)\+=.*$/\1=/gp}" "${__file}")"
	local _temp=$(mktmp)
	cat <(echo "# --- LAYER INIT") <(printf "${__cumulated_variables:+$__cumulated_variables\n}") <(echo -n) "${__file}" > "${_temp}"
	cat "${_temp}" > "${__file}"
	rm -f "${_temp}"


}

__parse_env_file() {
	
	local __file="$1"


	# process {{$var}}  ---------------
	__substitute_env_var_in_file "${__file}"
	# process special assignment notations
	__process_assignation_env_file "${__file}"


	# process {{var}} ---------------

	# security counter to avoid infinite loop
	local __loop=0

	local _temp=$(mktmp)
	local _nb_line=$(wc -l < "${__file}")

	cat <(echo -n) "${__file}" > ${_temp}

	__get_solvable_dynamic_variables "${_temp}"
	local __nb_solvable="$(echo "$SOLVABLE_DYNAMIC_VARIABLES" | awk '{ print NF}')"	
	local __non_solvable_variables="$NON_SOLVABLE_DYNAMIC_VARIABLES"
	__tango_log "DEBUG" "tango" "__parse_env_file : init of loop __nb_solvable restant: ${__nb_solvable} __solvable_dynamic_variables : $SOLVABLE_DYNAMIC_VARIABLES non_solvable : $NON_SOLVABLE_DYNAMIC_VARIABLES"


	while [  ${__nb_solvable} -gt 0 ]
	do
		[ ${__loop} -gt 2 ] && __tango_log "ERROR" "tango" "__parse_env_file : might be lost in an infinite loop. looped $__loop times while converting all {{variable}} in env file ${__file}" && cat "${_temp}" > "${__file}" && rm -f "${_temp}" && exit 1
		
		__substitute_key_in_file "${_temp}" "$__non_solvable_variables"
		
		if [ ${__loop} -gt 0 ]; then
			sed -i -e "1,${_nb_line}d" "${_temp}"
		fi
		
		# Check if there is remaining variable that can be solved. 
		# A dynamic variable {{VAR}} can be solved 
		# if there is a VAR= VAR!= VAR?= VAR+= assignation expression in an other layer OR if there is an assignation expression before in the same layer
		__get_solvable_dynamic_variables "${_temp}"
#cat $_temp
		__nb_solvable="$(echo "$SOLVABLE_DYNAMIC_VARIABLES" | awk '{ print NF}')"

		if [  ${__nb_solvable} -gt 0 ]; then
			cat <(echo -n) "${__file}" >> ${_temp}
		fi

		__tango_log "DEBUG" "tango" "__parse_env_file : end of loop $__loop  __nb_solvable restant: ${__nb_solvable} __solvable_dynamic_variables : $SOLVABLE_DYNAMIC_VARIABLES non_solvable : $NON_SOLVABLE_DYNAMIC_VARIABLES"
		((__loop++))
	done
	
	if [ ${__loop} -gt 0 ]; then
		cat "${_temp}" > "${__file}"
	fi
	rm -f "${_temp}"
	
}


# remove commentary 
# manage += : cumulative assignation
# manage ?= : init value of not already assigned variable (within file or in env var) with a value 
# manage != : switch assignation : erase value of an already assigned variable (within file or in env var) with a value
# NOTE : we check ENVIRONnment variable to combine them with special assignation += ?= or !=
__process_assignation_env_file() {
	local _file="$1"

	__tango_log "DEBUG" "tango" "__process_assignation_env_file : ${_file}"
	local _temp=$(mktmp)

	awk -F= '
	BEGIN {
	}


	# catch !=
	/^[a-zA-Z_]+[a-zA-Z0-9_]*!=/ {
		key=substr($1, 1, length($1)-1);
		if (arr[key]) arr[key]=$2;
		else if(ENVIRON[key]) arr[key]=$2;
		
		print key"="arr[key];
		next;
	}

	# catch ?=
	/^[a-zA-Z_]+[a-zA-Z0-9_]*\?=/ {
		key=substr($1, 1, length($1)-1);
		if (arr[key]) arr[key]=arr[key];
		else if(ENVIRON[key]) arr[key]=ENVIRON[key];
		else arr[key]=$2;
		print key"="arr[key];
		next;
	}


	# catch +=
	/^[a-zA-Z_]+[a-zA-Z0-9_]*\+=/ {
		key=substr($1, 1, length($1)-1);
		if (arr[key]) arr[key]=arr[key] " " $2;
		else if(ENVIRON[key]) arr[key]=ENVIRON[key] " " $2;
		else arr[key]=$2;
		print key"="arr[key];
		next;
	}

	# catch =
	/^[a-zA-Z_]+[a-zA-Z0-9_]*=/ {
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
}


# NOT USED
# a dynamic variable {{VAR}} can be solved 
# if there is a VAR= VAR!= VAR?= VAR+= assignation expression in an other layer OR if there is an assignation expression before in the same layer
# set SOLVABLE_DYNAMIC_VARIABLES NON_SOLVABLE_DYNAMIC_VARIABLES global variables
__get_solvable_dynamic_variables() {
	local _file="$1"

	{ IFS= read -r SOLVABLE_DYNAMIC_VARIABLES;  IFS= read -r NON_SOLVABLE_DYNAMIC_VARIABLES; } < <(awk -F= '

	
	BEGIN {
		emptyarray()
		CURRENT_LAYER=""
		PREVIOUS_LAYER=""
		INTO_A_LAYER=0
		VAR=""
		CURRENT_LAYER_ASSIGNED_VAR=""
		SOLVABLE_VAR=""
		NON_SOLVABLE_VAR=""
	}
	
	# https://unix.stackexchange.com/a/147958
	function emptyarray() {
		# empty array
		split("", ASSIGNED_VAR)
	}
	


	# catch a LAYER
	/^[#] --- LAYER/ {
		INTO_A_LAYER=1;
		PREVIOUS_LAYER=CURRENT_LAYER
		CURRENT_LAYER_ASSIGNED_VAR=""
		if (match($0,/LAYER [a-zA-Z0-9]+/)) {
			CURRENT_LAYER=substr($0,RSTART+6,RLENGTH-1)
		}
		next
	}

	# catch VAR=
	/^[a-zA-Z_]+[a-zA-Z0-9_]*=/ {
		if (match($1,/[a-zA-Z_]+[a-zA-Z0-9_]*/)) {
			if (FNR==NR) {
				if (INTO_A_LAYER==1) ASSIGNED_VAR[CURRENT_LAYER]=ASSIGNED_VAR[CURRENT_LAYER] " " substr($1,RSTART,RLENGTH-0)
				next
			} else {
				CURRENT_LAYER_ASSIGNED_VAR=CURRENT_LAYER_ASSIGNED_VAR " " substr($1,RSTART,RLENGTH-0)
			}
		}
	}

	# catch VAR+=
	/^[a-zA-Z_]+[a-zA-Z0-9_]*\+=/ {
		if (match($1,/[a-zA-Z_]+[a-zA-Z0-9_]*\+/)) {
			if (FNR==NR) {
				if (INTO_A_LAYER==1) ASSIGNED_VAR[CURRENT_LAYER]=ASSIGNED_VAR[CURRENT_LAYER] " " substr($1,RSTART,RLENGTH-1)
				next
			} else {
				CURRENT_LAYER_ASSIGNED_VAR=CURRENT_LAYER_ASSIGNED_VAR " " substr($1,RSTART,RLENGTH-1)
			}
		}
	}

	# catch ?=
	/^[a-zA-Z_]+[a-zA-Z0-9_]*\?=/ {
		if (match($1,/[a-zA-Z_]+[a-zA-Z0-9_]*\?/)) {
			if (FNR==NR) {
				if (INTO_A_LAYER==1) ASSIGNED_VAR[CURRENT_LAYER]=ASSIGNED_VAR[CURRENT_LAYER] " " substr($1,RSTART,RLENGTH-1)
				next
			} else {
				CURRENT_LAYER_ASSIGNED_VAR=CURRENT_LAYER_ASSIGNED_VAR " " substr($1,RSTART,RLENGTH-1)
			}
		}
	}


	# catch !=
	/^[a-zA-Z_]+[a-zA-Z0-9_]*!=/ {
		if (match($1,/[a-zA-Z_]+[a-zA-Z0-9_]*!/)) {
			if (FNR==NR) {
				if (INTO_A_LAYER==1) ASSIGNED_VAR[CURRENT_LAYER]=ASSIGNED_VAR[CURRENT_LAYER] " " substr($1,RSTART,RLENGTH-1)
				next
			} else {
				CURRENT_LAYER_ASSIGNED_VAR=CURRENT_LAYER_ASSIGNED_VAR " " substr($1,RSTART,RLENGTH-1)
			}
		}
	}


	/.*/ {
		# FNR=NR only when reading first file
		if (FNR==NR) {
			next
		}
	}
	


	# this block is triggered at each line only if not bypassed by next
	# so this block is really triggered only when reading second file
	{	

		# catch {{VAR}}
		if (match($0,/{{[a-zA-Z_]+[a-zA-Z0-9_]*}}/)) {
			VAR=substr($0,RSTART+2,RLENGTH-4)

			PATTERN="[ ]*" VAR "[ ]*"

			if (CURRENT_LAYER_ASSIGNED_VAR ~ PATTERN) {
				# variable assigned before in the current layer
				SOLVABLE_VAR=SOLVABLE_VAR " " VAR
				next
			}

			# if we parsed at least one layer
			if (INTO_A_LAYER==1) {
				if (CURRENT_LAYER!="INIT") {
					if (ASSIGNED_VAR["INIT"] ~ PATTERN) {
						# variable assigned in another layer
						SOLVABLE_VAR=SOLVABLE_VAR " " VAR
						next
					}
				}

				if (CURRENT_LAYER!="DEFAULT") {
					if (ASSIGNED_VAR["DEFAULT"] ~ PATTERN) {
						# variable assigned in another layer
						SOLVABLE_VAR=SOLVABLE_VAR " " VAR
						next
					}
				}
				
				if (CURRENT_LAYER!="CONTEXT") {
					if (ASSIGNED_VAR["CONTEXT"] ~ PATTERN) {
						# variable assigned in another layer
						SOLVABLE_VAR=SOLVABLE_VAR " " VAR
						next
					}
				}

				if (CURRENT_LAYER!="MODULE") {
					if (ASSIGNED_VAR["MODULE"] ~ PATTERN) {
						# variable assigned in another layer
						SOLVABLE_VAR=SOLVABLE_VAR " " VAR
						next
					}
				}

				if (CURRENT_LAYER!="USER") {
					if (ASSIGNED_VAR["USER"] ~ PATTERN) {
						# variable assigned in another layer
						SOLVABLE_VAR=SOLVABLE_VAR " " VAR
						next
					}
				}
			}


			NON_SOLVABLE_VAR=NON_SOLVABLE_VAR " " VAR

		}
	}
	
	END {


		split(NON_SOLVABLE_VAR,TEMP_NON_SOLVABLE_VAR," ")
		
		# if a variable is tagged as solvable, it cannot be also tagged as non solvable later/earlier in the file
		NON_SOLVABLE_VAR=""
		for (key in TEMP_NON_SOLVABLE_VAR) {
			PATTERN="[ ]*" TEMP_NON_SOLVABLE_VAR[key] "[ ]*"
			if (SOLVABLE_VAR !~ PATTERN) {
				NON_SOLVABLE_VAR=NON_SOLVABLE_VAR " " TEMP_NON_SOLVABLE_VAR[key]
			}
		}

		# trim SOLVABLE_VAR and NON_SOLVABLE_VAR
		{ gsub(/^[ \t]+|[ \t]+$/, "", SOLVABLE_VAR) } 1
		{ gsub(/^[ \t]+|[ \t]+$/, "", NON_SOLVABLE_VAR) } 1

		OFS=" "
		print SOLVABLE_VAR
		print NON_SOLVABLE_VAR
	}
	' "${_file}" "${_file}" )



	


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
#	_exclude_list : a white separated list of key to NOT resolve
__substitute_key_in_file() {

	local _file="$1"
	# keys list to not resolve
	local _exclude_list="$2"

	__tango_log "DEBUG" "tango" "__substitute_key_in_file : ${_file}"
	local _temp=$(mktmp)

	awk -F= -v EXCLUDE_LIST="${_exclude_list}" '

 		function parsekey(str) {
			# if there is a value assignation to a key into this string
			# update val array
			if (match(str,/^[a-zA-Z_]+[a-zA-Z0-9_]*=/)) {
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
			# prepare a dictionnary with exclude variable list
			split(EXCLUDE_LIST, TEMP_ARRAY_EXCLUDE_LIST," ")
			for (i in TEMP_ARRAY_EXCLUDE_LIST) ARRAY_EXCLUDE_LIST[TEMP_ARRAY_EXCLUDE_LIST[i]]="";

			for (k in key) {
				# transform any reference to the key in current line into its value, if it has a known value
				# key[] list all existing keys in file
				# val[] list only key which have a known value
				if (k in val) {
					# we replace any reference to the key with its value with gsub in current line
					if (k in ARRAY_EXCLUDE_LIST == 0) { 
						gsub("{{"k"}}", val[k]);
					}
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




# solve assignation symbol VAR= VAR!= VAR?= VAR+= and dynamic variable {{VAR}}, split in several layer
# a dynamic variable {{VAR}} can be solved 
# 	if there is a VAR= VAR!= VAR?= VAR+= assignation expression in an other layer (which is in this case a global variable)
# 	or if there is an assignation expression before in the same layer (which is in this case a local variable to the current layer)
# algorithm
#		1.read file a first time, at each line
#			catch assignation symbol VAR= VAR!= VAR?= VAR+=
#					and store assigned variable in an array by layer
#					and set to assigned variable a value in an array 
#			store each line in a global array
#		2.read file a second time, at each line
#			catch assignation symbol VAR= VAR!= VAR?= VAR+= and store assigned variable for the current layer
#			for each dynamic variable found in the line 
#				look for it as an assigned variable from the current layer and solve its with its value and store it as a solvable variable
#				or look for this assigned variable in ather layer and store it as a solvable variable
#		3.at the end, for each line stored in a global array
#			for each dynamic variable found in the line 
#				check if it is a solvable variable and solve its with its value 
__solve_dynamic_variables() {
	local _file="$1"

	# { IFS= read -r SOLVABLE_DYNAMIC_VARIABLES;  IFS= read -r NON_SOLVABLE_DYNAMIC_VARIABLES; } < <(
	awk -F= '

	
	BEGIN {
		emptyarray()
		CURRENT_LAYER=""
		VAR=""
		SOLVABLE_VAR=""
		SOLVED=0
		NON_SOLVABLE_VAR=""
		OUTPUT_LENGTH=0
		DEBUG=1
		# LAYER_REVERSED_LIST contains layer list in descending priority order (from last to first)
		LAYER_REVERSED_LIST=""

	}
	
	# https://unix.stackexchange.com/a/147958
	function emptyarray() {
		# empty array

		# ASSIGNED_VAR an array of assigned variables by layer name
		split("", ASSIGNED_VAR)
		# ASSIGNED_VAR_FIRST_ASSIGNATION is an array of line number of first assignation of a variable in a layer
		split("", ASSIGNED_VAR_FIRST_ASSIGNATION)
		# VALUE_VAR is an array of values by variable name
		split("", VALUE_VAR)
		# VALUE_VAR_BY_LAYER is an array of values by layer and variable name
		split("", VALUE_VAR_BY_LAYER)
		# OUTPUT is an array of result strings
		split("", OUTPUT)
		# NON_SOLVABLE_LOCAL_VAR is an array of non solvable local to a layer variables by line number
		split("", NON_SOLVABLE_LOCAL_VAR)
		# LAYER_START_LINE is an array by layer with its starting line number
		split("", LAYER_START_LINE)
		# LAYER_REVERSED_LIST_ARRAY[n] is an array with layer name as value in descending priority order (from last to first)
		split(LAYER_REVERSED_LIST, LAYER_REVERSED_LIST_ARRAY, " ")

	}

	# give name layer from line number
	function get_layer(LINE_NUMBER) {
		for(l in LAYER_REVERSED_LIST_ARRAY) {
			layer_name=LAYER_REVERSED_LIST_ARRAY[l]
			if (LINE_NUMBER>=LAYER_START_LINE[layer_name]) return layer_name
		}
	}

	# for a given layer give global value of a variable
	function get_global_var_value(VAR, LOCAL_LAYER) {
		
		PATTERN="[ ]*" VAR "[ ]*"

		for(l in LAYER_REVERSED_LIST_ARRAY) {
			index_name=LAYER_REVERSED_LIST_ARRAY[l]"_"VAR
			if (LAYER_REVERSED_LIST_ARRAY[l]==LOCAL_LAYER) continue
			if (ASSIGNED_VAR[LAYER_REVERSED_LIST_ARRAY[l]] ~ PATTERN) return VALUE_VAR_BY_LAYER[index_name]
		}
		return 
	}

	# for a given layer give local value of a variable
	function get_local_var_value(VAR, LOCAL_LAYER) {
		index_name=LOCAL_LAYER"_"VAR
		return VALUE_VAR_BY_LAYER[index_name]
	}

	
	# for a given layer return true if a local value of a variable exists
	function local_var_value_exists(VAR, LOCAL_LAYER) {
		PATTERN="[ ]*" VAR "[ ]*"
		if (ASSIGNED_VAR[LOCAL_LAYER] ~ PATTERN) return 1
		return 0
	}

	# for a given layer return the highest priority layer of a global value of a variable if it exists for a given local layer or return false
	function global_var_value_exists(VAR, LOCAL_LAYER) {
		PATTERN="[ ]*" VAR "[ ]*"

		for(l in LAYER_REVERSED_LIST_ARRAY) {
			if (LAYER_REVERSED_LIST_ARRAY[l]==LOCAL_LAYER) continue
			if (ASSIGNED_VAR[LAYER_REVERSED_LIST_ARRAY[l]] ~ PATTERN) return LAYER_REVERSED_LIST_ARRAY[l]
		}
		return 0
	}
	
	# give value of a variable depending of its local layer and line number
	# NOTE : before calling this function check if the var is a SOLVABLE_VAR
	#		 before using result first check if current var in this line number is not a NON_SOLVABLE_LOCAL_VAR 
	function get_var_value(VAR, LOCAL_LAYER, LINE_NUMBER) {
		index_name=LOCAL_LAYER"_"VAR

		if(local_var_value_exists(VAR, LOCAL_LAYER)) {
			if(ASSIGNED_VAR_FIRST_ASSIGNATION[index_name]<=LINE_NUMBER) {
				# use local layer value
				# loop until line_number to get local value
				for (i = ASSIGNED_VAR_FIRST_ASSIGNATION[index_name]; i <= LINE_NUMBER; i++) {
					REG="^" VAR "="
					if (match(OUTPUT[i], REG)) {
						VAL=substr(OUTPUT[i], RSTART+RLENGTH)
					}
				}
				if (DEBUG) print "----------value of "VAR" is solved as a local var assigned earlier with value "VAL ASSIGNED_VAR_FIRST_ASSIGNATION[index_name]
				return VAL
			} else {
				if (global_var_value_exists(VAR, LOCAL_LAYER)) {
					# use global layer value
					VAL=get_global_var_value(VAR, LOCAL_LAYER)
					if (DEBUG) print "----------value of "VAR" is solved as a global var with value : "VAL
					return VAL
				} else {
					# NON SOLVABLE LOCAL
					NON_SOLVABLE_LOCAL_VAR[LINE_NUMBER]=NON_SOLVABLE_LOCAL_VAR[LINE_NUMBER] " " VAR
					if (DEBUG) print "----------value of "VAR" is tagged as a non solvable local variable"
					return
				}
			}
		} else {
			if (global_var_value_exists(VAR, LOCAL_LAYER)) {
				# use global layer value
				VAL=get_global_var_value(VAR, LOCAL_LAYER)
				if (DEBUG) print "----------value of "VAR" is solved as a global var with value : "VAL
				return VAL
			} else {
				# NON SOLVABLE
				if (DEBUG) print "----------value of "VAR" is non solvable. We should never reach this point !"
				return
			}
		}
	}



	# function to catch assignation 
	# and store or return value
	function parse_var(str, LOCAL_LAYER) {

		# process = assignation
		if (match(str,/^[a-zA-Z_]+[a-zA-Z0-9_]*=/)) {
			VAR=substr(str, RSTART, RLENGTH-1)
			if (DEBUG) print "----------process "VAR"= in "str

			VAL=substr(str, RSTART+RLENGTH)

			VALUE_VAR[VAR]=VAL
			index_name=LOCAL_LAYER"_"VAR
			VALUE_VAR_BY_LAYER[index_name]=VAL
		}

		# process += assignation
		if (match(str,/[a-zA-Z_]+[a-zA-Z0-9_]*\+=/)) {
			VAR=substr(str, RSTART, RLENGTH-2)
			if (DEBUG) print "----------process "VAR"+= in "str

			VAL=substr(str, RSTART+RLENGTH)

			if (VALUE_VAR[VAR]) VALUE_VAR[VAR]=VALUE_VAR[VAR] " " VAL
			else if(ENVIRON[VAR]) VALUE_VAR[VAR]=ENVIRON[VAR] " " VAL
			else VALUE_VAR[VAR]=VAL

			index_name=LOCAL_LAYER"_"VAR
			if (VALUE_VAR_BY_LAYER[index_name]) VALUE_VAR_BY_LAYER[index_name]=VALUE_VAR_BY_LAYER[index_name] " " VAL
			else if (VALUE_VAR[VAR]) VALUE_VAR_BY_LAYER[index_name]=VALUE_VAR[VAR] " " VAL
			else if(ENVIRON[VAR]) VALUE_VAR_BY_LAYER[index_name]=ENVIRON[VAR] " " VAL
			else VALUE_VAR_BY_LAYER[index_name]=VAL
		}

		# process ?= assignation
		if (match(str,/[a-zA-Z_]+[a-zA-Z0-9_]*\?=/)) {
			VAR=substr(str, RSTART, RLENGTH-2)
			if (DEBUG) print "----------process "VAR"?= in "str

			VAL=substr(str, RSTART+RLENGTH)
			if (VALUE_VAR[VAR]) VALUE_VAR[VAR]=VALUE_VAR[VAR]
			else if(ENVIRON[VAR]) VALUE_VAR[VAR]=ENVIRON[VAR]
			else VALUE_VAR[VAR]=VAL

			index_name=LOCAL_LAYER"_"VAR
			if (VALUE_VAR_BY_LAYER[index_name]) VALUE_VAR_BY_LAYER[index_name]=VALUE_VAR_BY_LAYER[index_name]
			else if(ENVIRON[VAR]) VALUE_VAR_BY_LAYER[index_name]=ENVIRON[VAR]
			else VALUE_VAR_BY_LAYER[index_name]=VAL
		}

		# process != assignation
		if (match(str,/[a-zA-Z_]+[a-zA-Z0-9_]*!=/)) {
			VAR=substr(str, RSTART, RLENGTH-2)
			if (DEBUG) print "----------process "VAR"!= in "str

			VAL=substr(str, RSTART+RLENGTH)
			if (VALUE_VAR[VAR]) VALUE_VAR[VAR]=VAL
			else if(ENVIRON[VAR]) VALUE_VAR[VAR]=VAL
			
			index_name=LOCAL_LAYER"_"VAR
			if (VALUE_VAR_BY_LAYER[index_name]) VALUE_VAR_BY_LAYER[index_name]=VAL
			else if(ENVIRON[VAR]) VALUE_VAR_BY_LAYER[index_name]=VAL
		}


		if (DEBUG) {
			print "----------var "VAR" value is now : "VALUE_VAR[VAR]
			print "----------var "VAR" value for current layer "CURRENT_LAYER" is now : "VALUE_VAR_BY_LAYER[index_name]
		}

	}


	# replace dynamic variable with its current known value and return result string
	function replace_var(LINE, LINE_NUMBER) {
		LAYER=get_layer(LINE_NUMBER)
		if (DEBUG) { 
			print "-----BEGIN REPLACEVAR"
			print "----------line : "LINE
			print "----------line number: "LINE_NUMBER
			print "----------layer name: "LAYER
		}
		str=LINE
		while (match(str,/{{[a-zA-Z_]+[a-zA-Z0-9_]*}}/) >0) {
			
			VAR=substr(LINE,RSTART+2,RLENGTH-4)

			# next iteration
			str=substr(str, RSTART+RLENGTH)
			PATTERN="[ ]*" VAR "[ ]*"

			if (DEBUG) { 
				print "----------found variable "VAR " at pos "RSTART " length " RLENGTH
				print "----------check variable "VAR " is a solvable variable : "SOLVABLE_VAR
			}
			if (SOLVABLE_VAR ~ PATTERN) {
				VAL=get_var_value(VAR, LAYER, LINE_NUMBER)
				if (NON_SOLVABLE_LOCAL_VAR[LINE_NUMBER] !~ PATTERN) {
					if (DEBUG) print "----------replace variable "VAR "  with value " VAL
					gsub("{{"VAR"}}", VAL, LINE)
					parse_var(LINE, LAYER)
					LINE=replace_var(LINE, LINE_NUMBER)
				} else {
					if (DEBUG) print "----------variable is a non solvable local variable"
				}
			} else {
				if (DEBUG) print "----------variable is a non solvable variable"
			}
		}
		if (DEBUG) { 
			print "-----END REPLACEVAR"
		}
		return LINE
	}

	# -----------------------------------------------------------------------------

	/.*/ {
		# init CURRENT_LAYER value at each time file start to be read
		if (FNR==1) {
			CURRENT_LAYER="__NO_LAYER_NAME__"
		}
		# init only when first reading file
		if (NR==1) {
			LAYER_START_LINE[CURRENT_LAYER]=FNR
			LAYER_REVERSED_LIST=CURRENT_LAYER
			split(LAYER_REVERSED_LIST, LAYER_REVERSED_LIST_ARRAY, " ")
		}
	}

	# catch a LAYER
	/^[#] --- LAYER/ {
		if (match($0,/LAYER [a-zA-Z0-9]+/)) {
			CURRENT_LAYER=substr($0,RSTART+6,RLENGTH-1)
		}
		
		if (DEBUG) print "--LAYER : "CURRENT_LAYER

		if (FNR==NR) {
			LAYER_REVERSED_LIST=CURRENT_LAYER " " LAYER_REVERSED_LIST " "
			split(LAYER_REVERSED_LIST, LAYER_REVERSED_LIST_ARRAY, " ")

			LAYER_START_LINE[CURRENT_LAYER]=FNR
			OUTPUT_LENGTH++
			OUTPUT[OUTPUT_LENGTH]=$0
			next
		}
	}

	# catch VAR=
	/^[a-zA-Z_]+[a-zA-Z0-9_]*=/ {
		if (DEBUG) print "-----CATCH ="

		if (match($1,/[a-zA-Z_]+[a-zA-Z0-9_]*/)) {
			VAR=substr($1, RSTART, RLENGTH-0)
			
			# process = assignation
			parse_var($0, CURRENT_LAYER)

			if (FNR==NR) {
				# store assigned var for current layer
				ASSIGNED_VAR[CURRENT_LAYER]=ASSIGNED_VAR[CURRENT_LAYER] " " VAR
				# store assignation line number
				index_name=CURRENT_LAYER"_"VAR
				if (!ASSIGNED_VAR_FIRST_ASSIGNATION[index_name]) ASSIGNED_VAR_FIRST_ASSIGNATION[index_name]=FNR

				if (DEBUG) print "----------add "VAR" to ASSIGNED_VAR["CURRENT_LAYER"] "ASSIGNED_VAR[CURRENT_LAYER]
				
				OUTPUT_LENGTH++
				OUTPUT[OUTPUT_LENGTH]=$0
				next
			}
		}
	}

	# catch VAR+=
	/^[a-zA-Z_]+[a-zA-Z0-9_]*\+=/ {
		if (DEBUG) print "-----CATCH +="

		if (match($1,/[a-zA-Z_]+[a-zA-Z0-9_]*\+/)) {
			VAR=substr($1, RSTART, RLENGTH-1)
			
			if (FNR==NR) {
				# process += assignation
				#parse_var($0, CURRENT_LAYER)

				# store assigned var for current layer
				ASSIGNED_VAR[CURRENT_LAYER]=ASSIGNED_VAR[CURRENT_LAYER] " " VAR
				# store assignation line number
				index_name=CURRENT_LAYER"_"VAR
				if (!ASSIGNED_VAR_FIRST_ASSIGNATION[index_name]) ASSIGNED_VAR_FIRST_ASSIGNATION[index_name]=FNR

				if (DEBUG) print "----------add "VAR" to ASSIGNED_VAR["CURRENT_LAYER"] "ASSIGNED_VAR[CURRENT_LAYER]			

				OUTPUT_LENGTH++
				OUTPUT[OUTPUT_LENGTH]=VAR"="VALUE_VAR[VAR]
				next
			}
		}
	}

	# catch ?=
	/^[a-zA-Z_]+[a-zA-Z0-9_]*\?=/ {
		if (DEBUG) print "-----CATCH ?="

		if (match($1,/[a-zA-Z_]+[a-zA-Z0-9_]*\?/)) {
			VAR=substr($1, RSTART, RLENGTH-1)

			if (FNR==NR) {
				# process ?= assignation
				parse_var($0, CURRENT_LAYER)
							
				# store assigned var for current layer
				ASSIGNED_VAR[CURRENT_LAYER]=ASSIGNED_VAR[CURRENT_LAYER] " " VAR
				# store assignation line number
				index_name=CURRENT_LAYER"_"VAR
				if (!ASSIGNED_VAR_FIRST_ASSIGNATION[index_name]) ASSIGNED_VAR_FIRST_ASSIGNATION[index_name]=FNR

				if (DEBUG) print "----------add "VAR" to ASSIGNED_VAR["CURRENT_LAYER"] "ASSIGNED_VAR[CURRENT_LAYER]

				OUTPUT_LENGTH++
				OUTPUT[OUTPUT_LENGTH]=VAR"="VALUE_VAR[VAR]
				next
			}
		}
	}


	# catch !=
	/^[a-zA-Z_]+[a-zA-Z0-9_]*!=/ {
		if (DEBUG) print "-----CATCH !="

		if (match($1,/[a-zA-Z_]+[a-zA-Z0-9_]*!/)) {
			VAR=substr($1, RSTART, RLENGTH-1)

			# process != assignation
			parse_var($0, CURRENT_LAYER)

			if (FNR==NR) {
				# store assigned var for current layer
				ASSIGNED_VAR[CURRENT_LAYER]=ASSIGNED_VAR[CURRENT_LAYER] " " VAR
				# store assignation line number
				index_name=CURRENT_LAYER"_"VAR
				if (!ASSIGNED_VAR_FIRST_ASSIGNATION[index_name]) ASSIGNED_VAR_FIRST_ASSIGNATION[index_name]=FNR
				
				if (DEBUG) print "----------add "VAR" to ASSIGNED_VAR["CURRENT_LAYER"] "ASSIGNED_VAR[CURRENT_LAYER]

				OUTPUT_LENGTH++
				OUTPUT[OUTPUT_LENGTH]=VAR"="VALUE_VAR[VAR]
				next
			}
		}
	}


	/.*/ {
		# FNR=NR only when reading first file
		if (FNR==NR) {
			OUTPUT_LENGTH++
			OUTPUT[OUTPUT_LENGTH]=$0
			next
		}
	}
	


	# this block is triggered at each line only if not bypassed by next
	# so this block is really triggered only when reading second file
	{	
		if (DEBUG) {
			print "-----BEGIN analyse line num "NR
			print "----------LINE : "$0
			print "----------SOLVABLE_VAR so far : "SOLVABLE_VAR
		}

		# catch {{VAR}}
		LINE=$0

		while (match(LINE,/{{[a-zA-Z_]+[a-zA-Z0-9_]*}}/) >0) {
			VAR=substr(LINE,RSTART+2,RLENGTH-4)
			PATTERN="[ ]*" VAR "[ ]*"

			# next line
			LINE=substr(LINE, RSTART+RLENGTH)

			if (NON_SOLVABLE_VAR ~ PATTERN) {
				if (DEBUG) print "----------variable "VAR" is already tagged as a non solvable variable"
				continue
			}

			if (SOLVABLE_VAR ~ PATTERN) {
				if (DEBUG) print "----------variable "VAR" is already tagged as a solvable variable"
			} else {
				if (local_var_value_exists(VAR, CURRENT_LAYER)) {
					if (DEBUG) print "----------variable "VAR" can be solved as a local layer variable in the current layer "CURRENT_LAYER
					SOLVABLE_VAR=SOLVABLE_VAR " " VAR
				} else {
					l=global_var_value_exists(VAR, CURRENT_LAYER)
					if(l) {
						# there is an assigned global variable into another layer
						if (DEBUG) print "----------variable "VAR" can be solved as a global layer variable from layer : "l
						SOLVABLE_VAR=SOLVABLE_VAR " " VAR
					} else {
						if (DEBUG) print "----------variable "VAR" is a non solvable either in local layer nor in global layer"
						NON_SOLVABLE_VAR=NON_SOLVABLE_VAR " " VAR
					}
				}
			}
		}

		if (DEBUG) print "-----END analyse line num "NR
	}


	


	
	END {

		# trim SOLVABLE_VAR and NON_SOLVABLE_VAR
		{ gsub(/^[ \t]+|[ \t]+$/, "", SOLVABLE_VAR) } 1
		{ gsub(/^[ \t]+|[ \t]+$/, "", NON_SOLVABLE_VAR) } 1

		#OFS=" "
		#print SOLVABLE_VAR
		#print NON_SOLVABLE_VAR


		# replace {{VAR}} with global variables
		for (j = 1; j <= OUTPUT_LENGTH; j++) {
			OUTPUT[j]=replace_var(OUTPUT[j],j)
		}

		for (j = 1; j <= OUTPUT_LENGTH; j++) {
			print OUTPUT[j]
		}
		
	}
	' "${_file}" "${_file}"
	#)



}	




# Resolve strict assignation symbol VAR= and special assignation symbols VAR!= VAR?= VAR+= and dynamic variable {{VAR}}, splitted in several layer

# special assignation symbols VAR!= VAR?= VAR+= are relative to, in resolution order :
# 		* strict assignation VAR= or special assignation symbols VAR!= VAR?= VAR+= closest resulting value before the current line of the same layer
#		* strict assignation VAR= resulting value of another layer picking the highest layer priority order
# 		TODO ? * environment variable value if not empty
#		* any special assignation symbols VAR!= VAR?= VAR+= resulting value of the closest layer before the current one
# a dynamic variable {{VAR}} can be solved in this resolution order, if exists any
#       * strict assignation VAR= or special assignation symbols VAR!= VAR?= VAR+= before the current line of the same layer
# 		* strict assignation VAR= in any other layer
# 		* special assignation symbols VAR!= VAR?= VAR+= in any previous layer before the current one
# 	* OR it CANNOT be solved

# read N times file
# 	1st time: determine strict assigned value by layer
# 	2nd time: determine non solvable dynamic variable
# 	3rd time: resolve special assignation symbol
__solve_dynamic_variables2() {
	local _file="$1"

	awk -F= '

	
	BEGIN {
		DEBUG=1

		emptyarray()
		
		# STRICT_ASSIGN_VAR_LIST
		# list of variable which have been strict assigned at least once
		#STRICT_ASSIGN_VAR_LIST=""

		# REVERSED_ORDER_LAYER_LIST
		# list of layer names in descending priority order (from last to first)
		REVERSED_ORDER_LAYER_LIST=""

		# CURRENT_LAYER 
		# current analysed layer
		CURRENT_LAYER=""

		# OUTPUT_LENGTH 
		# array size of output resulting strings
		OUTPUT_LENGTH=0

		# CURRENT_VAR
		# current analysed variable name
		CURRENT_VAR=""

		# CURRENT_VAL
		# current analysed value
		CURRENT_VAL=""

		# NON_SOLVABLE_VAR_LIST
		# list of dynamic variable that cannot be solved at all
		NON_SOLVABLE_VAR_LIST=""
		SOLVABLE_AS_EMPTY_VAR_LIST=""
		SOLVABLE_VAR=""
		SOLVED=0
		#NON_SOLVABLE_VAR=""
	}
	
	# empty all arrays
	# https://unix.stackexchange.com/a/147958
	function emptyarray() {
		
		# FINAL_VALUE_BY_LAYER_VAR 
		# array of variable value by layer
		# split("", FINAL_VALUE_BY_LAYER_VAR)

		# FINAL_VALUE_STRICT_ASSIGN_BY_LAYER_VAR 
		# array by layer of variable value evaluated with a strict assignation as first assignation
		# split("", FINAL_VALUE_STRICT_ASSIGN_BY_LAYER_VAR)

		# FIRST_STRICT_ASSIGN_LN_BY_LAYER_VAR
		# array of line number of the first strict assignation of a variable by layer
		# split("", FIRST_STRICT_ASSIGN_LN_BY_LAYER_VAR)

		# STRICT_ASSIGN_VAR_LIST_BY_LAYER
		# list of variable which have been strict assigned at least once for each layer
		# split("", STRICT_ASSIGN_VAR_LIST_BY_LAYER)

		# ASSIGN_VAR_LIST_BY_LAYER
		# list of variable which have been assigned at least once for each layer
		# split("", ASSIGN_VAR_LIST_BY_LAYER)

		# REVERSED_ORDER_LAYER_BY_PRIORITY
		# array with layer name as value in descending priority order (from last to first)
		split(REVERSED_ORDER_LAYER_LIST, REVERSED_ORDER_LAYER_BY_PRIORITY, " ")

		# START_LN_BY_LAYER
		# array of first line number for each layer
		split("", START_LN_BY_LAYER)

		# OUTPUT_BY_LN
		# array of result strings by line number
		split("", OUTPUT_BY_LN)


		# ASSIGNED_VAR an array of assigned variables by layer name
		split("", ASSIGNED_VAR)
		# ASSIGNED_VAR_FIRST_ASSIGNATION is an array of line number of first assignation of a variable in a layer
		split("", ASSIGNED_VAR_FIRST_ASSIGNATION)
		# VALUE_VAR is an array of values by variable name
		split("", VALUE_VAR)
		# VALUE_VAR_BY_LAYER is an array of values by layer and variable name
		split("", VALUE_VAR_BY_LAYER)
		# NON_SOLVABLE_LOCAL_VAR is an array of non solvable local to a layer variables by line number
		split("", NON_SOLVABLE_LOCAL_VAR)
		

	}

	# return true if a word is present in a space separated list
	function list_contains(LIST, WORD) {
		if(LIST) {
			REGEX="[ ]*" WORD "[ ]*"
			return LIST ~ REGEX
		}
		return 0
	}


	# give name layer from line number
	function get_layer(LINE_NUMBER) {
		for(l in REVERSED_ORDER_LAYER_BY_PRIORITY) {
			layer_name=REVERSED_ORDER_LAYER_BY_PRIORITY[l]
			if (LINE_NUMBER>=START_LN_BY_LAYER[layer_name]) return layer_name
		}
	}



	# return the highest priority layer name previous than the given layer OR false
	function is_previous_priority_value_exists(VAR, LAYER) {
		flag=0
		for(l in REVERSED_ORDER_LAYER_BY_PRIORITY) {
			l=REVERSED_ORDER_LAYER_BY_PRIORITY[l]
			if (l==LAYER) {
				flag=1
				continue
			}
			if(!flag) continue
			if (list_contains(ASSIGN_VAR_LIST_BY_LAYER[l], VAR)) {
				return l
			}
		}
		return 0
	}

	function get_previous_priority_value(VAR, LAYER) {
		result=is_previous_priority_value_exists(VAR, LAYER)
		if(result) {
			index_name=result"_"VAR
			return FINAL_VALUE_BY_LAYER_VAR[index_name]
		}
		return
	}


	# return the highest priority layer name other than the given layer for a strict assigned var OR false
	function is_high_priority_value_exists(VAR, LAYER) {
		for(l in REVERSED_ORDER_LAYER_BY_PRIORITY) {
			l=REVERSED_ORDER_LAYER_BY_PRIORITY[l]
			if (l==LAYER) continue
			if (list_contains(STRICT_ASSIGN_VAR_LIST_BY_LAYER[l], VAR)) {
				return l
			}
		}
		return 0
	}

	# give the value of strict assignation resulting value of another layer picking the highest layer available in priority order
	function get_high_priority_value(VAR, LAYER) {
		result=is_high_priority_value_exists(VAR, LAYER)
		if(result) {
			index_name=result"_"VAR
			return FINAL_VALUE_STRICT_ASSIGN_BY_LAYER_VAR[index_name]
		}
		return
	}

	function is_dynamic_variable_solvable(VAR, LAYER) {
		if (list_contains(ASSIGN_VAR_LIST_BY_LAYER[LAYER], VAR))  {
			result=1
		} else {
			if (is_high_priority_value_exists(VAR, LAYER)) {
				result=1
			} else {
				if (is_previous_priority_value_exists(VAR, LAYER)) {
					result=1
				} else {
					result=0
				}
			}
		}
		return result

	}







	

	# replace dynamic variable with its current known value and return result string
	function replace_var(LINE, LINE_NUMBER) {
		LAYER=get_layer(LINE_NUMBER)
		if (DEBUG) { 
			print "-----BEGIN REPLACEVAR"
			print "----------line : "LINE
			print "----------line number: "LINE_NUMBER
			print "----------layer name: "LAYER
		}
		str=LINE
		while (match(str,/{{[a-zA-Z_]+[a-zA-Z0-9_]*}}/) >0) {
			
			VAR=substr(LINE,RSTART+2,RLENGTH-4)

			# next iteration
			str=substr(str, RSTART+RLENGTH)
			PATTERN="[ ]*" VAR "[ ]*"

			if (DEBUG) { 
				print "----------found variable "VAR " at pos "RSTART " length " RLENGTH
				print "----------check variable "VAR " is a solvable variable : "SOLVABLE_VAR
			}
			if (SOLVABLE_VAR ~ PATTERN) {
				VAL=get_var_value(VAR, LAYER, LINE_NUMBER)
				if (NON_SOLVABLE_LOCAL_VAR[LINE_NUMBER] !~ PATTERN) {
					if (DEBUG) print "----------replace variable "VAR "  with value " VAL
					gsub("{{"VAR"}}", VAL, LINE)
					parse_var(LINE, LAYER)
					LINE=replace_var(LINE, LINE_NUMBER)
				} else {
					if (DEBUG) print "----------variable is a non solvable local variable"
				}
			} else {
				if (DEBUG) print "----------variable is a non solvable variable"
			}
		}
		if (DEBUG) { 
			print "-----END REPLACEVAR"
		}
		return LINE
	}


	# give value of a variable depending of its layer and line number
	function get_var_value(VAR, LAYER, LINE_NUMBER) {
		index_name=LAYER"_"VAR

		if(local_var_value_exists(VAR, LAYER)) {
			if(ASSIGNED_VAR_FIRST_ASSIGNATION[index_name]<=LINE_NUMBER) {
				# use local layer value
				# loop until line_number to get local value
				for (i = ASSIGNED_VAR_FIRST_ASSIGNATION[index_name]; i <= LINE_NUMBER; i++) {
					REG="^" VAR "="
					if (match(OUTPUT_BY_LN[i], REG)) {
						VAL=substr(OUTPUT_BY_LN[i], RSTART+RLENGTH)
					}
				}
				if (DEBUG) print "----------value of "VAR" is solved as a local var assigned earlier with value "VAL ASSIGNED_VAR_FIRST_ASSIGNATION[index_name]
				return VAL
			} else {
				if (global_var_value_exists(VAR, LAYER)) {
					# use global layer value
					VAL=get_global_var_value(VAR, LAYER)
					if (DEBUG) print "----------value of "VAR" is solved as a global var with value : "VAL
					return VAL
				} else {
					# NON SOLVABLE LOCAL
					NON_SOLVABLE_LOCAL_VAR[LINE_NUMBER]=NON_SOLVABLE_LOCAL_VAR[LINE_NUMBER] " " VAR
					if (DEBUG) print "----------value of "VAR" is tagged as a non solvable local variable"
					return
				}
			}
		} else {
			if (global_var_value_exists(VAR, LAYER)) {
				# use global layer value
				VAL=get_global_var_value(VAR, LAYER)
				if (DEBUG) print "----------value of "VAR" is solved as a global var with value : "VAL
				return VAL
			} else {
				# NON SOLVABLE
				if (DEBUG) print "----------value of "VAR" is non solvable. We should never reach this point !"
				return
			}
		}
	}



	# function to catch assignation 
	# and store or return value
	function parse_var(str, LOCAL_LAYER) {

		# process = assignation
		if (match(str,/^[a-zA-Z_]+[a-zA-Z0-9_]*=/)) {
			VAR=substr(str, RSTART, RLENGTH-1)
			if (DEBUG) print "----------process "VAR"= in "str

			VAL=substr(str, RSTART+RLENGTH)

			VALUE_VAR[VAR]=VAL
			index_name=LOCAL_LAYER"_"VAR
			VALUE_VAR_BY_LAYER[index_name]=VAL
		}

		# process += assignation
		if (match(str,/^[a-zA-Z_]+[a-zA-Z0-9_]*\+=/)) {
			VAR=substr(str, RSTART, RLENGTH-2)
			if (DEBUG) print "----------process "VAR"+= in "str

			VAL=substr(str, RSTART+RLENGTH)

			if (VALUE_VAR[VAR]) VALUE_VAR[VAR]=VALUE_VAR[VAR] " " VAL
			else if(ENVIRON[VAR]) VALUE_VAR[VAR]=ENVIRON[VAR] " " VAL
			else VALUE_VAR[VAR]=VAL

			index_name=LOCAL_LAYER"_"VAR
			if (VALUE_VAR_BY_LAYER[index_name]) VALUE_VAR_BY_LAYER[index_name]=VALUE_VAR_BY_LAYER[index_name] " " VAL
			else if (VALUE_VAR[VAR]) VALUE_VAR_BY_LAYER[index_name]=VALUE_VAR[VAR] " " VAL
			else if(ENVIRON[VAR]) VALUE_VAR_BY_LAYER[index_name]=ENVIRON[VAR] " " VAL
			else VALUE_VAR_BY_LAYER[index_name]=VAL
		}

		# process ?= assignation
		if (match(str,/^[a-zA-Z_]+[a-zA-Z0-9_]*\?=/)) {
			VAR=substr(str, RSTART, RLENGTH-2)
			if (DEBUG) print "----------process "VAR"?= in "str

			VAL=substr(str, RSTART+RLENGTH)
			if (VALUE_VAR[VAR]) VALUE_VAR[VAR]=VALUE_VAR[VAR]
			else if(ENVIRON[VAR]) VALUE_VAR[VAR]=ENVIRON[VAR]
			else VALUE_VAR[VAR]=VAL

			index_name=LOCAL_LAYER"_"VAR
			if (VALUE_VAR_BY_LAYER[index_name]) VALUE_VAR_BY_LAYER[index_name]=VALUE_VAR_BY_LAYER[index_name]
			else if(ENVIRON[VAR]) VALUE_VAR_BY_LAYER[index_name]=ENVIRON[VAR]
			else VALUE_VAR_BY_LAYER[index_name]=VAL
		}

		# process != assignation
		if (match(str,/^[a-zA-Z_]+[a-zA-Z0-9_]*!=/)) {
			VAR=substr(str, RSTART, RLENGTH-2)
			if (DEBUG) print "----------process "VAR"!= in "str

			VAL=substr(str, RSTART+RLENGTH)
			if (VALUE_VAR[VAR]) VALUE_VAR[VAR]=VAL
			else if(ENVIRON[VAR]) VALUE_VAR[VAR]=VAL
			
			index_name=LOCAL_LAYER"_"VAR
			if (VALUE_VAR_BY_LAYER[index_name]) VALUE_VAR_BY_LAYER[index_name]=VAL
			else if(ENVIRON[VAR]) VALUE_VAR_BY_LAYER[index_name]=VAL
		}


		if (DEBUG) {
			print "----------var "VAR" value is now : "VALUE_VAR[VAR]
			print "----------var "VAR" value for current layer "CURRENT_LAYER" is now : "VALUE_VAR_BY_LAYER[index_name]
		}

	}

	
	# -----------------------------------------------------------------------------

	/.*/ {
		# value at each time we read the begining of the file
		if (FNR==1) {
			CURRENT_LAYER="__NO_LAYER_NAME__"
			
			# FNR=1 and NR!=1 each time we read the beginning of the file except the first time
			# if (NR!=1) {
			# 	for(i in FIRST_STRICT_ASSIGN_LN_BY_LAYER_VAR) {
			# 		split(l, array, "_")
			# 		STRICT_ASSIGN_VAR_LIST=STRICT_ASSIGN_VAR_LIST " " array[2]
			# 	}
			# }
		}

		# init only when first reading file
		if (NR==1) {
			START_LN_BY_LAYER[CURRENT_LAYER]=FNR
			REVERSED_ORDER_LAYER_LIST=CURRENT_LAYER
			split(REVERSED_ORDER_LAYER_LIST, REVERSED_ORDER_LAYER_BY_PRIORITY, " ")
		
			OUTPUT_LENGTH++
			OUTPUT_BY_LN[OUTPUT_LENGTH]=$0
		}
	}

	# catch a LAYER
	/^[#] --- LAYER/ {
		if (match($0,/LAYER [a-zA-Z0-9]+/)) {
			CURRENT_LAYER=substr($0,RSTART+6,RLENGTH-1)
		}
		
		if (DEBUG) print "--LAYER : "CURRENT_LAYER

		# only when first reading file
		if (FNR==NR) {
			REVERSED_ORDER_LAYER_LIST=CURRENT_LAYER " " REVERSED_ORDER_LAYER_LIST " "
			split(REVERSED_ORDER_LAYER_LIST, REVERSED_ORDER_LAYER_BY_PRIORITY, " ")

			START_LN_BY_LAYER[CURRENT_LAYER]=FNR

			next
		}
	}

	# catch VAR=
	/^[a-zA-Z_]+[a-zA-Z0-9_]*=/ {
		if (DEBUG) print "-----CATCH ="

		if (match($0,/^[a-zA-Z_]+[a-zA-Z0-9_]*=/)) {
			CURRENT_VAR=substr($0, RSTART, RLENGTH-1)
			CURRENT_VAL=substr($0, RSTART+RLENGTH)
			if (DEBUG) {
				print "----------CURRENT_VAR "CURRENT_VAR
				print "----------CURRENT_VAL "CURRENT_VAL
			}

			index_name=CURRENT_LAYER"_"CURRENT_VAR

			if (NR==1) {
				if (!FIRST_STRICT_ASSIGN_LN_BY_LAYER_VAR[index_name]) FIRST_STRICT_ASSIGN_LN_BY_LAYER_VAR[index_name]=FNR
				if (!list_contains(STRICT_ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER], CURRENT_VAR)) {
					STRICT_ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER]=STRICT_ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER] " " CURRENT_VAR
				}
				FINAL_VALUE_STRICT_ASSIGN_BY_LAYER_VAR[index_name]=CURRENT_VAL
				next

			} 
			if (NR==2) {
				# LINE=CURRENT_VAL
				# while (match(LINE,/{{[a-zA-Z_]+[a-zA-Z0-9_]*}}/) >0) {
				# 	DYN_VAR=substr($0,RSTART+2,RLENGTH-4)
				# 	# next iteration
				# 	LINE=substr(LINE, RSTART+RLENGTH)
				# 	if(!is_dynamic_variable_solvable(DYN_VAR,CURRENT_LAYER)) {
				# 		if (DEBUG) print "----------DYN_VAR" is non solvable dynamic variable."
				# 		gsub("{{"DYN_VAR"}}", "", CURRENT_VAL)
				# 	}
				# }


				if (!list_contains(ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER], CURRENT_VAR)) {
					ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER]=ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER] " " CURRENT_VAR
				}
				FINAL_VALUE_BY_LAYER_VAR[index_name]=CURRENT_VAL
			}
			
		}
	}

	# catch VAR+=
	/^[a-zA-Z_]+[a-zA-Z0-9_]*\+=/ {
		if (DEBUG) print "-----CATCH +="

		if (match($0,/^[a-zA-Z_]+[a-zA-Z0-9_]*\+=/)) {
			CURRENT_VAR=substr($0, RSTART, RLENGTH-2)
			CURRENT_VAL=substr($0, RSTART+RLENGTH)
			if (DEBUG) {
				print "----------CURRENT_VAR "CURRENT_VAR
				print "----------CURRENT_VAL "CURRENT_VAL
			}

			index_name=CURRENT_LAYER"_"CURRENT_VAR

			if (NR==1) {
				
				if (list_contains(STRICT_ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER], CURRENT_VAR)) {
					FINAL_VALUE_STRICT_ASSIGN_BY_LAYER_VAR[index_name]=FINAL_VALUE_STRICT_ASSIGN_BY_LAYER_VAR[index_name] " " CURRENT_VAL
				}

				next
			}
			if (NR==2) {
				# this variable have already been assigned in current layer
				if (list_contains(ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER], CURRENT_VAR)) {
					FINAL_VALUE_BY_LAYER_VAR[index_name]=FINAL_VALUE_BY_LAYER_VAR[index_name] " " CURRENT_VAL
				} else {
					# else we use strict assigned value from other highest priority layer
					if (is_high_priority_value_exists(CURRENT_VAR, CURRENT_LAYER)) {
						v=get_high_priority_value(CURRENT_VAR, CURRENT_LAYER)
						FINAL_VALUE_BY_LAYER_VAR[index_name]=v " " CURRENT_VAL
					} else {
						# else try to find a current value in previous layer
						if (is_previous_priority_value_exists(CURRENT_VAR, CURRENT_LAYER)) {
							v=get_previous_priority_value(CURRENT_VAR, CURRENT_LAYER)
							FINAL_VALUE_BY_LAYER_VAR[index_name]=v " " CURRENT_VAL
						} else {
							FINAL_VALUE_BY_LAYER_VAR[index_name]=CURRENT_VAL
						}
					}
					ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER]=ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER] " " CURRENT_VAR
				}
				
				OUTPUT_BY_LN[FNR]=CURRENT_VAR"="FINAL_VALUE_BY_LAYER_VAR[index_name]
			}
		}
	}

	# catch VAR?=
	/^[a-zA-Z_]+[a-zA-Z0-9_]*\?=/ {
		if (DEBUG) print "-----CATCH ?="

		if (match($0,/^[a-zA-Z_]+[a-zA-Z0-9_]*\?=/)) {
			CURRENT_VAR=substr($0, RSTART, RLENGTH-2)
			CURRENT_VAL=substr($0, RSTART+RLENGTH)
			if (DEBUG) {
				print "----------CURRENT_VAR "CURRENT_VAR
				print "----------CURRENT_VAL "CURRENT_VAL
			}

			index_name=CURRENT_LAYER"_"CURRENT_VAR

			if (NR==1) {
				if (list_contains(STRICT_ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER], CURRENT_VAR)) {
					if (!FINAL_VALUE_STRICT_ASSIGN_BY_LAYER_VAR[index_name]) FINAL_VALUE_STRICT_ASSIGN_BY_LAYER_VAR[index_name]=CURRENT_VAL
				}
				next
			}
			if (NR==2) {
				# this variable have already been assigned in current layer
				if (list_contains(ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER], CURRENT_VAR)) {
					if(!FINAL_VALUE_BY_LAYER_VAR[index_name]) FINAL_VALUE_BY_LAYER_VAR[index_name]=CURRENT_VAL
				} else {
					# else we use strict assigned value from other highest priority layer
					if (is_high_priority_value_exists(CURRENT_VAR, CURRENT_LAYER)) {
						v=get_high_priority_value(CURRENT_VAR, CURRENT_LAYER)
						if(!v) FINAL_VALUE_BY_LAYER_VAR[index_name]=CURRENT_VAL
						else FINAL_VALUE_BY_LAYER_VAR[index_name]=v
					} else {
						# else try to find a current value in previous layer
						if (is_previous_priority_value_exists(CURRENT_VAR, CURRENT_LAYER)) {
							v=get_previous_priority_value(CURRENT_VAR, CURRENT_LAYER)
							if(!v) FINAL_VALUE_BY_LAYER_VAR[index_name]=CURRENT_VAL
							else FINAL_VALUE_BY_LAYER_VAR[index_name]=v
						} else {
							FINAL_VALUE_BY_LAYER_VAR[index_name]=CURRENT_VAL
						}
					}
					ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER]=ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER] " " CURRENT_VAR
				}
				
				OUTPUT_BY_LN[FNR]=CURRENT_VAR"="FINAL_VALUE_BY_LAYER_VAR[index_name]
			}
		}
	}


	# catch VAR!=
	/^[a-zA-Z_]+[a-zA-Z0-9_]*!=/ {
		if (DEBUG) print "-----CATCH !="

		if (match($0,/^[a-zA-Z_]+[a-zA-Z0-9_]*!=/)) {
			CURRENT_VAR=substr($0, RSTART, RLENGTH-2)
			CURRENT_VAL=substr($0, RSTART+RLENGTH)
			if (DEBUG) {
				print "----------CURRENT_VAR "CURRENT_VAR
				print "----------CURRENT_VAL "CURRENT_VAL
			}

			index_name=CURRENT_LAYER"_"CURRENT_VAR

			
			if (NR==1) {
				if (list_contains(STRICT_ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER], CURRENT_VAR)) {
					if (FINAL_VALUE_STRICT_ASSIGN_BY_LAYER_VAR[index_name]) FINAL_VALUE_STRICT_ASSIGN_BY_LAYER_VAR[index_name]=CURRENT_VAL
				}
				next
			}
			if (NR==2) {
				# this variable have already been assigned in current layer
				if (list_contains(ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER], CURRENT_VAR)) {
					if(FINAL_VALUE_BY_LAYER_VAR[index_name]) FINAL_VALUE_BY_LAYER_VAR[index_name]=CURRENT_VAL
				} else {
					# else we use strict assigned value from other highest priority layer
					if (is_high_priority_value_exists(CURRENT_VAR, CURRENT_LAYER)) {
						v=get_high_priority_value(CURRENT_VAR, CURRENT_LAYER)
						if(v) FINAL_VALUE_BY_LAYER_VAR[index_name]=CURRENT_VAL
						else FINAL_VALUE_BY_LAYER_VAR[index_name]=v
					} else {
						# else try to find a current value in previous layer
						if (is_previous_priority_value_exists(CURRENT_VAR, CURRENT_LAYER)) {
							v=get_previous_priority_value(CURRENT_VAR, CURRENT_LAYER)
							if(v) FINAL_VALUE_BY_LAYER_VAR[index_name]=CURRENT_VAL
							else FINAL_VALUE_BY_LAYER_VAR[index_name]=v
						} else {
							FINAL_VALUE_BY_LAYER_VAR[index_name]=
						}
					}
					ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER]=ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER] " " CURRENT_VAR
				}
				
				OUTPUT_BY_LN[FNR]=CURRENT_VAR"="FINAL_VALUE_BY_LAYER_VAR[index_name]
			}
			
		}
	}



	# this block is triggered at each line only if not bypassed by next
	# so this block is really triggered only when reading second file
	{	
		if (DEBUG) {
			print "-----BEGIN analyse line num "NR" for dynamic variable"
			print "----------LINE : "$0
			print "----------SOLVABLE_VAR so far : "SOLVABLE_VAR
		}

		# catch {{VAR}}
		LINE=$0

		while (match(LINE,/{{[a-zA-Z_]+[a-zA-Z0-9_]*}}/) >0) {
			CURRENT_VAR=substr(LINE,RSTART+2,RLENGTH-4)

			# next line
			LINE=substr(LINE, RSTART+RLENGTH)

			if (list_contains(NON_SOLVABLE_VAR_LIST, CURRENT_VAR)) {
				if (DEBUG) print "----------variable "CURRENT_VAR" is already tagged as a dynamic non solvable variable"
				continue
			}

			# this variable have already been assigned in current layer
			if (list_contains(ASSIGN_VAR_LIST_BY_LAYER[CURRENT_LAYER], CURRENT_VAR)) {
				if (DEBUG) print "----------variable "CURRENT_VAR" can be solved with a previous assigned value before in the same layer : "CURRENT_LAYER
				#if(!FINAL_VALUE_BY_LAYER_VAR[index_name]) SOLVABLE_AS_EMPTY_VAR_LIST=SOLVABLE_AS_EMPTY_VAR_LIST " " CURRENT_VAR
			} else {
				# else we use strict assigned value from other highest priority layer
				l=is_high_priority_value_exists(CURRENT_VAR, CURRENT_LAYER)
				if (l) {
					if (DEBUG) print "----------variable "CURRENT_VAR" can be solved with a highest priority strict assigned value from layer : "l
				} else {
					# else try to find a current value in previous layer
					l=is_previous_priority_value_exists(CURRENT_VAR, CURRENT_LAYER)
					if (l) {
						if (DEBUG) print "----------variable "CURRENT_VAR" can be solved with a highest priority vaalue assigned in a previous layer : "l
					} else {
						if (DEBUG) print "----------variable "CURRENT_VAR" is a dynamic non solvable variable"
						NON_SOLVABLE_VAR_LIST=NON_SOLVABLE_VAR_LIST" "CURRENT_VAR
					}

				}
			}
		}

		if (DEBUG) print "-----END analyse line num "NR
	}


	


	
	END {

		# trim SOLVABLE_VAR and NON_SOLVABLE_VAR
		{ gsub(/^[ \t]+|[ \t]+$/, "", SOLVABLE_VAR) } 1
		{ gsub(/^[ \t]+|[ \t]+$/, "", NON_SOLVABLE_VAR) } 1




		# replace {{VAR}} with global variables
		for (j = 1; j <= OUTPUT_LENGTH; j++) {
			OUTPUT_BY_LN[j]=replace_var(OUTPUT_BY_LN[j],j)
		}

		for (j = 1; j <= OUTPUT_LENGTH; j++) {
			print OUTPUT_BY_LN[j]
		}
		
	}
	' "${_file}" "${_file}"
}	



# replace in a file exported environnement variable in the form {{$variable}}
# NOTE : authorized char as shell variable name : [a-zA-Z_]+[a-zA-Z0-9_]* https://stackoverflow.com/a/2821201
# WARN : env var must have been exported (with export command) to be used here
__substitute_env_var_in_file() {

	local _file="$1"

	__tango_log "DEBUG" "tango" "__substitute_env_var_in_file : ${_file}"
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


