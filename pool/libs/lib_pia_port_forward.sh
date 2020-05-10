
# NEED to be connected with PIA vpn
# WAIT for vpn service up

# about forwarding port with PIA
#   https://www.privateinternetaccess.com/helpdesk/kb/articles/can-i-use-port-forwarding-without-using-the-pia-client
#   https://www.privateinternetaccess.com/installer/port_forwarding.sh
# sample to forward port with PIA in shell and set transmission (torrent) service
#   https://github.com/haugene/docker-transmission-openvpn/blob/master/transmission/updatePort.sh



export PIA_FOLDER="/internal_data/scripts/pia_openforward"
pia_client_id_file="${PIA_FOLDER}/pia_client_id"

pia_new_client_id() {
    head -n 100 /dev/urandom | sha256sum | tr -d " -" | tee ${pia_client_id_file}
}

# NOTE : ask to open a port to private internet access vpn (PIA) provider
pia_get_port() {
    local new_port=

    # doc says : "Within two minutes of connecting the VPN"
    echo "  + Wait for tunnel to be fully initialized and PIA is ready to give us a port"
    sleep 15

    pia_client_id="$(cat ${pia_client_id_file} 2>/dev/null)"
    
    if [[ -z "${pia_client_id}" ]]; then
        echo "  + Generating new client id for PIA"
        pia_client_id=$(new_client_id)
    fi

    # Get the port
    port_assignment_url="http://209.222.18.222:2000/?client_id=$pia_client_id"
    pia_response=$(curl -s -f "$port_assignment_url")
    pia_curl_exit_code=$?

    if [[ -z "$pia_response" ]]; then
        echo "  + Port forwarding is already activated on this connection, has expired, or you are not connected to a PIA region that supports port forwarding"
    fi

    # Check for curl error (curl will fail on HTTP errors with -f flag)
    if [[ ${pia_curl_exit_code} -ne 0 ]]; then
        echo "  + curl encountered an error looking up new port: $pia_curl_exit_code"
        return 0
    fi

    # Check for errors in PIA response
    error=$(echo "  + $pia_response" | grep -oE "\"error\".*\"")
    if [[ ! -z "$error" ]]; then
        echo "  + PIA returned an error: $error"
        return 0
    fi

    # Get new port, check if empty
    new_port=$(echo "  + $pia_response" | grep -oE "[0-9]+")
    if [[ -z "$new_port" ]]; then
        echo "  + Could not find new port from PIA"
        return 0
    fi
    echo "  + Got new port $new_port from PIA"
    return $new_port
}
