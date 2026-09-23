# Check (and Update) Synology SSL Certs

[check_certs.sh](./check_certs.sh)

This script can be used to find certificate locations on synology NAS that differ from a set of newly / frequently generated certificates, and update the synology certs accordingly.

`sudo check_certs.sh`

It needs to be run as root (`sudo`) in order to access the synology's certificate folders and compare cert files.

_*** This script was recently rewritten from scratch and can now support multiple generated certificates with different common-names.***_

## A note about importing certificates into DSM (first time import)

This script will only UPDATE certificates that were set up in DSM; It cannot add new certs not yet recognized by DSM. Having said that, it's important to set these certs up correctly the first time you import them in DSM.

If you have certs from somewhere like **LetsEncrypt**, you will have a few files. It is not completely intuitive based on the names; in order to have this script work consistently, the correct files must be initially uploaded into DSM. Things can _appear_ to work with the incorrect files uploaded, however, you should upload the following files into DSM when prompted:

| DSM Form Field               | File to Upload    |
| ---------------------------- | ----------------- |
| **Private Key**              | `privkey.pem`     |
| **Certificate**              | `cert.pem`        |
| **Intermediate certificate** | --_leave blank_-- |

DSM certs **CAN** work if you upload a mixture of `fullchain.pem` and `chain.pem` as the Cert and Intermediate Certs respectively... However, future reverse proxy updates and DSM changes will become VERY slow as DSM reconstructs its own cert files for you, AND the script provided here will no longer work. So... Don't import the wrong files. Only updating the two shown here will make your system run much faster during restarts and when creating or editing Reverse Proxy entries.

\*_If you get browser untrusted errors with certs still, add `chain.pem` to the "Intermediate Certificate" - however DSM updates and reverse proxy changes will slow down a LOT._

## First time run, Configuration File

The first time you run the script, it will generate a `cert_config.json` file for you in the same folder. This will contain entries for each CN (Common Name) certificate that's currently configured on your Synology. Here's my example:

```console
Checking for Installed Certificates...

  cert ID: auLTvE  has CN: *.mydomain.com
  cert ID: okVdDh  has CN: *.myseconddomain.com

Configuration file does not exist.
 - Generating new configuration file: cert_config.json
Configuration file created successfully.

 Edit the file cert_config.json and for those certs you want to check / update,
 add the path to your new certificates in "cert_path". Leaving this blank
 will exclude it from checks and updates.

Reading configuration file: cert_config.json...

 - CN: *.mydomain.com will not be checked or updated (config file cert_path blank)
 - CN: *.myseconddomain.com will not be checked or updated (config file cert_path blank)

CNs to check/update:


Done... No Certificates to Check / Update.
```

After first-run, the newly created `cert_config.json` contains:

```json
{
  "config": [
    {
      "cn": "*.mydomain.com",
      "cert_path": ""
    },
    {
      "cn": "*.myseconddomain.com",
      "cert_path": ""
    }
  ]
}
```

In order to have `check_certs.sh` look for updated versions of these certificates, you'll need to edit the `cert_path` element and put in a folder location that contains your generated certs like the below:

```json
{
  "config": [
    {
      "cn": "*.mydomain.com",
      "cert_path": "/volume1/docker/certbot/etc_letsencrypt/live/mydomain.com"
    },
    {
      "cn": "*.myseconddomain.com",
      "cert_path": "/volume1/docker/certbot/etc_letsencrypt/live/myseconddomain.com"
    }
  ]
}
```

those folders are the destination for my **certbot** scripts that run periodically to generate LetsEncrypt certificates.

## Checking your certificates, no changes (default behavior)

Once those paths are in place, you can run the script again in "check only" mode (it defaults to "check only" and doesn't make change unless you pass an additional option... see below) and it will give you an output with color coding to show you which certificates are mismatched with your newly generated certificates:

Running in check-only mode is done with

`sudo ./check_cert.sh`

```diff
Checking for mismatched certificates...
Checking package cert folders for cert ID: okVdDh, CN: *.mydomain.com...
 (0 found, 0 mismatches)

Checking non-package cert folders for cert ID: okVdDh, CN: *.mydomain.com...
 - 🟢 /usr/syno/etc/certificate/ReverseProxy/fce4c5b9-5e61-4eb5-93b0-02a1ae4bb826
 - 🟢 /usr/syno/etc/certificate/ReverseProxy/e2d91896-c2f1-47b6-96b6-cf3b8c626b90
 - 🟢 /usr/syno/etc/certificate/ReverseProxy/8f3339c2-3460-460b-bdcc-bc40e61fd9ee
 (3 found, 0 mismatches)

Checking package cert folders for cert ID: auLTvE, CN: *.myseconddomain.com...
 - 🔴 /usr/local/etc/certificate/LogCenter/pkg-LogCenter
 - 🔴 /usr/local/etc/certificate/ScsiTarget/pkg-scsi-plugin-server
 - 🔴 /usr/local/etc/certificate/SynologyDrive/SynologyDrive
 (3 found, 3 mismatches)

Checking non-package cert folders for cert ID: auLTvE, CN: *.myseconddomain.com...
 - 🔴 /usr/syno/etc/certificate/kmip/kmip
 - 🔴 /usr/syno/etc/certificate/smbftpd/ftpd
 - 🔴 /usr/syno/etc/certificate/ReverseProxy/b9839a46-676f-43cf-9fc8-3663dc87d37d
 - 🔴 /usr/syno/etc/certificate/ReverseProxy/ba51a915-35ef-4d63-b6ac-4c1fb7820275
 - 🔴 /usr/syno/etc/certificate/ReverseProxy/bdad0b43-ddeb-404e-a8cf-a0ff787d6f4c
 - 🔴 /usr/syno/etc/certificate/ReverseProxy/4c70a5e2-8380-447a-ada6-053f284be873
 - 🔴 /usr/syno/etc/certificate/ReverseProxy/4eb86f9e-880d-47e7-9a49-e473d4383dc3
 - 🔴 /usr/syno/etc/certificate/ReverseProxy/06e7ddea-0ce5-40c0-8464-0dfd444210fe
 - 🔴 /usr/syno/etc/certificate/ReverseProxy/0f611775-5c33-498f-9e84-4264a6bca8f0
 - 🔴 /usr/syno/etc/certificate/ReverseProxy/e6d25084-7f5c-426e-ae75-6ec22fe15d95
 - 🔴 /usr/syno/etc/certificate/ReverseProxy/04fdc8fd-6d63-4ff9-b448-fcb697b0efd7
 - 🔴 /usr/syno/etc/certificate/ReverseProxy/209efc5f-5ff1-4f41-b34a-afa8d843814b
 - 🔴 /usr/syno/etc/certificate/ReverseProxy/25352c5b-7a82-42ef-bd39-fad36b7203a2
 - 🔴 /usr/syno/etc/certificate/ReverseProxy/4679a920-1a13-47e1-a0ec-0b6dca22d75a
 - 🔴 /usr/syno/etc/certificate/ReverseProxy/7806549a-25bc-417a-8e05-0b2bfd445c02
 - 🔴 /usr/syno/etc/certificate/ReverseProxy/9e5cb385-bb66-4c96-abba-67f982bb6d1c
 - 🔴 /usr/syno/etc/certificate/ReverseProxy/733a2fb8-5007-4f52-9c63-5d50bd38490a
 - 🔴 /usr/syno/etc/certificate/system/FQDN
 - 🔴 /usr/syno/etc/certificate/system/default
 (19 found, 19 mismatches)

```

## Updating your certificates

When you have certificates that show as red and need to be updated, you can run the script with

`sudo ./check_certs.sh --update`

The `--update` parameter will re-run the script the same as before, however it will copy your certificates from your generated folders (from the config file's `cert_path`) into your live cert folders. Once complete, it will also restart any necessary services (if it can) that were using those replaced certificates.

After the certificate update, you'll see the "check" run one more time... Any previously $${\color{red}red}$$ items (mismatched certificates) should now show as $${\color{green}green}$$ which means mismatches have been fixed.

Only additional services where mismatches occured will be restarted.

### Other Options

#### VPNCenter Certificates

By default, if you have VPN Center installed, this script will also regenerate your VPN Certificates automatically if certs are updated for the VPNCenter application.
If you DO NOT WANT VPN Center certificates updated (since this may mean that new VPN client files may need to be regenerated if you include certs in your client config),
add the additional option:

`sudo ./check_certs.sh --update --novpnregen`

#### Dry-Run / Do not modify files

To run the script without overwriting any files or restarting any apps, pass this additional option.

`sudo ./check_certs.sh --update --dry-run`

In this mode, actual certificates will not be updated, and Packages that would have been affected with an updated cert will not be restarted (This gives a chance to check for what WOULD change and is good for debugging)

## Downloading

- ssh into the synology as a user with `sudo` rights
- download the script:

```
sudo wget -O check_certs.sh https://raw.githubusercontent.com/telnetdoogie/synology-scripts/main/check_certs.sh
```

- Make it executable:

```
sudo chmod +x check_certs.sh
```

## Scheduling the script

Once you're comfortable with the script, you can use the Synology Task Scheduler to execute it as frequently as you'd like.

Don't forget in your scheduled task that you'll need to `cd` to where the config file is in order for things to run unattended. Here's my scheduled task:

```bash
cd /volume1/scripts
bash /volume1/scripts/check_certs.sh --update
```

- Run as: root
- Schedule: Daily, at midnight
- My config file and script are in `/volume1/scripts`
