#!/bin/bash

config_file="/etc/rsyslog.conf"  # LOG

if grep -qF '$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat' "$config_file"; then
    sudo sed -i '/$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat/d' "$config_file"
    echo "Removed the old template."
fi

if grep -qF '$ActionFileDefaultTemplate RSYSLOG_FileFormat' "$config_file"; then
    echo "Template already set. No changes needed."
else
    echo '$ActionFileDefaultTemplate RSYSLOG_FileFormat' | sudo tee -a "$config_file" > /dev/null
    echo "Template added."
fi

sudo systemctl restart rsyslog
echo "rsyslog service restarted."
