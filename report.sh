#!/bin/bash

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

# Extract IPs from the last hour of the SSH log file and create JSON data
extract_ips_from_ssh_log() {
    local LOG_FILE="$1"
    local SUSPICIOUS_IPS=()
    local TEMP_IP_LIST=()

    # Calculate the timestamp for one hour ago
    ONE_HOUR_AGO=$(date -d '1 hour ago' +'%Y-%m-%dT%H:%M:%S')

    # Use awk to extract IPs from the log file
    SUSPICIOUS_IPS=($(awk -v one_hour_ago="$ONE_HOUR_AGO" '$1" "$2 >= one_hour_ago && /Failed password/ { for (i=1; i<=NF; i++) { if ($i == "from" && $(i-1) != "Invalid") { print $(i+1) } } }' "$LOG_FILE" | sort | uniq))

    # Current timestamp
    CURRENT_TIMESTAMP=$(date +%s)

    # Check for duplicates and add IPs to the temporary list
    for IP in "${SUSPICIOUS_IPS[@]}"; do
        if ! [[ " ${TEMP_IP_LIST[*]} " =~ " $IP " ]]; then
            # Check if IP is not in reported_ips file or expired
            IP_EXPIRATION=$(grep "^$IP " "$REPORTED_IPS_FILE" | cut -d ' ' -f 2)
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
}

# Example: Extract and report IPs from the last hour of the SSH log
extract_ips_from_ssh_log "$SSH_LOG_FILE"
