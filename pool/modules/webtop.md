# webtop

* https://hub.docker.com/r/linuxserver/webtop
* https://github.com/linuxserver/docker-webtop

# howto

* To activate use : `TANGO_SERVICES_MODULES+=webtop` or `--module=webtop`
* By default the user/pass is abc/abc, if you change your password or want to login manually to the GUI session for any reason use the following link: http://webtop.domain.org/?login=true
* More advanced usage : `WEBTOP_VERSION_FIXED_VAR="alpine-openbox" WEBTOP_INSTANCES_LIST="foo bar" TANGO_DOMAIN="domain.org" ./tango up --freeport webtop --module webtop^2`

