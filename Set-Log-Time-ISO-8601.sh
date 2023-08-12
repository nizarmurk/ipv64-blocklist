#!/bin/bash

config_file="/etc/rsyslog.conf"  # Adjust the path to the configuration file

# Check if the template is already set
if grep -qF '$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat' "$config_file"; then
    echo "Template is set to RSYSLOG_TraditionalFileFormat."

    # Remove the old line from the configuration file
    sudo sed -i '/$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat/d' "$config_file"
    echo "Removed the old template."

    # Add the new template if not already present
    if ! grep -qF '$ActionFileDefaultTemplate RSYSLOG_FileFormat' "$config_file"; then
        echo '$ActionFileDefaultTemplate RSYSLOG_FileFormat' | sudo tee -a "$config_file" > /dev/null
        echo "Template added."
    else
        echo "Template RSYSLOG_FileFormat already set. No changes needed."
    fi

    # Restart the rsyslog service
    sudo systemctl restart rsyslog
    echo "rsyslog service restarted."

    # Back up the auth.log after the restart
    sudo cp /var/log/auth.log /var/log/auth.log.backup

    # Clear the auth.log
    sudo sh -c '> /var/log/auth.log'
    echo "auth.log backed up and cleared."
else
    echo "Template is not set to RSYSLOG_TraditionalFileFormat. No changes needed."
fi
