#!/bin/bash

# Linux setup.
# Installing necessary packages.
sudo apt install -y p7zip-full lz4 android-sdk-libsparse-utils python3 python3-pip zipalign unzip default-jre openjdk-17-jdk brotli e2fsprogs zstd aria2

# Installing Python packages.
pip3 install liblp tgcrypto pyrogram

# Run with sudo to avoid path problem.
pip3 install git+https://github.com/martinetd/samloader.git

# Cleanup.
sudo apt clean
rm -rf ~/.cache/*
sudo apt autoclean
sudo apt autoremove -y

simg2img
lpunpack
