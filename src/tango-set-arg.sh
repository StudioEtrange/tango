
#!/bin/bash

usage() {
	echo "USAGE :"
	echo "----------------"
	echo "o-- tango management :"
	echo "L     install : deploy this app."
	echo "L     up [service [-b]] [--module module] [--plugin plugin] [--freeport]: launch all available services or one service"
	echo "L     down [service] [--mods mod-name] [--all]: down all services or one service. Except shared internal service when in shared mode (--all force stop shared service)."
	echo "L     restart [service] [--module module] [--plugin plugin] [--freeport]: restart all services or one service."
	echo "L     info [--freeport] [-v] : give info. Will generate conf files and print configuration used when launching any service."
	echo "L     status [service] : see service status."
	echo "L     logs [service] : see service logs."
	echo "L     update <service> : get last version of docker image service. Will stop service if it was running."
	echo "L     shell <service> : launch a shell into a running service."
	echo "L     services|modules|plugins list : list available modules or plugins. A module is a predefined service. A plugin is plug onto a service."
	echo "L     plugins <exec-service> <service>|<exec> <plugin>: exec all plugin attached to a service OR exec a plugin into all serviced attached."
	echo "o-- various commands :"
	echo "L		cert <path> --domain=<domain> : generate self signed certificate for a domain into a current host folder."
	echo "L		letsencrypt rm : delete generated letsencrypt cert"
	echo "L		vendor <path> : copy tango into another path (inside a tango folder : <path>/tango), mainly to vendorize tango into another app."
}






# COMMAND LINE
PARAMETERS="
ACTION=										'action' 			a				'update info shell up down status install logs restart services modules plugins cert vendor letsencrypt' '1'
TARGET=										'target' 			s				''	'0'
ARGUMENT=									'argument' 			s				''	'0'
"
OPTIONS="
DOMAIN='' 					'' 				'domain'			s 			0			''		  Domain name.
APP=''				  		'a'				'name'				s			0		''					  Tango app name.
APPROOT=''				  	''				'path'				s			0		''					  Tango app path.
MODULE=''				  	'm'				'module'				s:			0		''					  Add a module as a service. Repeatable option. <module>[@<network area>][%<service dependency1>][%<service dependency2>][^<vpn id>]
PLUGIN=''					'p'				'plugin'				s:			0		''					  Active a plugin. Repeatable option. <plugin>[%<auto exec at launch into service1>][%!<manual exec into service2>][#arg1][#arg2]
ENV=''				  		'e'				'path'				s			0		''					  User env file (example : HOME/app.env).
COMPOSE=''				  	'c'				'path'					s			0		''					  User compose file (example : HOME/app-compose.yml).
DEBUG='' 					'd' 			''					b 			0			''		  Debug mode. More verbose and use lets encrypt debug server to not reach rate limit.
ALL='' 						'' 				''					b 			0			''		  Allow to stop all services including shared once like traefik.
VERBOSE=''				    'v'				''					b			0		''					  Verbose mode for debug purpose.
BUILD=''				    'b'				''					b			0		''					  Force build image before launch. Only for image which have a build context defined
PUID='' 					'u' 			'string'			s 			0			''		  user id - set TANGO_USER_ID variable - will own bind mount created folder/files - Default current user group $(id -u).
PGID='' 					'g' 			'string'			s 			0			''		  group id - set TANGO_GROUP_ID variable - will own bind mount created folder/files - Default current user group $(id -g).
FREEPORT=''				    'f'				''					b			0		''			  When up or restart services, will pick free random ports for network areas. Otherwise will pick previous setted random port.
"
