# USK – USB Security Key  
**A plug‑and‑play, hardware‑tied encrypted key for Linux**  

![GitHub release (latest by date)](https://img.shields.io/github/v/release/piratheon/USK?style=flat-square)
![GitHub License](https://img.shields.io/github/license/piratheon/USK?style=flat-square)
![GitHub stars](https://img.shields.io/github/stars/piratheon/USK?style=flat-square)
![GitHub issues](https://img.shields.io/github/issues/piratheon/USK?style=flat-square)

---  

## 📖 Overview  

USK (USB Security Key) automates the creation of an **encrypted container** stored on any USB thumb‑drive and mounts it **only on a specific machine**. It uses the motherboard’s UUID as the pass‑phrase, so even if the USB is stolen it remains useless without the originating host.

- **Zero‑trust** – the key never leaves the USB.  
- **No passwords** – the pass‑phrase is derived from hardware.  
- **Transparent** – udev watches USB insert/removal and mounts/unmounts automatically.  
- **Fully scriptable** – all actions are a single line of Bash.

## ✨ Features  

| ✅ | Feature |
|---|---|
| ✅ | One‑liner curl installer (no pre‑download required) |
| ✅ | Automatic udev rules – “plug‑and‑play” behaviour |
| ✅ | LUKS encrypted container (50 MiB by default) |
| ✅ | Uses host motherboard UUID as pass‑phrase (no human secret) |
| ✅ | Clean activation/deactivation scripts in `/usr/local/bin` |
| ✅ | Full uninstall routine (`usk_uninstall.sh`) |
| ✅ | Works on any modern Linux distro with `cryptsetup` and `dmidecode` |

> **TL;DR** – `curl … | sudo bash -s -- --install` → `sudo bash … --create-key` → plug USB → key appears at `/media/virtual_key`.

---

## 🚀 Getting Started  

### 1️⃣ Prerequisites  

| Package | Why? |
|---|---|
| `cryptsetup` | LUKS container handling |
| `dmidecode`   | Retrieve motherboard UUID |
| `udev`        | USB event detection (present on all distros) |
| `dd`, `lsblk` | Disk utilities used by the script |

On Debian/Ubuntu‑based systems:

```bash
sudo apt-get update && sudo apt-get install -y cryptsetup dmidecode
```

On Fedora/CentOS/RHEL:

```bash
sudo dnf install -y cryptsetup dmidecode
```

On ArchLinux:

```bash
sudo pacman -S cryptsetup dmidecode
```

> **Note** – The installer script checks for root privileges but does **not** install missing packages. Install them manually first.

### 2️⃣ One‑Line Installation (curl)

> Everything you need to set up USK lives in a single Bash script.  
> No need to clone the repository first.

```bash
# Download the installer & run it with the '--install' flag
sudo bash <(curl -fsSL https://raw.githubusercontent.com/piratheon/usk/main/usk.sh) --install
```

What this does:

1. Downloads `usk.sh` straight from GitHub.  
2. Installs the activation (`usk_activate.sh`) and deactivation (`usk_deactivate.sh`) scripts to `/usr/local/bin`.  
3. Installs a udev rule (`/etc/udev/rules.d/99-usk.rules`).  
4. Reloads udev so the rule becomes active immediately.

> **Security tip** – If you prefer to *review* before executing, you can fetch the script to a file first:  
> ```bash
> curl -fsSL -o usk.sh https://raw.githubusercontent.com/piratheon/usk/main/usk.sh
> less usk.sh            # inspect
> sudo bash usk.sh --install
> ```

### 3️⃣ Create Your Encrypted USB Key  

```bash
# Run the same script with the '--create-key' flag
sudo bash <(curl -fsSL https://raw.githubusercontent.com/piratheon/usk/main/usk.sh) --create-key
```

The script will:

- Prompt you to **insert** the USB drive you want to use.  
- Ask for its **mount point** (e.g., `/media/user/MYUSB`).  
- Write a 50 MiB random file `virtual_key.img` to the USB.  
- Initialise it as a **LUKS container**, encrypted with your motherboard UUID.  

> After the key is created, simply plug the USB into the same machine: the container will automatically mount at `/media/virtual_key`. Unplugging will securely unmount and close the LUKS mapping.

---

## 📦 What the Installer Actually Does  

```text
/usr/local/bin/
│
├─ usk_activate.sh      # Called by udev on USB insertion
└─ usk_deactivate.sh    # Called by udev on USB removal

/etc/udev/rules.d/
└─ 99-usk.rules         # Triggers the scripts on add/remove events
```

**Activation flow** (`usk_activate.sh`):

1. Reads `$1` – the mount point passed from udev.  
2. Checks for `virtual_key.img`.  
3. Retrieves the hardware UUID via `dmidecode`.  
4. Opens the LUKS container with that UUID as pass‑phrase.  
5. Mounts the decrypted mapper at `/media/virtual_key`.

**Deactivation flow** (`usk_deactivate.sh`):

1. Verifies `/media/virtual_key` is a mount point.  
2. Unmounts it and closes the LUKS mapper.  

All actions are silent by default; successful mount prints a friendly message.

---

## 🛠️ Manual Usage (Optional)

If you prefer to run the scripts manually (for debugging or custom setups):

```bash
# Activate a mounted USB (replace /media/your_usb with the actual path)
sudo /usr/local/bin/usk_activate.sh /media/your_usb

# Deactivate (unmount) the virtual key
sudo /usr/local/bin/usk_deactivate.sh
```

---

## 🗑️ Uninstall  

```bash
# One‑liner to clean everything
sudo bash <(curl -fsSL https://raw.githubusercontent.com/piratheon/usk/main/usk_uninstall.sh)
```

`usk_uninstall.sh` removes the scripts, the udev rule, and reloads udev. It **does not** delete your `virtual_key.img` file – you keep the encrypted container for future use.

> If you never saved `usk_uninstall.sh`, you can also manually delete the files:
> ```bash
> sudo rm /usr/local/bin/usk_activate.sh /usr/local/bin/usk_deactivate.sh
> sudo rm /etc/udev/rules.d/99-usk.rules
> sudo udevadm control --reload-rules && sudo udevadm trigger
> ```

---

## 🤔 How It Works – Under the Hood  

| Step | Explanation |
|------|-------------|
| **Mount detection** | udev passes the USB mount point to `usk_activate.sh`. |
| **Pass‑phrase generation** | `dmidecode -s system-uuid` returns a unique identifier that is **consistent** for the host and **unknown** to anyone else. |
| **LUKS container** | `cryptsetup luksOpen` uses the UUID (via stdin) as the secret key. |
| **Mounting** | The opened mapper device is mounted to a stable location (`/media/virtual_key`). |
| **Security** | When the USB is removed, the deactivation script unmounts and closes the mapper, wiping the key from memory. |

Because the UUID is tied to the **physical motherboard**, cloning the USB to another computer is useless – the decryption will always fail.

---

## 📚 FAQ  

**Q:** *Can I change the size of the encrypted file?*  
**A:** Yes. Edit `USK_KEY_FILENAME` and the `dd` command in `usk_create_key` to suit your needs (e.g., `bs=1M count=200` for 200 MiB).  

**Q:** *What if my OS doesn’t have `dmidecode`?*  
**A:** The script will abort with a clear error. Install `dmidecode` or modify the script to use another unique identifier (e.g., a TPM PCR).  

**Q:** *Will this work on a virtual machine?*  
**A:** Only if the VM exposes a consistent UUID (most hypervisors do). However, **hardware‑bound** security loses meaning inside a VM.  

**Q:** *Can I use this on a non‑Linux system?*  
**A:** The current implementation uses udev and `cryptsetup`, which are Linux‑specific. Porting to macOS or Windows would require a different activation mechanism.  

**Q:** *What happens if I disconnect the USB while the container is in use?*  
**A:** The deactivate script runs automatically, unmounting the filesystem and closing the LUKS mapping, preventing data corruption.

---

## 🤝 Contributing  

We love contributions!  

1. Fork the repo (`https://github.com/piratheon/usk`).  
2. Create a feature branch (`git checkout -b my‑feature`).  
3. Make your changes, write tests (if applicable) and commit.  
4. Open a Pull Request with a clear description.  


---

## 📜 License  

```text
GNU GENERAL PUBLIC LICENSE, Version 3
© 2025 piratheon
```

Feel free to use, modify, and distribute USK as you see fit. Attribution is appreciated but not required.

---

## 🙏 Acknowledgements  

- **cryptsetup** – for LUKS encryption capabilities.  
- **udev** – for reliable device event handling.  
- **dmidecode** – for exposing the motherboard UUID.  

---

## 📧 Contact  

- **GitHub:** <https://github.com/piratheon/usk>  
- **Issues:** <https://github.com/piratheon/usk/issues>  

*Your security is only as good as the key you trust – let USK be that key.*  
