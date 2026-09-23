#!/bin/bash

# List all Docker networks
echo "Listing Docker networks and their subnets:"
echo "------------------------------------------"

# Loop through each network
docker network ls --format "{{.Name}}" | while read -r network; do
  # Inspect the network and extract the subnet(s)
  subnets=$(docker network inspect "$network" | grep -oP '(?<="Subnet": ")[^"]+')

  # Display the network name and its subnets
  echo "Network: $network"
  if [ -n "$subnets" ]; then
    echo "  Subnets:"
    echo "$subnets" | while read -r subnet; do
      echo "    - $subnet"
    done
  else
    echo "  Subnets: None"
  fi
  echo
done
