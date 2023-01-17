<#

This script is intended to gather information about all virtual networks in all subscriptions of an Azure account. The output will include the subscription name, virtual network name, DDoS protection plan, and resource tags. The script will export all the information to a CSV file named VirtualNetworks.csv. It will also handle the case where a virtual network does not have a DDoS protection plan and will output "NA" in the DdosProtectionPlan column for that virtual network.

#>

# Connect to Azure account
Connect-AzAccount

# Login to the selected tenant
Add-AzAccount -Tenant <insert-tenant-id>

# Create an empty hash table to store the DDoS protection plan and virtual network objects
$cache = @{}

$subscriptions = Get-AzSubscription | Where-Object {$_.State -eq "Enabled" }
foreach ($subscription in $subscriptions) {
    Select-AzSubscription -SubscriptionId $subscription.Id
    # check if the DDoS protection plans and virtual networks for the current subscription are already in the cache
    if ($cache.ContainsKey($subscription.Id)) {
        # Get the DDoS protection plans and virtual networks from the cache
        $ddosPlans = $cache[$subscription.Id].ddosPlans
        $vnets = $cache[$subscription.Id].vnets
    } else {
        # Retrieve the DDoS protection plans and virtual networks from Azure
        $ddosPlans = Get-AzDdosProtectionPlan
        $vnets = Get-AzVirtualNetwork
        # Add the DDoS protection plans and virtual networks to the cache
        $cache.Add($subscription.Id, @{
            ddosPlans = $ddosPlans
            vnets = $vnets
        })
    }
}

$allVnets = $cache.Values | foreach {$_.vnets}

# Create an empty array to store the output objects
$outputs = @()

# Iterate through each virtual network
foreach ($vnet in $allVnets) {
    # Get the DDoS protection plan object
    if ($vnet.DdosProtectionPlan -ne $null) {
        if ($ddosPlans.ContainsKey($vnet.DdosProtectionPlan.Id)) {
            $ddos = $ddosPlans[$vnet.DdosProtectionPlan.Id]
        } else {
            $ddos = $null
        }
    } else {
        $ddos = $null
    }
    # Get the resource group object
    $rg = Get-AzResourceGroup -Name $vnet.ResourceGroupName
    # Get the tags for the virtual network
    $tags = (Get-AzResource -ResourceId $vnet.Id).Tags
    # Create an object to store the output for the current virtual network
    $output = [PSCustomObject]@{
        SubscriptionName = $subscription.Name
        VirtualNetworkName = $vnet.Name
        DDOSProtectionPlan = $ddos
        ResourceGroup = $rg.Name
        Tags = $tags
    }
    # Add the output object to the array of output objects
    $outputs += $output
}

# Export the output objects to a CSV file
$outputs | Export-Csv -Path "VirtualNetworks.csv" -NoTypeInformation
