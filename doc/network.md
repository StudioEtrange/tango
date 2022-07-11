# NETWORK : REWRITE THIS DOCUMENTATION

### Logical area & entrypoints

* To define network logical area use this syntax

```
NETWORK_SERVICES_AREA_LIST=<name>|<protocol>|<traefik internal port>|<traefik internal secured port>
i.e : NETWORK_SERVICES_AREA_LIST=main|http|80|443 admin|http|9000|9443
```

* For each logical area one traefik entrypoint will be created. Two entrypoints if a secured port is declared

* `zone|http|80|443` will create two entrypoints with this form : `entry_zone_http` and `entry_zone_http_secure`, making traefik listening on this port. Remember that traefik is itself in a container, so this port will be mapped to an external port that will be used as port for the entrypoint.

* To declare an external port matching the entrypoint use `NETWORK_PORT_<name>[_SECURE]` form
```
NETWORK_PORT_ADMIN=30000 ==> will match internal container port 9000
NETWORK_PORT_ADMIN_SECURE=30043 ==> will match internal container port 9443
```


* At least one network area must be called 'main' (with any protocol/port definition). If it is not declared, it will be auto created with values : main|http|80|443. This is the default area to which services are attached by default

* A service can be attached to several logical area, soo you can separate each service on different area according to your needs by opening/closing your router settings. Use the form `NETWORK_SERVICES_AREA_<name>=<service>` form 

```
NETWORK_SERVICES_AREA_MAIN=web who
```

* This will attached `web` and `who` services to main logical area (which can have two entrypoints, one not secure and one secure)

### Ports and Random free port

* With `--freeport` port associated with each entrypoints will be randomly choosen among free TCP ports. This option override any other entrypoint ports defined with variables from shell or env files.

* Any variables values ending with `_PORT` will be excluded from the free TCP ports. (including direct access port, see below)

    ```
    ./tango --freeport --module firefox --domain=mydomain.org up
    ```
    

* `--freeport` will allocate free ports of entrypoint each times a service is started with `up` or `restart` command. These ports are saved in an internal file and changed only when using `up` or `restart` command. When using `info` command `--freeport` will read ports from previously backup ones.

    ```
    ./tango --freeport --module firefox --domain=mydomain.org info
    ```
    

#### Direct access port

* For various purpose like debugging, you can declare a direct access HTTP port to the service to bypass traefik ang get directly to the service with variables `*_DIRECT_ACCESS_PORT`. The first port declared as `expose` in docker-compose file is mapped to its value.

    * access directly throuh http://host:7777
    ```
    MYSERVICE_DIRECT_ACCESS_PORT=7777
    ```

----
## HTTP/HTTPS configuration

### HTTPS redirection

* To enable/disable HTTP to HTTPS redirection engine, set `NETWORK_REDIRECT_HTTPS` variable
* To enable/disable HTTPS only access to each service, declare them in `NETWORK_SERVICES_REDIRECT_HTTPS` variable. An autosigned certificate will be autogenerate

* ie in user env file : 
    ```
    NETWORK_SERVICES_REDIRECT_HTTPS=traefik organizr2
    ```
### Certificate generation with Let's encrypt

* `LETS_ENCRYPT` variable control if let's encrypt (https://letsencrypt.org/) is used as a certificate authority and generator. ACME protocol is used to ask certificate generation
    * `LETS_ENCRYPT=disable` (default value) will disable auto generation
    * `LETS_ENCRYPT=enable` will auto generate a certificate for each services/subservices declared in `LETS_ENCRYPT_SERVICES`.
    * `LETS_ENCRYPT=debug` will use the test server of letsencrypt to not reach rate limit (https://letsencrypt.org/fr/docs/rate-limits/)

* You must set `LETS_ENCRYPT_MAIL` variable to use Let's encrypt service.

* NOTE : when you need to fully reset generated certificate, you have to delete the `acme.json` file Use `./tango letsencrypt rm` command for that.

* NOTE : letsencrypt do not allow "underscore" usage in domain name (https://community.letsencrypt.org/t/underscore-in-subdomain-fails/31431)

### Certificate generation and non default port for main area

* If you want change the network ports of main area to other ports than 80/443, you have to change the ACME protocol method from `HTTP Challenge` to `DNS Challenge`
    * By default tango uses the `HTTP Challenge` which *requires* port 80/443 to be opened and accessible from internet (https://docs.traefik.io/user-guides/docker-compose/acme-http/). 
    * Otherwise you need to use the `DNS Challenge` and configure how to access to your DNS provider through its API 
        * samples : https://docs.traefik.io/user-guides/docker-compose/acme-dns/
        * dns provider & configuration variable : https://doc.traefik.io/traefik/https/acme/#providers

* How-to : in your user conf file
    * Set `ACME_CHALLENGE` to `DNS`
    * Set `ACME_DNS_PROVIDER` with your provider name 
    * Add needed variables for your providers. Consult https://docs.traefik.io/https/acme/#providers for details. Prefix each needed variable with `ACME_VAR_`
    * sample for OVH (see samples/demo8):
        ```
        ACME_CHALLENGE=DNS
        ACME_DNS_PROVIDER=ovh
        ACME_VAR_OVH_ENDPOINT=xxx
        ACME_VAR_OVH_APPLICATION_KEY=xxx
        ACME_VAR_OVH_APPLICATION_SECRET=xxx
        ACME_VAR_OVH_CONSUMER_KEY=xxx
        ```




### Conception design note on router order and HTTPS Redirection (a tango internal mechanism)

* To make the system of HTTPS redirection fully customisable, we use the priority rules of traefik. Each service that need to have an HTTPS redirection use it

* We cannot use the method of set redirect middleware on each routers service because each service routers may have two entrypoints and redirect middlewares dont know from which entrypoint the request come. So we use a global catch all router rule, using priority for exclude some services

*Router order algorithm*

* if global HTTPS redirection engine disabled
    * 1.will match any HTTP service router with priority ROUTER_PRIORITY_DEFAULT_VALUE (i.e:2000)
	* 2.match error router which have a priority of ROUTER_PRIORITY_ERROR_VALUE (i.e:1800)

* if global HTTPS redirection engine enabled
    * 1.match router with HTTPS router with redirection middleware with priority ROUTER_PRIORITY_HTTP_TO_HTTPS_VALUE (i.e:1000)
    * 2.match any other router including HTTP service router with their lowered priority (i.e:500)
        * amount of priority to subtract : ROUTER_PRIORITY_DEFAULT_VALUE - ROUTER_PRIORITY_HTTP_TO_HTTPS_VALUE + (ROUTER_PRIORITY_HTTP_TO_HTTPS_VALUE / 2) (i.e:1500)
	* 3.match error router which have a lowered priority too (i.e:300)

Subservices have a priority higher than their service parent. 
In TANGO_SUBSERVICES_ROUTER each subservices, listed by group of parent service, get an increasing bonus of ROUTER_PRIORITY_DEFAULT_STEP (i.e:5) priority.

i.e with HTTPS redirection engine disabled
* TANGO_SERVICES_AVAILABLE=service1 service2
* TANGO_SUBSERVICES_ROUTER=service1_subservice1 service1_subservice2 service2_subservice1
* priorities computed : service1 : 2000, servce1_subservice1 : 2005, servce1_subservice2 : 2010,  service2 : 2000, servce2_subservice1 : 2005

----
## VPN

* Declare a vpn connection with `1` as id
    ```
    VPN_1_PATH=../mambo-data/vpn/pia_ovpn_default_recommended_conf_20200509
    VPN_1_VPN_FILES=Switzerland.ovpn
    VPN_1_VPN_AUTH=user;password
    VPN_1_DNS=1
    ```
    * These settings match ones from https://github.com/StudioEtrange/openvpn-client


### Connect a service to a VPN
* You can isolate some of your services to use this vpn connection :
    ```
    VPN_1_SERVICES=<service>
    ```

* How-To check service isolation, by checking its external ip
    ```
    ./mambo shell <service>
    curl 'https://api.ipify.org?format=json'
    ```

* services connected to a vpn 
    * have env var `VPN_ID` setted with the id of the vpn
    * inherits all env var `VPN_*`
    * have all config files inside a mounted volume at `/vpn`
    * all port declaration mapping and exposed port in compose-file are removed
    * its network alias coming from service name ais replaced by network alias from `vpn_<id>` container. Meaning cannot `ping <service>` from within other service, but `ping vpn_<id>` instead
    * the service container network become : `network_mode: service:vpn_<id>` meaning its network stack is the one from `vpn_<id>` container



