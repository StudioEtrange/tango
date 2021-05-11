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

	scripts )
		case ${TARGET} in
			list )
				echo "Available scripts : $(__list_items "script")"
				;;

			exec )
				if [ -f "$TANGO_SCRIPTS_ROOT/$ARGUMENT" ]; then
				 	. $TANGO_SCRIPTS_ROOT/$ARGUMENT
				fi
				if [ ! "${TANGO_NOT_IN_APP}" = "1" ]; then
					if [ -f "$TANGO_APP_SCRIPTS_ROOT/$ARGUMENT" ]; then
						. $TANGO_APP_SCRIPTS_ROOT/$ARGUMENT
					fi
				fi
				;;
		esac 
	;;

	install )
		if [ "$TANGO_NOT_IN_APP" = "1" ]; then
			# standalone tango
			__tango_log "INFO" "tango" "Install tango requirements : $STELLA_APP_FEATURE_LIST"
			$STELLA_API get_features
		else
			STELLA_APP_FEATURE_LIST=$(__get_all_properties $(__select_app $TANGO_ROOT); echo $STELLA_APP_FEATURE_LIST)' '$STELLA_APP_FEATURE_LIST
			__tango_log "INFO" "tango" "Install tango and $TANGO_APP_NAME requirements : $STELLA_APP_FEATURE_LIST"
			$STELLA_API get_features
		fi
		
		
		
	;;

	update )
		if [ "${TARGET}" = "" ]; then
			__tango_log "ERROR" "tango" "Specify a service to update its docker image"
			exit 1
		else
			__tango_log "INFO" "tango" "Will get last docker image version of ${TARGET}"
			docker-compose pull ${TARGET}
			__tango_log "WARN" "tango" "You have to restart ${TARGET} service to run the updated version"
		fi
	;;

	shell )
		if [ "${TARGET}" = "" ]; then
			echo "** ERROR : specify a running service in which you want a shell access"
			exit 1
		else
			case ${TARGET} in
				traefik )
					docker-compose exec --user ${TANGO_USER_ID}:${TANGO_GROUP_ID} ${TARGET} /bin/sh
				;;
				* )
					docker-compose exec --user ${TANGO_USER_ID}:${TANGO_GROUP_ID} ${TARGET} /bin/sh
				;;
			esac
		fi
	;;

	info )
		case "${TARGET}" in
			* )
				docker-compose up service_info
			;;
		esac
	;;

	up )
		[ "${BUILD}" = "1" ] && BUILD="BUILD"
		__service_up "${TARGET}" "${BUILD}"
		
	;;

	down )
		case "${TARGET}" in
			"") 
				__service_down_all
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
			*) 
				#__service_down "${TARGET}" "NO_DELETE"
				__service_down "${TARGET}"
			;;
		esac
		
		[ "${BUILD}" = "1" ] && BUILD="BUILD"
		__service_up "${TARGET}" "${BUILD}"
	;;

	status )
		docker-compose ps ${TARGET}
	;;

	logs )
		docker-compose logs ${FOLLOW} -t ${TARGET}
	;;

	letsencrypt )
		if [ "${TARGET}" = "rm" ]; then
			rm -f "${LETS_ENCRYPT_DATA_PATH}/acme.json"
		fi
		if [ "${TARGET}" = "logs" ]; then
			docker-compose logs -f -t traefik | grep letsencrypt
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
			echo "* ERROR ${TARGET} do not exist or is not a folder"
		fi
	;;


	vendor )
		if [ "${TARGET}" = "" ]; then
			echo "* ERROR specify a target path"
		else
			echo "* Copy tango into ${TARGET}/tango"
			$STELLA_API transfer_app "${TARGET}"
		fi
	;;
esac
