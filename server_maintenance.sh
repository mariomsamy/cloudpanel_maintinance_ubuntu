#!/bin/bash

# Recipe Codes - Server Maintenance Script
# Copyright (c) 2026 Recipe Codes. All rights reserved.

# Check if the script is running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo or switch to the root user."
    exit 1
fi

# Function to update and upgrade the server
update_upgrade_server() {
    echo "Updating package lists..."
    apt-get update -y

    echo "Upgrading installed packages..."
    apt-get upgrade -y

    echo "Performing distribution upgrade..."
    apt-get dist-upgrade -y

    echo "Removing unused packages..."
    apt-get autoremove -y

    echo "Cleaning up package cache..."
    apt-get autoclean -y
}

# Function to improve security
improve_security() {
    echo "Enabling automatic security updates..."
    apt-get install unattended-upgrades -y
    dpkg-reconfigure --priority=low unattended-upgrades

    echo "Configuring UFW (Uncomplicated Firewall)..."
    apt-get install ufw -y
    ufw allow ssh
    ufw enable

    echo "Installing fail2ban to prevent brute-force attacks..."
    apt-get install fail2ban -y
    systemctl enable fail2ban
    systemctl start fail2ban
}

# Function to disable PHP versions
disable_php_versions() {
    declare -A php_versions=(
        ["1"]="php7.1-fpm"
        ["2"]="php7.2-fpm"
        ["3"]="php7.3-fpm"
        ["4"]="php7.4-fpm"
        ["5"]="php8.0-fpm"
        ["6"]="php8.1-fpm"
        ["7"]="php8.2-fpm"
        ["8"]="php8.3-fpm"
        ["9"]="php8.4-fpm"
    )

    echo "Select PHP versions to disable (comma-separated list, e.g., 1,2,3):"
    echo "1. php7.1-fpm"
    echo "2. php7.2-fpm"
    echo "3. php7.3-fpm"
    echo "4. php7.4-fpm"
    echo "5. php8.0-fpm"
    echo "6. php8.1-fpm"
    echo "7. php8.2-fpm"
    echo "8. php8.3-fpm"
    echo "9. php8.4-fpm"
    echo "10. Disable all PHP versions"
    read -p "Your choice: " choices

    if [[ "$choices" == "10" ]]; then
        # Disable all PHP versions
        for version in "${php_versions[@]}"; do
            echo "Disabling and stopping $version..."
            systemctl stop "$version" > /dev/null 2>&1
            systemctl disable "$version" > /dev/null 2>&1
        done
        echo "All PHP versions have been disabled."
    else
        # Disable selected PHP versions
        IFS=',' read -r -a selected_versions <<< "$choices"
        for choice in "${selected_versions[@]}"; do
            version=${php_versions["$choice"]}
            if [[ -n "$version" ]]; then
                echo "Disabling and stopping $version..."
                systemctl stop "$version" > /dev/null 2>&1
                systemctl disable "$version" > /dev/null 2>&1
            else
                echo "Invalid choice: $choice (skipping)"
            fi
        done
    fi
}

# Main script
echo "Starting server maintenance..."

# Update and upgrade the server
update_upgrade_server

# Improve security
improve_security

# Ask user if they want to disable PHP versions
read -p "Do you want to disable PHP versions? (y/n): " disable_php
if [[ "$disable_php" == "y" || "$disable_php" == "Y" ]]; then
    disable_php_versions
else
    echo "Skipping PHP version disable."
fi

# Ask user to reboot or exit
echo "Server maintenance completed!"
read -p "Do you want to reboot the server now? (y/n): " reboot_choice
if [[ "$reboot_choice" == "y" || "$reboot_choice" == "Y" ]]; then
    echo "Rebooting the server..."
    reboot
else
    echo "Exiting without rebooting. Have a great day!"
    exit 0
fi
