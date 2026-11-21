
#Requires -Version 7.0

<#
.SYNOPSIS
    Validates AWS infrastructure deployed using Terraform.

.DESCRIPTION
    Reads Terraform outputs and checks that the VPC,
    subnets, internet gateway, and security groups
    exist in the configured AWS account and region.
#>

[CmdletBinding()]
param(
    [string]$Profile = "portfolio",
    [string]$Region = "eu-north-1"
)

$ErrorActionPreference = "Stop"

$TerraformPath = Join-Path $PSScriptRoot "..\terraform"

function Invoke-AWSCLI {
    param(
        [string[]]$Arguments
    )

    $Result = & aws @Arguments --profile $Profile --region $Region --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI failed: $($Result -join ' ')"
    }

    return ($Result | Out-String | ConvertFrom-Json)
}

Write-Host "Validating AWS infrastructure..." -ForegroundColor Cyan

# Verify AWS authentication
$Identity = Invoke-AWSCLI -Arguments @("sts", "get-caller-identity")
Write-Host "AWS account: $($Identity.Account)"

# Retrieve Terraform outputs
Push-Location $TerraformPath

try {
    $OutputJson = & terraform output -json

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve Terraform outputs."
    }

    $Outputs = $OutputJson | ConvertFrom-Json
}
finally {
    Pop-Location
}

# Validate VPC
$VpcId = $Outputs.vpc_id.value

$Vpc = Invoke-AWSCLI -Arguments @(
    "ec2", "describe-vpcs",
    "--vpc-ids", $VpcId
)

$ExpectedVpcCidr = "10.0.0.0/16"

if (
    $Vpc.Vpcs.Count -eq 1 -and
    $Vpc.Vpcs[0].CidrBlock -eq $ExpectedVpcCidr
) {
    Write-Host "[PASS] VPC exists: $VpcId" -ForegroundColor Green
    Write-Host "[PASS] VPC CIDR: $ExpectedVpcCidr" -ForegroundColor Green
}
else {
    throw "VPC validation failed. Expected CIDR: $ExpectedVpcCidr"
}

# Validate subnets and CIDR ranges
$ExpectedSubnets = [ordered]@{
    public_subnet_id      = "10.0.1.0/24"
    application_subnet_id = "10.0.2.0/24"
    database_subnet_id    = "10.0.3.0/24"
}

foreach ($Name in $ExpectedSubnets.Keys) {
    $SubnetId = $Outputs.$Name.value
    $ExpectedCidr = $ExpectedSubnets[$Name]

    $Subnet = Invoke-AWSCLI -Arguments @(
        "ec2", "describe-subnets",
        "--subnet-ids", $SubnetId
    )

    if (
        $Subnet.Subnets.Count -eq 1 -and
        $Subnet.Subnets[0].VpcId -eq $VpcId -and
        $Subnet.Subnets[0].CidrBlock -eq $ExpectedCidr
    ) {
        Write-Host "[PASS] $Name : $SubnetId" -ForegroundColor Green
        Write-Host "[PASS] CIDR: $ExpectedCidr" -ForegroundColor Green
    }
    else {
        throw "Subnet validation failed: $Name. Expected CIDR: $ExpectedCidr"
    }
}

foreach ($Name in $SubnetOutputs) {
    $SubnetId = $Outputs.$Name.value

    $Subnet = Invoke-AWSCLI -Arguments @(
        "ec2", "describe-subnets",
        "--subnet-ids", $SubnetId
    )

    if (
        $Subnet.Subnets.Count -eq 1 -and
        $Subnet.Subnets[0].VpcId -eq $VpcId
    ) {
        Write-Host "[PASS] $Name : $SubnetId" -ForegroundColor Green
    }
    else {
        throw "Subnet validation failed: $Name"
    }
}

# Validate internet gateway
$GatewayId = $Outputs.internet_gateway_id.value

$Gateway = Invoke-AWSCLI -Arguments @(
    "ec2", "describe-internet-gateways",
    "--internet-gateway-ids", $GatewayId
)

if (
    $Gateway.InternetGateways.Count -eq 1 -and
    $Gateway.InternetGateways[0].Attachments.VpcId -contains $VpcId
) {
    Write-Host "[PASS] Internet Gateway: $GatewayId" -ForegroundColor Green
}
else {
    throw "Internet Gateway validation failed."
}

# Validate route tables
Write-Host "`nValidating route tables..." -ForegroundColor Cyan

$ExpectedRouteTables = [ordered]@{
    public      = $Outputs.public_subnet_id.value
    application = $Outputs.application_subnet_id.value
    database    = $Outputs.database_subnet_id.value
}

foreach ($Tier in $ExpectedRouteTables.Keys) {
    $SubnetId = $ExpectedRouteTables[$Tier]

    $RouteTables = Invoke-AWSCLI -Arguments @(
        "ec2", "describe-route-tables",
        "--filters", "Name=association.subnet-id,Values=$SubnetId"
    )

    if ($RouteTables.RouteTables.Count -ne 1) {
        throw "Expected one explicitly associated route table for $Tier subnet."
    }

    $RouteTable = $RouteTables.RouteTables[0]

    if ($RouteTable.VpcId -ne $VpcId) {
        throw "Route table for $Tier belongs to an unexpected VPC."
    }

    $DefaultRoutes = @(
        $RouteTable.Routes | Where-Object {
            $_.DestinationCidrBlock -eq "0.0.0.0/0"
        }
    )

    if ($Tier -eq "public") {
        $ExpectedGatewayId = $Outputs.internet_gateway_id.value

        if (
            $DefaultRoutes.Count -ne 1 -or
            $DefaultRoutes[0].GatewayId -ne $ExpectedGatewayId -or
            $DefaultRoutes[0].State -ne "active"
        ) {
            throw "Public subnet does not have an active default route via the expected Internet Gateway."
        }
    }
    else {
        $DirectInternetRoutes = @(
            $DefaultRoutes | Where-Object {
                $_.GatewayId -like "igw-*"
            }
        )

        if ($DirectInternetRoutes.Count -gt 0) {
            throw "$Tier subnet has an unexpected direct Internet Gateway route."
        }
    }

    Write-Host "[PASS] $Tier route table: $($RouteTable.RouteTableId)" -ForegroundColor Green
}

# Validate route table routes and subnet associations
Write-Host "`nValidating route table routes and associations..." -ForegroundColor Cyan

$ExpectedRouteTables = @(
    @{
        Name       = "public"
        Subnet     = "public_subnet_id"
        Public     = $true
    },
    @{
        Name       = "application"
        Subnet     = "application_subnet_id"
        Public     = $false
    },
    @{
        Name       = "database"
        Subnet     = "database_subnet_id"
        Public     = $false
    }
)

$RouteTableData = Invoke-AWSCLI -Arguments @(
    "ec2", "describe-route-tables",
    "--filters", "Name=vpc-id,Values=$VpcId"
)

foreach ($Expected in $ExpectedRouteTables) {

    $SubnetId = $Outputs.($Expected.Subnet).value

    $RouteTable = @(
        $RouteTableData.RouteTables | Where-Object {
            $_.Associations | Where-Object {
                $_.SubnetId -eq $SubnetId -and
                $_.AssociationState.State -eq "associated"
            }
        }
    )

    if ($RouteTable.Count -ne 1) {
        throw "Route table association validation failed: $($Expected.Name)"
    }

    Write-Host "[PASS] $($Expected.Name) subnet association" -ForegroundColor Green

    $Routes = @($RouteTable[0].Routes)

    $LocalRoutes = @(
        $Routes | Where-Object {
            $_.DestinationCidrBlock -eq "10.0.0.0/16" -and
            $_.GatewayId -eq "local" -and
            $_.State -eq "active"
        }
    )

    if ($LocalRoutes.Count -ne 1) {
        throw "Local route validation failed: $($Expected.Name)"
    }

    Write-Host "[PASS] $($Expected.Name) local route" -ForegroundColor Green

    $DefaultRoutes = @(
        $Routes | Where-Object {
            $_.DestinationCidrBlock -eq "0.0.0.0/0"
        }
    )

    if ($Expected.Public) {

        $GatewayId = $Outputs.internet_gateway_id.value

        if (
            $DefaultRoutes.Count -ne 1 -or
            $DefaultRoutes[0].GatewayId -ne $GatewayId -or
            $DefaultRoutes[0].State -ne "active"
        ) {
            throw "Public internet route validation failed."
        }

        Write-Host "[PASS] Public internet route: $GatewayId" -ForegroundColor Green
    }
    else {
        if ($DefaultRoutes.Count -ne 0) {
            throw "Unexpected internet route found: $($Expected.Name)"
        }

        Write-Host "[PASS] $($Expected.Name) has no IPv4 default route" -ForegroundColor Green
    }

    if ($Expected.Public -and $Routes.Count -ne 2) {
        throw "Unexpected routes found in public route table."
    }

    if (-not $Expected.Public -and $Routes.Count -ne 1) {
        throw "Unexpected routes found in $($Expected.Name) route table."
    }
}

Write-Host "Route table validation completed successfully." -ForegroundColor Green

# Validate security groups
$SecurityGroupOutputs = @(
    "web_security_group_id",
    "application_security_group_id",
    "database_security_group_id"
)

foreach ($Name in $SecurityGroupOutputs) {
    $GroupId = $Outputs.$Name.value

    $Group = Invoke-AWSCLI -Arguments @(
        "ec2", "describe-security-groups",
        "--group-ids", $GroupId
    )

    if (
        $Group.SecurityGroups.Count -eq 1 -and
        $Group.SecurityGroups[0].VpcId -eq $VpcId
    ) {
        Write-Host "[PASS] $Name : $GroupId" -ForegroundColor Green
    }
    else {
        throw "Security group validation failed: $Name"
    }
}

# Validate security group traffic rules
Write-Host "`nValidating security group traffic rules..." -ForegroundColor Cyan

$WebSG = $Outputs.web_security_group_id.value
$AppSG = $Outputs.application_security_group_id.value
$DbSG  = $Outputs.database_security_group_id.value

function Test-SecurityGroupRule {
    param(
        [string]$GroupId,
        [string]$Direction,
        [int]$Port,
        [string]$SourceGroupId,
        [string]$Cidr
    )

    $Group = Invoke-AWSCLI -Arguments @(
        "ec2", "describe-security-groups",
        "--group-ids", $GroupId
    )

    if ($Group.SecurityGroups.Count -ne 1) {
        throw "Security group not found: $GroupId"
    }

    $Permissions = if ($Direction -eq "Inbound") {
        $Group.SecurityGroups[0].IpPermissions
    }
    else {
        $Group.SecurityGroups[0].IpPermissionsEgress
    }

    $MatchingRules = @(
        $Permissions | Where-Object {
            $_.IpProtocol -eq "tcp" -and
            $_.FromPort -eq $Port -and
            $_.ToPort -eq $Port -and
            (
                (
                    $SourceGroupId -and
                    $_.UserIdGroupPairs.GroupId -contains $SourceGroupId
                ) -or
                (
                    $Cidr -and
                    $_.IpRanges.CidrIp -contains $Cidr
                )
            )
        }
    )

    if ($MatchingRules.Count -ne 1) {
        throw "Missing $Direction TCP/$Port rule on $GroupId"
    }

    Write-Host "[PASS] $Direction TCP/$Port on $GroupId" -ForegroundColor Green
}

# Web inbound rules
Test-SecurityGroupRule -GroupId $WebSG `
    -Direction Inbound -Port 80 -Cidr "0.0.0.0/0"

Test-SecurityGroupRule -GroupId $WebSG `
    -Direction Inbound -Port 443 -Cidr "0.0.0.0/0"

# Web to application
Test-SecurityGroupRule -GroupId $WebSG `
    -Direction Outbound -Port 8080 -SourceGroupId $AppSG

Test-SecurityGroupRule -GroupId $AppSG `
    -Direction Inbound -Port 8080 -SourceGroupId $WebSG

# Application to database
Test-SecurityGroupRule -GroupId $AppSG `
    -Direction Outbound -Port 5432 -SourceGroupId $DbSG

Test-SecurityGroupRule -GroupId $DbSG `
    -Direction Inbound -Port 5432 -SourceGroupId $AppSG

# Confirm database has no outbound rules
$DatabaseGroup = Invoke-AWSCLI -Arguments @(
    "ec2", "describe-security-groups",
    "--group-ids", $DbSG
)

if (@($DatabaseGroup.SecurityGroups[0].IpPermissionsEgress).Count -ne 0) {
    throw "Database security group has unexpected outbound rules."
}

# Validate security group least-privilege configuration
Write-Host "`nValidating security group least privilege..." -ForegroundColor Cyan

$WebSgId = $Outputs.web_security_group_id.value
$AppSgId = $Outputs.application_security_group_id.value
$DbSgId  = $Outputs.database_security_group_id.value

$ExpectedRules = @(
    @{
        Group = $WebSgId
        Direction = "ingress"
        Protocol = "tcp"
        Port = 80
        Cidr = "0.0.0.0/0"
        PeerGroup = $null
    },
    @{
        Group = $WebSgId
        Direction = "ingress"
        Protocol = "tcp"
        Port = 443
        Cidr = "0.0.0.0/0"
        PeerGroup = $null
    },
    @{
        Group = $WebSgId
        Direction = "egress"
        Protocol = "tcp"
        Port = 8080
        Cidr = $null
        PeerGroup = $AppSgId
    },
    @{
        Group = $AppSgId
        Direction = "ingress"
        Protocol = "tcp"
        Port = 8080
        Cidr = $null
        PeerGroup = $WebSgId
    },
    @{
        Group = $AppSgId
        Direction = "egress"
        Protocol = "tcp"
        Port = 5432
        Cidr = $null
        PeerGroup = $DbSgId
    },
    @{
        Group = $DbSgId
        Direction = "ingress"
        Protocol = "tcp"
        Port = 5432
        Cidr = $null
        PeerGroup = $AppSgId
    }
)

$SecurityGroupIds = @($WebSgId, $AppSgId, $DbSgId)

$RuleData = Invoke-AWSCLI -Arguments @(
    "ec2", "describe-security-group-rules",
    "--filters", "Name=group-id,Values=$($SecurityGroupIds -join ',')"
)

$ActualRules = @($RuleData.SecurityGroupRules)

if ($ActualRules.Count -ne $ExpectedRules.Count) {
    throw "Security group rule count mismatch. Expected $($ExpectedRules.Count), found $($ActualRules.Count)."
}

foreach ($Expected in $ExpectedRules) {

    $Matches = @(
        $ActualRules | Where-Object {
            $Rule = $_

            $Direction = if ($Rule.IsEgress) {
                "egress"
            }
            else {
                "ingress"
            }

            $PeerGroupId = if ($null -ne $Rule.ReferencedGroupInfo) {
                $Rule.ReferencedGroupInfo.GroupId
            }
            else {
                $null
            }

            $Rule.GroupId -eq $Expected.Group -and
            $Direction -eq $Expected.Direction -and
            $Rule.IpProtocol -eq $Expected.Protocol -and
            $Rule.FromPort -eq $Expected.Port -and
            $Rule.ToPort -eq $Expected.Port -and
            $Rule.CidrIpv4 -eq $Expected.Cidr -and
            $PeerGroupId -eq $Expected.PeerGroup
        }
    )

    if ($Matches.Count -ne 1) {
        throw "Unexpected or missing security group rule: $($Expected.Group) $($Expected.Direction) TCP/$($Expected.Port)"
    }

    Write-Host "[PASS] $($Expected.Direction) TCP/$($Expected.Port) on $($Expected.Group)" -ForegroundColor Green
}

Write-Host "[PASS] No unexpected security group rules found." -ForegroundColor Green
Write-Host "Security group least-privilege validation completed successfully." -ForegroundColor Green

Write-Host "[PASS] Database security group has no outbound rules." -ForegroundColor Green

Write-Host "`nInfrastructure validation completed successfully." -ForegroundColor Green
