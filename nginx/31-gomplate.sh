# !/bin/bash

FILE=/usr/share/nginx/html/assets/config.json
if [ ! -f "$FILE" ]; then
    gomplate -f /config.json.template -o /usr/share/nginx/html/assets/config.json
    echo "Configuration with env vars done."
else
    echo "config.json file found. Skipping configuration with env vars."
fi