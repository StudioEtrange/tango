# xbackbone


* A lightweight file manager with full ShareX, Screencloud support and more

* https://hub.docker.com/r/linuxserver/xbackbone
* https://github.com/SergiX44/XBackBone


# howto

* To activate use : `TANGO_SERVICES_MODULES+=xbackbone` or `--module=xbackbone`
* To configure do not forget to set base_url with HTTPS : https://xbackbone.domain.org
* Change max upload file size in `$XBACKBONE_DATA_PATH/php/php-local.ini`
    ```
    upload_max_filesize = 25M
    post_max_size = 25M
    ```
