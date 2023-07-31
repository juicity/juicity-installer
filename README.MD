# An Installer For Juicity

## Installation

Install with curl:

```sh
sudo sh -c "$(curl -sL https://github.com/juicity/juicity-installer/raw/master/installer.sh)"
```

Install with wget:

```sh
sudo sh -c "$(wget -qO- https://github.com/juicity/juicity-installer/raw/master/installer.sh)"
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
