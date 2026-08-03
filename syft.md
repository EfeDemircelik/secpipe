# Syft

Syft is a Software Bill of Materials (SBOM) generation tool. It scans container images and filesystems, and produces a detailed inventory of installed packages and dependencies.

## 1. Prerequisites

* Linux (x86_64) environment

* `curl`installed

    > $ sudo apt-get install curl

* `sudo` privilages

## 2. Installation

* Install Syft

> $ curl -sSfL https://get.anchore.io/syft | sudo sh -s -- -b /usr/local/bin

The installation script downloads the latest Syft release and places the executable in `/usr/local/bin`.

## 3. Usage

### Generate software inverntory from an image:

> $ syft scan `<image_name:tag>`

Syft analyzes the container image and displays detected packages, libraries, and versions.

#### Example Output:

| NAME | VERSION | TYPE |
| --- | --- | --- |
| alpine-keys | 2.4-r0 | apk |
| apk-tools | 2.10.8-r1 | apk |
| busybox | 1.31.1-r22 | apk |

### Generate an SBOM:

> $ syft scan `<image_name:tag>`-o cyclonedx-json > `<file_name>`

The generated file contains a structured software inventory that can be analyzed by vulnerability scanners. 

## 4. Verification

### Verify the installation:

> $ syft version

#### Expected output

> Application: syft  
> Version: `<version>`

