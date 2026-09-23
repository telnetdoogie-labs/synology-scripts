#!/bin/bash
# Copies Let's Encrypt certs to staging for network devices

SCP_USER=admin
FILE_TO_CHECK=cert.pem
FILES_TO_COPY=("cert.pem" "privkey.pem" "fullchain.pem")
OUTPUT_FILE=cert.pem
NEW_CERT_PATH=/volume1/docker/certbot/etc_letsencrypt/live/{your_domain_here}
DESTINATION_PATH=/var/services/homes/admin/ssl_certs
KEYTOOL_PATH=/var/packages/java-installer/target/bin

# default keystorepass for UniFi, change if generating for some other system
KEYSTORE_PASS=aircontrolenterprise
# default alias for UniFi, change if generaing for some other system
KEYSTORE_ALIAS=UniFi

# Get MD5 Hash representations of the current cert file
#  and the previously copied version in the destination for comparison
CURRENT_VER=`md5sum $NEW_CERT_PATH/$FILE_TO_CHECK | awk '{ print $1 }'`
PREVIOUS_VER=`md5sum $DESTINATION_PATH/$OUTPUT_FILE | awk '{ print $1 }'`

if [[ "$CURRENT_VER" == "$PREVIOUS_VER" ]]; then
  echo "Certificates have not been updated, no action"
  exit 0
else
  echo "Certificates have been updated; Copying to new location"
  rm $DESTINATION_PATH/*
  for FILE in "${FILES_TO_COPY[@]}"; do
     if ! cp "$NEW_CERT_PATH/$FILE" "$DESTINATION_PATH/$FILE"; then
         echo "Error copying $FILE"
         exit 1
     fi
  done

  openssl pkcs12 -export -in $DESTINATION_PATH/cert.pem -inkey $DESTINATION_PATH/privkey.pem \
     -out $DESTINATION_PATH/temp.p12 -name $KEYSTORE_ALIAS -CAfile $DESTINATION_PATH/fullchain.pem \
     -caname root -password pass:$KEYSTORE_PASS

  $KEYTOOL_PATH/keytool -importkeystore -deststorepass $KEYSTORE_PASS -destkeypass $KEYSTORE_PASS \
     -destkeystore $DESTINATION_PATH/keystore -srckeystore $DESTINATION_PATH/temp.p12 \
     -srcstoretype PKCS12 -srcstorepass $KEYSTORE_PASS -alias $KEYSTORE_ALIAS -noprompt

  if [ -f $DESTINATION_PATH/temp.p12 ]; then rm $DESTINATION_PATH/temp.p12; fi
  chown $SCP_USER $DESTINATION_PATH/*
  chmod 700 $DESTINATION_PATH/*

fi

exit 1
