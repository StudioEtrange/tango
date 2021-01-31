## VPN


* PIA ovpn files : https://www.privateinternetaccess.com/helpdesk/kb/articles/where-can-i-find-your-ovpn-files
    * PIA non official ovpn files with real IP : https://github.com/Lars-/PIA-servers
* PIA linux script to open vpn and manage port forwarding : 
    * https://www.privateinternetaccess.com/helpdesk/kb/articles/manual-connection-and-port-forwarding-scripts
    * https://github.com/pia-foss/manual-connections
* PIA port forwarding : All servers support port forwarding except from USA


* dperson openvpn client
    * https://github.com/dperson/openvpn-client
    * https://hub.docker.com/r/dperson/openvpn-client/

* test leaks : https://dnsleaktest.com/
* sample with openvpn server https://gist.github.com/darth-veitcher/93acda9617bab3e1de0264cebf4637fc
* free vpn provider for test https://pilovali.nl/free-vpn/
* UI
    * qomui - Qt - openvpn client conf management  https://github.com/corrad1nho/qomui

## Reverse Proxy

### Traefik2
* Traefik1 forward auth and keycloak https://geek-cookbook.funkypenguin.co.nz/ha-docker-swarm/traefik-forward-auth/keycloak/
* Traefik2 reverse proxy + reverse an external url : https://blog.eleven-labs.com/fr/utiliser-traefik-comme-reverse-proxy/
* Traefik1 and oauth2 proxy https://geek-cookbook.funkypenguin.co.nz/reference/oauth_proxy/
* Traefik1 and OpenIDConnect provider with keycloak 
        * https://geek-cookbook.funkypenguin.co.nz/ha-docker-swarm/traefik-forward-auth/keycloak/
        * https://geek-cookbook.funkypenguin.co.nz/recipes/keycloak/setup-oidc-provider/
* Traefik2 minimal forward authentication service that provides OAuth/SSO login and authentication for the traefik reverse proxy/load balancer (have several fork)
        * https://github.com/thomseddon/traefik-forward-auth
* Traefik2 REST API : https://community.containo.us/t/rest-provider-put-giving-404-when-api-auth-is-enabled/2832/6

### Nginx

* various services nginx configuration https://github.com/linuxserver/reverse-proxy-confs

## SSL / certificate 
* Let's encrypt
    * challenge types : https://letsencrypt.org/fr/docs/challenge-types/

## Backup solutions
* https://geek-cookbook.funkypenguin.co.nz/recipes/duplicity/
* https://rclone.org/
    * rclone desktop browser : https://github.com/kapitainsky/RcloneBrowser
    * rclone desktop browser on docker with VNC : https://github.com/romancin/rclonebrowser-docker
    * rclone for android : https://github.com/x0b/rcx
* restic is a backup program, can use rclone https://github.com/restic/restic
