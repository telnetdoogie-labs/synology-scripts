#!/bin/bash
# Copies Let's Encrypt certs to staging for network devices
#
# Exit codes (see copy_SSL_certs.md):
#   0 - certificate unchanged, nothing done
#   1 - new certificate copied and keystore generated (intentional, so Task Scheduler
#       "send run details only when the script terminates abnormally" emails you)
#   2 - an error occurred

SCP_USER="admin"
FILE_TO_CHECK=cert.pem
FILES_TO_COPY=("cert.pem" "privkey.pem" "fullchain.pem")
OUTPUT_FILE=cert.pem
NEW_CERT_PATH="/volume1/docker/certbot/etc_letsencrypt/live/{your_domain_here}"
DESTINATION_PATH=/var/services/homes/admin/ssl_certs
KEYTOOL_PATH=/var/packages/java-installer/target/bin

# default keystorepass for UniFi, change if generating for some other system
KEYSTORE_PASS=aircontrolenterprise
# default alias for UniFi, change if generating for some other system
KEYSTORE_ALIAS=UniFi

if [[ ! -f "$NEW_CERT_PATH/$FILE_TO_CHECK" ]]; then
  echo "Error: $NEW_CERT_PATH/$FILE_TO_CHECK not found (have you set NEW_CERT_PATH?)"
  exit 2
fi
if [[ ! -d "$DESTINATION_PATH" ]]; then
  echo "Error: destination folder $DESTINATION_PATH does not exist"
  exit 2
fi

# Get MD5 Hash representations of the current cert file
#  and the previously copied version in the destination for comparison
CURRENT_VER=$(md5sum "$NEW_CERT_PATH/$FILE_TO_CHECK" | awk '{ print $1 }')
PREVIOUS_VER=$(md5sum "$DESTINATION_PATH/$OUTPUT_FILE" 2>/dev/null | awk '{ print $1 }')

if [[ "$CURRENT_VER" == "$PREVIOUS_VER" ]]; then
  echo "Certificates have not been updated, no action"
  exit 0
fi

echo "Certificates have been updated; Copying to new location"
rm -f "$DESTINATION_PATH"/*
for FILE in "${FILES_TO_COPY[@]}"; do
  if ! cp "$NEW_CERT_PATH/$FILE" "$DESTINATION_PATH/$FILE"; then
    echo "Error copying $FILE"
    exit 2
  fi
done

if ! openssl pkcs12 -export -in "$DESTINATION_PATH/cert.pem" -inkey "$DESTINATION_PATH/privkey.pem" \
   -out "$DESTINATION_PATH/temp.p12" -name "$KEYSTORE_ALIAS" -CAfile "$DESTINATION_PATH/fullchain.pem" \
   -caname root -password "pass:$KEYSTORE_PASS"; then
  echo "Error: openssl pkcs12 export failed"
  rm -f "$DESTINATION_PATH/temp.p12"
  exit 2
fi

if ! "$KEYTOOL_PATH/keytool" -importkeystore -deststorepass "$KEYSTORE_PASS" -destkeypass "$KEYSTORE_PASS" \
   -destkeystore "$DESTINATION_PATH/keystore" -srckeystore "$DESTINATION_PATH/temp.p12" \
   -srcstoretype PKCS12 -srcstorepass "$KEYSTORE_PASS" -alias "$KEYSTORE_ALIAS" -noprompt; then
  echo "Error: keytool import failed"
  rm -f "$DESTINATION_PATH/temp.p12"
  exit 2
fi

rm -f "$DESTINATION_PATH/temp.p12"
chown "$SCP_USER" "$DESTINATION_PATH"/*
# owner read/write only; cert and key files don't need to be executable
chmod 600 "$DESTINATION_PATH"/*

echo "Certificates copied and keystore generated."
exit 1
