## Table of Contents

- [Overview](#overview)
- [Pre-Requisites](#pre-requisites)
  - [AWS](#aws)
    - [IAM (Identity Access Manager)](#iam-identity-access-manager)
    - [SES (Simple Email Service)](#ses-simple-email-service)
    - [Secrets Manager](#secrets-manager)
  - [Tailscale (Optional)](#tailscale-optional)
- [Setup Guide](#setup-guide)
    - [Step One:  Bootstrapping Dabian **`./intall/00.bootstrap.sh`**](#step-one--bootstrapping-dabian-intall00bootstrapsh)
    - [Step Two: Installing Dependencies **`./intall/01-dependencies.sh`**](#step-two-installing-dependencies-intall01-dependenciessh)
    - [Step Three: Tailscale (Optional)](#step-three-tailscale-optional)
        - [Step Three-Point-Five: Breather](#step-three-point-five-breather)
    - [Step Four: Nextcloud](#step-four-nextcloud)
      - [Deploy :  **`./helm/nextcloud/deploy.sh`**](#deploy---helmnextclouddeploysh)
      - [Cleanup :  **`./helm/nextcloud/cleanup.sh`**](#cleanup---helmnextcloudcleanupsh)


# Overview

The purpose of this repository is to automate my HomeLab environment. This Dabian deployment is currently being managed by Proxmox installed on the baremetal server. Everything in this repository should be able to take a fresh installation to a complete deployment of the listed services.

# Pre-Requisites 

Below are preparations that would need to be made to have a successful deployment. There are broad assumptions being made, but none of them should be major hurdles if the decision was made to opt-out of them. 

## AWS
To keep this environment secure for public viewing, I decided to leverage AWS Secrets Manager to hold the Tailscale and SOPs keys. There are many secrets throughout the deployment, but most of them are handled in the yaml files, being encrypted via age and SOPs.

### IAM (Identity Access Manager)

This goes without saying that in order to use these services, you'll need to create an IAM User and create an Access Key to pass to the installer. You will be prompted for those credentials from **`./intall/01-dependencies.sh`**. Down the road I may include some recommended policy documents to allow your user to access the various resources (As you should!) - but for development purposes, AdministratorAccess should be sufficient.

### SES (Simple Email Service)
For many of my HomeLab services, I am including a purchased domain that I am leveraging to send out HomeLab emails and alerts. This is aboslutely not required; in-fact, an interesting side project would be to set up a SMTP server - but why do that when we have AWS SES to make our lives easier.

### Secrets Manager
You can bypass AWS Secrets Manager by setting environment variables of the secrets listed below. The 'dependency' script just fetches and sets them. But below is the information you'll need to continue:

|  Secret Name | HomeLabSOPKey |
| ------------ | ------------ |
| Key  | null (not required for plaintext)  |
|  Value | Plantext formatted the same as the .txt file from SOPs  |

| Secret Name  | Tailscale_Access  | 
| ------------ | ------------ |
| Key | TAILNET  | 
|  Key | AUTH_KEY  |
| Key | API_KEY |


## Tailscale (Optional)
Ref: https://tailscale.com/

This is entirely optional. Given my current HomeLab network configurations, I am leveraging Tailscale for privledged access. If you are curious about Tailscale, it's very easy to get started and there are plenty of guides to gather the information you'll need to complete this guide. I believe the only place Tailscale is being referenced is the tailscale.sh script and the trustedDomains of the various values.yaml. 

# Setup Guide

This guide will assume that you are running off a fresh Dabian installation and you have taken into consideration the pre-requisites. If you decided to not go the AWS route, please ensure that you are modifying the **`./intall/01-dependencies.sh`** script to bypass those configurations.

### Step One:  Bootstrapping Dabian **`./intall/00.bootstrap.sh`**
- Basic hygiene by updating packages and installing the initial packages you'll need to move forward.
- Creates a volume mount from storaged passed with Proxmox **`/mnt/data`**

*WARNING* :  This script creates a volume mount with storage passed from Proxmox. If you are installing this on a already developed environment, please read lines 10-24 carefully. I have not made concessions for environments outside of my own (Proxmox/Dabian). What is most important is you end up with **`/mnt/data`** as it'll be required for the Helm deployments. 

### Step Two: Installing Dependencies **`./intall/01-dependencies.sh`**

- Docker
- Docker Compose
- K3
- Helm (linked to **`./install/get_helm.sh`**)
- Age
- SOPs
- AWS CLI 
-- Starts at line 57, this is where you would comment out if you don't go this route
- Fetch Secrets
-- TailScale to environment variables
-- SOPs to **`/.config/sops/age/keys.txt`**

It's worth pointing out, if you not looking to use AWS or SOPs, you can comment out line 57 onwards. If you are using my values.yaml, you'll have to include your own values anyways. But be warned, a lot of this is linked together (e.g., pv's, pvc's, names, db names, etc). *I never said it would be easy!*

### Step Three: Tailscale (Optional)

If you decided you wanted to go the Tailscale route and you have the required environment variables set (via export or 01-dependencies.sh), you can run the **`./install/tailscale.sh`** script to set that up for you.

##### Step Three-Point-Five: Breather
If you made it this far without issues, you can take a breather. A large part of the work is done, especially if you went with all of the optionals. The good news is, installing these applications is pretty straight forward **once you modify the values.yaml** of each. In the future, I may try to extract these outs to another file. I'm still learning. But for now, you should try to only modify all of the secrets if you can help it. It was a PAIN to get this working with persistence. NextCloud wasn't the easiest to get off the ground, but it's good now. 

### Step Four: Nextcloud

As mentioned in the breather, you should have already mocked up the secrets in the **`./helm/nextcloud/values.yaml`** file. Be careful and be mindful; Nextcloud can be *very* quirky with Helm. Many of times I told myself I was going back to TrueNas Scale, but I persisted. 

- Replace Encrypted Values with your own
- Remove SOPs jargon at the bottom
- PerstistentVolumes and PersistentVolumeClaims can be found at **`./k8s/nextcloud/`**
-- Remember, this requires the path from the **`./install/00-bootstrap.sh`** : **`/mnt/data`**.

#### Deploy :  **`./helm/nextcloud/deploy.sh`**
- Create 'nextcloud' namespace in k8s
- Create required PV's and PVC's
- Install Nextcloud via Helm

#### Cleanup :  **`./helm/nextcloud/cleanup.sh`**
- Uninstalls Nextcloud via Helm
- Deletes PV's and PVC's
- Deletes local paths created from deploy.sh
- Deletes 'nextcloud' namespace

This brings you back to a clean environment. You can only imagine why this exists.

