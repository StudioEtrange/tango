# NOTES

- [NOTES](#notes)
  - [VPN](#vpn)
  - [Paas](#paas)
  - [Reverse Proxy](#reverse-proxy)
    - [Traefik](#traefik)
    - [Nginx](#nginx)
  - [SSL / certificate](#ssl--certificate)
  - [dashboard/homepage application](#dashboardhomepage-application)
  - [Backup solutions](#backup-solutions)


## VPN

* PIA ovpn files : https://www.privateinternetaccess.com/helpdesk/kb/articles/where-can-i-find-your-ovpn-files
    * PIA non official ovpn files with real IP : https://github.com/Lars-/PIA-servers
* PIA linux script to open vpn and manage port forwarding : 
    * https://www.privateinternetaccess.com/helpdesk/kb/articles/manual-connection-and-port-forwarding-scripts
    * https://github.com/pia-foss/manual-connections
* PIA port forwarding : All pia servers support port forwarding except from USA

* dperson openvpn client
    * https://github.com/dperson/openvpn-client
    * https://hub.docker.com/r/dperson/openvpn-client/

* test leaks : https://dnsleaktest.com/
* sample with openvpn server https://gist.github.com/darth-veitcher/93acda9617bab3e1de0264cebf4637fc
* free vpn provider for test https://pilovali.nl/free-vpn/
* qomui - Qt - openvpn client conf management  https://github.com/corrad1nho/qomui


## Paas

  * dokploy
    * Dokploy is a free, self-hostable Platform as a Service (PaaS) that simplifies the deployment and management of applications and databases.
    * based on traefik and docker compose and docker swarm
    * https://dokploy.com/
    * https://github.com/Dokploy/dokploy




## Reverse Proxy

### Traefik

* Traefik1 forward auth and keycloak 
    * https://geek-cookbook.funkypenguin.co.nz/ha-docker-swarm/traefik-forward-auth/keycloak/
* Traefik2 reverse proxy + reverse an external url
    * https://blog.eleven-labs.com/fr/utiliser-traefik-comme-reverse-proxy/
* Traefik1 and oauth2 proxy 
    * https://geek-cookbook.funkypenguin.co.nz/reference/oauth_proxy/
* Traefik1 and OpenIDConnect provider with keycloak 
    * https://geek-cookbook.funkypenguin.co.nz/ha-docker-swarm/traefik-forward-auth/keycloak/
    * https://geek-cookbook.funkypenguin.co.nz/recipes/keycloak/setup-oidc-provider/
* Traefik2 minimal forward authentication service that provides OAuth/SSO login and authentication for the traefik reverse proxy/load balancer (have several fork)
    * https://github.com/thomseddon/traefik-forward-auth
* Traefik2 REST API
    * https://community.containo.us/t/rest-provider-put-giving-404-when-api-auth-is-enabled/2832/6

* Several traefik setups
    * https://github.com/htpcBeginner/docker-traefik

* Plugins : https://pilot.traefik.io/plugins

* exemple of docker compose keycloak forward auth traefik 2 https://github.com/htpcBeginner/docker-traefik/blob/master/docker-compose.yml


* docker provider network and traefik https://doc.traefik.io/traefik/providers/docker/#network
     * `--providers.docker.network=mynetwork` traefik launch option : it defines mynetwork as the default network used by traefik to route network trafic to containers. Can be usefull if there is several neetworks and you want to select one. WARN : to route trafic using a specific network, traefik instance AND routed containers MUST be connected to this network ! 
        i.e in a compose file
        traefk:
            ...
            networks:
                - mynetwork
    * docker label "traefik.docker.network=mynetwork" 
        * if setted on a container it will override value defined by the previous launch option and tell traefik to use mynetwork to route network trafic to this container. Can be usefull if there is several neetworks and you want to select one. WARN : to route trafic using a specific network, traefik instance AND the routed container MUST be connected to this network ! 
        i.e in a compose file
        apache:
            ...
            networks:
                - mynetwork
        * if setted on traefik instance itself, not sure of what its purpose and effect. Maybe useless to set it on traefik instance. Or it is to route trafic to traefik api http service.
   

### Nginx

* various preconfigured services for nginx : https://github.com/linuxserver/reverse-proxy-confs

## SSL / certificate

* Let's encrypt
    * challenge types : https://letsencrypt.org/fr/docs/challenge-types/




## dashboard/homepage application

* Heimdall
    * https://github.com/linuxserver/Heimdall
    * have integrations with some services https://apps.heimdall.site/applications/enhanced

* organizr2
    * https://organizr.app/
    * https://github.com/causefx/Organizr/
    * have integrations with some services
    * support authentification
    * lot of features

* Dashy
    * Dashy helps you organize your self-hosted services by making them accessible from a single place
    * https://github.com/lissy93/dashy
    * https://dashy.to/
    * support authentification
      * OIDC, keycloak, authelia, HTTP Basic Auth
    * lot of features

* homepage    
    * https://github.com/benphelps/homepage
    * have integrations with some services

* homer
    * Homer is a full static html/js dashboard, based on a simple yaml configuration file.
    * have integrations with some services
    * https://github.com/bastienwirtz/homer
    * https://www.reddit.com/r/selfhosted/comments/nfkeju/organizr_to_heimdall_to_sui_and_now_homer_my/

* SUI
    * a startpage for your server and / or new tab page
    * https://github.com/jeroenpardon/sui

* Homarr
  * https://github.com/ajnart/homarr
  * homepage specialized in *arr product

* Flame
    * Flame is self-hosted startpage for your server. Its design is inspired (heavily) by SUI. Flame is very easy to setup and use. With built-in editors, it allows you to setup your very own application hub in no time - no file editing necessary.
    * https://github.com/pawelmalak/flame
    * Docker integration to automatically pick and add apps based on their labels
  
* Fenrus
    * https://github.com/revenz/Fenrus
    * start page
    * support some authentification mechanism

## Backup solutions

* Duplicity
    * https://geek-cookbook.funkypenguin.co.nz/recipes/duplicity/
    * docker volume backup system based on duplicity

* docker volume backup system
    * https://github.com/futurice/docker-volume-backup
    * https://github.com/offen/docker-volume-backup

* Rclone (Mirroring tool)
    * https://rclone.org/ 
    * rclone desktop browser : https://github.com/kapitainsky/RcloneBrowser
    * rclone desktop browser on docker with VNC : https://github.com/romancin/rclonebrowser-docker
    * rclone for android : https://github.com/x0b/rcx

* restic (backup tool)
    * https://github.com/restic/restic
    * have a lot of storage connectivity including using rclone
    * list of related products : https://github.com/rubiojr/awesome-restic
    * docker crontabisable restic : https://github.com/lobaro/restic-backup-docker https://hub.docker.com/r/lobaro/restic-backup-docker/
    * https://github.com/Southclaws/restic-robot

* Borg (backup tool)
    * https://www.borgbackup.org/
    * dockerfile version : https://github.com/BaptisteBdn/docker-selfhosted-apps/tree/main/borg-backup

* Duplicacy
    * https://duplicacy.com/
    * command line version is free and open source

* Duplicati
    * https://www.duplicati.com/

* rclone vs restic : 
    * Rclone is more of a mirroring tool while restic is a backup tool.
    * https://www.reddit.com/r/DataHoarder/comments/ogfyq2/how_to_sue_google_drive_for_a_large_backup_to_a/h4kus5t?utm_source=share&utm_medium=web2x&context=3

* restic vs borg vs Arq 5 vs duplicati vs duplicacy
    * https://forum.duplicati.com/t/big-comparison-borg-vs-restic-vs-arq-5-vs-duplicacy-vs-duplicati/9952