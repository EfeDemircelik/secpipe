# Hadolint

Hadolint (Haskell Dockerfile Linter) is an analyzer for Dockerfiles that checks for syntax issues, best practices, and common mistakes. 

## 1. Prerequisites

* Linux (x86_64) environment (Ubuntu 26.04 is used in this project) 
* ``wget`` installed
    
    > $ sudo apt-get install wget

* ``sudo`` privilages

## 2. Installation

* Download the latest Hadolint binary

> $ wget https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64

* Make the binary executable

> $ chmod +x hadolint-Linux-x86_64

* Move it to the system path

> $ sudo mv hadolint-Linux-x86_64 /usr/local/bin/hadolint

## 3. Usage

### Use Hadolint on a Dockerfile

> $ hadolint Dockerfile

#### Output:

* DLxxxx (Docker Linter): These are Hadolint's native rules. They strictly check docker best practices.
* SCxxxx (ShellCheck): These aer ShellCheck rules for bash commands inside RUN statements. 

#### Severities:

* error: A serious issue that may cause the build to fail or the command to behave incorrectly.
* warning: The build can continue, but the Dockerfile contains risky, inefficient, or non-recommended practices.  
* info: Informational recommandations intended to improve readability and maintability.

#### Example Output:

> DL3007 warning: Using latest is prone to errors if the image will ever update. Pin the version explicitly to a release tag

## 4. Verification

### Verify the installation

> $ hadolint --version

#### Expected output:

> Haskell Dockerfile Linter `<version>`
