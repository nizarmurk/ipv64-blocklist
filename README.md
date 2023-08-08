# IPv64-blocklist
Parser for IPv64-blocklist

Add your API key and the BlockerID.

Add cron for hourly run -> crontab -e -> 0 * * * * bash /report.sh >/dev/null 2>&1 
(With this cron, the script is located in the root directory.)

IMPORTANT: 
After running this script, the file "/var/log/auth.log" is emptied. 


