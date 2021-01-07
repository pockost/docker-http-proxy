#!/bin/bash

export HTTP_PORT=${HTTP_PORT:-80}
export MODE=${MODE:-redirect}

export REDIRECT=${REDIRECT:-https://www.pockost.com}
export REDIRECT_TYPE=${REDIRECT_TYPE:-permanent}
export KEEP_PATH=${KEEP_PATH:-false}

export PROXY_HOST=${PROXY_HOST:-www.pockost.com}
export PROXY_PORT=${PROXY_PORT:-443}

export EVENTS_CONFIG="[worker_connections]=1024"
declare -A EVENTS_CONFIG="($EVENTS_CONFIG)"

export SERVER_CONFIG="[worker_connections]=1024"
declare -A SERVER_CONFIG="($EVENTS_CONFIG)"

export SERVER_LOCATION_CONFIG="[worker_connections]=1024"
declare -A SERVER_LOCATION_CONFIG="($EVENTS_CONFIG)"
 
export CONFIG_FILE=${CONFIG_FILE:-/etc/nginx/redirect.conf}

cat <<EOF > $CONFIG_FILE
user root;
daemon off;

EOF

##########
# Events #
##########
if [ ${EVENTS_CONFIG[@]} ]; then

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

############
# Upstream #
############
if [ $MODE = "proxy" ]; then

  cat <<EOF >> $CONFIG_FILE
    upstream $PROXY_HOST {
        server $PROXY_HOST:$PROXY_PORT;
    }

EOF

fi

##########
# Server #
##########
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

if [ $MODE = "redirect" ]; then

  if $KEEP_PATH -eq true; then
    REDIRECT="$REDIRECT\$1"
  fi

  cat <<EOF >> $CONFIG_FILE
            rewrite ^(.*) $REDIRECT $REDIRECT_TYPE;
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
