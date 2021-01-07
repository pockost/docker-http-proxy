#!/bin/bash

export HTTP_PORT=${HTTP_PORT:-80}
export MODE=${MODE:-redirect}

export REDIRECT_URL=${REDIRECT_URL:-https://www.pockost.com}
export REDIRECT_TYPE=${REDIRECT_TYPE:-permanent}
export REDIRECT_KEEP_PATH=${REDIRECT_KEEP_PATH:-false}

export PROXY_HOST=${PROXY_HOST:-www.pockost.com}
export PROXY_PORT=${PROXY_PORT:-443}

export EVENTS_CONFIG=${EVENTS_CONFIG:-"[worker_connections]=1024"}
declare -A EVENTS_CONFIG="($EVENTS_CONFIG)"

export SERVER_CONFIG=${SERVER_CONFIG:-"[server_tokens]=off"}
declare -A SERVER_CONFIG="($SERVER_CONFIG)"

export SERVER_LOCATION_CONFIG=${SERVER_LOCATION_CONFIG}
declare -A SERVER_LOCATION_CONFIG="($SERVER_LOCATION_CONFIG)"

export CONFIG_FILE=${CONFIG_FILE:-/etc/nginx/redirect.conf}
export HTPASSWD_FILE=${HTPASSWD_FILE:-/etc/nginx/.htpasswd}

cat <<EOF > $CONFIG_FILE
user root;
daemon off;

EOF

if [ "${#EVENTS_CONFIG[@]}" -ne 0 ]; then

  cat <<EOF >> $CONFIG_FILE
events {
EOF

  for i in "${!EVENTS_CONFIG[@]}"
  do
    cat <<EOF >> $CONFIG_FILE
    $i ${EVENTS_CONFIG[$i]};
EOF
  done

  cat <<EOF >> $CONFIG_FILE
}

EOF

fi

cat <<EOF >> $CONFIG_FILE
http {
EOF

if [ $MODE = "proxy" ]; then

  cat <<EOF >> $CONFIG_FILE
    upstream $PROXY_HOST {
        server $PROXY_HOST:$PROXY_PORT;
    }

EOF

fi

cat <<EOF >> $CONFIG_FILE
    server {
        listen $HTTP_PORT;
EOF

for i in "${!SERVER_CONFIG[@]}"
do
  cat <<EOF >> $CONFIG_FILE
        $i ${SERVER_CONFIG[$i]};
EOF
done

cat <<EOF >> $CONFIG_FILE

        location / {
EOF

if [ "${#SERVER_LOCATION_CONFIG[@]}" -ne 0 ]; then

  for i in "${!SERVER_LOCATION_CONFIG[@]}"
  do
    cat <<EOF >> $CONFIG_FILE
            $i ${SERVER_LOCATION_CONFIG[$i]};
EOF
  done

  cat <<EOF >> $CONFIG_FILE

EOF

fi

if [ $MODE = "redirect" ]; then

  if $REDIRECT_KEEP_PATH -eq true; then
    REDIRECT_URL="$REDIRECT_URL\$1"
  fi

  cat <<EOF >> $CONFIG_FILE
            rewrite ^(.*) $REDIRECT_URL $REDIRECT_TYPE;
EOF

elif [ $MODE = "proxy" ]; then

  if [ $PROXY_PORT = 443 ]; then PROXY_PASS_SCHEMA="https"; else PROXY_PASS_SCHEMA="http"; fi

  cat <<EOF >> $CONFIG_FILE
            proxy_pass $PROXY_PASS_SCHEMA://$PROXY_HOST;
            proxy_set_header Host \$host;
EOF

fi

cat <<EOF >> $CONFIG_FILE
        }
    }
}

EOF

exec nginx -c $CONFIG_FILE
