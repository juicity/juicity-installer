# An Installer For Juicity

## Installation

### Go version

Install with curl:

```sh
sudo sh -c "$(curl -sL https://github.com/juicity/juicity-installer/raw/master/installer.sh)"
```

Install with wget:

```sh
sudo sh -c "$(wget -qO- https://github.com/juicity/juicity-installer/raw/master/installer.sh)"
```

### Rust version

Install with curl:

```sh
sudo sh -c "$(curl -sL https://github.com/juicity/juicity-installer/raw/master/installer-rs.sh)"
```

Install with wget:

```sh
sudo sh -c "$(wget -qO- https://github.com/juicity/juicity-installer/raw/master/installer-rs.sh)"
```

## Uninstallation

Remove with curl:

```sh
sudo sh -c "$(curl -sL https://github.com/juicity/juicity-installer/raw/master/uninstaller.sh)"
```

Remove with wget:

```sh
sudo sh -c "$(wget -qO- https://github.com/juicity/juicity-installer/raw/master/uninstaller.sh)"
```

## Services

### Systemd

See [Systemd](https://github.com/juicity/juicity-installer/tree/master/systemd)

### OpenRC

See [OpenRC](https://github.com/juicity/juicity-installer/tree/master/OpenRC)

### Launchd (macOS)

See [Launchd](https://github.com/juicity/juicity-installer/tree/master/launchd)

Put plists to `~/Library/LaunchAgents/` for current user, or `/Library/LaunchAgents/` for all users, start a launchd service like this:

```sh
launchctl load ~/Library/LaunchAgents/juicity-server.plist
```

## Server SSL Certificate

We run all our services with user `nobody`, so we need to make sure that the server certificate is readable by user `nobody`. For example, if you get your SSL certificate from Let's Encrypt by using Certbot, you can run the following command to make sure that the certificate is readable by user `nobody`:

```sh
sudo setfacl -R -m u:nobody:rX /etc/letsencrypt/{live,archive}
sudo setfacl -m u:nobody:rX /etc/letsencrypt
```

Then add a cerbot hook to make sure that the ACL is set after the certificate is renewed:

```sh
sudo certbot renew --deploy-hook "setfacl -R -m u:nobody:rX /etc/letsencrypt/{live,archive}"
```