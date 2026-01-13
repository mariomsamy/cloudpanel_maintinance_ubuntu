# CloudPanel Server Maintenance Script

A **safe, production-ready server maintenance script** designed specifically for  
**CloudPanel-supported Linux distributions (Debian / Ubuntu family)**.

This script automates system updates, optional security hardening, and **controlled PHP-FPM management** with **strong safety guardrails** to prevent accidental server outages.

---

## 🚀 Key Highlights

- ✅ CloudPanel-safe by design
- ✅ Prevents disabling all PHP versions
- ✅ Supports re-enabling disabled PHP-FPM services
- ✅ Interactive & guarded destructive actions
- ✅ Full logging & rollback awareness
- ✅ Production friendly – no risky defaults

---

## 📌 Table of Contents

1. [Features](#features)
2. [Supported Systems](#supported-systems)
3. [Installation](#installation)
4. [How to Use](#how-to-use)
   - [Basic Usage](#basic-usage)
   - [Security Hardening](#security-hardening)
   - [PHP-FPM Management](#php-fpm-management)
   - [Reboot Options](#reboot-options)
5. [Advanced Configuration](#advanced-configuration)
6. [Safety & Guardrails](#safety--guardrails)
7. [Logs & State Files](#logs--state-files)
8. [Troubleshooting](#troubleshooting)
9. [License](#license)
10. [Support](#support)

---

## ✨ Features

### 1️⃣ System Maintenance
- `apt update`
- `apt upgrade`
- `apt dist-upgrade`
- `apt autoremove`
- `apt autoclean`

Ensures the system is fully up-to-date and clean.

---

### 2️⃣ Optional Security Hardening
- Automatic security updates (`unattended-upgrades`)
- Firewall protection with **UFW**
- Brute-force attack protection using **fail2ban**

> All security steps are **optional** and require confirmation.

---

### 3️⃣ Safe PHP-FPM Management (CloudPanel Aware)

- Automatically detects installed `php*-fpm` services
- Disable **selected** PHP versions only
- ❌ Impossible to disable **all PHP-FPM versions**
- Stores disabled services in a **persistent state file**
- Allows **safe re-enable** of disabled PHP versions
- Blocked in non-interactive mode for safety

📁 State tracking file:
```

/var/lib/recipe-codes/disabled-php-fpm-services.txt

```

---

### 4️⃣ Logging & Error Handling
- All actions logged with timestamps
- Errors are trapped with line numbers
- Log file:
```

/var/log/recipe-codes-server-maintenance.log

````

---

## 🖥 Supported Systems

This script supports **CloudPanel-compatible Linux distributions**:

- Ubuntu 20.04 / 22.04 / 24.04
- Debian 10 / 11 / 12
- Any **APT-based CloudPanel installation**

❌ RPM-based systems are intentionally blocked for safety.

---

## 📥 Installation

### Step 1 – Download Script
```bash
wget https://raw.githubusercontent.com/mariomsamy/cloudpanel_maintinance_ubuntu/main/server_maintenance.sh
````

### Step 2 – Make Executable

```bash
chmod +x server_maintenance.sh
```

---

## ▶ How to Use

### Basic Usage

Run the script as root:

```bash
sudo ./server_maintenance.sh
```

Or:

```bash
sudo su
./server_maintenance.sh
```

You will be guided step-by-step.

---

### 🔐 Security Hardening

You will be prompted:

```
Apply security improvements? (y/n)
```

If **Yes**, the script will:

* Enable automatic updates
* Configure UFW safely (SSH allowed)
* Install and enable fail2ban

---

### 🐘 PHP-FPM Management

You will be prompted:

```
Do you want to manage PHP-FPM services? (y/n)
```

#### Options Available:

1. **Disable selected PHP versions**
2. **Re-enable previously disabled versions**
3. **View detected PHP-FPM services**

⚠ **Critical Protection**

* Script **refuses** to disable all PHP-FPM services
* Requires multi-step confirmation

---

### 🔄 Reboot Options

At the end:

```
Maintenance completed. Reboot the server now? (y/n)
```

* `y` → reboot
* `n` → exit safely

---

## ⚙ Advanced Configuration

You can control behavior using environment variables:

| Variable           | Purpose                                  |
| ------------------ | ---------------------------------------- |
| `NONINTERACTIVE=1` | Reduce prompts (PHP management disabled) |
| `ASSUME_YES=1`     | Auto-confirm prompts (⚠ dangerous)       |
| `APPLY_SECURITY=0` | Skip security hardening                  |
| `MANAGE_PHP=0`     | Skip PHP-FPM management                  |

Example:

```bash
APPLY_SECURITY=0 MANAGE_PHP=0 sudo ./server_maintenance.sh
```

---

## 🛡 Safety & Guardrails

This script includes **strong safeguards**:

* ❌ No “Disable All PHP” option
* ❌ PHP actions blocked in non-interactive mode
* ❌ Cannot lock yourself out via firewall
* ✅ CloudPanel compatibility preserved
* ✅ Rollback path via recorded state

⚠ Disabling PHP incorrectly can break:

* CloudPanel UI
* Websites
* PHP applications

This script is intentionally conservative.

---

## 🗂 Logs & State Files

### Main Log

```
/var/log/recipe-codes-server-maintenance.log
```

### PHP Disabled State

```
/var/lib/recipe-codes/disabled-php-fpm-services.txt
```

---

## 🛠 Troubleshooting

### Script exits immediately

* Ensure you are running as `root`
* Check log file for error details

### PHP-FPM missing

* CloudPanel may not use PHP-FPM yet
* Script will safely skip

### Locked out via firewall?

* UFW enable requires confirmation
* SSH rule is always added before enabling

---

## 📜 License

© 2023–2026 **Recipe Codes**
All rights reserved.

---

## 🧑‍💻 Support

* GitHub Repository:
  [https://github.com/mariomsamy/cloudpanel_maintinance_ubuntu](https://github.com/mariomsamy/cloudpanel_maintinance_ubuntu)
* Issues & Requests:
  [https://github.com/mariomsamy/cloudpanel_maintinance_ubuntu/issues](https://github.com/mariomsamy/cloudpanel_maintinance_ubuntu/issues)
* Maintainer: **Mario M. Samy**
* Company: **Recipe Codes**
