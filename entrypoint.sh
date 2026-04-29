#!/bin/sh

# start all sigma backend instances in the background
cd backend/ && ./launch-backends.sh && cd ..

# serve static files and proxy API calls via nginx (foreground, keeps container alive)
nginx -g "daemon off;"
