
#!/bin/bash

usage() {
	echo "USAGE :"
	echo "----------------"
	echo "o-- commands :"
	echo "L     install : deploy this app"
	echo "L     init [addons] : init services & addons. Do it once before launch."
	echo "L     up [service [-d]] : launch all services or one service"
	echo "L     down [service] [--all]: down all services or one service. Except shared service when in shared mode."
	echo "L     restart [service [-d]] : restart all services or one service"
	echo "L     info : give info. Will generate conf files and print configuration used when launching any service."
	echo "L     status [service] : see status"
	echo "L     logs [service] : see logs"
	echo "L     shell <service> : launch a shell into a running service"
	echo "L		cert <path> --domain=<domain> : generate self signed certificate for a domain into a path"
}






# COMMAND LINE
PARAMETERS="
ACTION=										'action' 			a				'cert info shell up down status install logs init restart' '1'
TARGET=										'target' 			s				''	'0'
"
OPTIONS="
DOMAIN='' 					'' 				'domain'			s 			0			''		  Domain name.
APP=''				  		'a'				'name'				s			0		''					  Tango app name.
APPROOT=''				  	''				'path'				s			0		''					  Tango app path.
ENV=''				  		'e'				'path'				s			0		''					  User env file (example : HOME/app.env).
COMPOSE=''				  	'c'				'path'					s			0		''					  User compose file (example : HOME/app-compose.yml).
DEBUG='' 					'' 				''					b 			0			''		  Debug mode. More verbose and use lets encrypt debug server to not reach rate limit.
ALL='' 						'' 				''					b 			0			''		  Allow to stop all services including shared once like traefik.
VERBOSE=''				    'v'				''					b			0		''					  Verbose mode for debug purpose.
DAEMON=''				    'd'				''					b			0		''					  Daemon mode. When launching the whole app, it is in daemon mode by default, but when launching a specific service, launch it in daemon mode.
PUID='' 					'u' 			'string'			s 			0			''		  user id - set TANGO_USER_ID variable - will own bind mount created folder/files - Default current user group $(id -u).
PGID='' 					'g' 			'string'			s 			0			''		  group id - set TANGO_GROUP_ID variable - will own bind mount created folder/files - Default current user group $(id -g).
"
