#!/bin/bash

# Print table headers
printf "%-30s %-15s\n" "Container Name" "Logger"
echo "---------------------------------------------"

# Iterate over all running containers
for container_id in $(docker container ls -q); do
    # Get the container name
    container_name=$(docker inspect -f '{{.Name}}' "$container_id" | sed 's|/||')

    # Get the logging driver
    logger=$(docker inspect -f '{{.HostConfig.LogConfig.Type}}' "$container_id")

    # Print the container name and logger in table format
    printf "%-30s %-15s\n" "$container_name" "$logger"
done
