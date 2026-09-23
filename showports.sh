#!/bin/bash

# Check for sudo privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root or with sudo"
    exit 1
fi

echo "Listing all listening ports with processes (and Docker containers if applicable):"
echo "----------------------------------------------------------------------------------"
echo
echo "Grabbing Docker Ports..."
# Collect Docker container host port mappings
declare -A port_to_container
while read -r cid; do
    container_name=$(sudo docker inspect -f '{{.Name}}' "$cid" | sed 's/^\/\|\/$//g')

    # Use correct syntax to get the host ports mapped to the container
    host_ports=$(sudo docker inspect -f \
        '{{range $p, $conf := .NetworkSettings.Ports}} {{range $conf}} {{.HostPort}} {{end}} {{end}}' "$cid")

    for host_port in $host_ports; do
        printf "."
        # Map the host port to the container name, only if not empty
        if [[ -n $host_port ]]; then
            port_to_container[$host_port]=$container_name
        fi
    done
done < <(sudo docker ps -q)
echo
echo

# For Debug: Print the Docker host-port-to-container map
#echo "Docker host port-to-container mapping:"
#for port in "${!port_to_container[@]}"; do
#    echo "Host Port: $port, Container: ${port_to_container[$port]}"
#done
#echo "----------------------------------------------------------------------------------"

# use this to remove duplicates
declare -A listed_ports

sudo netstat -tulnp | grep -E "^tcp " | while read -r line; do
    # Extract address:port and PID/process fields
    addr_port=$(echo "$line" | awk '{print $4}')
    pid_process=$(echo "$line" | awk '{print $7}')
    # Extract the port number from addr_port
    port=$(echo "$addr_port" | awk -F':' '{print $NF}')

    # Skip if we've already processed this port
    if [[ -n ${listed_ports[$port]} ]]; then
        continue
    fi
    listed_ports[$port]=1

    # pad the port to 5 characters for output consistency
    padded_port=$(printf "%5s" "$port")

    # Extract the PID and process name
    pid=$(echo "$pid_process" | cut -d'/' -f1)
    pname=$(ps -p "$pid" -o comm= 2>/dev/null)

    # Check if the port belongs to a Docker container
    if [[ -n ${port_to_container[$port]} ]]; then
        container=${port_to_container[$port]}
        echo "$padded_port | Container : $container (PID: $pid)"
    else
        echo "$padded_port | Process   : $pname (PID: $pid)"
    fi
done | sort -n

echo "----------------------------------------------------------------------------------"
