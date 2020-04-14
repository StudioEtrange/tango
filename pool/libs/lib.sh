# MANAGE ENV VARIABLES AND FILES GENERATION -----------------

# update env files with current declared variables in VARIABLES_LIST
__update_env_files() {
	local __text="$1"
	echo "# ------ UPDATE : update_env_files : $(date) -- ${__text}" >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"
	echo "# ------ UPDATE : update_env_files : $(date) -- ${__text}" >> "${GENERATED_ENV_FILE_FOR_BASH}"
	for __variable in ${VARIABLES_LIST}; do
		[ -z ${!__variable+x} ] || echo "${__variable}=${!__variable}" >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"
		[ -z ${!__variable+x} ] || echo "${__variable}=\"${!__variable}\"" >> "${GENERATED_ENV_FILE_FOR_BASH}"		
	done
}


__get_declared_variable_names() {
	VARIABLES_LIST=""
	[ -f "${TANGO_ENV_FILE}" ] && VARIABLES_LIST="$(sed -e '/^[[:space:]]*$/d' -e '/^[#].*$/d' -e 's/^\(.*\)=\(.*\)$/\1/g' "${TANGO_ENV_FILE}")"
	[ -f "${TANGO_APP_ENV_FILE}" ] && VARIABLES_LIST="${VARIABLES_LIST} $(sed -e '/^[[:space:]]*$/d' -e '/^[#].*$/d' -e 's/^\(.*\)=\(.*\)$/\1/g' "${TANGO_APP_ENV_FILE}")"
	[ -f "${TANGO_USER_ENV_FILE}" ] && VARIABLES_LIST="${VARIABLES_LIST} $(sed -e '/^[[:space:]]*$/d' -e '/^[#].*$/d' -e 's/^\(.*\)=\(.*\)$/\1/g' "${TANGO_USER_ENV_FILE}")"

	VARIABLES_LIST="$($STELLA_API list_filter_duplicate "${VARIABLES_LIST}")"
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
	
	# add user app env file
	[ -f "${TANGO_USER_ENV_FILE}" ] &&  cat <(echo \# --- PART FROM user env file ${TANGO_USER_ENV_FILE}) <(echo) <(echo) "${TANGO_USER_ENV_FILE}" <(echo) >> "${GENERATED_ENV_FILE_FOR_COMPOSE}"


}

# generate an env file to be sourced (GENERATED_ENV_FILE_FOR_BASH)
__create_env_for_bash() {
	echo "# ------ CREATE : create_env_for_bash : $(date)" > "${GENERATED_ENV_FILE_FOR_BASH}"

	# add default tango env file
	cat <(echo \# --- PART FROM default tango env file ${TANGO_ENV_FILE}) <(echo) <(echo) "${TANGO_ENV_FILE}" <(echo) >> "${GENERATED_ENV_FILE_FOR_BASH}"
	
	# add app env file
	[ -f "${TANGO_APP_ENV_FILE}" ] &&  cat <(echo \# --- PART FROM app env file ${TANGO_APP_ENV_FILE}) <(echo) <(echo) "${TANGO_APP_ENV_FILE}" <(echo) >> "${GENERATED_ENV_FILE_FOR_BASH}"
	
	# add user app env file
	[ -f "${TANGO_USER_ENV_FILE}" ] &&  cat <(echo \# --- PART FROM user env file ${TANGO_USER_ENV_FILE}) <(echo) <(echo) "${TANGO_USER_ENV_FILE}" <(echo) >> "${GENERATED_ENV_FILE_FOR_BASH}"

	# add quote for variable bash support
	sed -i 's/^\([a-zA-Z0-9_-]*\)=\(.*\)$/\1=\"\2\"/g' "${GENERATED_ENV_FILE_FOR_BASH}"

}



# generate docker compose file
__create_docker_compose_file() {
	rm -f "${GENERATED_DOCKER_COMPOSE_FILE}"

	# concatenate compose file
	cp -f "${TANGO_COMPOSE_FILE}" "${GENERATED_DOCKER_COMPOSE_FILE}"

	[ -f "${TANGO_APP_COMPOSE_FILE}" ] && yq m -i -a -- "${GENERATED_DOCKER_COMPOSE_FILE}" "${TANGO_APP_COMPOSE_FILE}"
	[ -f "${TANGO_USER_COMPOSE_FILE}" ] && yq m -i -a -- "${GENERATED_DOCKER_COMPOSE_FILE}" "${TANGO_USER_COMPOSE_FILE}"
	
	__set_services_all
	__set_time_all
	__set_entrypoints_service_all
	__set_redirect_https_service_all
	__add_service_direct_port_access_all
	__add_gpu_all
	__add_volume_artefact_all
	__add_volume_app_pool_all
	__set_letsencrypt_service_all
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

__set_services_all() {
	for s in ${TANGO_SERVICES}; do
		[[ " ${TANGO_DISABLED_SERVICES} " =~ .*\ ${s}\ .* ]] || __add_service_dependency "tango" "${s}"
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
				__add_volume_mapping_service "${s}" "artefact_${__name}:${TANGO_ARTEFACT_MOUNT_POINT}/${target}"
			done
			[ "${VERBOSE}" = "1" ] && echo "** [${f}] will be mapped to {${TANGO_ARTEFACT_MOUNT_POINT}/${target}}"			
		fi
	done
}


# add volume to service which needs app pool if it exists
__add_volume_app_pool_all() {
	if [ -d "${TANGO_APP_ROOT}/pool" ]; then
		__add_volume_mapping_service "service_info" "${TANGO_APP_ROOT}/pool:/pool/${TANGO_APP_NAME}"
		__add_volume_mapping_service "service_init" "${TANGO_APP_ROOT}/pool:/pool/${TANGO_APP_NAME}"
		__add_volume_mapping_service "addons" "${TANGO_APP_ROOT}/pool:/pool/${TANGO_APP_NAME}"
	fi

}

# add gpu to all container that need its
# NVIDIA | INTEL_QUICKSYNC
__add_gpu_all() {
	for service in $(compgen -A variable | grep _GPU); do
		gpu="${!service}"
		if [ ! "${gpu}" = "" ]; then
			service="${service%_GPU}"
			service="${service,,}"
			__add_gpu "${service}" "${gpu}"
		fi
	done
}

# set timezone to containers which need it
__set_time_all() {
	
	for s in $TANGO_TIME_VOLUME_SERVICES; do
		__add_volume_for_time "$s"
	done

	for s in $TANGO_TIME_VAR_TZ_SERVICES; do
		__add_tz_var_for_time "$s"
	done

}



__set_letsencrypt_service_all() {

	
	case ${LETS_ENCRYPT} in
		enable|debug )
			for serv in ${LETS_ENCRYPT_SERVICES}; do
				__add_letsencrypt_service "${serv}"
				# add lets encrypt support for subservices
				for sub in ${TANGO_SUBSERVICES}; do
					case ${sub} in
						${serv}* ) __add_letsencrypt_service "${serv}" "${sub}";;
					esac
				done
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
	for s in ${NETWORK_SERVICES_AREA_MAIN}; do
		__set_entrypoint_service "${s}"  "web_main"
	done
	for s in ${NETWORK_SERVICES_AREA_SECONDARY}; do
		__set_entrypoint_service "${s}"  "web_secondary"
	done
	for s in ${NETWORK_SERVICES_AREA_ADMIN}; do
		__set_entrypoint_service "${s}"  "web_admin"
	done
}

__set_redirect_https_service_all() {
	for s in ${NETWORK_SERVICES_REDIRECT_HTTPS}; do
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
	done
}


__add_service_direct_port_access_all() {
	for service in $(compgen -A variable | grep _DIRECT_ACCESS_PORT); do
		port="${!service}"
		if [ ! "${port}" = "" ]; then
			service="${service%_DIRECT_ACCESS_PORT}"
			service="${service,,}"
			port_inside="$(yq r "${GENERATED_DOCKER_COMPOSE_FILE}" services.$service.expose[0])"
			if [ ! "${port_inside}" = "" ]; then
				[ "${VERBOSE}" = "1" ] && echo "* Activate direct access to $service : mapping $port to $port_inside"
				yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.$service.ports[+]" "$port:$port_inside"
			else
				echo "* WARN : cannot activate direct access to $service through $port : Unknown inside port to map to. Inside port must be declared as first port in expose section."
			fi
		fi
	done
}




# FEATURES MANAGEMENT --------
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
		yq w -i -- "${GENERATED_DOCKER_COMPOSE_FILE}" "services.plex.environment[+]" "TZ=${TZ}"
	fi
}



__add_service_dependency () {
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

docker-compose() {
	# NOTE we need to specify project directory because when launching from an other directory, docker compose seems to NOT auto load .env file
	case ${TANGO_INSTANCE_MODE} in
		shared ) 
			COMPOSE_IGNORE_ORPHANS=1 command docker-compose ${DOCKER_COMPOSE_LOG} -f "${GENERATED_DOCKER_COMPOSE_FILE}" --env-file "${GENERATED_ENV_FILE_FOR_COMPOSE}" --project-name "${TANGO_INSTANCE_NAME}" --project-directory "${TANGO_APP_ROOT}" $@
			;;
		* ) 
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
