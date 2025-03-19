#!/bin/sh
#
# Intended to be installed via the following command:
# curl -sSf https://endurasecurity.github.io/endura-cli-install/dist/testing.sh | sh

set -eu

CHANNEL=endura-repo-testing
DEB_URL="https://endurasecurity.github.io/${CHANNEL}/endura-cli-tools/deb"
SIG_URL="https://endurasecurity.github.io/${CHANNEL}/endura-cli-tools/endura.asc"
MISSING_CMDS=""
RPM_URL="https://endurasecurity.github.io/${CHANNEL}/endura-cli-tools/rpm"
TGZ_URL="https://endurasecurity.github.io/${CHANNEL}/endura-cli-tools/tgz/endura-cli-tools-latest.tgz"

BOLD="\033[1m"
RESET="\033[0m"
RED="\033[1;31m"
GREEN="\033[1;32m"
WHITE="\033[1;37m"
YELLOW="\033[1;33m"

main() {
    needs_cmd cat
    needs_cmd curl
    needs_cmd gpg
    needs_cmd grep
    needs_cmd printf
    needs_cmd rm
    needs_cmd tar
    needs_cmd tee

    if [ -n "$MISSING_CMDS" ]; then
        fail "please install the following missing command(s) and try again: $MISSING_CMDS"
    fi

    if [ "$(id -u)" -ne 0 ]; then
        fail "must be run as root"
    fi

    if is_deb_distro; then
        install_deb_package
    elif is_rpm_distro; then
        install_rpm_package
    else
        install_tgz_package
    fi

    return 0
}

install_deb_package() {
    info "installing deb repository: ${DEB_URL}"
    echo "deb [signed-by=/usr/share/keyrings/endura-keyring.gpg] ${DEB_URL} /" | tee /etc/apt/sources.list.d/endura-cli-tools.list
    curl -sL "${SIG_URL}" | gpg --dearmor --batch --yes -o /usr/share/keyrings/endura-keyring.gpg
    
    info "installing endura-cli-tools package"
    apt-get update
    apt-get install -y endura-cli-tools

    info "successfully installed endura $(endura version)"
}

install_rpm_package() {
    info "installing rpm repository: ${RPM_URL}" 
    cat <<EOF | tee /etc/yum.repos.d/endura-cli-tools.repo
[endura-cli-tools]
name=Endura Cli Tools Repository
baseurl=${RPM_URL}
enabled=1
gpgcheck=1
gpgkey=${SIG_URL}
EOF

    info "installing endura-cli-tools package"
    dnf makecache
    dnf install -y endura-cli-tools

    info "successfully installed endura $(endura version)"
}

install_tgz_package() {
    info "downloading tgz package: ${TGZ_URL}"
    curl -sL "$TGZ_URL" -o /tmp/endura-cli-tools.tgz
    curl -sL "$SIG_URL" -o /tmp/endura-cli-tools.tgz.sig

    if ! gpg --verify /tmp/endura-cli-tools.tgz.sig /tmp/endura-cli-tools.tgz; then
        fail "tgz package signature verification failed"
    fi

    info "installing tgz package"
    tar -C / -xzf /tmp/endura-cli-tools.tgz
    rm -f /tmp/endura-cli-tools.tgz /tmp/endura-cli-tools.tgz.sig

    info "successfully installed endura $(endura version)"    
}

is_deb_distro() {
    grep -qiE "debian|ubuntu" /etc/os-release 2>/dev/null
}

is_rpm_distro() {
    grep -qiE "almalinux|amazon linux|centos|fedora|oracle|rocky|suse" /etc/os-release 2>/dev/null
}

info() {
    printf "${BOLD}${WHITE}[endura]${RESET} ${GREEN}[info]${RESET} %s\n" "$1" >&2
}

warn() {
    printf "${BOLD}${WHITE}[endura]${RESET} ${YELLOW}[warn]${RESET} %s\n" "$1" >&2
}

fail() {
    printf "${BOLD}${WHITE}[endura]${RESET} ${RED}[fatal]${RESET} %s\n" "$1" >&2
    exit 1
}

needs_cmd() {
    if ! check_cmd "$1"; then
        warn "needs '$1' (command not found)\n"
        MISSING_CMDS="$MISSING_CMDS $1"
    fi
}

check_cmd() {
    command -v "$1" > /dev/null 2>&1
}

assert_nz() {
    if [ -z "$1" ]; then fail "assert_nz $2"; fi
}

ensure() {
    if ! "$@"; then fail "command failed: $*"; fi
}

ignore() {
    "$@"
}

main "$@" || exit 1
