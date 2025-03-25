#!/bin/bash


# ------------------- ACTION ----------------------------

case ${ACTION} in

	services )
		if [ "${TARGET}" = "list" ]; then
			echo "Available services : ${TANGO_SERVICES_AVAILABLE}"
		fi
	;;

	modules )
		if [ "${TARGET}" = "list" ]; then
			echo "Available modules to use as a service : $(__list_items "module")"
		fi
	;;

	plugins )
		case ${TARGET} in
			list )
				echo "Available plugins : $(__list_items "plugin")"
				;;

			exec-service )
				if $STELLA_API list_contains "${TANGO_SERVICES_ACTIVE}" "${ARGUMENT}"; then
					echo "** Exec plugins attached to service ${ARGUMENT}"
					__exec_plugin_all_by_service "${ARGUMENT}"
				else
					echo "** ERROR ${ARGUMENT} is not an active service"
				fi
				;;

			exec )
				if $STELLA_API list_contains "${TANGO_PLUGINS}" "${ARGUMENT}"; then
					echo "** Exec plugin ${ARGUMENT} attached to all its services"
					__exec_plugin_into_services "${ARGUMENT}"
				else
					echo "** ERROR plugin ${ARGUMENT} is not available"
				fi
				;;
		esac 
	;;



	install )
		__install_tango_dependencies
	;;

	update )
		if [ "${TARGET}" = "" ]; then
			__tango_log "ERROR" "tango" "Specify a service to update"
			exit 1
		else
			__tango_log "INFO" "tango" "Will update service ${TARGET}"
			__tango_log "WARN" "tango" "You may have to restart ${TARGET} service to run its updated version"
			if $STELLA_API list_contains "${TANGO_SERVICES_MODULES_SCALED}" "${TARGET}"; then
				__instances="${__service^^}_INSTANCES_LIST"
				for i in ${!__instances}; do
					docker-compose pull --ignore-buildable ${i}
				done
			else
				# first try to build if service have a build context defined in compose
				docker-compose build --pull ${TARGET}
				# second try to pull if not buildable
				docker-compose pull --ignore-buildable ${TARGET}
			fi
			
		fi
	;;

	exec )
		if $STELLA_API list_contains "${TANGO_SERVICES_MODULES_SCALED}" "${TARGET}"; then
			__instances="${TARGET^^}_INSTANCES_LIST"
			for i in ${!__instances}; do
				__compose_exec "${i}" "${OTHER_ARG_EVAL}" "$USERROOT"
			done
		else
			__compose_exec "${TARGET}" "${OTHER_ARG_EVAL}" "$USERROOT"
		fi
	;;

	shell )
		if $STELLA_API list_contains "${TANGO_SERVICES_MODULES_SCALED}" "${TARGET}"; then
			__instances="${TARGET^^}_INSTANCES_LIST"
			__tango_log "ERROR" "tango" "Can not shell into a scaled module ${TARGET}, choose an instance instead : ${!__instances}"
		else
			__compose_exec "${TARGET}" "set -- /bin/sh" "$USERROOT"
		fi
	;;

	info )
		case "${TARGET}" in
			vpn* )
				__print_info_services_vpn "${TARGET}"
			;;
			"" )
				docker-compose up service_info
			;;
			* )
				__print_info_services "${TARGET}"
			;;
		esac
	;;

	gen )
		__tango_log "INFO" "tango" "Compose & env files and files & folders are generated"
		echo "---------==---- INFO  ----==---------"
		echo "* Tango current context name : ${TANGO_CTX_NAME}"
		echo "L-- standalone context : $([ "${TANGO_NOT_IN_ANY_CTX}" = "1" ] && echo NO || echo YES)"
		echo "L-- instance mode : ${TANGO_INSTANCE_MODE}"
		echo "L-- tango root : ${TANGO_ROOT}"
		echo "L-- tango env file : ${TANGO_ENV_FILE}"
		echo "L-- tango compose file : ${TANGO_COMPOSE_FILE}"
		echo "L-- selected context root : ${TANGO_CTX_ROOT}"
		echo "L-- selected context env file : ${TANGO_CTX_ENV_FILE}"
		echo "L-- selected context compose file : ${TANGO_CTX_COMPOSE_FILE}"
		echo "L-- user env file : ${TANGO_USER_ENV_FILE}"
		echo "L-- user compose file : ${TANGO_USER_COMPOSE_FILE}"

		echo "---------==---- GENERATED FILES  ----==---------"
		echo "L-- GENERATED_DOCKER_COMPOSE_FILE : ${GENERATED_DOCKER_COMPOSE_FILE}"
		echo "L-- GENERATED_ENV_FILE_FOR_BASH : ${GENERATED_ENV_FILE_FOR_BASH}"
		echo "L-- GENERATED_ENV_FILE_FOR_COMPOSE : ${GENERATED_ENV_FILE_FOR_COMPOSE}"
		echo "L-- GENERATED_ENV_FILE_FREEPORT : ${GENERATED_ENV_FILE_FREEPORT}"
		echo "L-- GENERATED_TLS_FILE : ${GENERATED_TLS_FILE}"


		echo "---------==---- PATHS ----==---------"
		echo "Format : [host path] is mapped to {inside container path}"
		echo "Context data path : [$CTX_DATA_PATH] is mapped to {/data}"
		echo "Plugins data path : [$PLUGINS_DATA_PATH] is mapped to {/plugins_data}"
		echo "Data path of internal tango data : [$TANGO_DATA_PATH]"
		echo "Artefact folders : [$TANGO_ARTEFACT_FOLDERS] are mapped to {${TANGO_ARTEFACT_MOUNT_POINT:-/artefact}} subfolders"
		echo "Lets encrypt store file : [${LETS_ENCRYPT_DATA_PATH}/acme.json] mapped inside traefik to {/letsencrypt/acme.json}"
		echo "Traefik dynamic conf files directory [${TRAEFIK_CONFIG_DATA_PATH}] mapped inside traefik to {/traefikconfig}"
		echo "Traefik log directory [${TRAEFIK_LOG_PATH}] mapped inside traefik to {/traefiklog}"
		
		__print_info_services "${TANGO_SERVICES_ACTIVE}"
	;;

	up )
		[ "${BUILD}" = "1" ] && BUILD="BUILD"
		
		
		__service_up "${TARGET}" "${BUILD}"

		[ "${TARGET}" = "vpn" ] && __tango_log "INFO" "tango" "Will start all vpn services"]

		case ${TARGET} in
			vpn*)
				__print_info_services_vpn "${TARGET}"
			;;
			"")
				__print_info_services "${TANGO_SERVICES_ACTIVE}"
			;;
			*)
				__print_info_services "${TARGET}"
			;;
		esac
	;;

	down )
		case "${TARGET}" in
			"") 
				__service_down_all
			;;
			vpn)
				__tango_log "INFO" "tango" "Will stop all vpn services"
				__service_down "vpn $VPN_SERVICES_LIST"
			;;
			*) 
				__service_down "${TARGET}"
			;;
		esac
	;;

	restart )
		case "${TARGET}" in
			"") 
				if [ "${TANGO_INSTANCE_MODE}" = "shared" ]; then
					if [ ! "${ALL}" = "1" ]; then
						__tango_log "WARN" "tango" "This is a tango shared instance, to restart everything including shared service like traefik, use restart --all option"
					fi
				fi
				#__service_down_all "NO_DELETE"
				__service_down_all
			;;
			vpn)
				__tango_log "INFO" "tango" "Will restart all vpn services"
				__service_down "vpn $VPN_SERVICES_LIST"
			;;
			*) 
				#__service_down "${TARGET}" "NO_DELETE"
				__service_down "${TARGET}"
			;;
		esac
		
		[ "${BUILD}" = "1" ] && BUILD="BUILD"
		__service_up "${TARGET}" "${BUILD}"

		case ${TARGET} in
			vpn*)
				__print_info_services_vpn "${TARGET}"
			;;
			"")
				__print_info_services "${TANGO_SERVICES_ACTIVE}"
			;;
			*)
				__print_info_services "${TARGET}"
			;;
		esac

	;;

	status )
		if $STELLA_API list_contains "${TANGO_SERVICES_MODULES_SCALED}" "${TARGET}"; then
			__instances="${TARGET^^}_INSTANCES_LIST"
			docker-compose ps -a ${!__instances}
		else
			docker-compose ps -a ${TARGET}
		fi
		
	;;

	logs )
		if $STELLA_API list_contains "${TANGO_SERVICES_MODULES_SCALED}" "${TARGET}"; then
			__instances="${TARGET^^}_INSTANCES_LIST"
			docker-compose logs ${FOLLOW} -t ${!__instances}
		else
			docker-compose logs ${FOLLOW} -t ${TARGET}
		fi
	;;

	letsencrypt )
		if [ "${TARGET}" = "rm" ]; then
			rm -f "${LETS_ENCRYPT_DATA_PATH}/acme.json"
		fi
		if [ "${TARGET}" = "logs" ]; then
			docker-compose logs --no-color -f -t traefik | grep 'acme'
		fi
	
		if [ "${TARGET}" = "test" ]; then
			case $ACME_CHALLENGE in

				HTTP)
					__tango_log "WARN" "tango" "Can only test ACME using DNS Challenge, not HTTP Challenge."
					;;

				DNS)
					__acme_var=""
					for var in $(compgen -A variable | grep ^ACME_VAR_); do
						__acme_var="${__acme_var} -e ${var/ACME_VAR_}=${!var}"
					done

					# empty previous generated files
					rm -Rf "${LETS_ENCRYPT_TEST_DATA_PATH}/*"

					echo docker run --rm --user "${TANGO_USER_ID}:${TANGO_GROUP_ID}" -v "${LETS_ENCRYPT_TEST_DATA_PATH}:/data" ${__acme_var} goacme/lego:latest \
					--server ${LETS_ENCRYPT_SERVER_DEBUG} --email ${LETS_ENCRYPT_MAIL} --dns ${ACME_DNS_PROVIDER} --domains "test.${TANGO_DOMAIN}" --path /data --accept-tos --dns.resolvers 1.1.1.1:53 --dns.resolvers 8.8.8.8:53 run

					docker run --rm --user "${TANGO_USER_ID}:${TANGO_GROUP_ID}" -v "${LETS_ENCRYPT_TEST_DATA_PATH}:/data" ${__acme_var} goacme/lego:latest \
					--server ${LETS_ENCRYPT_SERVER_DEBUG} --email ${LETS_ENCRYPT_MAIL} --dns ${ACME_DNS_PROVIDER} --domains "test.${TANGO_DOMAIN}" --path /data --accept-tos --dns.resolvers 1.1.1.1:53 --dns.resolvers 8.8.8.8:53 run

					__tango_log "INFO" "tango" "Check files in $LETS_ENCRYPT_TEST_DATA_PATH"
					;;
			esac
		fi
		;;


	cert )
		TARGET="$($STELLA_API rel_to_abs_path "${TARGET}" "${TANGO_CURRENT_RUNNING_DIR}")"
		if [ -d "${TARGET}" ]; then
			cd "${TARGET}"
			echo "* Generate self signed certificate for domain ${TANGO_DOMAIN}"
			echo "L-- ${TARGET}/tango.crt"
			echo "L-- ${TARGET}/tango.key"
			openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
			-keyout tango.key -out tango.crt -extensions san -config \
			<(echo "[req]"; 
				echo distinguished_name=req; 
				echo "[san]"; 
				echo subjectAltName=DNS:${TANGO_DOMAIN}
				) \
			-subj "/CN=${TANGO_DOMAIN}"
		else
			__tango_log "ERROR" "tango" "${TARGET} do not exist or is not a folder"
		fi
	;;


	vendor )
		if [ "${TARGET}" = "" ]; then
			__tango_log "ERROR" "tango" "Specify a target path"
		else
			__tango_log "INFO" "tango" "Vendorize ${TARGET}"
			__tango_log "INFO" "tango" "Copy tango into ${TARGET}/tango"
			$STELLA_API transfer_app "${TARGET}"

			cp -f "$TANGO_ROOT/pool/tango-link.sh" "${TARGET}/tango-link.sh"
			chmod +x "${TARGET}/tango-link.sh"

			cp -f "$TANGO_ROOT/pool/sample-app.sh" "${TARGET}/sample-app.sh"
			chmod +x "${TARGET}/sample-app.sh"

			__tango_log "INFO" "tango" "Link stella framework"
			$STELLA_API init_app "$(basename "${TARGET}")" "${TARGET}"

			echo ". \$_STELLA_LINK_CURRENT_FILE_DIR/tango-link.sh set-tango-root" >"${TARGET}/.stella-id"
			echo "export STELLA_ROOT=\$TANGO_ROOT/pool/stella" >>"${TARGET}/.stella-id"
			echo "STELLA_DEP_FLAVOUR=VENDOR" >>"${TARGET}/.stella-id"
			echo "STELLA_DEP_VERSION=" >>"${TARGET}/.stella-id"
			
		fi
	;;
esac
