#!/bin/bash

# https://github.com/dominictarr/JSON.sh
source /etc/sensu/handlers/JSON.sh

read sensu_event

json=$(echo $sensu_event | tokenize | parse)

value=$(echo "$json" | awk -F '"' '/^\["check","output"\]/ { print $6 }')

echo "$value" >> /var/log/sensutest.log
