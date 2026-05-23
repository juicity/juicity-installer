#!/usr/bin/env sh

# shellcheck disable=SC3000-SC4000

# set -e

## Color
if command -v tput > /dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RESET=$(tput sgr0)
fi

## Check System
if [ "$(uname)" != 'Linux' ] && [ "$(uname)" != 'Darwin' ]; then
    echo "${RED}error: This script only support Linux or macOS!${RESET}"
    exit 1
fi

## Check Root
if [ "$(id -u)" != '0' ]; then
    echo "${RED}error: This script must be run as root!${RESET}"
    exit 1
fi

## Check Command
tools="curl unzip"
for tool in $tools; do
    if ! command -v "$tool"> /dev/null 2>&1; then
        tool_need="$tool"" ""$tool_need"
    fi
done
if [ -n "$tool_need" ]; then
    if command -v apt > /dev/null 2>&1; then
        command_install_tool="apt update; apt install $tool_need -y"
    elif command -v dnf > /dev/null 2>&1; then
        command_install_tool="dnf install $tool_need -y"
    elif command -v yum > /dev/null  2>&1; then
        command_install_tool="yum install $tool_need -y"
    elif command -v zypper > /dev/null 2>&1; then
        command_install_tool="zypper --non-interactive install $tool_need"
    elif command -v pacman > /dev/null 2>&1; then
        command_install_tool="pacman -Sy $tool_need --noconfirm"
    elif command -v apk > /dev/null 2>&1; then
        command_install_tool="apk add $tool_need"
    else
        echo "$RED""You should install ""$tool_need""then try again.""$RESET"
        exit 1
    fi
    if ! /bin/sh -c "$command_install_tool";then
        echo "$RED""Use system package manager to install ""$tool_need""failed,""$RESET"
        echo "$RED""You should install ""$tool_need""then try again.""$RESET"
        exit 1
    fi
fi

notice_installled_tool() {
    if [ -n "$tool_need" ]; then
        echo "${GREEN}You have installed the following tools during installation:${RESET}"
        echo "$tool_need"
        echo "${GREEN}You can uninstall them now if you want.${RESET}"
    fi
}

detect_libc() {
    if ldd --version 2>&1 | grep -qi 'musl'; then
        LIBC='musl'
    elif [ -f /etc/alpine-release ]; then
        LIBC='musl'
    elif ldd /bin/sh 2>&1 | grep -q 'musl'; then
        LIBC='musl'
    else
        LIBC='gnu'
    fi
}

check_arch_and_os() {
    if [ "$(uname)" = 'Linux' ]; then
        detect_libc
        case "$(uname -m)" in
            'x86_64' | 'amd64')
                TARGET="x86_64-unknown-linux-$LIBC"
                ;;
            'i386' | 'i686')
                TARGET="i686-unknown-linux-$LIBC"
                ;;
            'armv7l' | 'armv7')
                if [ "$LIBC" = 'musl' ]; then
                    TARGET='armv7-unknown-linux-musleabihf'
                else
                    TARGET='armv7-unknown-linux-gnueabihf'
                fi
                ;;
            'armv8' | 'aarch64' | 'arm64')
                TARGET="aarch64-unknown-linux-$LIBC"
                ;;
            'loongarch64')
                TARGET="loongarch64-unknown-linux-$LIBC"
                ;;
            'riscv64')
                TARGET="riscv64gc-unknown-linux-$LIBC"
                ;;
            *)
                echo "${RED}error: Unsupported architecture: $(uname -m)${RESET}"
                exit 1
                ;;
        esac
    fi
    if [ "$(uname)" = 'Darwin' ]; then
        case "$(uname -m)" in
            'x86_64' | 'amd64')
                TARGET='x86_64-apple-darwin'
                ;;
            'arm64' | 'aarch64')
                TARGET='aarch64-apple-darwin'
                ;;
            *)
                echo "${RED}error: Unsupported architecture: $(uname -m)${RESET}"
                exit 1
                ;;
        esac
    fi
}

check_version() {
    if [ -z "$JUICITY_RS_VERSION" ]; then
        JUICITY_RS_VERSION=$(curl -s https://api.github.com/repos/juicity/juicity-rs/releases/latest | awk -F 'tag_name' '{printf $2}' | awk -F '"' '{printf $3}')
        [ -f /usr/local/bin/juicity-server ] && LOCAL_VERSION="$(/usr/local/bin/juicity-server --version 2>/dev/null | grep tag | awk -F ' ' '{print $2}')" || LOCAL_VERSION=0
        if [ "$LOCAL_VERSION" != 0 ]; then
            case "$LOCAL_VERSION" in
                v[0-9]*)
                    is_local_version_legal=1
                    ;;
                *)
                    is_local_version_legal=0
                    ;;
            esac
            if [ "$is_local_version_legal" = 0 ]; then
                echo "$RED""The local version number of juicity-rs is illegal, it should be like:""$RESET"
                echo "$RED""v0.1.0""$RESET"
                echo "$RED""But we got:""$RESET"
                echo "$RED""$LOCAL_VERSION""$RESET"
                echo "$RED""If you have installed juicity-rs from other providers, please uninstall""$RESET"
                echo "$RED""it first then try again.""$RESET"
                exit
            fi
        fi
        if [ "$JUICITY_RS_VERSION" = "$LOCAL_VERSION" ]; then
            echo "$GREEN""Latest version $JUICITY_RS_VERSION already installed.""$RESET" && exit 0
        elif [ "$LOCAL_VERSION" != 0 ] && [ "$(printf '%s\n' "$LOCAL_VERSION" "$JUICITY_RS_VERSION" | sort -rV | head -n1)" = "$JUICITY_RS_VERSION" ]; then
            echo "$GREEN""Upgrading juicity-rs from $LOCAL_VERSION to $JUICITY_RS_VERSION...""$RESET"
        elif [ "$LOCAL_VERSION" = 0 ]; then
            echo "$GREEN""Installing juicity-rs $JUICITY_RS_VERSION...""$RESET"
        else
            echo "${YELLOW}warning: You are installing juicity-rs version $JUICITY_RS_VERSION${RESET}"
            echo "${YELLOW}which is older than local version $LOCAL_VERSION, if you still${RESET}"
            echo "${YELLOW}want to install this online version of juicity-rs, please${RESET}"
            echo "${YELLOW}set JUICITY_RS_VERSION variable then try again, or you can${RESET}"
            echo "${YELLOW}uninstall local installed version at first.${RESET}"
            exit 1
        fi
    else
        echo "${YELLOW}warning: You are installing juicity-rs version $JUICITY_RS_VERSION${RESET}"
        LOCAL_VERSION=0
    fi
}

create_etc_juicity() {
    if [ ! -d /usr/local/etc/juicity ]; then
        mkdir -p /usr/local/etc/juicity
    fi
}

download_juicity_rs() {
    ASSET_NAME="juicity-$TARGET.zip"
    JUICITY_RS_DOWNLOAD_URL="https://github.com/juicity/juicity-rs/releases/download/$JUICITY_RS_VERSION/$ASSET_NAME"
    JUICITY_RS_DOWNLOAD_TMP_FILE="/tmp/$ASSET_NAME"
    echo "${GREEN}Downloading juicity-rs from $JUICITY_RS_DOWNLOAD_URL...${RESET}"
    if ! curl -# -L -o "$JUICITY_RS_DOWNLOAD_TMP_FILE" "$JUICITY_RS_DOWNLOAD_URL"; then
        echo "${RED}error: Download juicity-rs failed!${RESET}"
        exit 1
    fi
    REMOTE_SHA256=$(curl -s "https://api.github.com/repos/juicity/juicity-rs/releases/tags/$JUICITY_RS_VERSION" | \
        awk -v name="\"$ASSET_NAME\"" '
            index($0, name) { found=1 }
            found && index($0, "\"digest\":") {
                sub(/.*"digest": "sha256:/, "")
                sub(/".*/, "")
                print
                exit
            }
        ')
    if [ -z "$REMOTE_SHA256" ]; then
        echo "${YELLOW}warning: Could not retrieve SHA256 from GitHub API, skipping verification.${RESET}"
    else
        if command -v sha256sum > /dev/null 2>&1; then
            local_sha256="$(sha256sum "$JUICITY_RS_DOWNLOAD_TMP_FILE" | cut -d' ' -f1)"
        elif command -v shasum > /dev/null 2>&1; then
            local_sha256="$(shasum -a 256 "$JUICITY_RS_DOWNLOAD_TMP_FILE" | cut -d' ' -f1)"
        else
            echo "${RED}error: Can not find command sha256sum or shasum, sha256 cannot be calculated!${RESET}"
            exit 1
        fi
        if [ "$local_sha256" != "$REMOTE_SHA256" ]; then
            echo "${RED}error: SHA256 verification failed!${RESET}"
            exit 1
        fi
        echo "${GREEN}SHA256 verification passed.${RESET}"
    fi
}

download_systemd_service() (
    JUICITY_SERVICE_URL="https://raw.githubusercontent.com/juicity/juicity-installer/master/systemd/juicity-server.service"
    JUICITY_SERVICE_TMP_FILE="/tmp/juicity-server.service"
    echo "${GREEN}Downloading juicity server service file from $JUICITY_SERVICE_URL...${RESET}"
    if ! curl -# -L -o "$JUICITY_SERVICE_TMP_FILE" "$JUICITY_SERVICE_URL"; then
        echo "${RED}error: Download juicity service file failed!${RESET}"
        exit 1
    fi
    JUICITY_CLIENT_SERVICE_URL="https://raw.githubusercontent.com/juicity/juicity-installer/master/systemd/juicity-client.service"
    JUICITY_CLIENT_SERVICE_TMP_FILE="/tmp/juicity-client.service"
    echo "${GREEN}Downloading juicity client service file from $JUICITY_CLIENT_SERVICE_URL...${RESET}"
    if ! curl -# -L -o "$JUICITY_CLIENT_SERVICE_TMP_FILE" "$JUICITY_CLIENT_SERVICE_URL"; then
        echo "${RED}error: Download juicity client service file failed!${RESET}"
        exit 1
    fi
    mv /tmp/juicity-server.service /etc/systemd/system/juicity-server.service
    mv /tmp/juicity-client.service /etc/systemd/system/juicity-client.service
    systemctl daemon-reload
)

download_openrc_service() (
    JUICITY_SERVICE_URL="https://github.com/juicity/juicity-installer/raw/master/OpenRC/juicity-server"
    JUICITY_SERVICE_TMP_FILE="/tmp/juicity-server"
    echo "${GREEN}Downloading juicity server service file from $JUICITY_SERVICE_URL...${RESET}"
    if ! curl -# -L -o "$JUICITY_SERVICE_TMP_FILE" "$JUICITY_SERVICE_URL"; then
        echo "${RED}error: Download juicity service file failed!${RESET}"
        exit 1
    fi
    JUICITY_CLIENT_SERVICE_URL="https://github.com/juicity/juicity-installer/raw/master/OpenRC/juicity-client"
    JUICITY_CLIENT_SERVICE_TMP_FILE="/tmp/juicity-client"
    echo "${GREEN}Downloading juicity client service file from $JUICITY_CLIENT_SERVICE_URL...${RESET}"
    if ! curl -# -L -o "$JUICITY_CLIENT_SERVICE_TMP_FILE" "$JUICITY_CLIENT_SERVICE_URL"; then
        echo "${RED}error: Download juicity client service file failed!${RESET}"
        exit 1
    fi
    mv /tmp/juicity-server /etc/init.d/juicity-server
    mv /tmp/juicity-client /etc/init.d/juicity-client
    chmod +x /etc/init.d/juicity-server
    chmod +x /etc/init.d/juicity-client
)

download_service() {
    if command -v systemctl > /dev/null 2>&1; then
        download_systemd_service
    elif [ -f /sbin/openrc-run ]; then
        download_openrc_service
    else
        echo "${YELLOW}warning: You are not using systemd or OpenRC, you need to manually configure the service file.${RESET}"
    fi
}

stop_juicity() {
    if command -v systemctl > /dev/null 2>&1; then
        if [ "$(systemctl is-active juicity-server)" = 'active' ]; then
            echo "${GREEN}Stopping juicity server...${RESET}"
            systemctl stop juicity-server
            juicity_server_stopped=1
        fi
        if [ "$(systemctl is-active juicity-client)" = 'active' ]; then
            echo "${GREEN}Stopping juicity client...${RESET}"
            systemctl stop juicity-client
            juicity_client_stopped=1
        fi
    fi
    if command -v rc-service > /dev/null 2>&1; then
        if [ -f /sbin/openrc-run ] && [ -n "$(pidof juicity-server)" ]; then
            echo "${GREEN}Stopping juicity server...${RESET}"
            rc-service juicity-server stop
            juicity_server_stopped=1
        fi
        if [ -f /sbin/openrc-run ] && [ -n "$(pidof juicity-client)" ]; then
            echo "${GREEN}Stopping juicity client...${RESET}"
            rc-service juicity-client stop
            juicity_client_stopped=1
        fi
    fi
}

install_juicity_rs() {
    tmp_dir=$(mktemp -d)
    unzip -o "$JUICITY_RS_DOWNLOAD_TMP_FILE" -d "$tmp_dir"
    pkg_dir="$tmp_dir/juicity-$TARGET"
    mv "$pkg_dir/juicity-server" /usr/local/bin/juicity-server
    chmod +x /usr/local/bin/juicity-server
    mv "$pkg_dir/juicity-client" /usr/local/bin/juicity-client
    chmod +x /usr/local/bin/juicity-client
    mv "$pkg_dir/server-config.json" /usr/local/etc/juicity/server.json.example
    mv "$pkg_dir/client-config.json" /usr/local/etc/juicity/client.json.example
    rm -rf "$tmp_dir"
    if [ "$(uname)" = "Darwin" ]; then
        xattr -rd com.apple.quarantine /usr/local/bin/juicity-server 2>/dev/null || true
        xattr -rd com.apple.quarantine /usr/local/bin/juicity-client 2>/dev/null || true
    fi
}

start_juicity() {
    if [ "$juicity_server_stopped" = '1' ]; then
        echo "${GREEN}Starting juicity server...${RESET}"
        if [ -f /sbin/openrc-run ]; then
            rc-service juicity-server start
        elif command -v systemctl > /dev/null 2>&1; then
            systemctl start juicity-server
        fi
    fi
    if [ "$juicity_client_stopped" = '1' ]; then
        echo "${GREEN}Starting juicity client...${RESET}"
        if [ -f /sbin/openrc-run ]; then
            rc-service juicity-client start
        elif command -v systemctl > /dev/null 2>&1; then
            systemctl start juicity-client
        fi
    fi
}

notice_config_path() {
    echo "${GREEN}-------------------------------------------------------------${RESET}"
    echo "${GREEN}1. The configuration dir is in ${RESET}/usr/local/etc/juicity${GREEN},${RESET}"
    echo "${GREEN}   and the server config file is server.json, the client ${RESET}"
    echo "${GREEN}   config file is client.json.${RESET}"
    echo "${GREEN}2. The example config files are server.json.example and ${RESET}"
    echo "${GREEN}   client.json.example, don't use them directly but move${RESET}"
    echo "${GREEN}   them to server.json and client.json.${RESET}"
    echo "${GREEN}3. If you are using systemd or OpenRC, services will be ${RESET}"
    echo "${GREEN}   installed, you can use systemctl or rc-service to manage${RESET}"
    echo "${GREEN}   them. However, if you are not using systemd or OpenRC, no${RESET}"
    echo "${GREEN}   services will be installed, you need to manage the${RESET}"
    echo "${GREEN}   services by yourself.${RESET}"
    echo "${GREEN}4. An SSL certificate is required to run the Juicity server,${RESET}"
    echo "${GREEN}   you can apply for a certificate through lego, certbot or ${RESET}"
    echo "${GREEN}   acme.sh. ${RESET}"
    echo "${GREEN}-------------------------------------------------------------${RESET}"
    echo "${GREEN}These acme clients might be helpful for you: ${RESET}"
    echo "1. https://github.com/go-acme/lego"
    echo "2. https://certbot.eff.org/"
    echo "3. https://github.com/acmesh-official/acme.sh"
    echo "${GREEN}-------------------------------------------------------------${RESET}"
}

main() {
    check_arch_and_os
    check_version
    create_etc_juicity
    download_juicity_rs
    download_service
    stop_juicity
    install_juicity_rs
    start_juicity
    echo "${GREEN}Installed successfully!${RESET}"
    notice_installled_tool
    notice_config_path
}

main
