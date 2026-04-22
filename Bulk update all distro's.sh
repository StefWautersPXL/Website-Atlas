#!/bin/bash

# controle uitvoeren script via root        
if [ "$EUID" -ne 0 ]; then
    echo "Voer dit script uit als root (sudo)"
    exit 1
fi

# Alle bekende pakketbeheerders afgaan om te updaten
if command -v apt &> /dev/null; then
    echo "==> Debian/Ubuntu gedetecteerd (apt)"
    apt update && apt upgrade -y

elif command -v dnf &> /dev/null; then
    echo "==> Fedora/RHEL gedetecteerd (dnf)"
    dnf update -y

elif command -v yum &> /dev/null; then
    echo "==> CentOS/RHEL (oud) gedetecteerd (yum)"
    yum update -y

elif command -v pacman &> /dev/null; then
    echo "==> Arch Linux gedetecteerd (pacman)"
    pacman -Syu --noconfirm

elif command -v zypper &> /dev/null; then
    echo "==> openSUSE gedetecteerd (zypper)"
    zypper refresh && zypper update -y

elif command -v apk &> /dev/null; then
    echo "==> Alpine Linux gedetecteerd (apk)"
    apk update && apk upgrade

else
    echo "Contacteer de IT dienst voor meer hulp"
    exit 1
fi

echo ""
echo "✅ Systeem succesvol bijgewerkt!"
