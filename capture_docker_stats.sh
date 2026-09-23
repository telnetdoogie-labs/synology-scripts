#!/bin/bash

# Initialize variables
CONTAINER_NAME=""
VERBOSE=false
STOPPED=false

# Parse arguments
for arg in "$@"; do
	if [ "$arg" == "-v" ]; then
		VERBOSE=true
	else
		CONTAINER_NAME="$arg"
	fi
done

# Validate if the container name is provided and exists
if [ ! -z "$CONTAINER_NAME" ]; then
	if ! docker ps --format '{{.Names}}' | grep -wq "$CONTAINER_NAME"; then
		echo "Error: Container '$CONTAINER_NAME' is not running or does not exist."
		exit 1
	fi
fi

# Define the log file based on the container name
if [ -z "$CONTAINER_NAME" ]; then
	LOG_FILE="stats_all_containers.log"
else
	LOG_FILE="stats_${CONTAINER_NAME}.log"
fi

# Let the user know we're running
if [ -z "$CONTAINER_NAME" ]; then
    echo "Capturing all container stats to $LOG_FILE"
	echo " - add container name as argument to capture for specific container"
else
	echo "Capturing Container '${CONTAINER_NAME}' stats to $LOG_FILE"
fi

# If verbose mode is enabled, also print to the screen
if [ "$VERBOSE" = false ]; then
	 echo " - add -v parameter to log to screen as well"
fi
echo "CTRL-C to finish"

# Capture CTRL-C to gracefully exit on the next iteration instead of abending
trap 'STOPPED=true' SIGINT

# Loop to capture CPU usage continually
while [[ $STOPPED = false ]]; do
	# Capture the current timestamp
	TIMESTAMP=$(date --iso-8601=seconds)

	# Run docker stats in a subshell where SIGINT is ignored
	if [ -z "$CONTAINER_NAME" ]; then
		JSON=$(setsid docker stats --format json --no-stream)
	else
		JSON=$(setsid docker stats "$CONTAINER_NAME" --format json --no-stream)
	fi

	# Add the current timestamp to the JSON and format fields for logging
	UPDATED_JSON=$(echo "$JSON" | jq -c --arg time "$TIMESTAMP" '
	.dateTime = $time |
	del(.BlockIO, .NetIO, .PIDs) |
		.CPUPerc = (.CPUPerc | gsub("%"; "") | tonumber) |
		.MemPerc = (.MemPerc | gsub("%"; "") | tonumber) |
		.MemUsage |= (split(" / ") | {
			Memory: .[0] | capture("(?<value>[-0-9.]+)(?<unit>[a-zA-Z]+)") | {Memory: .value | tonumber, Units: .unit},
			Max: .[1] | capture("(?<value>[-0-9.]+)(?<unit>[a-zA-Z]+)") | {Memory: .value | tonumber, Units: .unit}
		}) |
		.MemMax = .MemUsage.Max |
		.MemUsage = .MemUsage.Memory |
	{dateTime, ID, Name, Container, CPUPerc, MemPerc, MemUsage, MemMax}
	')

	# Write the JSON to the log file
	echo "$UPDATED_JSON" >> "$LOG_FILE"

	# If verbose mode is enabled, also print to the screen
	if [ "$VERBOSE" = true ]; then
		echo "$UPDATED_JSON"
	fi

	# Sleep for a desired interval (seconds)
	sleep 0.25
done

echo "CTRL-C / SIGINT - Stopping."
