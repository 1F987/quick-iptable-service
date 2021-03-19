Source : https://sleeplessbeastie.eu/2018/10/01/how-to-make-iptables-configuration-persistent-using-systemd/

### Script install

```
mv fw.sh /sbin/fw.sh
chown root:root /sbin/fw.sh
chmod 750 /sbin/fw.sh
```

### systemd services


#### production service

```
nano /etc/systemd/system/firewall-custom.service
```

Content : 

```
[Unit]
Description=Firewall custom service
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/fw.sh start
RemainAfterExit=true
ExecStop=/sbin/fw.sh stop
StandardOutput=journal

[Install]
WantedBy=multi-user.target
```

#### test service

```
nano /etc/systemd/system/firewall-test-custom.service
```

Content : 

```
[Unit]
Description=Firewall custom test
BindsTo=firewall-custom.service
After=firewall-custom.service

[Service]
Type=oneshot
ExecStart=/usr/bin/systemd-run --on-active=180 --timer-property=AccuracySec=1s /bin/systemctl stop firewall-custom.service
StandardOutput=journal

[Install]
WantedBy=multi-user.target
```

Restart the daemon to load the new configuration

```
systemctl daemon-reload
```

Test your rules for 3 minutes

```
systemctl start firewall-test-custom.service
systemctl status firewall-custom.service
/sbin/fw.sh status
```

Put your rules in production

```
# Start at boot
systemctl enable firewall-custom.service
systemctl start firewall-custom.service
```
