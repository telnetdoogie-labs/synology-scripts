#!/bin/bash


readonly CERT_PATH=/usr/syno/etc/certificate
readonly PKGS_PATH=/usr/local/etc/certificate
readonly ARCHIVE_PATH=${CERT_PATH}/_archive
readonly INFO_FILE=${ARCHIVE_PATH}/INFO
readonly CONFIG_FILE="cert_config.json"
readonly CERT_FILE="cert.pem"
declare -A cert_map            # a map of CertID:CN that already exist
declare -a check_cns           # CNs / Certs we will check or update
declare -A config_map          # map of config entries to paths
declare -a services_to_restart # Packages that will need to be restarted
GREEN='🟢 '
RED='🔴 '
UPDATE=false                    # this defaults to check-only mode
CHANGES_MADE=false              # used to track if changes were made.
VPN_REGEN=true                  # defaults to true to update VPNCenter certs
NO_OVERWRITE=false              # will get set to true for a dry-run

# Give example usage
usage() {
    terminate "Usage: sudo $0 [--update] [--dry-run] [--novpnregen] \n
       --update to update mismatched certs\n
       --dry-run to emulate update with no modified files\n
       --novpnregen to skip updating VPNCenter certificates\n
        \n
       default (without --update) will just check files and make no change"
}

show_title() {
    echo
    echo "SSL Certificate Checker / Updater"
    echo "=================================="
    echo "(c) telnetdoogie 2024"
    echo "https://github.com/telnetdoogie/synology-scripts/blob/main/check_certs.md"
    echo
}

# Terminate with error message
terminate() {
    echo
    echo -e "$1"
    echo
    exit "${2:-1}"
}

# Check whether a specific entry is in an array
exists_in_array() {
    local search="$1"
    shift
    local array=("$@")
    for entry in "${array[@]}"; do
        if [[ "$entry" == "$search" ]]; then
            return 0 # found in array
        fi
    done
    return 1 # not found in array
}

# Extract CN from a given certificate file
get_cert_cn() {
    local cert_file="$1"
    if [[ -f "$cert_file" ]]; then
        # multiline nameopt gives one "commonName = value" line regardless of OpenSSL version
        openssl x509 -in "$cert_file" -noout -subject -nameopt multiline |
            sed -n 's/^ *commonName *= *//p' | head -n 1
    else
        echo ""
    fi
}

# Generate an empty config file based on existing certs in use
generate_config_file() {
    echo "Configuration file does not exist."
    echo " - Generating new configuration file: $CONFIG_FILE"

    # Create an array of objects with jq
    jq -n --argjson certs "$(
        for certCode in "${!cert_map[@]}"; do
            cn="${cert_map[$certCode]}"
            jq -n --arg cn "$cn" --arg cert_path "" '{cn: $cn, cert_path: $cert_path}'
        done | jq -s .
    )" '{config: $certs}' >"$CONFIG_FILE"

    echo "Configuration file created successfully."
    echo
    echo " Edit the file $CONFIG_FILE and for those certs you want to check / update,"
    echo " add the path to your new certificates in \"cert_path\". Leaving this blank"
    echo " will exclude it from checks and updates."
    echo
}

# Function to read an existing configuration file
read_config_file() {
    echo "Reading configuration file: $CONFIG_FILE..."
    echo
    # Check if the config file is valid JSON
    if ! jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
        terminate "Configuration file $CONFIG_FILE is not valid JSON. Please check the syntax."
    fi

    # Read the CNs and cert paths from the config file into an associative array
    while IFS= read -r line; do

        cn=$(echo "$line" | jq -r '.cn')
        cert_path=$(echo "$line" | jq -r '.cert_path // ""') # default to empty

        # Ensure CN is unique
        if [[ -v config_map["$cn"] ]]; then
            terminate "Duplicate CN detected in config file: $cn"
        fi

        # Store the path, ensuring only zero or one cert_path
        config_map["$cn"]="$cert_path"

    done \
        < <(jq -c '.config[]' "$CONFIG_FILE")

    # Validate that each CN in cert_map has an entry in config_map
    for certCode in "${!cert_map[@]}"; do
        cn="${cert_map[$certCode]}"

        if [[ -v config_map["$cn"] ]]; then # Check if CN exists in config_map
            if [[ -n "${config_map[$cn]}" ]]; then
                echo " - CN: $cn has a cert_path set."
                echo "    ${config_map[$cn]}"
                # read the cn from the cert.pem in cert_path
                cert_file="${config_map[$cn]}/cert.pem"
                cert_cn=$(get_cert_cn "$cert_file")
                if [[ "$cert_cn" == "$cn" ]]; then
                    echo "    - CN in cert.pem matches config CN. This CN will be checked."
                    check_cns+=("$cn")
                else
                    echo "    - Will not check $cn. CN in cert_path does not match ($cert_cn)."
                fi
            else
                echo " - CN: $cn will not be checked or updated (config file cert_path blank)"
            fi
        else
            echo " - CN: $cn will not be checked or updated (no entry in config file)"
        fi
    done

    # Check for entries in the config file with no corresponding CN in cert_map
    for config_cn in "${!config_map[@]}"; do
        if ! exists_in_array "$config_cn" "${cert_map[@]}"; then
            echo " - CN: $config_cn has entry in config but CN not found in certs."
        fi
    done
    echo
    echo "CNs to check/update: ${check_cns[*]}"
    echo
}

# Ensure the script is run as root
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        usage
    fi
}

# Set update to true if parameter passed
check_parameters() {
    for arg in "$@"; do
        case "$arg" in
            --update)
                UPDATE=true
                ;;
            --novpnregen)
                VPN_REGEN=false
                ;;
            --dry-run)
                NO_OVERWRITE=true
                ;;
            *)
                echo "Unknown argument passed: $arg"
                exit 1
                ;;
        esac
    done
}

# build entries in the cert_map array for certificate ID and cert name (CN) from existing certs
check_installed_certs() {

    echo "Checking for Installed Certificates..."
    echo

    while IFS= read -r certCode; do
        cert_path="$ARCHIVE_PATH/$certCode/cert.pem"

        # Extract the CN (Common Name) from the certificate file
        if [[ -f "$cert_path" ]]; then
            cn=$(get_cert_cn "$cert_path")
            if [[ -n "$cn" ]]; then
                echo "  cert ID: $certCode  has CN: $cn"
                cert_map["$certCode"]="$cn"
            else
                terminate "Warning: CN not found in $cert_path"
            fi
        else
            terminate "Warning: Certificate file $cert_path not found"
        fi
    done < <(jq -r 'keys[]' "$INFO_FILE")

    echo
    if [[ ${#cert_map[@]} -eq 0 ]]; then
        terminate "No configured certificates found"
    fi
}

# Function to output a line for a specific folder, coloring RED if mismatched and GREEN if correct
output_folder_check_md5() {
    local folder="$1"
    local check_md5="$2"
    local this_md5
    this_md5=$(md5sum "${folder}/${CERT_FILE}" | awk '{print $1}')

    if [[ "$check_md5" != "$this_md5" ]]; then
        # non-matching file
        echo " - ${RED}${folder}"
        return 1
    else
        # matching file
        echo " - ${GREEN}${folder}"
        return 0
    fi
}

# Function to overwrite a folder's certificates with updated certs. Takes the folder and the CN as inputs
overwrite_certificates() {
    local dest_folder=$1
    if [[ "$NO_OVERWRITE" == "true" ]]; then
        echo "   - Dry Run - not updating $dest_folder"
    else
        local source_folder=$2
        # group all three commands so a failure in ANY of them is caught
        # (a bare `! cp ... && chown ... && chmod ...` only negates cp and skips chown/chmod on success)
        if ! { cp "$source_folder/"{cert,chain,fullchain,privkey}.pem "$dest_folder/" &&
            chown root:root "$dest_folder/"{cert,chain,fullchain,privkey}.pem &&
            chmod 400 "$dest_folder/"{cert,chain,fullchain,privkey}.pem; }; then
            terminate "   - Error with copy, chown, or chmod certificates in $dest_folder"
        fi
    fi
    CHANGES_MADE=true
}

# Function to iterate over the list of folders for a given certCode and CN
check_cert_folders() {
    local certCode="$1"
    local cn="$2"
    local count=0
    local mismatch_count=0
    local user_cert_folder
    local updated_md5

    user_cert_folder="${config_map["$cn"]}"
    updated_md5=$(md5sum "${config_map["$cn"]}/${CERT_FILE}" | awk '{print $1}')

    echo "Checking package cert folders for cert ID: $certCode, CN: $cn..."

    # Check folders under $PKGS_PATH using isPkg == true
    while IFS= read -r pkg_folder; do
        if [[ -d "$PKGS_PATH/$pkg_folder" ]]; then
            ((count++))
            output_folder_check_md5 "$PKGS_PATH/$pkg_folder" "$updated_md5"
            if [[ $? -eq 1 ]]; then
                ((mismatch_count++))
                if [[ "$UPDATE" == "true" ]]; then
                    # the %%/* here will get the top-level Folder (the package name); add each package only once
                    if ! exists_in_array "${pkg_folder%%/*}" "${services_to_restart[@]}"; then
                        services_to_restart+=("${pkg_folder%%/*}")
                    fi
                    overwrite_certificates "${PKGS_PATH}/${pkg_folder}" "$user_cert_folder"
                fi
            fi
        fi
    done < <(jq -r --arg certCode "$certCode" '.[$certCode] | .services[] | select(.isPkg == true) | "\(.subscriber)/\(.service)"' "$INFO_FILE")

    echo " ($count found, $mismatch_count mismatches)"
    echo

    # Reset count and check folders under $CERT_PATH using isPkg == false
    echo "Checking non-package cert folders for cert ID: $certCode, CN: $cn..."
    count=0
    mismatch_count=0

    while IFS= read -r cert_folder; do
        if [[ -d "$CERT_PATH/$cert_folder" ]]; then
            ((count++))
            output_folder_check_md5 "$CERT_PATH/$cert_folder" "$updated_md5"
            if [[ $? -eq 1 ]]; then
                ((mismatch_count++))
                if [[ "$UPDATE" == "true" ]]; then
                    # There's something to restart here, but it's never worked for me on 7.2
                    # Would need to add a 'services to restart' specifically for these kinds of services...
                    overwrite_certificates "${CERT_PATH}/${cert_folder}" "$user_cert_folder"
                fi
            fi
        fi
    done < <( (echo "_archive/$certCode"; jq -r --arg certCode "$certCode" '.[$certCode] | .services[] | select(.isPkg == false) | "\(.subscriber)/\(.service)"' "$INFO_FILE") )

    echo " ($count found, $mismatch_count mismatches)"
    echo
}

# restarts packages needing to be restarted
restart_packages() {
    echo "Finishing up..."
    echo
    if [[ "$UPDATE" == "true" ]]; then
        if [[ "$CHANGES_MADE" == "true" ]]; then

            # I don't think this is actually needed; it will regen Reverse Proxy definitions
            # and since no definitions change, an nginx reload should be all that's needed.
            # gen-all
            if [[ "$NO_OVERWRITE" == "false" ]]; then
                echo "Running \"synow3tool --gen-all\" (can take some time)..."
                if ! /usr/syno/bin/synow3tool --gen-all; then
                    echo "synow3tool --gen-all failed"
                fi
            else
                echo "Running \"synow3tool --gen-all\" (dry run, not executing)..."
                sleep 3
            fi


            # regenerate VPNCenter certs if VPNCenter was updated
            # fixes https://github.com/telnetdoogie/synology-scripts/issues/4
            if exists_in_array "VPNCenter" "${services_to_restart[@]}"; then
                if [[ "$VPN_REGEN" == "true" ]]; then
                    if [[ "$NO_OVERWRITE" == "false" ]]; then
                        echo "VPNCenter certificate regeneration..."
                        /var/packages/VPNCenter/target/hook/CertReload.sh copy_cert_only
                    else
                        echo "VPNCenter certificate regeneration (dry run, no files changed)..."
                        sleep 3
                    fi
                else
                    echo "Skipping VPNCenter certificate regeneration..."
                fi
            fi

            # pending packages
            for pkg in "${services_to_restart[@]}"; do
                if [[ "$NO_OVERWRITE" == "false" ]]; then
                    /usr/syno/bin/synopkg is_onoff "$pkg" 1>/dev/null &&
                    echo "Restarting \"$pkg\"..." &&
                    /usr/syno/bin/synopkg restart "$pkg"
                else
                    echo "Restarting \"$pkg\"... (dry run, not executing)..."
                    sleep 3
                fi
            done

            # reloading nginx
            if [[ "$NO_OVERWRITE" == "false" ]]; then
                echo "Reloading nginx..."
                if ! /usr/syno/bin/synow3tool --nginx=reload; then
                    echo "/usr/syno/bin/synow3tool --nginx=reload failed"
                fi
            else
                echo "Reloading nginx... (dry run, not executing)"
                sleep 3
            fi


            # restart DSM
            if [[ "$NO_OVERWRITE" == "false" ]]; then
                echo "Restarting DSM..."
                if ! /usr/syno/bin/synow3tool --restart-dsm-service; then
                    echo "/usr/syno/bin/synow3tool --restart-dsm-service failed"
                fi
            else
                echo "Restarting DSM... (dry run, not executing)"
                sleep 3
            fi

        fi
    else
        echo "No changes made. Run with --update to make changes."
    fi
}

# Actually check certificates to be checked
check_certificates() {
    # For each CN to check, iterate folders and check certs
    for certCode in "${!cert_map[@]}"; do
        cn="${cert_map[$certCode]}"

        if exists_in_array "$cn" "${check_cns[@]}"; then
            check_cert_folders "$certCode" "$cn"
        fi
    done
}

#######################################################################################
# Main flow of the program below
show_title
check_root_privileges
check_parameters "$@"
check_installed_certs

# Check if the configuration file exists and act accordingly
if [[ ! -f "$CONFIG_FILE" ]]; then
    generate_config_file
fi

# Read the config file, build check_cns array for certs to check.
read_config_file
if [[ ${#check_cns[@]} -eq 0 ]]; then
    terminate "Done... No Certificates to Check / Update."
fi

#i Check Certificates
echo "Checking for mismatched certificates..."
check_certificates
echo

# If changes were made, recheck certs
if [[ "$CHANGES_MADE" == "true" ]]; then
    UPDATE=false
    echo "##################################################################"
    if [[ "$NO_OVERWRITE" == "true" ]]; then
        echo "Dry run... re-checking certs... nothing was changed, so mismatches remain ${RED}"
    else
        echo "Changes were made... re-checking certs... All below should show ${GREEN}"
    fi
    echo "##################################################################"
    echo
    check_certificates
    UPDATE=true
fi

# Restart packages if necessary
restart_packages

# All done
terminate "Finished\n  " 0
