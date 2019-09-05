#!/bin/sh

mv /tmp/after.local  /etc/init.d
mv /tmp/before.local /etc/init.d
chmod 755 /etc/init.d/after.local
chmod 755 /etc/init.d/before.local
chown root:root /etc/init.d/after.local
chown root:root /etc/init.d/before.local
