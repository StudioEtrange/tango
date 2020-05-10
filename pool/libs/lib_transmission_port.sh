
# NEED transmission volumes
# WAIT for transmission service up


transmission_set_port() {
    local new_port="$1"
    
    TRANSMISSION_HOME="/transmission"
    transmission_username="${TRANSMISSION_USER}"
    transmission_passwd="${TRANSMISSION_PASSWORD}"
    transmission_settings_file="${TRANSMISSION_HOME}/settings.json"

    # Check if transmission remote is set up with authentication
    auth_enabled=$(grep 'rpc-authentication-required\"' "$transmission_settings_file" \
                    | grep -oE 'true|false')
    if [[ "true" = "$auth_enabled" ]]
    then
    echo "  + transmission auth required"
    myauth="--auth $transmission_username:$transmission_passwd"
    else
        echo "  + transmission auth not required"
        myauth=""
    fi

    # make sure transmission is running and accepting requests
    echo "  + waiting for transmission to become responsive"
    until torrent_list="$(transmission-remote $myauth -l)"; do sleep 10; done
    echo "  + transmission became responsive"
    output="$(echo "  + $torrent_list" | tail -n 2)"
    echo "  + $output"

    # get current listening port
    transmission_peer_port=$(transmission-remote $myauth -si | grep Listenport | grep -oE '[0-9]+')
    if [[ "$new_port" != "$transmission_peer_port" ]]; then
        #   if [[ "true" = "$ENABLE_UFW" ]]; then
        #     echo "  + Update UFW rules before changing port in Transmission"

        #     echo "  + denying access to $transmission_peer_port"
        #     ufw deny "$transmission_peer_port"

        #     echo "  + allowing $new_port through the firewall"
        #     ufw allow "$new_port"
        #   fi

        echo "  + setting transmission port to $new_port"
        transmission-remote ${myauth} -p "$new_port"

        echo "  + Checking port..."
        sleep 10
        transmission-remote ${myauth} -pt
    else
        echo "  + No action needed, port hasn't changed"
    fi
}