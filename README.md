
# Azure VM Image Builder

This repository provides Infrastructure as Code (IaC) templates and automated workflows for building custom Azure Virtual Machine (VM) images using Azure Image Builder. The solution leverages Bicep templates for declarative infrastructure deployment and GitHub Actions for CI/CD automation, enabling consistent and repeatable image creation across different environments and operating systems.

## Repository Structure

```
azure-vm-image-builder/
├── .github/
│   └── workflows/          # GitHub Actions workflows for automated deployment
├── iac/                    # Infrastructure as Code using Bicep
│   ├── image-gallery/      # Azure Compute Gallery and image definitions
│   ├── image-template-linux/  # Image template for Linux (RHEL) builds
│   ├── image-template-windows/ # Image template for Windows builds
│   ├── pre-requisite/      # Core infrastructure (VNet, storage, DNS)
│   ├── resource-group/     # Resource group definitions
│   └── role-assignment/    # RBAC role assignments and managed identities
├── scripts/                # Python scripts for automation
│   └── aap_request.py      # Ansible Automation Platform integration
├── files/                  # Static files (Python installer, modules, etc.)
├── tagsFile.yaml           # Common resource tags
├── id_ed25519.pub          # SSH public key for VM access
└── LICENSE                 # Repository license
```

## Infrastructure as Code (IaC) Overview

The `iac/` folder contains Bicep templates that define the complete Azure infrastructure required for VM image building. All templates follow Azure best practices and include proper tagging, security configurations, and modular design.

### Core Infrastructure (`pre-requisite/`)

Deploys foundational resources required for image building:

- **Virtual Network (VNet)**: Isolated network with subnets for VM and Azure Container Instance (ACI) usage
- **Storage Account**: Secure blob storage for scripts, files, and artifacts with private endpoints
- **Private DNS Zone**: Enables private connectivity to storage services

**Key Parameters:**
- `location`: Azure region for deployment
- `environment`: Environment name (dev/prod)
- `projectName`: Project identifier
- `storageAccountName`: Unique storage account name

### Resource Groups (`resource-group/`)

Creates dedicated resource groups for different components:

- **Image Builder RG**: Contains image templates and build resources
- **Image Gallery RG**: Hosts Azure Compute Gallery for image storage
- **Staging RGs**: Temporary resources for Linux (RHEL) and Windows builds

**Scope:** Subscription-level deployment

### Role Assignments (`role-assignment/`)

Configures Role-Based Access Control (RBAC) and managed identities:

- **User Assigned Identities**: Separate identities for image builder and VM operations
- **Built-in Roles**: Contributor, Storage Blob Data Reader, Managed Identity Operator
- **Custom Roles**: Specialized permissions for image building operations

**Key Features:**
- Least-privilege access principles
- Scoped to appropriate resource groups
- Automated identity management

### Image Gallery (`image-gallery/`)

Sets up Azure Compute Gallery for image storage and distribution:

- **Shared Image Gallery**: Centralized repository for custom images
- **Image Definitions**: Metadata for different OS types (Linux/Windows)
- **Replication**: Cross-region image distribution

**Supported OS Types:**
- RHEL 9/10 (Linux)
- Windows Server 2022/2025

### Image Templates (`image-template-linux/`, `image-template-windows/`)

Defines Azure Image Builder templates for custom image creation:

**Common Features:**
- Base OS customization (RHEL/Windows Server)
- Software installation and configuration
- Security hardening
- Network configuration
- Integration with Ansible Automation Platform (AAP)

**Linux-Specific (RHEL):**
- SSH key injection
- Python environment setup
- AAP workflow triggering for configuration management

**Windows-Specific:**
- WinRM configuration
- PowerShell-based customization
- Python module installation
- AAP integration

**Key Parameters:**
- `galleryImageId`: Target gallery image definition
- `stagingResourceGroupName`: Temporary build resources
- `aapServer`, `aapToken`: AAP integration credentials
- `replicationRegions`: Target regions for image distribution

## Automated Workflows

The repository includes GitHub Actions workflows for end-to-end automation of the image building process.

### Prerequisites

Before running workflows, ensure:

1. **Azure Service Principal**: With appropriate permissions for resource deployment
2. **GitHub Secrets**: Configure the following in your repository/environment:
   - `AZURE_TENANT_ID`: Azure tenant ID
   - `AZURE_CLIENT_ID`: Service principal client ID
   - `AZURE_SUBSCRIPTION_ID`: Target subscription ID
   - `AAP_TOKEN`: Ansible Automation Platform token
   - `VM_USERNAME`: VM admin username
   - `VM_PASSWORD`: VM admin password
3. **GitHub Variables**: Set `AIB_RESOURCE_GROUP_NAME` and `AAP_SERVER`
4. **Self-hosted Runner**: Workflows require a runner labeled `cicd` with Azure CLI installed

### Workflow: Pre-requisite Resources (`pre-requisite.yml`)

**Purpose:** Deploy core infrastructure components

**Trigger:** Manual (`workflow_dispatch`)

**Inputs:**
- `environment_type`: DEV or PROD
- `location`: Azure region (e.g., australiaeast)
- `os_type`: OS type (not used in this workflow)

**What it does:**
1. Deploys VNet, storage account, and private DNS zone
2. Configures network security and private endpoints
3. Sets up secure artifact storage

**Run Order:** Execute this workflow first before any image building

### Workflow: Role Assignment (`role-assignment.yml`)

**Purpose:** Configure RBAC and managed identities

**Trigger:** Manual (`workflow_dispatch`)

**Inputs:**
- `environment_type`: DEV or PROD

**What it does:**
1. Creates user-assigned managed identities
2. Assigns necessary roles for image building operations
3. Configures permissions for storage and compute resources

**Run Order:** Execute after pre-requisite resources are deployed

### Workflow: Create Image Gallery (`acg.yml`)

**Purpose:** Set up Azure Compute Gallery

**Trigger:** Manual (`workflow_dispatch`)

**Inputs:**
- `environment_type`: DEV or PROD
- `location`: Azure region
- `os_type`: Target OS type

**What it does:**
1. Creates shared image gallery
2. Defines image definitions for specified OS
3. Configures gallery permissions

**Run Order:** Execute after role assignments

### Workflow: Build Image (`build-image.yml`)

**Purpose:** Execute custom image creation

**Trigger:** Manual (`workflow_dispatch`)

**Inputs:**
- `environment_type`: DEV or PROD
- `location`: Azure region
- `os_type`: OS type (rhel9, rhel10, win22, win25)

**What it does:**
1. Deploys image builder template
2. Initiates image build process
3. Monitors build status and completion
4. Distributes image to configured regions

**Key Features:**
- Supports both Linux (RHEL) and Windows builds
- Integrates with AAP for post-build configuration
- Automatic cleanup of temporary resources

**Run Order:** Execute after all prerequisite workflows

### Workflow Execution Order

1. **Pre-requisite** → Deploy core infrastructure
2. **Role Assignment** → Configure permissions
3. **Image Gallery** → Set up image storage
4. **Build Image** → Create custom images

## Usage Instructions

### 1. Initial Setup

1. Clone the repository
2. Configure GitHub secrets and variables as described in Prerequisites
3. Ensure self-hosted runner is available

### 2. Deploy Infrastructure

Execute workflows in the specified order:

1. Run `Pre-requisite Resources` workflow
2. Run `Role Assignment` workflow  
3. Run `Create Image Gallery` workflow

### 3. Build Custom Images

1. Run `Build Image` workflow with desired OS type
2. Monitor workflow execution in GitHub Actions
3. Verify image creation in Azure Compute Gallery

### 4. Integration with AAP

The image templates include AAP integration for automated configuration:

- Linux builds trigger AAP workflows for software installation
- Windows builds use PowerShell for initial setup, then AAP for advanced configuration
- Monitor AAP job status through the Python script in `scripts/aap_request.py`

## Next Plan

Adding ansible code that will be used in Ansible Automation Platform (AAP) to complete the E2E automation.

## Security Considerations

- All sensitive data (passwords, tokens) are stored as GitHub secrets
- Managed identities are used for Azure resource access
- Private endpoints ensure secure communication
- Least-privilege RBAC assignments

## Contributing

1. Follow Bicep best practices for template development
2. Test workflows in DEV environment before PROD deployment
3. Update documentation for any infrastructure changes
4. Ensure all secrets are properly configured

## License

This project is licensed under MIT license.
