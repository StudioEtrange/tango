# Domain Name Service

* A requirement to use tango is to have a wildcard domain name targeting your current host from internet. In other words `*.domain.org` should be solved as your public IP of your host

* If you do not have one there is some alternatives techniques


## Solution #1 : using nip.io (the simplest !)

* This solution is for test developement, do not use it in production

* Tango integrate an easy solution based on free nip.io service if you do not have a wildcard domain name.

* Use these special values as domain :
    * `TANGO_DOMAIN=auto-nip` or `--domain=auto-nip` : you can access your services deployed by tango from internet.
    * `TANGO_DOMAIN=auto-nip-lan` or `--domain=auto-nip-lan` : you can access your services deployed by tango only from local network. WARN this method may not work if your DNS server/forwarder configuration have DNS rebinding protection and resolving adress as local private ip address is blocked (https://en.wikipedia.org/wiki/DNS_rebinding) 

* NOTE : everywhere you see in tango doc and samples you can replace any `domain.org` value with `auto-nip` or `auto-nip-lan`

### long explanation :

* This solution use the free nip.io service
    * `<anything>[.-]<IP Address>.nip.io` will be resolved as `<IP Address>`
    * `firefox-20-20-30-40-nip.io` will be resolved as `20.20.30.40`

* When you set domain values with sepcial values, tango will internaly set your domain
    *  `auto-nip` : `<YOUR_PUBLIC_IP_ADRESS>.nip.io`
    *  `auto-nip-lan` : `<YOUR_CURRENT_LOCAL_IP_ADRESS>.nip.io`

* nip.io informations :
    * https://nip.io/
    * https://github.com/exentriquesolutions/nip.io


-----
## Solution #2 : editing /etc/hosts

* This solution is for localhost testing only.

* Edit /etc/hosts file mannually and add an entry for every services with your `<YOUR_CURRENT_LOCAL_IP_ADRESS>`
    ```
    192.168.0.50 firefox.domain.org 
    ```

* set `TANGO_DOMAIN` or `--domain` command line option with `domain.org` value, and access to the service only using a web browser from your localhost

----
## Solution #3 : edition your local network domain name server

* This solution is for local network testing only, and show how to configure your local network for some dns name server

* *OpenWrt* router configuration using dnsmasq to resolve any *.domain.org or domain.org as a unique 192.168.0.50 host inside localhost
    ```
    uci add_list dhcp.@dnsmasq[0].address="/domain.org/192.168.0.50"
    uci changes firewall
    uci commit
    /etc/init.d/firewall reload
    ```

* *pfsense* router to resolve any *.domain.org or domain.org as a unique 192.168.0.50 host inside localhost
    * Go to Services / DNS Forwarder
    * Pick Custom options and set `address=/domain.org/192.168.0.50`