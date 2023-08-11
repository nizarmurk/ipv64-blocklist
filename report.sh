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
    local TEMP_REPORTED_IPS_FILE="/tmp/reported_ips.txt"
    local TEMP_IP_LIST=()

    # Calculate the timestamp for one hour ago
    ONE_HOUR_AGO=$(date -d '1 hour ago' +'%b %d %H:%M:%S')

    # Use awk to extract suspicious entries from the log file and extract IPs
    awk -v one_hour_ago="$ONE_HOUR_AGO" '
        $1" "$2 >= one_hour_ago && (/Failed password/ || /Failed password for invalid user/) {
            match($0, /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/, ip)
            if (ip[0] != "") {
                print ip[0]
            }
        }
    ' "$LOG_FILE" | sort | uniq > "$TEMP_REPORTED_IPS_FILE"

    # Only report if there are suspicious IPs to report
    if [ -s "$TEMP_REPORTED_IPS_FILE" ]; then
        local JSON_DATA='{"ip_list":['
        local FIRST_ENTRY=true

        while read -r IP; do
            # Check if IP is not in reported_ips file or expired
            IP_EXPIRATION=$(grep "^$IP " "$REPORTED_IPS_FILE" | cut -d ' ' -f 2)
            CURRENT_TIMESTAMP=$(date +%s)
            if [ -z "$IP_EXPIRATION" ] || [ "$CURRENT_TIMESTAMP" -gt "$IP_EXPIRATION" ]; then
                if [ "$FIRST_ENTRY" = true ]; then
                    FIRST_ENTRY=false
                else
                    JSON_DATA+=','
                fi
                JSON_DATA+="{\"ip\":\"$IP\",\"category\":\"1\",\"info\":\"Failed login attempts detected\",\"port\":\"$SSH_PORT\"}"

                # Add IP and expiration time to reported_ips file (4 hours from now)
                EXPIRATION_TIME=$((CURRENT_TIMESTAMP + 4 * 3600))  # 4 hours in seconds
                echo "$IP $EXPIRATION_TIME" >> "$REPORTED_IPS_FILE"
            fi
        done < "$TEMP_REPORTED_IPS_FILE"

        JSON_DATA+=']}'

        # Report all suspicious IPs in a single API request
        report_ip_list "$JSON_DATA"
    fi

    # Clean up temporary file
    rm "$TEMP_REPORTED_IPS_FILE"
}

# Example: Extract, validate, and report IPs from the last hour of the SSH log
extract_ips_from_ssh_log "$SSH_LOG_FILE"
