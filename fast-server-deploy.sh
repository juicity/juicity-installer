#!/usr/bin/env sh

## Color
echo_red() {
  printf '\033[31m%s\033[0m\n' "$*"
}
echo_red_bold() {
  printf "\033[1;31m%s\033[0m\n" "$1"
}
echo_yellow() {
  printf '\033[33m%s\033[0m\n' "$*"
}
echo_yellow_bold() {
  printf "\033[1;33m%s\033[0m\n" "$1"
}
echo_green() {
  printf '\033[32m%s\033[0m\n' "$*"
}
echo_green_bold() {
  printf "\033[1;32m%s\033[0m\n" "$1"
}

show_notice () {
    echo_yellow_bold '------------------------------------------'
    echo_yellow_bold '------------------NOTICE------------------'
    echo_yellow_bold '------------------------------------------'
    echo_yellow "This script will install certbot and nginx"
    echo_yellow "for you, if you don't want those software,"
    echo_yellow "exit this script and deploy juicity server"
    echo_yellow "by yourself."
}

## Check OS
check_os_package_manager() {
    for package_manager in apt yum dnf pacman zypper apk; do
        if command -v "$package_manager" >/dev/null 2>&1; then
            echo_green "Found $package_manager as package manager."
            PACKAGE_MANAGER=$package_manager
            return 0
        fi
    done
    if [ -z "$PACKAGE_MANAGER" ]; then
        echo_red "No supported package manager found."
        exit 1
    fi
}

check_os_release() {
    if [ -f /etc/os-release ]; then
        OS_RELEASE="$(grep NAME < /etc/os-release)"
        echo_green "Found $OS_RELEASE"
    else
        echo_red "Cannot determine OS release."
        exit 1
    fi
}

## Define the package needed
## Actually, we only need certbot and nginx, but we
## also install curl and unzip for convenience
define_packages() {
    case "$PACKAGE_MANAGER" in
        apt)
            PACKAGES="nginx certbot python3-certbot-nginx curl unzip jq jo"
            INSTALL_CMD="apt update && apt install -y $PACKAGES"
            ;;
        dnf)
            PACKAGES="nginx certbot python3-certbot-nginx curl unzip jq jo"
            INSTALL_CMD="dnf install -y $PACKAGES"
            ;;
        yum)
            PACKAGES="nginx certbot python3-certbot-nginx curl unzip jq jo"
            INSTALL_CMD="yum install -y $PACKAGES"
            ;;
        pacman)
            PACKAGES="nginx certbot python-certbot-nginx curl unzip jq jo"
            INSTALL_CMD="pacman -Sy --noconfirm $PACKAGES"
            ;;
        zypper)
            PACKAGES="nginx certbot python3-certbot-nginx curl unzip jq jo"
            INSTALL_CMD="zypper --non-interactive install $PACKAGES"
            ;;
        apk)
            PACKAGES="nginx certbot py3-certbot-nginx curl unzip jq jo"
            INSTALL_CMD="apk add $PACKAGES"
            ;;
        *)
            echo_red "Unsupported package manager: $PACKAGE_MANAGER"
            exit 1
            ;;
    esac
}

## Ask domain and email
ask_domain_email() {
    while true; do
        echo_yellow "Enter your domain:"
        read -r DOMAIN
        echo_yellow "Your domain is: $DOMAIN"
        echo_yellow "Confirm? (y/n)"
        read -r confirm
        case "$confirm" in
            y|Y) break ;;
            *) echo_yellow "Please re-enter." ;;
        esac
    done

    while true; do
        echo_yellow "Enter your email:"
        read -r EMAIL
        echo_yellow "Your email is: $EMAIL"
        echo_yellow "Confirm? (y/n)"
        read -r confirm
        case "$confirm" in
            y|Y) break ;;
            *) echo_yellow "Please re-enter." ;;
        esac
    done
}

## Nginx Config
set_nginx_config() {
    for dir in /etc/nginx/conf.d /etc/nginx/http.d /etc/nginx/sites-available /etc/nginx/vhosts.d; do
        if [ -d "$dir" ]; then
            NGINX_CONF_DIR="$dir"
            break
        fi
    done

    if [ -z "$NGINX_CONF_DIR" ]; then
        NGINX_CONF_DIR="/etc/nginx/conf.d"
        mkdir -p "$NGINX_CONF_DIR"
    fi

    cat > "$NGINX_CONF_DIR/$DOMAIN.conf" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        return 404;
    }
}
EOF

    echo_green "Nginx config created at $NGINX_CONF_DIR/$DOMAIN.conf"
}

## Ask juicity config path and create config
ask_juicity_config_path() {
    DEFAULT_CONFIG_PATH="/usr/local/etc/juicity/server.json"

    while true; do
        echo_yellow "Enter juicity server config path [$DEFAULT_CONFIG_PATH]:"
        read -r CONFIG_PATH
        CONFIG_PATH="${CONFIG_PATH:-$DEFAULT_CONFIG_PATH}"

        # Validate the path ends with .json
        case "$CONFIG_PATH" in
            *.json) ;;
            *)
                echo_red "error: Config path must end with .json"
                continue
                ;;
        esac

        # Ensure parent directory exists
        CONFIG_DIR="$(dirname "$CONFIG_PATH")"
        if [ ! -d "$CONFIG_DIR" ]; then
            echo_yellow "Directory $CONFIG_DIR does not exist. Create it? (y/n)"
            read -r confirm
            case "$confirm" in
                y|Y)
                    mkdir -p "$CONFIG_DIR" || {
                        echo_red "error: Failed to create directory $CONFIG_DIR"
                        continue
                    }
                    ;;
                *)
                    echo_yellow "Please provide a different path."
                    continue
                    ;;
            esac
        fi

        # Check write permission
        if [ ! -w "$CONFIG_DIR" ]; then
            echo_red "error: No write permission to $CONFIG_DIR"
            continue
        fi

        echo_yellow "Config path: $CONFIG_PATH"
        echo_yellow "Confirm? (y/n)"
        read -r confirm
        case "$confirm" in
            y|Y) break ;;
            *) echo_yellow "Please re-enter." ;;
        esac
    done

    # Collect config values
    echo_yellow "Enter listen address (e.g. 0.0.0.0:443):"
    read -r LISTEN_ADDR
    echo_yellow "Enter certificate file path:"
    read -r CERT_PATH
    echo_yellow "Enter key file path:"
    read -r KEY_PATH
    echo_yellow "Enter UUID:"
    read -r UUID
    echo_yellow "Enter password:"
    read -r PASSWORD

    # Create JSON config using jo
    jo -p \
        listen="$LISTEN_ADDR" \
        users="$(jo "$UUID"="$PASSWORD")" \
        certificate="$CERT_PATH" \
        key="$KEY_PATH" \
        > "$CONFIG_PATH" 2>/dev/null

    if [ $? -ne 0 ] || [ ! -f "$CONFIG_PATH" ]; then
        echo_red "error: Failed to create config file using jo!"
        exit 1
    fi

    # Validate JSON with jq
    if ! jq empty "$CONFIG_PATH" 2>/dev/null; then
        echo_red "error: Generated config is not valid JSON!"
        rm -f "$CONFIG_PATH"
        exit 1
    fi

    echo_green "Juicity config created and validated at $CONFIG_PATH"
}

## Install packages
install_packages() {
    echo_green "Installing packages: $PACKAGES"
    if ! sh -c "$INSTALL_CMD"; then
        echo_red "error: Failed to install packages!"
        exit 1
    fi
    echo_green "Packages installed successfully."
}

## Obtain SSL certificate via certbot
obtain_ssl_cert() {
    echo_green "Obtaining SSL certificate for $DOMAIN..."
    if ! certbot --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive; then
        echo_red "error: Failed to obtain SSL certificate!"
        exit 1
    fi
    echo_green "SSL certificate obtained successfully."
}

## Start and enable service
start_service() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload
        systemctl enable --now nginx
        systemctl enable --now juicity-server
        if systemctl is-active --quiet juicity-server; then
            echo_green "juicity-server is running (systemd)."
        else
            echo_red "error: juicity-server failed to start (systemd)!"
            exit 1
        fi
    elif [ -f /sbin/openrc-run ]; then
        rc-update add nginx default
        rc-update add juicity-server default
        rc-service nginx start
        rc-service juicity-server start
        if rc-service juicity-server check; then
            echo_green "juicity-server is running (OpenRC)."
        else
            echo_red "error: juicity-server failed to start (OpenRC)!"
            exit 1
        fi
    else
        echo_yellow "warning: No systemd or OpenRC found. Please start services manually."
    fi
}

## Main workflow
main() {
    show_notice

    # Step 1: Collect user input
    ask_domain_email
    ask_juicity_config_path

    # Step 2: Check system and install software
    check_os_package_manager
    check_os_release
    define_packages
    install_packages
    set_nginx_config

    # Step 3: Obtain SSL and start services
    obtain_ssl_cert
    start_service

    echo_green_bold "Deployment complete!"
}

main "$@"

##
