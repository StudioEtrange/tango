# codeserver

* https://hub.docker.com/r/linuxserver/code-server
* https://github.com/linuxserver/docker-code-server
* https://fleet.linuxserver.io/image?name=linuxserver/code-server

# howto

* To activate use : `TANGO_SERVICES_MODULES+=codeserver` or `--module=codeserver`
* Advanced usage : `TANGO_DOMAIN="domain.com" CODESERVER_ADDITIONAL_VOLUMES="$HOME:/workspace" ./tango up codeserver --module=codeserver`