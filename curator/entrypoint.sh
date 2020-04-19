#!/bin/sh

echo "$CRON /usr/bin/curator  --config ${CONFIG_FILE} ${ACTION_FILE}" >>/etc/crontabs/root

# https://github.com/krallin/tini/blob/master/README.md#subreaping
tini -s -- crond -f -d 8 -l 8