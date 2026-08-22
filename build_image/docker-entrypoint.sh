#!/bin/sh
set -eu

# Volume mounts on /root/.acme.sh hide the image copy. Seed it on first start.
if [ ! -x /root/.acme.sh/acme.sh ]; then
	mkdir -p /root/.acme.sh
	(cd /opt/acme.sh && ./acme.sh --install --home /root/.acme.sh --nocron >/dev/null)
fi
ln -sfn /root/.acme.sh/acme.sh /usr/bin/acme.sh

# Cron is lost when the container is recreated; re-register and start crond.
if [ -x /root/.acme.sh/acme.sh ]; then
	/root/.acme.sh/acme.sh --install-cronjob >/dev/null 2>&1 || true
	crond
fi

exec "$@"
