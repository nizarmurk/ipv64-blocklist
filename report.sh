# Set your API key/token and Blocker ID here
API_KEY=""
BLOCKER_ID=""
SSH_PORT="22" # If another SSH port is used, adjust it individually here.

# Function to report a list of poisoned IPs
report_ip_list() {
    local JSON_DATA="$1"

    curl -X POST -H "Authorization: Bearer $API_KEY" \
         -d "blocker_id=$BLOCKER_ID" \
         -d "report_ip_list=$JSON_DATA" \
         "https://ipv64.net/api"
}

# SSH log file path
SSH_LOG_FILE="/var/log/auth.log"

# Extract IPs from the SSH log file and create JSON data
extract_ips_from_ssh_log() {
    local LOG_FILE="$1"
    local SUSPICIOUS_IPS=()
    local TEMP_IP_LIST=()
    
    # Use awk to extract IPs from the log file
    SUSPICIOUS_IPS=($(awk '/Failed password/ { print $(NF-3) }' "$LOG_FILE" | sort | uniq))
    
    # Check for duplicates and add IPs to the temporary list
    for IP in "${SUSPICIOUS_IPS[@]}"; do
        if ! [[ " ${TEMP_IP_LIST[*]} " =~ " $IP " ]]; then
            TEMP_IP_LIST+=("$IP")
        fi
    done
    
    # Create JSON data for the report_ip_list function
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

    # Clear the content of the log file
    > "$LOG_FILE"
}

# Example: Extract and report IPs from the SSH log and then clear the log file
extract_ips_from_ssh_log "$SSH_LOG_FILE"
