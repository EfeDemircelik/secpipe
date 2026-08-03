# Kyverno

Kyverno is a Kubernetes-native policy engine. It runs inside a Kubernetes cluster and can validate, mutate, generate, and verify Kubernetes resources based on defined policies.

## 1. Prerequisites

* Linux (x86_64) environment

* `curl`installed

    > $ sudo apt-get install curl

* `sudo` privilages

* K3s installed and running

    Install K3s:

    > $ curl -sfL https://get.k3s.io | sh -

    Check the K3s service: 

    > $ sudo systemctl status k3s

* Kubernetes cluster access configured  
    K3s stores its kubeconfig file at `/etc/rancher/k3s/k3s.yaml`. Configure to use this file and make it persistent:

    > $ echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc

    > $ source ~/.bashrc 

    If the current user cannot read the kubeconfig file:

    > $ sudo chmod 644 /etc/rancher/k3s/k3s.yaml

    This command makes the file readable by every local user. It should not be used on shared or production systems.

* Kubernetes node available

    > $ kubectl get nodes

    Expected output:

    | NAME | STATUS | ROLES | AGE | VERSION |
    | --- | --- | --- | --- | --- |
    | `node_name` | Ready | control-plane | `<time>` | `<version>` |


* `helm` installed

    > $ sudo snap install helm --classic

    Verify the `helm` installation:

    > $ helm version

## 2. Installation

* Add the kyverno helm repository

> $ helm repo add kyverno https://kyverno.github.io/kyverno/

This command adds the official Kyverno Helm chart repository.

* Update the Helm repositories

> $ helm repo update

This command downloads the latest chart information from the configured Helm repositories.

* Install Kyverno

> $ helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace

This command creates the kyverno namespace, installs the kyverno helm chart and creates Kyverno controllers, services, webhooks, and roles.

## 3. Usage

### Apply a Kyverno policy

> $ kubectl apply -f `<policy_file_name>`.yaml

Kyverno policies are defined in YAML files.

### List cluster policies

> $ kubectl get clusterpolicy

This command displays the cluster-wide Kyverno policies.

### Inspect a policy

> $ kubectl describe clusterpolicy `<policy_name>`

This command displays the policy rules, status, conditions and related events.

### Run a pod for policy testing

> $ kubectl run `<pod_name>` --image=`<image_name:tag>

If the image satisfies the Kyverno policy, Kubernetes creates the pod.

If the image violates an enforced policy, Kyverno rejects the pod creation request and returns an admission webhook error.

#### Check whether the pod was created

> $ kubectl get pods

#### Delete the test pod after the test

> $ kubectl delete pod `<pod_name>`

### Remove a policy

> $ kubectl delete clusterpolicy `<policy_name>`

### View Kyverno logs

First, list the kyverno pods:

> $ kubectl get pods -n kyverno

Then view the logs of a specific pod:

> $ kubectl logs -n kyverno `<kyverno_pod_name>` 

## 4. Verification

### Verify the Helm release

> $ helm list -n kyverno

#### Expected output:

| NAME | NAMESPACE | STATUS | CHART | APP VERSION |
| --- | --- | --- | --- | --- |
| kyverno | kyverno | deployed | kyverno-`<chart_version>` | `<app_version>` |

### Verify the Kyverno pods

> $ kubectl get pods -n kyverno

#### Expected output:

| NAME | READY | STATUS | RESTARTS |
| --- | --- | --- | --- |
| kyverno-admission-controller-`<id>` | 1/1 | Running | `<restart_count>` |
| kyverno-background-controller-`<id>` | 1/1 | Running | `<restart_count>` |
| kyverno-cleanup-controller-`<id>` | 1/1 | Running | `<restart_count>` |
| kyverno-reports-controller-`<id>` | 1/1 | Running | `<restart_count>` |

### Verify an applied policy

> $ kubectl get clusterpolicy

#### Expected output:

| NAME | ADMISSION | BACKGROUND | READY | AGE | MESSAGE |
| --- | --- | --- | --- | --- | --- |
| `<policy_name>` | true | false | true | `<age>` | Ready |

