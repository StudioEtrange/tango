# SERVICE LIFECYCLE -----------


# start a service or all services
# at first step, stop service 
# if no service specified will start all service (by starting docker compose service "tango")
# if service specified is the name of a scaled modules, all instances of this module will be launched
# OPTIONS
#		NO_EXEC_PLUGINS do not run attached plugins
#		BUILD	build image before starting
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



	__tango_log "DEBUG" "tango" "service_up : first stopping services"
	case "${__service}" in
		"") 
			__service_down_all "${__opt}"
		;;
		vpn)
			__tango_log "INFO" "tango" "Will stop all vpn services"
			__service_down "vpn $VPN_SERVICES_LIST"
		;;
		*) 
			__service_down "${__service}" "${__opt}"
		;;
	esac
	
	__tango_log "DEBUG" "tango" "service_up : remove volumes not used in case of path have changed"
	__compose_volume_remove



	if $STELLA_API list_contains "${TANGO_SERVICES_MODULES_SCALED}" "${__service}"; then
		__instances="${__service^^}_INSTANCES_LIST"
		__tango_log "DEBUG" "tango" "service_up : starting all instances of scaled ${__service} : ${!__instances}"
		if docker-compose up -V -d $__build ${!__instances}; then
			__tango_log "INFO" "tango" "${!__instances} started"
			for i in ${!__instances}; do
				[ ! "$__no_exec_plugins" = "1" ] && __exec_auto_plugin_all_by_service ${i}
				docker-compose logs ${i}
			done
		else
			__tango_log "ERROR" "tango" "service_up : error code $? in docker-compose up"
			exit 1
		fi
		
	else
		
		if docker-compose up -V -d $__build ${__service:-tango}; then
			__tango_log "INFO" "tango" "${__service:-tango} started"
		else
			__tango_log "ERROR" "tango" "service_up : error code $? in docker-compose up"
		fi

		if [ "${__service}" = "" ]; then
			[ ! "$__no_exec_plugins" = "1" ] && __exec_auto_plugin_service_active_all
			docker-compose logs tango
		else
			[ ! "$__no_exec_plugins" = "1" ] && __exec_auto_plugin_all_by_service ${__service}
			docker-compose logs ${__service}
		fi
	fi

	

}

# docker-compose services stop all
# OPTIONS
#	NO_DELETE do not delete containers nor volumes, just stop containers
__service_down_all() {
	local __opt="$1"

	local __list=

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
			# get all containers running or not
			__list="$(docker ps -a $(__container_filter 'LIST_NAMES '${TANGO_CTX_NAME}'_.*'))"
			# stop containers
			docker stop ${__list}
			if [ ! "${__no_delete}" = "1" ]; then
				# remove containers and remove anonymous volumes associated
				# NOTE : named volumes are not removed here !
				docker rm -v $(docker ps -a $(__container_filter 'ONLY_STOPPED LIST_NAMES '${TANGO_CTX_NAME}'_.*'))
			fi
		else
			# only shared and non shared service
			if [ "${__no_delete}" = "1" ]; then
				# get all stopped containers
				__list="$(docker ps -q $(__container_filter 'NON_STOPPED LIST_NAMES '${TANGO_CTX_NAME}'_.* '${TANGO_INSTANCE_NAME}'_.*'))"
				# stop containers
				docker stop ${__list}			
			else
				# stop and remove containers
				# also remove named volumes declared in the `volumes` section of the Compose file and anonymous volumes attached to containers.
				docker-compose down -v
			fi
		fi
	else
		if [ "${__no_delete}" = "1" ]; then
			# get all stopped containers
			__list="$(docker ps -q $(__container_filter 'NON_STOPPED LIST_NAMES '${TANGO_CTX_NAME}'_.* '${TANGO_INSTANCE_NAME}'_.*'))"
			# stop containers
			docker stop ${__list}		
		else
			# stop and remove containers
			# also remove named volumes declared in the `volumes` section of the Compose file and anonymous volumes attached to containers.
			docker-compose down -v
		fi
	fi
}


# docker-compose service stop specific service (or all instance of a specific service)
# OPTIONS
#	NO_DELETE do not delete containers nor volumes, just stop containers
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
		# stop containers
		docker-compose stop ${!__instances}
		if [ ! "${__no_delete}" = "1" ]; then
			# remove containers and any anonymous volumes attached to containers
			# NOTE : named volumes are not removed here !
			docker-compose rm -f -v ${!__instances}
		fi
	else
		# stop containers
		docker-compose stop ${__service}
		if [ ! "${__no_delete}" = "1" ]; then
			# remove containers and any anonymous volumes attached to containers
			# NOTE : named volumes are not removed here !
			docker-compose rm -f -v ${__service}
		fi

	fi
}
