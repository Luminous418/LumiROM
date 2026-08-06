#!/bin/bash

source scripts/bash_colors.sh

UBUNTU_PACKAGES() {
    PACKAGES=(
        file
        7zip
        android-sdk-libsparse-utils
        python3
        python3-pip
        zipalign
        default-jre
        openjdk-17-jdk
        brotli
        e2fsprogs
        zstd
        aria2
        unzip
        tar
        lz4
        tree
        git
        gnupg
        flex
        bison
        build-essential
        zip
        curl
        zlib1g-dev
        libncurses-dev
        libssl-dev
        libelf-dev
        libxml2-utils
        xsltproc
        fontconfig
        python3-protobuf
        libprotobuf32t64
    )

    echo "Searching for repository updates..."
    sudo apt update -qq

    echo -e "\nChecking dependency status...\n"

    for pkg in "${PACKAGES[@]}"; do
        if dpkg-query -s "$pkg" 2>/dev/null | grep -q "Status: install ok installed"; then
            IS_UPGRADABLE=$(apt list --upgradable "$pkg" 2>/dev/null | grep "$pkg")

            if [ -n "$IS_UPGRADABLE" ]; then
                echo "${BOLD_YELLOW}[↑] Updating $pkg to the latest version...${RESET}"
                sudo apt install --only-upgrade -y "$pkg"
            else
                echo "${GREEN}[✓] $pkg is updated.${RESET}"
            fi
        else
            echo "${YELLOW}[+] Installing $pkg...${RESET}"
            sudo apt install -y "$pkg"
        fi
    done

    echo -e "\n¡All dependencies checked and updated!"
}

PYTHON_PACKAGES() {
    PIP_PACKAGES=(
        liblp
        tgcrypto
        pyrogram
        huggingface_hub
        hf_xet
    )

    SAMLOADER_URL="git+https://github.com/ananjaser1211/samloader.git"

    echo -e "Checking Python dependencies (pip3)...\n"

    for pkg in "${PIP_PACKAGES[@]}"; do
        if python3 -m pip show "$pkg" >/dev/null 2>&1; then
            echo "${GREEN}[✓] $pkg (pip) is already installed.${RESET}"
        else
            echo "${YELLOW}[+] Installing $pkg with pip3...${RESET}"
            python3 -m pip install "$pkg" --break-system-packages
        fi
    done

    if python3 -m pip show samloader >/dev/null 2>&1; then
        echo "${GREEN}[✓] samloader (Git) is already installed.${RESET}"
    else
        echo "${YELLOW}[+] Installing samloader from GitHub...${RESET}"
        python3 -m pip install "$SAMLOADER_URL" --break-system-packages
    fi

    echo -e "\nPython environment verified successfully!"
}

# Cleanup.
sudo apt clean
rm -rf ~/.cache/*
sudo apt autoclean
sudo apt autoremove -y
