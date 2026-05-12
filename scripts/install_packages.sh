#!/bin/bash

# Linux setup.
# Installing necessary packages.
sudo apt install -y -q p7zip-full android-sdk-libsparse-utils python3 python3-pip zipalign default-jre openjdk-17-jdk brotli e2fsprogs zstd aria2 unzip tar lz4 tree git-core gnupg flex bison build-essential zip curl zlib1g-dev libncurses5-dev libssl-dev libelf-dev libxml2-utils xsltproc unzip fontconfig python3 python3-protobuf libprotobuf32t64

# Installing Python packages.
pip3 install liblp tgcrypto pyrogram --break-system-packages
pip3 install git+https://github.com/martinetd/samloader.git --break-system-packages

# Cleanup.
sudo apt clean
rm -rf ~/.cache/*
sudo apt autoclean
sudo apt autoremove -y
