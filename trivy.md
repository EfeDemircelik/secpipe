# Trivy

Trivy is a comprehensive security scanner that detects vulnerabilities (CVEs), misconfigurations, exposed secrets, and software licenses.

## 1. Prerequisites

* Linux (x86_64) environment (Ubuntu 26.04 is used in this project)
* ``wget`` and ``gnupg`` packages

    > $ sudo apt-get install wget gnupg

* ``sudo`` privilages

## 2. Installation

* Import the Trivy repository

> $ wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null

* Add the Trivy repository

> $ echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee -a /etc/apt/sources.list.d/trivy.list

* Update package lists

> $ sudo apt-get update

* Install Trivy

> $ sudo apt-get install trivy

## 3. Usage

### Scan a container image:

> $ trivy image `<image_name:tag>`

Scans the specified container image.

#### Example output:

| Library | Vulnerability | Severity | Status | Installed Version | Fixed Version | Title |
| --- | --- | --- | --- | --- | --- | --- |
| sqlite-libs | CVE-2019-8457 | CRITICAL | fixed | 3.26.0-r3 | 3.28.0-r0 | sqlite: heap out-of-bound read in function rtreenode() https://avd.aquasec.com/nvd/cve-2019-8457 |

### Scan only for vulnerabilities:

> $ trivy image --scanners vuln `<image_name:tag>`

Limits the scan to known vulnerabilities (CVEs).

### Show only HIGH and CRITICAL vulnerabilities:

> $ trivy image --scanners vuln --severity HIGH,CRITICAL `<image_name:tag>`

Outputs only the HIGH and CRITICAL severity vulnerabilities. 

### Export scan results as JSON:

> $ trivy image --format json -o result-trivy.json `<image_name:tag>`

Saves the result in JSON format.

### Scan the filesystem:

> $ trivy fs `</path/to/project>`

Scans the specified directory.

## 4. Verification

### Verify the installation:

> $ trivy --version

#### Expected Output:

> Version: `<version>`

