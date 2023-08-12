#!/bin/bash

config_file="/etc/rsyslog.conf"  # Adjust the path to the configuration file

# Variable to track whether changes were made
changes_made=false

# Check if the template is already set
if grep -qF '$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat' "$config_file"; then
    echo "Template is set to RSYSLOG_TraditionalFileFormat."

    # Remove the old line from the configuration file
    sudo sed -i '/$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat/d' "$config_file"
    echo "Removed the old template."
    changes_made=true

    # Add the new template if not already present
    if ! grep -qF '$ActionFileDefaultTemplate RSYSLOG_FileFormat' "$config_file"; then
        echo '$ActionFileDefaultTemplate RSYSLOG_FileFormat' | sudo tee -a "$config_file" > /dev/null
        echo "Template RSYSLOG_FileFormat added."
        changes_made=true
    fi
else
    # Add the new template if not set to RSYSLOG_TraditionalFileFormat
    if ! grep -qF '$ActionFileDefaultTemplate RSYSLOG_FileFormat' "$config_file"; then
        echo '$ActionFileDefaultTemplate RSYSLOG_FileFormat' | sudo tee -a "$config_file" > /dev/null
        echo "Template RSYSLOG_FileFormat added."
        changes_made=true
    fi
fi

# Only perform the following actions if changes were made
if [ "$changes_made" = true ]; then
    # Restart the rsyslog service
    sudo systemctl restart rsyslog
    echo "rsyslog service restarted."

    # Back up the auth.log
    sudo cp "$SSH_LOG_FILE" /var/log/auth.log.backup

    # Clear the auth.log
    sudo sh -c '> $SSH_LOG_FILE'
    echo ""$SSH_LOG_FILE" backed up and cleared."
fi

# Load configuration from config_report.txt
source "$(dirname "${BASH_SOURCE[0]}")/config_report.txt"

# Function to report a list of poisoned IPs
report_ip_list() {
    local JSON_DATA="$1"

    curl -X POST -H "Authorization: Bearer $API_KEY" \
         -d "blocker_id=$BLOCKER_ID" \
         -d "report_ip_list=$JSON_DATA" \
         "https://ipv64.net/api"
}

# Remove expired IPs from REPORTED_IPS_FILE
CURRENT_TIMESTAMP=$(date +%s)
TEMP_REPORTED_IPS_FILE="/var/log/reported_ips_temp.txt"
touch "$TEMP_REPORTED_IPS_FILE"  # Create the temporary file if it doesn't exist
while read -r line; do
    IP=$(echo "$line" | cut -d ' ' -f 1)
    EXPIRATION_TIME=$(echo "$line" | cut -d ' ' -f 2)
    if [ "$CURRENT_TIMESTAMP" -le "$EXPIRATION_TIME" ]; then
        echo "$line" >> "$TEMP_REPORTED_IPS_FILE"
    fi
done < "$REPORTED_IPS_FILE"
sudo mv "$TEMP_REPORTED_IPS_FILE" "$REPORTED_IPS_FILE"

# Extract IPs from the last hour of the SSH log file and create JSON data
extract_ips_from_ssh_log() {
    local LOG_FILE="$1"
    local SUSPICIOUS_IPS=()
    local TEMP_IP_LIST=()

    # Calculate the timestamp for one hour ago
    ONE_HOUR_AGO=$(date -d '1 hour ago' +'%Y-%m-%dT%H:%M:%S')

    # Use awk to extract IPs from the log file
    SUSPICIOUS_IPS=($(awk -v one_hour_ago="$ONE_HOUR_AGO" '$1" "$2 >= one_hour_ago && /Failed password/ { for (i=1; i<=NF; i++) { if ($i == "from" && $(i-1) != "Invalid") { print $(i+1) } } }' "$LOG_FILE" | sort | uniq))

    # Check for duplicates and add IPs to the temporary list
    for IP in "${SUSPICIOUS_IPS[@]}"; do
        if ! [[ " ${TEMP_IP_LIST[*]} " =~ " $IP " ]]; then
            # Check if IP is not in reported_ips file or expired
            IP_EXPIRATION=$(grep "^$IP " "$REPORTED_IPS_FILE" | cut -d ' ' -f 2)
            if [ -z "$IP_EXPIRATION" ] || [ "$CURRENT_TIMESTAMP" -gt "$IP_EXPIRATION" ]; then
                TEMP_IP_LIST+=("$IP")

                # Add IP and expiration time to reported_ips file (4 hours from now)
                EXPIRATION_TIME=$((CURRENT_TIMESTAMP + 4 * 3600))  # 4 hours in seconds
                echo "$IP $EXPIRATION_TIME" >> "$REPORTED_IPS_FILE"
            fi
        fi
    done

    # Only report if there are suspicious IPs to report
    if [ ${#TEMP_IP_LIST[@]} -gt 0 ]; then
        local JSON_DATA='{"ip_list":['
        local FIRST_ENTRY=true

        for IP in "${TEMP_IP_LIST[@]}"; do
            if [ "$FIRST_ENTRY" = true ]; then
                FIRST_ENTRY=false
            else
                JSON_DATA+=','
            fi
            JSON_DATA+="{\"ip\":\"$IP\",\"category\":\"1\",\"info\":\"Failed login attempts detected\",\"port\":\"$SSH_PORT\"}"
        done

        JSON_DATA+=']}'

        # Report all suspicious IPs in a single API request
        report_ip_list "$JSON_DATA"
    fi
}

# Example: Extract and report IPs from the last hour of the SSH log
extract_ips_from_ssh_log "$SSH_LOG_FILE"
