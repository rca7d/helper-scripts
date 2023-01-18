<#

This script is intended to gather information about all virtual networks in all subscriptions of an Azure account. The output will include the subscription name, virtual network name, DDoS protection plan, and resource tags. The script will export all the information to a CSV file named VirtualNetworks.csv. It will also handle the case where a virtual network does not have a DDoS protection plan and will output "NA" in the DdosProtectionPlan column for that virtual network.

#>

# Connect to Azure account
Connect-AzAccount

# Retrieve all subscriptions
$subscriptions = Get-AzSubscription

# Create empty hash tables to store the DDoS protection plan and virtual network objects
$ddosCache = @{}
$vnetCache = @{}
$subscriptionCache = @{}

# Get all subscriptions
$subscriptions = Get-AzSubscription

# Iterate through each subscription
foreach ($subscription in $subscriptions) {
    # Select the current subscription
    Select-AzSubscription -SubscriptionId $subscription.Id

    # Retrieve the DDoS protection plans and virtual networks for the current subscription
    $ddosPlans = Get-AzDdosProtectionPlan
    $vnets = Get-AzVirtualNetwork
    
    # Iterate through each DDoS protection plan
    foreach ($ddos in $ddosPlans) {
        # Add the DDoS protection plan to the cache
        $ddosCache.Add($ddos.Id, $ddos)
    }

    # Iterate through each vnet
    foreach ($vnet in $vnets) {
        # Add the vnet to the cache
        $vnetCache.Add($vnet.Id, @{
        vnet = $vnet
        subscription = $subscription
    })
    }
}

$allVnets = $vnetCache.Values | foreach {$_.vnet}

Write-Output "Retrieved $(($allVnets | Measure-Object).Count) virtual networks across all subscriptions"

$outputs = @()
foreach ($vnet in $allVnets) {
    $subscription = $vnetCache[$vnet.Id].subscription
    $ddosPlanName = "N/A"
    if($vnet.DdosProtectionPlan) {
        $ddosPlan = $ddosCache[$vnet.DdosProtectionPlan.Id]
        ddosPlanName = $ddosPlan.Name
    }
    
    $output = [PSCustomObject]@{
        SubscriptionId = $subscription.Id
        SubscriptionName = $subscription.Name
        ResourceGroupName = $vnet.ResourceGroupName
        VirtualNetworkId = $vnet.Id
        DDOSProtectionPlanName = $ddosPlanName
    }
    $outputs += $output
}

$outputs | Export-Csv -Path "VirtualNetworks.csv" -NoTypeInformation
