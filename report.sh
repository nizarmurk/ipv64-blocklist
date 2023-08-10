#!/bin/bash

# Set your API key/token and Blocker ID here
API_KEY=""
BLOCKER_ID=""

# SSH log file path
SSH_LOG_FILE="/var/log/auth.log"
# Set your SSH port here
SSH_PORT="22"

# File to store reported IPs and their expiration times
REPORTED_IPS_FILE="/var/log/reported_ips.txt"

# Function to report a list of poisoned IPs
report_ip_list() {
    local JSON_DATA="$1"

    curl -X POST -H "Authorization: Bearer $API_KEY" \
         -d "blocker_id=$BLOCKER_ID" \
         -d "report_ip_list=$JSON_DATA" \
         "https://ipv64.net/api"
}

# Ensure REPORTED_IPS_FILE exists or create it
if [ ! -f "$REPORTED_IPS_FILE" ]; then
    touch "$REPORTED_IPS_FILE"
fi

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
mv "$TEMP_REPORTED_IPS_FILE" "$REPORTED_IPS_FILE"

# Extract IPs from the SSH log file and create JSON data
extract_ips_from_ssh_log() {
    local LOG_FILE="$1"
    local SUSPICIOUS_IPS=()
    local TEMP_IP_LIST=()

    # Current timestamp
    CURRENT_TIMESTAMP=$(date +%s)

    # Use awk to extract IPs from the log file
    SUSPICIOUS_IPS=($(awk '/Failed password/ { print $(NF-3) }' "$LOG_FILE" | sort | uniq))

    # Check for duplicates and add IPs to the temporary list
    for IP in "${SUSPICIOUS_IPS[@]}"; do
        if ! [[ " ${TEMP_IP_LIST[*]} " =~ " $IP " ]]; then
            # Check if IP is not in reported_ips file or expired
            IP_EXPIRATION=$(grep "$IP" "$REPORTED_IPS_FILE" | cut -d ' ' -f 2)
            if [[ -z "$IP_EXPIRATION" || "$CURRENT_TIMESTAMP" -gt "$IP_EXPIRATION" ]]; then
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

    # Clear the content of the log file if there are suspicious IPs to report
    if [ ${#TEMP_IP_LIST[@]} -gt 0 ]; then
        > "$LOG_FILE"
    fi
}

# Example: Extract and report IPs from the SSH log and then clear the log file
extract_ips_from_ssh_log "$SSH_LOG_FILE"
