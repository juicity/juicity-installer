#!/usr/bin/env sh

# shellcheck disable=SC3000-SC4000

# set -e

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --libc-target)
                if [ -z "$2" ]; then
                    echo_red "error: --libc-target requires an argument: glibc or musl"
                    exit 1
                fi
                case "$2" in
                    glibc)
                        USER_LIBC_TARGET='gnu'
                        ;;
                    musl)
                        USER_LIBC_TARGET='musl'
                        ;;
                    *)
                        echo_red "error: --libc-target only supports glibc or musl"
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            --x86-64-version)
                if [ -z "$2" ]; then
                    echo_red "error: --x86-64-version requires an argument: v2 or v3"
                    exit 1
                fi
                case "$2" in
                    v2 | v3)
                        X86_64_VERSION="$2"
                        ;;
                    *)
                        echo_red "error: --x86-64-version only supports v2 or v3"
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            --force)
                FORCE_INSTALL=1
                shift
                ;;
            --version)
                if [ -z "$2" ]; then
                    echo_red "error: --version requires a version argument"
                    exit 1
                fi
                USER_JUICITY_RS_VERSION="$2"
                shift 2
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *)
                echo_red "error: Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done
}

validate_args() {
    OS_NAME="$(uname)"
    ARCH_NAME="$(uname -m)"

    if [ -n "$USER_LIBC_TARGET" ] && [ "$OS_NAME" != 'Linux' ]; then
        echo_red "error: --libc-target only supports Linux"
        exit 1
    fi

    if [ -n "$X86_64_VERSION" ]; then
        if [ "$OS_NAME" != 'Linux' ]; then
            echo_red "error: --x86-64-version only supports Linux"
            exit 1
        fi
        if [ "$ARCH_NAME" != 'x86_64' ] && [ "$ARCH_NAME" != 'amd64' ]; then
            echo_red "error: --x86-64-version only supports x86_64/amd64"
            exit 1
        fi
    fi
}

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

## Show usage
usage() {
echo_green_bold 'Usage: installer-rs.sh [options]'

echo_green 'Options:'
echo_green '  --libc-target glibc|musl   Force Linux libc target instead of auto detect.'
echo_green '  --x86-64-version v2|v3     Use x86_64 CPU optimized build variant on Linux.'
echo_green '  --force                    Skip local version checks and force online install.'
echo_green '  --version VERSION          Install the specified juicity-rs version directly.'
echo_green '  -h, --help                 Show this help message.'
}

## Check System
if [ "$(uname)" != 'Linux' ] && [ "$(uname)" != 'Darwin' ]; then
    echo_red "error: This script only support Linux or macOS!"
    exit 1
fi

## Check Root
if [ "$(id -u)" != '0' ]; then
    echo_red "error: This script must be run as root!"
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
        echo_green "You have installed the following tools during installation:"
        echo "$tool_need"
        echo_green "You can uninstall them now if you want."
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
        if [ -n "$USER_LIBC_TARGET" ]; then
            LIBC="$USER_LIBC_TARGET"
        else
            detect_libc
        fi
        case "$(uname -m)" in
            'x86_64' | 'amd64')
                TARGET="x86_64-unknown-linux-$LIBC"
                if [ -n "$X86_64_VERSION" ]; then
                    TARGET="$TARGET-$X86_64_VERSION"
                fi
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
                echo_red "error: Unsupported architecture: $(uname -m)"
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
                echo_red "error: Unsupported architecture: $(uname -m)"
                exit 1
                ;;
        esac
    fi
}

check_version() {
    if [ -n "$USER_JUICITY_RS_VERSION" ]; then
        JUICITY_RS_VERSION="$USER_JUICITY_RS_VERSION"
        echo_yellow "warning: You are installing juicity-rs version $JUICITY_RS_VERSION"
        LOCAL_VERSION=0
        return
    fi

    if [ -z "$JUICITY_RS_VERSION" ]; then
        JUICITY_RS_VERSION=$(curl -s https://api.github.com/repos/juicity/juicity-rs/releases/latest | awk -F 'tag_name' '{printf $2}' | awk -F '"' '{printf $3}')
        if [ "$FORCE_INSTALL" = '1' ]; then
            echo_yellow "warning: Force install enabled, local version check is skipped."
            echo "$GREEN""Installing juicity-rs $JUICITY_RS_VERSION...""$RESET"
            LOCAL_VERSION=0
            return
        fi
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
            echo_yellow "warning: You are installing juicity-rs version $JUICITY_RS_VERSION"
            echo_yellow "which is older than local version $LOCAL_VERSION, if you still"
            echo_yellow "want to install this online version of juicity-rs, please"
            echo_yellow "set JUICITY_RS_VERSION variable then try again, or you can"
            echo_yellow "uninstall local installed version at first."
            exit 1
        fi
    else
        echo_yellow "warning: You are installing juicity-rs version $JUICITY_RS_VERSION"
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
    echo_green "Downloading juicity-rs from $JUICITY_RS_DOWNLOAD_URL..."
    if ! curl -# -L -o "$JUICITY_RS_DOWNLOAD_TMP_FILE" "$JUICITY_RS_DOWNLOAD_URL"; then
        echo_red "error: Download juicity-rs failed!"
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
        echo_yellow "warning: Could not retrieve SHA256 from GitHub API, skipping verification."
    else
        if command -v sha256sum > /dev/null 2>&1; then
            local_sha256="$(sha256sum "$JUICITY_RS_DOWNLOAD_TMP_FILE" | cut -d' ' -f1)"
        elif command -v shasum > /dev/null 2>&1; then
            local_sha256="$(shasum -a 256 "$JUICITY_RS_DOWNLOAD_TMP_FILE" | cut -d' ' -f1)"
        else
            echo_red "error: Can not find command sha256sum or shasum, sha256 cannot be calculated!"
            exit 1
        fi
        if [ "$local_sha256" != "$REMOTE_SHA256" ]; then
            echo_red "error: SHA256 verification failed!"
            exit 1
        fi
        echo_green "SHA256 verification passed."
    fi
}

download_systemd_service() (
    JUICITY_SERVICE_URL="https://raw.githubusercontent.com/juicity/juicity-installer/master/systemd/juicity-server.service"
    JUICITY_SERVICE_TMP_FILE="/tmp/juicity-server.service"
    if [ -f /etc/systemd/system/juicity-server.service ] && [ "$FORCE_INSTALL" != '1' ]; then
        echo_yellow "warning: /etc/systemd/system/juicity-server.service already exists, skipping replacement (use --force to overwrite)."
    else
        echo_green "Downloading juicity server service file from $JUICITY_SERVICE_URL..."
        if ! curl -# -L -o "$JUICITY_SERVICE_TMP_FILE" "$JUICITY_SERVICE_URL"; then
            echo_red "error: Download juicity service file failed!"
            exit 1
        fi
        mv /tmp/juicity-server.service /etc/systemd/system/juicity-server.service
    fi
    JUICITY_CLIENT_SERVICE_URL="https://raw.githubusercontent.com/juicity/juicity-installer/master/systemd/juicity-client.service"
    JUICITY_CLIENT_SERVICE_TMP_FILE="/tmp/juicity-client.service"
    if [ -f /etc/systemd/system/juicity-client.service ] && [ "$FORCE_INSTALL" != '1' ]; then
        echo_yellow "warning: /etc/systemd/system/juicity-client.service already exists, skipping replacement (use --force to overwrite)."
    else
        echo_green "Downloading juicity client service file from $JUICITY_CLIENT_SERVICE_URL..."
        if ! curl -# -L -o "$JUICITY_CLIENT_SERVICE_TMP_FILE" "$JUICITY_CLIENT_SERVICE_URL"; then
            echo_red "error: Download juicity client service file failed!"
            exit 1
        fi
        mv /tmp/juicity-client.service /etc/systemd/system/juicity-client.service
    fi
    systemctl daemon-reload
)

download_openrc_service() (
    JUICITY_SERVICE_URL="https://github.com/juicity/juicity-installer/raw/master/OpenRC/juicity-server"
    JUICITY_SERVICE_TMP_FILE="/tmp/juicity-server"
    if [ -f /etc/init.d/juicity-server ] && [ "$FORCE_INSTALL" != '1' ]; then
        echo_yellow "warning: /etc/init.d/juicity-server already exists, skipping replacement (use --force to overwrite)."
    else
        echo_green "Downloading juicity server service file from $JUICITY_SERVICE_URL..."
        if ! curl -# -L -o "$JUICITY_SERVICE_TMP_FILE" "$JUICITY_SERVICE_URL"; then
            echo_red "error: Download juicity service file failed!"
            exit 1
        fi
        mv /tmp/juicity-server /etc/init.d/juicity-server
        chmod +x /etc/init.d/juicity-server
    fi
    JUICITY_CLIENT_SERVICE_URL="https://github.com/juicity/juicity-installer/raw/master/OpenRC/juicity-client"
    JUICITY_CLIENT_SERVICE_TMP_FILE="/tmp/juicity-client"
    if [ -f /etc/init.d/juicity-client ] && [ "$FORCE_INSTALL" != '1' ]; then
        echo_yellow "warning: /etc/init.d/juicity-client already exists, skipping replacement (use --force to overwrite)."
    else
        echo_green "Downloading juicity client service file from $JUICITY_CLIENT_SERVICE_URL..."
        if ! curl -# -L -o "$JUICITY_CLIENT_SERVICE_TMP_FILE" "$JUICITY_CLIENT_SERVICE_URL"; then
            echo_red "error: Download juicity client service file failed!"
            exit 1
        fi
        mv /tmp/juicity-client /etc/init.d/juicity-client
        chmod +x /etc/init.d/juicity-client
    fi
)

download_service() {
    if command -v systemctl > /dev/null 2>&1; then
        download_systemd_service
    elif [ -f /sbin/openrc-run ]; then
        download_openrc_service
    else
        echo_yellow "warning: You are not using systemd or OpenRC, you need to manually configure the service file."
    fi
}

stop_juicity() {
    if command -v systemctl > /dev/null 2>&1; then
        if [ "$(systemctl is-active juicity-server)" = 'active' ]; then
            echo_green "Stopping juicity server..."
            systemctl stop juicity-server
            juicity_server_stopped=1
        fi
        if [ "$(systemctl is-active juicity-client)" = 'active' ]; then
            echo_green "Stopping juicity client..."
            systemctl stop juicity-client
            juicity_client_stopped=1
        fi
    fi
    if command -v rc-service > /dev/null 2>&1; then
        if [ -f /sbin/openrc-run ] && [ -n "$(pidof juicity-server)" ]; then
            echo_green "Stopping juicity server..."
            rc-service juicity-server stop
            juicity_server_stopped=1
        fi
        if [ -f /sbin/openrc-run ] && [ -n "$(pidof juicity-client)" ]; then
            echo_green "Stopping juicity client..."
            rc-service juicity-client stop
            juicity_client_stopped=1
        fi
    fi
}

install_juicity_rs() {
    tmp_dir=$(mktemp -d)
    unzip -o "$JUICITY_RS_DOWNLOAD_TMP_FILE" -d "$tmp_dir"
    pkg_dir="$tmp_dir"
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
        echo_green "Starting juicity server..."
        if [ -f /sbin/openrc-run ]; then
            rc-service juicity-server start
        elif command -v systemctl > /dev/null 2>&1; then
            systemctl start juicity-server
        fi
    fi
    if [ "$juicity_client_stopped" = '1' ]; then
        echo_green "Starting juicity client..."
        if [ -f /sbin/openrc-run ]; then
            rc-service juicity-client start
        elif command -v systemctl > /dev/null 2>&1; then
            systemctl start juicity-client
        fi
    fi
}

notice_config_path() {
    echo_green "-------------------------------------------------------------"
    echo_green "1. The configuration dir is in /usr/local/etc/juicity${GREEN},"
    echo_green "   and the server config file is server.json, the client "
    echo_green "   config file is client.json."
    echo_green "2. The example config files are server.json.example and "
    echo_green "   client.json.example, don't use them directly but move"
    echo_green "   them to server.json and client.json."
    echo_green "3. If you are using systemd or OpenRC, services will be "
    echo_green "   installed, you can use systemctl or rc-service to manage"
    echo_green "   them. However, if you are not using systemd or OpenRC, no"
    echo_green "   services will be installed, you need to manage the"
    echo_green "   services by yourself."
    echo_green "4. An SSL certificate is required to run the Juicity server,"
    echo_green "   you can apply for a certificate through lego, certbot or "
    echo_green "   acme.sh. "
    echo_green "-------------------------------------------------------------"
    echo_green "These acme clients might be helpful for you: "
    echo "1. https://github.com/go-acme/lego"
    echo "2. https://certbot.eff.org/"
    echo "3. https://github.com/acmesh-official/acme.sh"
    echo_green "-------------------------------------------------------------"
}

main() {
    parse_args "$@"
    validate_args
    check_arch_and_os
    check_version
    create_etc_juicity
    download_juicity_rs
    download_service
    stop_juicity
    install_juicity_rs
    start_juicity
    echo_green "Installed successfully!"
    notice_installled_tool
    notice_config_path
}

main "$@"
