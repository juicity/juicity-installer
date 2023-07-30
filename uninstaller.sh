#!/bin/sh

if command -v systemctl > /dev/null 2>&1; then
    systemctl stop juicity-server 2> /dev/null
    systemctl stop juicity-client 2> /dev/null
    rm -f /etc/systemd/system/juicity-server.service 2> /dev/null
    rm -f /etc/systemd/system/juicity-client.service 2> /dev/null
    systemctl daemon-reload
elif [ -f /sbin/openrc-run ]; then
    rc-service juicity-server stop 2> /dev/null
    rc-service juicity-client stop 2> /dev/null
    rm -f /etc/init.d/juicity-server 2> /dev/null
    rm -f /etc/init.d/juicity-client 2> /dev/null
fi

rm -f /usr/local/bin/juicity-server 2> /dev/null
rm -f /usr/local/bin/juicity-client 2> /dev/null

echo "Juicity uninstalled, but config dir /usr/local/etc/juicity/ is still there."
echo "If you want to remove it, run:"
echo "    rm -rf /usr/local/etc/juicity/"