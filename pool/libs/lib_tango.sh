# MANAGE ENV VARIABLES AND FILES GENERATION -----------------

# update env files with current declared variables in VARIABLES_LIST
__update_env_files() {
	local __text="$1"
	echo "# ------ UPDATE : update_env_files : $(date) -- ${__text}" >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"
	echo "# ------ UPDATE : update_env_files : $(date) -- ${__text}" >> "${GENERATED_ENV_FILE_FOR_BASH}"
	for __variable in ${VARIABLES_LIST}; do
		[ -z ${!__variable+x} ] || echo "${__variable}=${!__variable}" >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"
		[ -z ${!__variable+x} ] || echo "${__variable}=\"$(echo ${!__variable} | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/\\$/g')\"" >> "${GENERATED_ENV_FILE_FOR_BASH}"	
	done
}

__get_declared_variable_names() {
	VARIABLES_LIST=""
	[ -f "${TANGO_ENV_FILE}" ] && VARIABLES_LIST="$(sed -e '/^[[:space:]]*$/d' -e '/^[#]\+.*$/d' -e 's/^\([^=+]*\)+\?=\(.*\)$/\1/g' "${TANGO_ENV_FILE}")"
	[ -f "${TANGO_APP_ENV_FILE}" ] && VARIABLES_LIST="${VARIABLES_LIST} $(sed -e '/^[[:space:]]*$/d' -e '/^[#]\+.*$/d' -e 's/^\([^=+]*\)+\?=\(.*\)$/\1/g' "${TANGO_APP_ENV_FILE}")"
	[ -f "${TANGO_USER_ENV_FILE}" ] && VARIABLES_LIST="${VARIABLES_LIST} $(sed -e '/^[[:space:]]*$/d' -e '/^[#]\+.*$/d' -e 's/^\([^=+]*\)+\?=\(.*\)$/\1/g' "${TANGO_USER_ENV_FILE}")"

	VARIABLES_LIST="$($STELLA_API list_filter_duplicate "${VARIABLES_LIST}")"

}

# add new variables names from modules env file
__add_modules_declared_variable_names() {
				
	# add modules env file
	for s in ${TANGO_SERVICES_MODULES}; do
		if [ -f "${TANGO_APP_MODULES_ROOT}/${s}.env" ]; then
			VARIABLES_LIST="${VARIABLES_LIST} $(sed -e '/^[[:space:]]*$/d' -e '/^[#]\+.*$/d' -e 's/^\([^=+]*\)+\?=\(.*\)$/\1/g' "${TANGO_APP_MODULES_ROOT}/${s}.env")"
		else
			[ -f "${TANGO_MODULES_ROOT}/${s}.env" ] && VARIABLES_LIST="${VARIABLES_LIST} $(sed -e '/^[[:space:]]*$/d' -e '/^[#]\+.*$/d' -e 's/^\([^=+]*\)+\?=\(.*\)$/\1/g' "${TANGO_MODULES_ROOT}/${s}.env")"
		fi
	done
	VARIABLES_LIST="$($STELLA_API list_filter_duplicate "${VARIABLES_LIST}")"
}


# filter existing modules and split module list between full list and name list
# full modules list format : <name>[@<network area>]
__parse_modules_list() {
	local _existing_modules=

	# split module list between full list and name list
	TANGO_SERVICES_MODULES_FULL="${TANGO_SERVICES_MODULES}"
	TANGO_SERVICES_MODULES="$(echo "${TANGO_SERVICES_MODULES}" | sed -e 's/@[^ ]* */ /g')"

	# filter existing modules
	for s in ${TANGO_SERVICES_MODULES}; do
		# app modules overrides tango modules
		if [ -f "${TANGO_APP_MODULES_ROOT}/${s}.yml" ]; then
			_existing_modules="${_existing_modules} ${s}"
		else
			[ -f "${TANGO_MODULES_ROOT}/${s}.yml" ] && _existing_modules="${_existing_modules} ${s}" \
				|| echo "* WARN : module ${s} not found."
		fi
	done
	
	TANGO_SERVICES_MODULES="${_existing_modules}"
}



# add variables to variables list
__add_declared_variables() {
	VARIABLES_LIST="${VARIABLES_LIST} $1"
}






# generate an env file to be uses as env-file in environment section of docker compose file (GENERATED_ENV_FILE_FOR_COMPOSE)
__create_env_for_docker_compose() {
	echo "# ------ CREATE : create_env_for_docker_compose : $(date)" > "${GENERATED_ENV_FILE_FOR_COMPOSE}"

	# add default tango env file
	cat <(echo \# --- PART FROM default tango env file ${TANGO_ENV_FILE}) <(echo) <(echo) "${TANGO_ENV_FILE}" <(echo) >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"
	
	# add app env file
	[ -f "${TANGO_APP_ENV_FILE}" ] &&  cat <(echo \# --- PART FROM app env file ${TANGO_APP_ENV_FILE}) <(echo) <(echo) "${TANGO_APP_ENV_FILE}" <(echo) >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"
	
	# add modules env file
	for s in ${TANGO_SERVICES_MODULES}; do
		# app modules overrides tango modules
		if [ -f "${TANGO_APP_MODULES_ROOT}/${s}.env" ]; then
			cat <(echo \# --- PART FROM modules env file ${TANGO_APP_MODULES_ROOT}/${s}.env) <(echo) <(echo) "${TANGO_APP_MODULES_ROOT}/${s}.env" <(echo) >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"
		else
			[ -f "${TANGO_MODULES_ROOT}/${s}.env" ] && cat <(echo \# --- PART FROM modules env file ${TANGO_MODULES_ROOT}/${s}.env) <(echo) <(echo) "${TANGO_MODULES_ROOT}/${s}.env" <(echo) >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"
		fi
	done

	# add user env file
	[ -f "${TANGO_USER_ENV_FILE}" ] &&  cat <(echo \# --- PART FROM user env file ${TANGO_USER_ENV_FILE}) <(echo) <(echo) "${TANGO_USER_ENV_FILE}" <(echo) >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"

	__parse_env_file "${GENERATED_ENV_FILE_FOR_COMPOSE}"
}

# generate an env file to be sourced (GENERATED_ENV_FILE_FOR_BASH)
__create_env_for_bash() {
	echo "# ------ CREATE : create_env_for_bash : $(date)" > "${GENERATED_ENV_FILE_FOR_BASH}"

	# add default tango env file
	cat <(echo \# --- PART FROM default tango env file ${TANGO_ENV_FILE}) <(echo) <(echo) "${TANGO_ENV_FILE}" <(echo) >> "${GENERATED_ENV_FILE_FOR_BASH}"
	
	# add app env file
	[ -f "${TANGO_APP_ENV_FILE}" ] &&  cat <(echo \# --- PART FROM app env file ${TANGO_APP_ENV_FILE}) <(echo) <(echo) "${TANGO_APP_ENV_FILE}" <(echo) >> "${GENERATED_ENV_FILE_FOR_BASH}"

	# add modules env file
	for s in ${TANGO_SERVICES_MODULES}; do
		# app modules overrides tango modules
		if [ -f "${TANGO_APP_MODULES_ROOT}/${s}.env" ]; then
			cat <(echo \# --- PART FROM modules env file ${TANGO_APP_MODULES_ROOT}/${s}.env) <(echo) <(echo) "${TANGO_APP_MODULES_ROOT}/${s}.env" <(echo) >> "${GENERATED_ENV_FILE_FOR_BASH}"
		else
			[ -f "${TANGO_MODULES_ROOT}/${s}.env" ] && cat <(echo \# --- PART FROM modules env file ${TANGO_MODULES_ROOT}/${s}.env) <(echo) <(echo) "${TANGO_MODULES_ROOT}/${s}.env" <(echo) >> "${GENERATED_ENV_FILE_FOR_BASH}"
		fi
	done

	# add user env file
	[ -f "${TANGO_USER_ENV_FILE}" ] &&  cat <(echo \# --- PART FROM user env file ${TANGO_USER_ENV_FILE}) <(echo) <(echo) "${TANGO_USER_ENV_FILE}" <(echo) >> "${GENERATED_ENV_FILE_FOR_BASH}"

	__parse_env_file "${GENERATED_ENV_FILE_FOR_BASH}"

	# add quote for variable bash support
	sed -i -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/\\$/g' "${GENERATED_ENV_FILE_FOR_BASH}"
	sed -i 's/^\([a-zA-Z0-9_-]*\)=\(.*\)$/\1=\"\2\"/g' "${GENERATED_ENV_FILE_FOR_BASH}"

}



# remove commentary and manage cumulative assignation with +=
__parse_env_file() {
	local _file="$1"

	local _temp=$(mktmp)

	awk -F= '
	BEGIN {
	}

	# catch +=
	/^[^=#]*\+=/ {
		key=substr($1, 1, length($1)-1);
		if (arr[key]) arr[key]=arr[key] " " $2;
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
	
}


# generate docker compose file
__create_docker_compose_file() {
	rm -f "${GENERATED_DOCKER_COMPOSE_FILE}"

	# concatenate compose files
	cp -f "${TANGO_COMPOSE_FILE}" "${GENERATED_DOCKER_COMPOSE_FILE}"

	# app compose file
	[ -f "${TANGO_APP_COMPOSE_FILE}" ] && yq m -i -a -- "${GENERATED_DOCKER_COMPOSE_FILE}" "${TANGO_APP_COMPOSE_FILE}"

	# modules compose files
	for s in ${TANGO_SERVICES_MODULES}; do
		# app modules overrides tango modules
		if [ -f "${TANGO_APP_MODULES_ROOT}/${s}.yml" ]; then
			yq m -i -a -- "${GENERATED_DOCKER_COMPOSE_FILE}" "${TANGO_APP_MODULES_ROOT}/${s}.yml"
		else
			[ -f "${TANGO_MODULES_ROOT}/${s}.yml" ] && yq m -i -a -- "${GENERATED_DOCKER_COMPOSE_FILE}" "${TANGO_MODULES_ROOT}/${s}.yml"
		fi
	done

	# user compose file
	[ -f "${TANGO_USER_COMPOSE_FILE}" ] && yq m -i -a -- "${GENERATED_DOCKER_COMPOSE_FILE}" "${TANGO_USER_COMPOSE_FILE}"
	
	
	__set_active_services_all
	__set_time_all
	__set_entrypoints_service_all
	__set_redirect_https_service_all
	__add_service_direct_port_access_all
	__add_gpu_all
	__add_volume_artefact_all
	__add_volume_app_pool_all
	__set_letsencrypt_service_all
	__create_vpn_all

	__create_plugin_all

	# do this after other compose modification 	
	# because it remove some network definition
	__set_vpn_service_all
}


# translate all relative path to absolute
# translate all declared variables which end with _PATH
__translate_all_path() {


	for __variable in ${VARIABLES_LIST}; do
		case ${__variable} in
			*_PATH) [ ! "${!__variable}" = "" ] && export ${__variable}="$($STELLA_API rel_to_abs_path "${!__variable}" "${TANGO_APP_ROOT}")"
			;;
		esac
	done


	if [ ! "${TANGO_ARTEFACT_FOLDERS}" = "" ]; then
		__tmp=
		for f in ${TANGO_ARTEFACT_FOLDERS}; do
			f="$($STELLA_API rel_to_abs_path "${f}" "${TANGO_APP_ROOT}")"
			__tmp="${__tmp} ${f}"
		done
		export TANGO_ARTEFACT_FOLDERS="$($STELLA_API trim "${__tmp}")"
	fi

	if [ ! "${TANGO_CERT_FILES}" = "" ]; then
		__tmp=
		for f in ${TANGO_CERT_FILES}; do
			f="$($STELLA_API rel_to_abs_path "${f}" "${TANGO_APP_ROOT}")"
			__tmp="${__tmp} ${f}"
		done
		export TANGO_CERT_FILES="$($STELLA_API trim "${__tmp}")"
	fi

	if [ ! "${TANGO_KEY_FILES}" = "" ]; then
		__tmp=
		for f in ${TANGO_KEY_FILES}; do
			f="$($STELLA_API rel_to_abs_path "${f}" "${TANGO_APP_ROOT}")"
			__tmp="${__tmp} ${f}"
		done
		export TANGO_KEY_FILES="$($STELLA_API trim "${__tmp}")"
	fi
}




# MANAGE FEATURES FOR ALL CONTAINTERS -----------------

__create_plugin_all() {

	__add_declared_variables "TANGO_PLUGINS_LIST"
	# NOTE : +13/-13 is for bybass 'TANGO_PLUGIN_'
	for _id in $(compgen -A variable | awk 'match($0,/TANGO_PLUGIN_[0-9]+/) {print substr($0,RSTART+13,RLENGTH-13)}' | sort | uniq); do
		__create_plugin "${_id}"
		__add_service_dependency "plugins" "plugin_${_id}"
		export TANGO_PLUGINS_LIST="${TANGO_PLUGINS_LIST} plugin_${_id}"
		export TANGO_TIME_VOLUME_SERVICES="${TANGO_TIME_VOLUME_SERVICES} plugin_${_id}"
	done

}


__create_plugin() {
	local __plugin_id="$1"
	
	local _tmp=
	local __plugin_name=
	local __arg_list=
	local __dep_list=

	local __service_name="plugin_${__plugin_id}"
	local __command=

	_tmp="TANGO_PLUGIN_${__plugin_id}"
	_tmp="${!_tmp}"

	if [ -z "${_tmp##*@*}" ]; then
		__plugin_name="${_tmp%%@*}"
	else
		[ -z "${_tmp##*#*}" ] && __plugin_name="${_tmp%%#*}" || __plugin_name="${_tmp}" 
	fi

	if [ -z "${_tmp##*#*}" ]; then
		__arg_list="${_tmp#*#}"
		__arg_list="${__arg_list//#/ }"
	fi

	if [ -z "${_tmp##*@*}" ]; then
		__dep_list="${_tmp#*@}"
		__dep_list="${__dep_list%%#*}"
		__dep_list="${__dep_list//@/ }"
	fi
	
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.<<" default-plugin
	# need tweak '*default-vpn' yaml anchor while this issue exist in yq : https://github.com/mikefarah/yq/issues/377
	sed -i 's/[^&]default-plugin/ \*default-plugin/' "${GENERATED_DOCKER_COMPOSE_FILE}"
	# NOTE : plugin are specific for each tango app : use of TANGO_APP_NAME
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.container_name" '${TANGO_APP_NAME}_'${__service_name}
	
	for d in ${__dep_list}; do
		__add_service_dependency "${__service_name}" "${d,,}"
	done
	__command='bash -c "echo \"* Plugin : '$__plugin_name'\" && echo L-- dep list : '$__dep_list' && echo L-- arg list : '$__arg_list' && [ -f \"/pool/${TANGO_APP_NAME}/plugins/'$__plugin_name'\" ] && /pool/${TANGO_APP_NAME}/plugins/'$__plugin_name' || ( [ -f \"/pool/tango/plugins/'$__plugin_name'\" ] && /pool/tango/plugins/'$__plugin_name' || echo \"** WARN plugin not found\")"'

	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.command" "${__command}"

}



__set_active_services_all() {
	# declare all active service in tango depdenciess
	for s in ${TANGO_SERVICES_ACTIVE}; do
		__check_service_exist "${s}" && __add_service_dependency "tango" "${s}" || echo "** WARN : unknow ${s} service declared in TANGO_SERVICES_ACTIVE"
	done
}

__set_vpn_service_all() {

	local _tmp=
	for v in ${VPN_SERVICES_LIST}; do
		_tmp="${v^^}_SERVICES"
		for s in ${!_tmp}; do
			__check_service_exist "${s}" && __set_vpn_service "${s}" "${v}" || echo "** WARN : unknow ${s} service declared in ${_tmp}"
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
		export TANGO_TIME_VOLUME_SERVICES="${TANGO_TIME_VOLUME_SERVICES} vpn_${_id}"
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



# add a artefact_xxx named volume defintion
# attach this artefact_xxx named volume to a /$TANGO_ARTEFACT_MOUNT_POINT/xxxx folder to each service listed in TANGO_ARTEFACT_SERVICES
__add_volume_artefact_all() {
	for f in ${TANGO_ARTEFACT_FOLDERS}; do
		f="$($STELLA_API rel_to_abs_path "${f}" "${TANGO_APP_ROOT}")"
		target="$(basename "${f}")"
		if [ -f "${f}" ]; then 
			echo "** [${f}] is a file, not mounted inside folder {${TANGO_ARTEFACT_MOUNT_POINT}}"
		else
			[ ! -d "${f}" ] && echo "** [${f}] is not an existing directory and will be auto created."
			__name="$($STELLA_API md5 "${f}")"
			__add_volume_local_definition "artefact_${__name}" "${f}"
			for s in $TANGO_ARTEFACT_SERVICES; do
				__check_service_exist "${s}" && __add_volume_mapping_service "${s}" "artefact_${__name}:${TANGO_ARTEFACT_MOUNT_POINT}/${target}"
				# NOTE : do not print WARN because a warn is printed for each artefact folder for each undefined services
				#	|| echo "** WARN : unknow ${s} service declared in TANGO_ARTEFACT_SERVICES"
				
			done
			[ "${VERBOSE}" = "1" ] && echo "** [${f}] will be mapped to {${TANGO_ARTEFACT_MOUNT_POINT}/${target}}"			
		fi
	done
}


# add volume to service which needs app pool if it exists
__add_volume_app_pool_all() {
	if [ ! "${TANGO_NOT_IN_APP}" = "1" ]; then
		if [ -d "${TANGO_APP_ROOT}/pool" ]; then
			__add_volume_mapping_service "service_info" "${TANGO_APP_ROOT}/pool:/pool/${TANGO_APP_NAME}"
			__add_volume_mapping_service "service_init" "${TANGO_APP_ROOT}/pool:/pool/${TANGO_APP_NAME}"
			#__add_volume_mapping_service "x-plugin" "${TANGO_APP_ROOT}/pool:/pool/${TANGO_APP_NAME}"
			yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "x-plugin.volumes[+]" "${TANGO_APP_ROOT}/pool:/pool/${TANGO_APP_NAME}"
		fi
	fi

}

# add gpu to all container that need its
# NVIDIA | INTEL_QUICKSYNC
__add_gpu_all() {
	for s in $(compgen -A variable | grep _GPU); do
		gpu="${!s}"
		if [ ! "${gpu}" = "" ]; then
			service="${s%_GPU}"
			service="${service,,}"
			__check_service_exist "${service}" && __add_gpu "${service}" "${gpu}" || echo "** WARN : unknow ${service} service declared in ${s}"
		fi
	done
}

# set timezone to containers which need it
__set_time_all() {

	for s in $TANGO_TIME_VOLUME_SERVICES; do
		__check_service_exist "${s}" && __add_volume_for_time "$s" || echo "** WARN : unknow ${s} service declared in TANGO_TIME_VOLUME_SERVICES"
	done

	for s in $TANGO_TIME_VAR_TZ_SERVICES; do
		__check_service_exist "${s}" && __add_tz_var_for_time "$s" || echo "** WARN : unknow ${s} service declared in TANGO_TIME_VAR_TZ_SERVICES"
	done

}



__set_letsencrypt_service_all() {

	
	case ${LETS_ENCRYPT} in
		enable|debug )
			for serv in ${LETS_ENCRYPT_SERVICES}; do
				if __check_service_exist "${serv}"; then
					__add_letsencrypt_service "${serv}"
					
					# add lets encrypt support for subservices
					for sub in ${TANGO_SUBSERVICES}; do
						case ${sub} in
							${serv}* ) __add_letsencrypt_service "${serv}" "${sub}";;
						esac
					done
				else
					echo "** WARN : unknow ${serv} service declared in LETS_ENCRYPT_SERVICES"
				fi
			done

			case ${LETS_ENCRYPT_CHALLENGE} in
				HTTP )
					yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--certificatesresolvers.tango.acme.httpchallenge=true"
					yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--certificatesresolvers.tango.acme.httpchallenge.entrypoint=web_main"
				;;
				DNS )
					yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--certificatesresolvers.tango.acme.dnschallenge=true"
					yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--certificatesresolvers.tango.acme.dnschallenge.provider=${LETS_ENCRYPT_CHALLENGE_DNS_PROVIDER}"
				;;
			esac
			
		;;
	esac

	# set letsencrypt debug server if needed
	[ "${LETS_ENCRYPT}" = "debug" ] && yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.traefik.command[+]" "--certificatesresolvers.tango.acme.caserver=${LETS_ENCRYPT_SERVER_DEBUG}"
}


__set_entrypoints_service_all() {
	local __name=
	local __area=
	local __var=
	# add modules entrypoint
	for m in ${TANGO_SERVICES_MODULES_FULL}; do
		__name="${m%%@*}"
		[ -z "${m##*@*}" ] && __area="${m##*@}" || __area="main"

		__var="NETWORK_SERVICES_AREA_${__area^^}"
		eval "export ${__var}=\"${!__var} ${__name}\""
	done

	for s in ${NETWORK_SERVICES_AREA_MAIN}; do
		__check_service_exist "${s}" && __set_entrypoint_service "${s}"  "web_main" || echo "** WARN : unknow ${s} service declared in NETWORK_SERVICES_AREA_MAIN"
	done
	for s in ${NETWORK_SERVICES_AREA_SECONDARY}; do
		__check_service_exist "${s}" && __set_entrypoint_service "${s}"  "web_secondary" || echo "** WARN : unknow ${s} service declared in NETWORK_SERVICES_AREA_SECONDARY"
	done
	for s in ${NETWORK_SERVICES_AREA_ADMIN}; do
		__check_service_exist "${s}" && __set_entrypoint_service "${s}"  "web_admin" || echo "** WARN : unknow ${s} service declared in NETWORK_SERVICES_AREA_ADMIN"
	done


}

__set_redirect_https_service_all() {
	for s in ${NETWORK_SERVICES_REDIRECT_HTTPS}; do
		if __check_service_exist "${s}"; then
			# look if on any entrypoint, we have to override the service router rule with the http-catchall rule
			for se in ${NETWORK_SERVICES_AREA_ADMIN}; do
				[ "${se}" = "${s}" ] && __set_redirect_https_service "${s}"  "web_admin"
			done
			for se in ${NETWORK_SERVICES_AREA_SECONDARY}; do
				[ "${se}" = "${s}" ] && __set_redirect_https_service "${s}"  "web_secondary"
			done
			for se in ${NETWORK_SERVICES_AREA_MAIN}; do
				[ "${se}" = "${s}" ] && __set_redirect_https_service "${s}"  "web_main"
			done
		else
			echo "** WARN : unknow ${s} service declared in NETWORK_SERVICES_REDIRECT_HTTPS"
		fi
	done
}


__add_service_direct_port_access_all() {
	for s in $(compgen -A variable | grep _DIRECT_ACCESS_PORT); do
		port="${!s}"
		if [ ! "${port}" = "" ]; then
			service="${s%_DIRECT_ACCESS_PORT}"
			service="${service,,}"
			
			if __check_service_exist "${service}"; then
				port_inside="$(yq r "${GENERATED_DOCKER_COMPOSE_FILE}" services.$service.expose[0])"
				if [ ! "${port_inside}" = "" ]; then
					[ "${VERBOSE}" = "1" ] && echo "* Activate direct access to $service : mapping $port to $port_inside"
					yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.$service.ports[+]" "$port:$port_inside"
				else
					echo "* WARN : cannot activate direct access to $service through $port : Unknown inside port to map to. Inside port must be declared as first port in expose section."
				fi
			else
				echo "** WARN : unknow ${service} service declared in ${s}"
			fi
		fi
	done
}




# FEATURES MANAGEMENT --------

__pick_free_port() {
	local __free_port_list=
	local __exclude=

	# exclude direct access port AND any variable ending with _PORT (for service_PORT variable)
	for p in $(compgen -A variable | grep _PORT); do
		p="${!p}"
		[[ ${p} =~ ^[0-9]+$ ]] && __exclude="${__exclude} ${p}"
	done
	[ ! "${__exclude}" = "" ] && __exclude="EXCLUDE_LIST_BEGIN ${__exclude} EXCLUDE_LIST_END"

	__free_port_list="$($STELLA_API find_free_port "6" "TCP RANGE_BEGIN 10000 RANGE_END 65000 CONSECUTIVE ${__exclude}")"
	if [ ! "${__free_port_list}" = "" ]; then
		__free_port_list=( ${__free_port_list} )
		NETWORK_PORT_MAIN=${__free_port_list[0]}
		NETWORK_PORT_MAIN_SECURE=${__free_port_list[1]}
		NETWORK_PORT_SECONDARY=${__free_port_list[2]}
		NETWORK_PORT_SECONDARY_SECURE=${__free_port_list[3]}
		NETWORK_PORT_ADMIN=${__free_port_list[4]}
		NETWORK_PORT_ADMIN_SECURE=${__free_port_list[5]}

		echo "NETWORK_PORT_MAIN=${__free_port_list[0]}" > "${GENERATED_ENV_FILE_FREEPORT}"
		echo "NETWORK_PORT_MAIN_SECURE=${__free_port_list[1]}" >> "${GENERATED_ENV_FILE_FREEPORT}"
		echo "NETWORK_PORT_SECONDARY=${__free_port_list[2]}" >> "${GENERATED_ENV_FILE_FREEPORT}"
		echo "NETWORK_PORT_SECONDARY_SECURE=${__free_port_list[3]}" >> "${GENERATED_ENV_FILE_FREEPORT}"
		echo "NETWORK_PORT_ADMIN=${__free_port_list[4]}" >> "${GENERATED_ENV_FILE_FREEPORT}"
		echo "NETWORK_PORT_ADMIN_SECURE=${__free_port_list[5]}" >> "${GENERATED_ENV_FILE_FREEPORT}"
	fi
}

 __set_vpn_service() {
 	local __service_name="$1"
 	local __vpn_name="$2"

	yq d -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.networks"
	yq d -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.expose"
	yq d -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.ports"

	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.network_mode" "service:${__vpn_name}"

	__add_service_dependency "${__service_name}" "${__vpn_name}"
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
	
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service_name}.<<" default-vpn
	# need tweak '*default-vpn' yaml anchor while this issue exist in yq : https://github.com/mikefarah/yq/issues/377
	sed -i 's/[^&]default-vpn/ \*default-vpn/' "${GENERATED_DOCKER_COMPOSE_FILE}"
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

}


__check_service_exist() {
	local __service="$1"
	
	[ ! -z "$(yq r -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service}.image")" ]
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



__add_service_dependency() {
	local __service="$1"
	local __dependency="$2"

	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service}.depends_on[+]" "${__dependency}"
}

__add_volume_for_time() {
	local __service="$1"
	
	# create these volumes only if files exists
	[ -f "/etc/timezone" ] && __add_volume_mapping_service "${__service}" "/etc/timezone:/etc/timezone:ro"
	[ -f "/etc/localtime" ] && __add_volume_mapping_service "${__service}" "/etc/localtime:/etc/localtime:ro"
}


__add_letsencrypt_service() {
	local __service="$1"
	local __router="$2"

	[ "${__router}" = "" ] && __router="${__service}"

	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service}.labels[+]" "traefik.http.routers.${__router}-secure.tls.certresolver=tango"
}

# declare an entrypoint to a service as well to the secured version of the entrypoint
__set_entrypoint_service() {
	local __service="$1"
	local __entrypoint="$2"
	local __var="${__service^^}_ENTRYPOINTS"
	local __var_secure="${__service^^}_ENTRYPOINTS_SECURE"

	local __previous
	[ ! "${!__var}" = "" ] && __previous=",${!__var}"
	eval "export ${__var}=${__entrypoint}${__previous}"
	__add_declared_variables "${__var}"

	__previous=
	[ ! "${!__var_secure}" = "" ] && __previous=",${!__var_secure}"
	eval "export ${__var_secure}=${__entrypoint}_secure${__previous}"
	__add_declared_variables "${__var_secure}"
}

# change rule priority of a service to be overriden by the http-catchall rule
__set_redirect_https_service() {
	local __service="$1"
	
	__service="${__service^^}"
	local __var="${__service}_REDIRECT_HTTPS_PRIORITY"

	eval "export ${__var}=50"
	__add_declared_variables "${__var}"

	# DEPRECATED : technique was to add a middleware redirect rule for each service
	# add only once ',' separator to compose file only if there is other middlewars declarated 
	# ex : "traefik.http.routers.sabnzbd.middlewares=${SABNZBD_REDIRECT_HTTPS}sabnzbd-stripprefix"
	# sed -i 's/\(.*\)\${'$__service'_REDIRECT_HTTPS}\([^,].\+\)\"$/\1\${'$__service'_REDIRECT_HTTPS},\2\"/g' "${GENERATED_DOCKER_COMPOSE_FILE}"

}

__add_volume_mapping_service() {
	local __service="$1"
	local __mapping="$2"
	
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.${__service}.volumes[+]" "${__mapping}"


}

__add_volume_local_definition() {
	local __name="$1"
	local __path="$2"

	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "volumes.${__name}.driver" "local"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "volumes.${__name}.name" "${TANGO_APP_NAME}_${__name}"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "volumes.${__name}.driver_opts.type" "none"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "volumes.${__name}.driver_opts.o" "bind"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "volumes.${__name}.driver_opts.device" "${__path}"
}

__set_network_as_external() {
	local __name="$1"
	local __full_name="$2"

	yq d -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "networks.${__name}.name"
	yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "networks.${__name}.external.name" "${__full_name}"
}


# VARIOUS -----------------


# list available modules or plugins
# item : modules or plugins
# mode : all (default) | app | tango
__list_items() {
	local __item="${1}"
	local __mode="${2:-all}"

	local __app_folder=
	local __tango_folder=
	local __file_ext=
	case ${__item} in
		modules ) __app_folder="${TANGO_APP_MODULES_ROOT}"; __tango_folder="${TANGO_MODULES_ROOT}"; __file_ext='*.yml';;
		plugins ) __app_folder="${TANGO_APP_PLUGINS_ROOT}"; __tango_folder="${TANGO_PLUGINS_ROOT}"; __file_ext='*';;
	esac

	local __result=""
	case ${__mode} in
		all ) __do_app=1; __do_tango=1;;
		app ) __do_app=1; __do_tango=0;;
		tango ) __do_app=0; __do_tango=1;;
	esac

	 
	if [ "${__do_app}" = "1" ]; then
		if ! $STELLA_API "is_dir_empty" "${__app_folder}"; then
			for f in ${__app_folder}/*; do
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


# filter a list with items of another list
__filter_list() {
	local __list_src="$1"
	local __list_filter="$2"

	[ -z "${__list_src}" ] && return

	[ -z "${__list_filter}" ] && echo -n "${__list_src}" && return

	local __result_list=
	for s in ${__list_src}; do
		[[ " ${__list_filter} " =~ .*\ ${s}\ .* ]] || __result_list="${__result_list} ${s}"
	done

	# remove trailing whitespace and return list
	echo -n "${__result_list%"${__result_list##*[![:space:]]}"}"
}

docker-compose() {
	# NOTE we need to specify project directory because when launching from an other directory, docker compose seems to NOT auto load .env file
	case ${TANGO_INSTANCE_MODE} in
		shared ) 
			[ "${VERBOSE}" = "1" ] && echo COMPOSE_IGNORE_ORPHANS=1 docker-compose ${DOCKER_COMPOSE_LOG} -f "${GENERATED_DOCKER_COMPOSE_FILE}" --env-file "${GENERATED_ENV_FILE_FOR_COMPOSE}" --project-name "${TANGO_INSTANCE_NAME}" --project-directory "${TANGO_APP_ROOT}" $@
			COMPOSE_IGNORE_ORPHANS=1 command docker-compose ${DOCKER_COMPOSE_LOG} -f "${GENERATED_DOCKER_COMPOSE_FILE}" --env-file "${GENERATED_ENV_FILE_FOR_COMPOSE}" --project-name "${TANGO_INSTANCE_NAME}" --project-directory "${TANGO_APP_ROOT}" $@
			;;
		* ) 
			[ "${VERBOSE}" = "1" ] && echo COMPOSE_IGNORE_ORPHANS=1 docker-compose ${DOCKER_COMPOSE_LOG} -f "${GENERATED_DOCKER_COMPOSE_FILE}" --env-file "${GENERATED_ENV_FILE_FOR_COMPOSE}" --project-name "${TANGO_APP_NAME}" --project-directory "${TANGO_APP_ROOT}" $@
			COMPOSE_IGNORE_ORPHANS=1 command docker-compose ${DOCKER_COMPOSE_LOG} -f "${GENERATED_DOCKER_COMPOSE_FILE}" --env-file "${GENERATED_ENV_FILE_FOR_COMPOSE}" --project-name "${TANGO_APP_NAME}" --project-directory "${TANGO_APP_ROOT}" $@
			;;
	esac
	
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

__xml_get_attribute_value() {
	local __file="$1"
	local __xpath_selector="$2"

	xidel "${__file}" --silent --extract "${__xpath_selector}"
}


# create various default folder and files if not exist
__create_default_path() {
	local __root="$1"
	local __list="$2"

	local __folder=
	local __file=
	for p in ${__list}; do
		[ "${p}" = "FOLDER" ] && __folder=1 && __file= && continue
		[ "${p}" = "FILE" ] && __folder= && __file=1 && continue
		__path="${__root}/${p}"
		if [ "${__folder}" = "1" ]; then
			[ ! -d "${__path}" ] && docker run -it --rm --user ${TANGO_USER_ID}:${TANGO_GROUP_ID} -v "${__root}":"/foo" bash:4.4.23 bash -c "mkdir -p /foo/${p} && chown ${TANGO_USER_ID}:${TANGO_GROUP_ID} /foo/${p}"
		fi
		if [ "${__file}" = "1" ]; then
			[ ! -f "${__path}" ] && docker run -it --rm --user ${TANGO_USER_ID}:${TANGO_GROUP_ID} -v "${__root}":"/foo" bash:4.4.23 bash -c "touch /foo/${p} && chown ${TANGO_USER_ID}:${TANGO_GROUP_ID} /foo/${p}"
		fi
	done


}





# test if mandatory  paths exists
__check_mandatory_path() {

	for p in ${TANGO_PATH_LIST}; do
		[ ! -d "${!p}" ] && echo "* ERROR : Mandatory root path ${p} [${!p}] do not exist" && exit 1
	done 

	if [ ! "${TANGO_ARTEFACT_FOLDERS}" = "" ]; then
		for f in ${TANGO_ARTEFACT_FOLDERS}; do
			[ ! -d "${f}" ] && echo "* ERROR : Mandatory declared artefact folder [${f}] do not exist" && exit 1
		done
	fi
}



__check_lets_encrypt_settings() {
	local __mode="$1"
	local __exit=
 	case ${LETS_ENCRYPT} in
    	enable|debug ) 
			[ "${LETS_ENCRYPT_MAIL}" = "" ] && echo "* ERROR : you have to specify a mail as identity into LETS_ENCRYPT_MAIL variable when using let's encrypt." && __exit=1
			[ "${TANGO_DOMAIN}" = '.*' ] && echo "* ERROR : you cannot use a generic domain (.*) setted by TANGO_DOMAIN when using let's encrypt. Set TANGO_DOMAIN variables or --domain comand line option with other value." && __exit=1
			[ "${TANGO_DOMAIN}" = "" ] && echo "* ERROR : you have to set a domain with TANGO_DOMAIN variable or --domain comand line option when using let's encrypt." && __exit=1
			[ ! "${NETWORK_PORT_MAIN}" = "80" ] && echo "* ERROR : main area network HTTP port is not 80 but ${NETWORK_PORT_MAIN}. You need to use DNS challenge for let's encrypt. Set LETS_ENCRYPT_CHALLENGE* variables." && __exit=1
			[ ! "${NETWORK_PORT_MAIN_SECURE}" = "443" ] && echo "* ERROR : main area network HTTPS port is not 443 but ${NETWORK_PORT_MAIN_SECURE}. You need to use DNS challenge for let's encrypt. Set LETS_ENCRYPT_CHALLENGE* variables" && __exit=1
		;;
	esac

	[ ! "${__mode}" = "warn" ] && [ "${__exit}" = "1" ] && exit 1
}
