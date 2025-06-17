#!/bin/sh

# Substitute environment variables into the Nginx config template
# and output the result to the actual Nginx config file.
# This ensures that the GKE_BACKEND_IP environment variable
# passed at Docker run time, is used in the Nginx configuration.
envsubst '$GKE_BACKEND_IP' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

# Execute the original command passed to the entrypoint (e.g "nginx -g 'daemon off;'")
# This ensures Nginx starts correctly after the config is updated.
exec "$@"
