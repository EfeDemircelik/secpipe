# Installing Aselsan Root CA Certificates on an Ubuntu VM (VirtualBox)

## Overview

ASELSAN’s internal services use company-issued certificates. This guide explains how 
to export these certificates from Windows and add them to an Ubuntu VirtualBox VM so 
the VM can securely access internal services.


**Certificates involved:**
- `AselsanCA`
- `AselsanInternetCA`

**High-level flow:**
1. Export both certificates from Windows Certificate Manager
2. Share them with the Ubuntu VM through a VirtualBox shared folder
3. Install VirtualBox Guest Additions so the shared folder actually mounts
4. Copy the certificates into Ubuntu's trust store and refresh it

---

## Part 1 — Export the Certificates (Windows)

1. Open the Run dialog: **Windows key + R**
2. Enter `certmgr.msc` and press Enter
3. In the left-hand tree, navigate to:
   ```
   Trusted Root Certification Authorities → Certificates
   ```
4. Find the two certificates:
   - `AselsanCA`
   - `AselsanInternetCA`
5. Right-click **AselsanCA** → **All Tasks** → **Export**
6. In the Certificate Export Wizard, select the format:
   - **Base-64 encoded X.509 (.CER)**
7. Finish the wizard and save the file (e.g. `AselsanCA.cer`)
8. Repeat steps 5–7 for **AselsanInternetCA**

---

## Part 2 — Share the Certificates with the VM

### 2.1 Stage the files on Windows
1. Create a folder, e.g. `C:\VM-Share`
2. Copy both exported `.cer` files into it

### 2.2 Add a VirtualBox shared folder
1. **Shut down the Ubuntu VM** first — shared folders can't be added while it's running
2. Select the VM in VirtualBox Manager → **Settings** → **Shared Folders**
3. Click the folder icon with the **+**
4. Configure it as follows:

   | Setting | Value |
   |---|---|
   | Folder Path | `C:\VM-Share` |
   | Folder Name | `VM-Share` |
   | Auto-mount | Enabled |
   | Make Permanent | Enabled |
   | Read-only | Disabled |

5. Click **OK**

---

## Part 3 — Install Guest Additions & Access the Shared Folder (Ubuntu)

1. Start the VM, then update packages:
   ```bash
   $ sudo apt update
   ```
2. Install the build tools needed to compile the Guest Additions kernel modules:
   ```bash
   $ sudo apt install -y \
     build-essential \
     dkms \
     linux-headers-$(uname -r)
   ```
3. Install certificate tooling:
   ```bash
   $ sudo apt install -y ca-certificates openssl
   ```
4. With the VM still running, from the VirtualBox window menu: 
    **Devices → Insert Guest Additions CD Image**

5. A virtual disc icon will appear in Ubuntu — open it and run the installer 
6. Reboot:
   ```bash
   $ sudo reboot
   ```
7. After reboot, confirm the shared folder is visible:
   ```bash
   $ ls -l /media/sf_VM-Share
   ```
8. Add your user to the `vboxsf` group so it can read the shared folder:
   ```bash
   $ sudo usermod -aG vboxsf "$USER"
   ```
9. Reboot again for the new group membership to take effect:
   ```bash
   $ sudo reboot
   ```
10. Confirm the group was added:
    ```bash
    $ groups
    ```
    You should see `vboxsf` in the output.

---

## Part 4 — Install the Certificates into Ubuntu's Trust Store

1. Copy each `.cer` file into the system CA directory, renaming it to `.crt` 
    (`update-ca-certificates` only scans for `.crt` files here):
   ```bash
   $ sudo cp /media/sf_VM-Share/AselsanCA.cer \
     /usr/local/share/ca-certificates/AselsanCA.crt

   $ sudo cp /media/sf_VM-Share/AselsanInternetCA.cer \
     /usr/local/share/ca-certificates/AselsanInternetCA.crt
   ```
2. Refresh the system trust store:
   ```bash
   $ sudo update-ca-certificates
   ```
3. Restart `snapd` so it picks up the updated trust store:
   ```bash
   $ sudo systemctl restart snapd
   ```

---

## Verification

Confirm both certificates were picked up:
```bash
$ ls /etc/ssl/certs/ | grep -i aselsan
```
You should see entries for both certificates. You can also test a connection to an 
internal endpoint that previously failed TLS verification to confirm the error is gone.

## Notes

- `.cer` (Base-64/PEM) and `.crt` are the same encoding — renaming just satisfies
  `update-ca-certificates`, which only reads `.crt` files from `/usr/local/share/ca-certificates/`.
- Two reboots are expected in Part 3: one after the Guest Additions install, one after
  the `vboxsf` group change.
- If `/media/sf_VM-Share` isn't visible after the first reboot, double-check the shared
  folder settings in Part 2 and confirm Guest Additions installed without errors.
