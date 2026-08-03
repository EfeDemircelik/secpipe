# Cosign

Cosign is a tool for signing and verifying container images and other OCI artifacts.

## 1. Prerequisites

* Linux (x86_64) environment

* `wget`installed

    > $ sudo apt-get install wget

    verify installation:
    
    > $ wget --version

* `sudo` privilages

* Access to the target container registry (Docker Hub)

## 2. Installation

* Download the Cosign binary

> $ wget https://github.com/sigstore/cosign/releases/download/v2.4.1/cosign-linux-amd64

* Move the binary to the system path

> $ sudo mv cosign-linux-amd64 /usr/local/bin/cosign

* Make the binary executable

> $ sudo chmod +x /usr/local/bin/cosign

## 3. Usage

### Generate a key pair:

> $ cosign generate-key-pair

This command generates:

* ***cosign.key*** - private key used to sign container images.
* ***cosign.pub*** - public key used to verify image signatures

### Sign a container image:

> $ cosign sign --key cosign.key `<image_name@digest>`

This command signs the specified container image at the given digest with the private key, and pushes the signature to the registry alongside the image.

***Important:*** Cosign can only sign images that already exist in a registry, it can not sign a local-only image (e.g. one that's just been `docker build`, sitting in the local Docker image cache). The signature isn't stored inside the image itself; it's pushed to the registry as a separate object linked to the image.

### Verify a signed image:

> $ cosign verify --key cosign.pub `<image_name:tag>`

This command checks whether the image is signed.

* **If the image is signed, output:**

> Verification for `<registry>/<image_name>:<tag>` -- The following checks were performed on each of these signatures:   
> `-` The cosign claims were validated   
> `-` Existence of the claims in the transparency log was verified offline   
> `-` The signatures were verified against the specified public key   

A json array is returned - one entry per signature found.

* **If the image is not signed, output:**

> Error: no signatures found   
> main.go:69: error during command execution: no signatures found

Return code 10 means no signatures found, 12 means there is a different sign.

### View the signature tree:

> $ cosign tree `<image_name:tag>`

Displays the signatures, attestations, and SBOMs attached to an image. Accepts either a tag or a specific digest.

## 4. Verification

### Verify the installation

> $ cosign version

#### Expected output:

> GitVersion:   `<version>`

 
