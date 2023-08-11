# SSH Intrusion Detection and Reporting Script

This Bash script is designed to identify suspicious IP addresses that have attempted to log into a system via SSH (Secure Shell) and report this information to an API endpoint. It serves as a part of a security monitoring solution.

## How It Works

1. Configuration data is loaded from the `config_report.txt` file located in the same directory as the script using the following command:
   ```bash
   source "$(dirname "${BASH_SOURCE[0]}")/config_report.txt"


## Reporting Function

The `report_ip_list()` function takes JSON data containing information about blocked IP addresses and sends this data to an API endpoint (`https://ipv64.net/api`) using the `curl` command. It requires an API key (`$API_KEY`) and a blocker ID (`$BLOCKER_ID`), both of which are sourced from the loaded configuration file.

## Extracting and Reporting IPs

The `extract_ips_from_ssh_log()` function is responsible for extracting suspicious IP addresses from SSH log data and preparing them in a JSON format for reporting to the API endpoint.

1. First, a timestamp is calculated for one hour ago (`ONE_HOUR_AGO`).

2. Then, using the `awk` command, IP addresses are extracted from the specified SSH log file (`$LOG_FILE`) that had failed login attempts in the last hour. These IP addresses are collected, sorted, and deduplicated.

3. For each suspicious IP address, it checks if it has already been reported in the `REPORTED_IPS_FILE` or if the report has expired. If not reported or expired, the IP address is added to the temporary list of IP addresses (`TEMP_IP_LIST`), and a new report entry with expiration time is added to the `REPORTED_IPS_FILE`.

4. Finally, the suspicious IP addresses are prepared in a JSON format and passed to the `report_ip_list()` function for reporting to the API endpoint, if there are any suspicious IP addresses.

## Setting Up Cron Job for Regular Execution

To regularly execute this script and monitor for suspicious SSH login attempts, you can set up a cron job. Open your terminal and enter the following command to edit your crontab:

```bash
crontab -e
*/30 * * * * /bin/bash /report.sh





