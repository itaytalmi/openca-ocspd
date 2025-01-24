# openca-ocspd

OpenCA OCSP Daemon Container

This repository contains the source code for the OpenCA OCSP Daemon container, as well as the deployment configuration for Kubernetes.

The original purpose of this repository is to integrate the HashiCorp Vault PKI Secrets Engine with an external OCSP server, to query the CRL and OCSP status of issued certificates. This Kubernetes-based deployment uses an init container to download the CRL from the Vault PKI Secrets Engine and update the CRL in the OCSP Daemon configuration. Additionally, there is a second container that continiously updates the CRL.

This repository can be used as a reference for other deployments and implementations of the OpenCA OCSP Daemon.

## Build

```bash
docker build -t openca-ocspd:3.1.3-b2 .
```

To build and push the container image to a container registry, you can refer to the following commands:

```bash
IMAGE_REGISTRY="harbor.demo.cloudnativeapps.cloud"
IMAGE_TAG="openca-ocspd/openca-ocspd:3.1.3-b2"
docker login $IMAGE_REGISTRY
docker build -t $IMAGE_REGISTRY/$IMAGE_TAG . --push
```

## Requirements

You must issue a certificate for the OCSP Daemon using the relevant CA. The certificate must be issued with the `OCSPSigning` key usage.

When using HashiCorp Vault, you can refer to the following example for issuing the certificate:

```bash
# Create a role for the OCSP Daemon
vault write pki-int-ext-ocsp/roles/ocsp-role \
    key_usage="DigitalSignature" \
    ext_key_usage="OCSPSigning" \
    allowed_domains="demo.cloudnativeapps.lab" \
    allow_subdomains=true \
    max_ttl="12000h"

# Issue a certificate for the OCSP Daemon
vault write pki-int-ext-ocsp/issue/ocsp-role \
    common_name="ocsp.demo.cloudnativeapps.lab"
```

## Deploy to Kubernetes

Create a Kubernetes namespace.

```bash
kubectl create namespace openca-ocspd
```

Create a secret containing the CA certificate and the OCSP Daemon certificate and key.

```bash
kubectl create secret generic ocsp-certs -n openca-ocspd \
    --from-literal=ca.crt=<ca-certificate> \
    --from-literal=tls.crt=<ocspd-certificate> \
    --from-literal=tls.key=<ocspd-key>
```

In the `deploy/deployment.yaml` file, replace the `VAULT_CRL_URL` and the ingress hostname with the appropriate values.

Deploy the OCSP Daemon.

```bash
kubectl apply -f deploy/deployment.yaml
```
