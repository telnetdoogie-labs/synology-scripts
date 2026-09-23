#!/bin/bash
USERNAME=
PASSWORD=

# Check for USERNAME and PASSWORD
if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
   echo "Set both USERNAME and PASSWORD in the script"
   exit
fi

AUTH_B64=$(echo -n "${USERNAME}:${PASSWORD}" | base64 -w 0)
if [[ $EUID -ne 0 ]]; then
   echo "Run using sudo or as root"
   exit
fi

ORIG=$(cat /etc/nginx/sites-enabled/server.ReverseProxy.conf | grep Authorization)

# Check for existence of Authorization line in nginx config
if [[ -z "$ORIG" ]]; then
   echo "The proxy_set_header 'Authorization' was not found in your config."
   echo "Have you added it to your Reverse Proxy config in DSM?"
   exit
fi

# Output the matches BEFORE the change is made
echo "Before:"
echo -e "$ORIG"
echo

sed -E -i "/^\s*proxy_set_header\s+Authorization\s+/s/(Authorization).*/\1\t\t\"Basic ${AUTH_B64}\";/" /etc/nginx/sites-enabled/server.ReverseProxy.conf

NEW=$(cat /etc/nginx/sites-enabled/server.ReverseProxy.conf | grep Authorization)
# Output the matches AFTER the change is made
echo "After:"
echo -e "$NEW"
echo

# If changes were made, reload NGINX configs.
if [[ "${ORIG}" != "${NEW}" ]]; then
	echo "Changes made... reloading nginx"
	synow3tool --nginx=reload
else
	echo "No Changes made... exiting"
fi
