# codeserver

A template showing usage of docker image by Linuxserver.io, with codeserver as sample

|Categories|Links|
|-|-|
| code source | https://github.com/Piwigo/Piwigo |
| docker image code source | https://github.com/linuxserver/docker-piwigo |
| docker image docs | https://docs.linuxserver.io/images/docker-piwigo |
| docker image registry | https://hub.docker.com/r/linuxserver/piwigo |
||https://github.com/linuxserver/docker-piwigo/pkgs/container/piwigo|
|doc links|http://piwigo.org/|

# howto

* To activate use : `TANGO_SERVICES_MODULES+=codeserver` or `--module=codeserver`
* Advanced usage : `TANGO_DOMAIN="domain.com" CODESERVER_ADDITIONAL_VOLUMES="$HOME:/workspace" ./tango up codeserver --module=codeserver`