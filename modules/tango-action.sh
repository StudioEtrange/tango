#!/bin/bash


# ------------------- ACTION ----------------------------


case ${ACTION} in
	install )
		echo "** Install requirements"
		$STELLA_API get_features
	;;

	shell )
		if [ "${TARGET}" = "" ]; then
			echo "** ERROR : specify a running service in which you want a shell access"
			exit 1
		else
			case ${TARGET} in
				traefik )
					docker exec -it "${TANGO_INSTANCE_NAME}_traefik" /bin/sh -c "[ -e /bin/bash ] && /bin/bash || /bin/sh"
				;;
				* )
					docker exec -it "${TANGO_APP_NAME}_${TARGET}" /bin/sh -c "[ -e /bin/bash ] && /bin/bash || /bin/sh"
				;;

			esac
			
			
		fi
	;;

	init )
		
		case ${TARGET} in
			addons )
				echo "** Init service ${TANGO_APP_NAME} addons"
				docker-compose up addons
				;;
			* )
				echo "** Init service Plex"
				__init_service_plex
				echo "** Init service ${TANGO_APP_NAME} addons"
				docker-compose up addons
				;;
		esac
	;;

	info )
		case "${TARGET}" in
			* )
				docker-compose up service_info
			;;
		esac
	;;

	up )
		# TODO up --no-recreate ?
		docker-compose up ${DAEMON} ${BUILD} ${TARGET:-tango}
		if [ "${DAEMON}" = "" ]; then		
			[ "${TARGET}" = "" ] && docker-compose logs service_init
		else
			docker-compose logs service_init
		fi
	;;

	down )
		case "${TARGET}" in
			"") 
				if [ "${TANGO_INSTANCE_MODE}" = "shared" ]; then 
					# test if network already exist and set it as 'external' to not erase it
					if [ ! -z $(docker network ls --filter name=^${TANGO_APP_NETWORK_NAME}$ --format="{{ .Name }}") ] ; then 
						__set_network_as_external "default" "${TANGO_APP_NETWORK_NAME}"
					fi
				fi
				docker-compose down -v
				# restart common services like traefik when in shared mode because we do not want to stop them
                # TODO : do not restart traefik if it was already stopped ! ==> the idea is to conserve previous traefik state
				if [ "${TANGO_INSTANCE_MODE}" = "shared" ]; then 
					[ ! "${ALL}" = "1" ] && docker-compose up -d traefik
				fi
			;;
			*) 
				docker-compose stop ${TARGET}
				docker-compose rm ${TARGET}
			;;
		esac
	;;

	restart )
		case "${TARGET}" in
			"") 
				docker-compose down -v
			;;
			*) 
				docker-compose stop ${TARGET}
			;;
		esac
		docker-compose up ${DAEMON} ${BUILD} ${TARGET:-tango}
		if [ "${DAEMON}" = "" ]; then
			[ "${TARGET}" = "" ] && docker-compose logs service_info
		else
			docker-compose logs service_info
		fi

	;;

	status )
		docker-compose ps ${TARGET}
	;;

	logs )
		docker-compose logs -t ${TARGET}
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
esac
