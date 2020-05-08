
#!/bin/bash

usage() {
	echo "USAGE :"
	echo "----------------"
	echo "o-- commands :"
	echo "L     install : deploy this app"
	echo "L     init addons : install and init addons only if any declared in current app."
	echo "L     up [service [-d][-b]] [--add mod-name] [--freeport]: launch all available services or one service"
	echo "L     down [service] [--mods mod-name] [--all]: down all services or one service. Except shared internal service when in shared mode (-all force stop shared service)."
	echo "L     restart [service [-d]] [--add mod-name] [--freeport]: restart all services or one service. Note : on restart when using freeport, new ports will be allocated."
	echo "L     info : give info. Will generate conf files and print configuration used when launching any service."
	echo "L     status [service] : see service status"
	echo "L     logs [service] : see service logs"
	echo "L     shell <service> : launch a shell into a running service"
	echo "L     mods : list available modules for use as a service"
	echo "L		cert <path> --domain=<domain> : generate self signed certificate for a domain into a current host folder"
}






# COMMAND LINE
PARAMETERS="
ACTION=										'action' 			a				'cert info shell up down status install logs init restart mods' '1'
TARGET=										'target' 			s				''	'0'
"
OPTIONS="
DOMAIN='' 					'' 				'domain'			s 			0			''		  Domain name.
APP=''				  		'a'				'name'				s			0		''					  Tango app name.
APPROOT=''				  	''				'path'				s			0		''					  Tango app path.
ADD=''					  	''				'name'				s:			0		''					  Add a mod as a service. Repeatable option.
ENV=''				  		'e'				'path'				s			0		''					  User env file (example : HOME/app.env).
COMPOSE=''				  	'c'				'path'					s			0		''					  User compose file (example : HOME/app-compose.yml).
DEBUG='' 					'' 				''					b 			0			''		  Debug mode. More verbose and use lets encrypt debug server to not reach rate limit.
ALL='' 						'' 				''					b 			0			''		  Allow to stop all services including shared once like traefik.
VERBOSE=''				    'v'				''					b			0		''					  Verbose mode for debug purpose.
DAEMON=''				    'd'				''					b			0		''					  Daemon mode. When launching the whole app, it is in daemon mode by default, but when launching a specific service, launch it in daemon mode.
BUILD=''				    'b'				''					b			0		''					  Force build image before launch. Only for image which have a build context defined
PUID='' 					'u' 			'string'			s 			0			''		  user id - set TANGO_USER_ID variable - will own bind mount created folder/files - Default current user group $(id -u).
PGID='' 					'g' 			'string'			s 			0			''		  group id - set TANGO_GROUP_ID variable - will own bind mount created folder/files - Default current user group $(id -g).
FREEPORT=''				    'f'				''					b			0		''			  Pick free random ports for network areas.
"
