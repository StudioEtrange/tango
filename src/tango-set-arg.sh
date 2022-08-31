
#!/bin/bash

usage() {
	echo "USAGE :"
	echo "----------------"
	echo "o-- tango management :"
	echo "L     install : deploy/update Tango dependencies."
	echo "L     up [service [-b]] [--module module] [--plugin plugin] [--freeport|--port port]: launch all available services or one service"
	echo "L     down [service] [--module module] [--all]: down all services or one service. Except shared internal service when in shared mode (--all force stop shared service)."
	echo "L     restart [service] [--module module] [--plugin plugin] [--freeport|--port port]: restart all services or one service."
	echo "L     info [service] [--module module] [--plugin plugin] [--freeport|--port port] [-v] : give info."
	echo "L     status [service] : see service status."
	echo "L     logs [service] [-f] : see service logs."
	echo "L     modules|services|plugins list : list available modules, plugins or default defined services within current selected context."
	echo "L 	-v : print Tango version."
	echo "|"
	echo "o-- advanced management :"
	echo "L     update <service> : pull last version of the defined docker tag image for the service. Do not update running service."
	echo "L     shell <service> [--userroot] : launch a shell into a running service. Shell can be launched as root user instead of setted user."
	echo "L     gen [--module module] [--plugin plugin] [--freeport|--port port]: generate compose & env files and create needed files & folders."
	echo "L     exec <service> [--userroot] -- command : exec a command into a running service. Can be launched as root user instead of setted user."
	echo "L     plugins exec-service <service> : exec all plugin attached to a running service."
	echo "L     plugins exec <plugin> :  exec a plugin into all running service attached."
	echo "|"
	echo "o-- various commands :"
	echo "L		cert <path> --domain=<domain> : generate self signed certificate for a domain into a current host folder."
	echo "L		letsencrypt rm : delete generated letsencrypt cert [WARN : delete certs will regenerate request to letsencrypt. Too much requests and you may be banned for a time]"
	echo "L		letsencrypt logs : follow letsencrypt actions"
	echo "L		letsencrypt test : test certificate generation using dns-challenge"
	echo "L		vendor <path> : copy tango into another path (inside a tango folder : <path>/tango), mainly to vendorize tango into another folder."
}






# COMMAND LINE
PARAMETERS="
ACTION=										'action' 			a				'update info gen shell exec up down status install logs restart services modules plugins cert vendor letsencrypt' '1'
TARGET=										'target' 			s				''	'0'
ARGUMENT=									'argument' 			s				''	'0'
"
OPTIONS="
DOMAIN='' 					'' 				'domain'			s 			0		''		  Domain name.
PORT=''						'p'				'port'				s:			0		''		  Ports associated to each network area. Repeatable option. Syntax : <network area>@<port>[@<secure port>]
CTX=''				  		'c'				'name'				s			0		''		  Context name.
CTXROOT=''				  	''				'path'				s			0		''		  Context path.
MODULE=''				  	'm'				'module'			s:			0		''		  Add a module as a service. Repeatable option. Syntax : <module>[@<network area>][%<service dependency1>][%<service dependency2>][^nb instance][~<vpn id>]
PLUGIN=''					''				'plugin'			s:			0		''		  Active a plugin. Repeatable option. <plugin>[%<auto exec at launch into service1>][%!<manual exec into service2>][#arg1][#arg2]
ENV=''				  		'e'				'path'				s			0		''		  User env file (example : HOME/ctx.env).
COMPOSE=''				  	''				'path'				s			0		''		  User compose file (example : HOME/ctx-compose.yml).
DEBUG='' 					'd' 			''					b 			0		''		  Debug mode. More verbose and use lets encrypt debug server to not reach rate limit.
ALL='' 						'' 				''					b 			0		''		  Allow to stop all services including shared once like traefik.
BUILD=''				    'b'				''					b			0		''		  Force build image before launch. Only for image which have a build context defined
PUID='' 					'u' 			'string'			s 			0		''		  user id - set TANGO_USER_ID variable - will own bind mount created folder/files - Default current user group $(id -u).
PGID='' 					'g' 			'string'			s 			0		''		  group id - set TANGO_GROUP_ID variable - will own bind mount created folder/files - Default current user group $(id -g).
FREEPORT=''				    ''				''					b			0		''		  When up or restart services, will pick free random ports for network areas. Otherwise will pick previous setted random port.
FOLLOW=''				    'f'				''					b			0		''		  Follow mode for logs.
USERROOT=''				    'r'				''					b			0		''		  Launch shell as root instead of setted user
"
