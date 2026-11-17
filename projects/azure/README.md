# Azure Windows Server infrastructure lab

**Status: deployment-ready Bicep example; not deployed or validated in an Azure subscription.**

## Scenario
Provision a Windows Server 2022 VM in a private VNet subnet with an NSG, managed OS disk, boot diagnostics and a Log Analytics workspace. No public IP and no inbound internet access. The workspace is provisioned, **but guest telemetry is not connected**; configuring Azure Monitor Agent + a Data Collection Rule is a separate follow-up.

## Architecture
Resource group → VNet 10.52.0.0/16 → workload subnet 10.52.1.0/24 → NIC/NSG → private Windows VM. Separate Log Analytics workspace. No bastion or VPN is included, so the VM cannot be interactively reached from the public internet.

## Requirements
Azure CLI, a subscription with sufficient quota and permissions, and a secure administrator password. VM, storage and monitoring costs may apply. Deploy only to a disposable resource group.

## Run
```bash
az login
az account show --output table
az group create --name rg-portfolio-lab --location uksouth
az deployment group what-if --resource-group rg-portfolio-lab --template-file main.bicep
read -r -s -p 'Temporary lab VM password: ' LAB_VM_PASSWORD; echo
az deployment group create --resource-group rg-portfolio-lab --template-file main.bicep --parameters adminPassword="$LAB_VM_PASSWORD"
unset LAB_VM_PASSWORD
az vm show -g rg-portfolio-lab -n portfolio-lab-vm -d --output table
```
The example uses Bash to prompt without echoing the password and clears the shell variable afterwards. For production use, prefer a secret store and managed deployment identity; command-line arguments may still be visible to local process inspection. Check that the VM has no public IP, the NSG denies Internet inbound, boot diagnostics is enabled, and the workspace exists. A workspace alone does not prove log collection.

## Evidence checklist
- [ ] Bicep build/what-if and deployment results (sanitized)
- [ ] VNet/subnet/NSG/VM inventory
- [ ] VM boot diagnostics screenshot
- [ ] Workspace screenshot (clearly note whether data collection was configured)
- [ ] Cost estimate, date, validation results and cleanup confirmation

## Cleanup
`az group delete --name rg-portfolio-lab --yes --no-wait` (verify the group contains only disposable lab resources).
