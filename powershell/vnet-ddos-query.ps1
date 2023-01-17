<#

This script is intended to gather information about all virtual networks in all subscriptions of an Azure account. The output will include the subscription name, virtual network name, DDoS protection plan, and resource tags. The script will export all the information to a CSV file named VirtualNetworks.csv. It will also handle the case where a virtual network does not have a DDoS protection plan and will output "NA" in the DdosProtectionPlan column for that virtual network.

#>

# Connect to Azure account
Connect-AzAccount

# Retrieve all subscriptions
$subscriptions = Get-AzSubscription

# Create an empty hash table to store the DDoS protection plan and virtual network objects
$cache = @{}

# Iterate through each subscription
foreach ($subscription in $subscriptions) {
    Select-AzSubscription -SubscriptionId $subscription.Id
    Write-Output "Retrieving DDoS protection plans and virtual networks for subscription $($subscription.Name) ($($subscription.Id))"
    # Retrieve DDoS protection plans and virtual networks for the current subscription
    $ddosPlans = Get-AzDdosProtectionPlan -SubscriptionId $subscription.Id
    $vnets = Get-AzVirtualNetwork -SubscriptionId $subscription.Id
    # Add the DDoS protection plans and virtual networks to the cache
    $cache.Add($subscription.Id, @{
        ddosPlans = $ddosPlans
        vnets = $vnets
    })
}

$allVnets = $cache.Values | foreach {$_.vnets}

Write-Output "Retrieved $(($allVnets | Measure-Object).Count) virtual networks across all subscriptions"

# Create an empty array to store the output objects
$outputs = @()

# Iterate through each virtual network
foreach ($vnet in $allVnets) {
    Write-Output "Processing virtual network $($vnet.Name)"
    # Get the subscription ID from the virtual network's resource ID
    $subscriptionId = ($vnet.Id -split '/')[2]
    $subscriptionName = $subscriptions | Where-Object {$_.Id -eq $subscriptionId}
    # Get the DDoS protection plan object
    if ($vnet.DdosProtectionPlan -ne $null) {
        $ddos = $cache[$subscriptionId].ddosPlans | Where-Object {$_.Id -eq $vnet.DdosProtectionPlan.Id}
        if ($ddos) {
            $ddosName = $ddos.Name
        } else {
            $ddosName = "NA"
        }
    } else {
        $ddosName = "NA"
    }
    # Get the resource group name from the vnet object
    $rgName = $vnet.ResourceGroupName
    # Get the tags for the virtual network
    $tags = (Get-AzResource -ResourceId $vnet.Id).Tags
    # Create an object to store the output for the current virtual network
    $output = [PSCustomObject]@{
        SubscriptionName = $subscriptionName
        VirtualNetworkName = $vnet.Name
        DDOSProtectionPlanName = $ddosName
        ResourceGroupName = $rgName
        Tags = $tags
    }
    # Add the output object to the array of output objects
    $outputs += $output
}

# Export the output objects to a CSV file
$outputs | Export-Csv -Path "VirtualNetworks.csv" -NoTypeInformation
