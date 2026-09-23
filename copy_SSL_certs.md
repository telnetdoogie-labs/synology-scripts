# Copy SSL Certs

[copy_SSL_certs.sh](./copy_SSL_certs.sh)

This script can be used to copy certificates, and generate a new `keystore` file specifically for use on the UniFi platform
(I use this to generate `keystore` file for a UniFi Dream Machine Pro)

It will only move files and generate a keystore if the certificates have changed between source and destination.

I schedule this script to run nightly.

- If cert has not changed, the script will exit
- If a new cert is detected, it will copy files and generate keystore, and exit with code 1.
  Exiting with code 1 on a 'successful push' allows "Send run details only when the script terminates abnormally" on the Synology Task Scheduler to send an email summarizing that changes were made.

### Downloading

- ssh into the Synology as a user with `sudo` rights
- download the script:

```
sudo wget -O copy_SSL_certs.sh https://raw.githubusercontent.com/telnetdoogie-labs/synology-scripts/main/copy_SSL_certs.sh
```

- Make it executable:

```
sudo chmod +x copy_SSL_certs.sh
```

### Usage

You will need to edit parameters in this file to suit your specific setup:

`NEW_CERT_PATH` - The location of your 'live' CERT files, perhaps from a `certbot` output \
`DESTINATION_PATH` - Destination you want your files to be copied to \
`SCP_USER` - The user that will be used to SCP into the location to pick up the files from any external boxes \

---

Typical output when certificates are found and moved:

```
Certificates have been updated; Copying to new location
Importing keystore /var/services/homes/admin/ssl_certs/temp.p12 to /var/services/homes/admin/ssl_certs/keystore...
```
