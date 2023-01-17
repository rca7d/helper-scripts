<#

This script is intended to gather information about all virtual networks in all subscriptions of an Azure account. The output will include the subscription name, virtual network name, DDoS protection plan, and resource tags. The script will export all the information to a CSV file named VirtualNetworks.csv. It will also handle the case where a virtual network does not have a DDoS protection plan and will output "NA" in the DdosProtectionPlan column for that virtual network.

#>

# Connect to Azure account
Connect-AzAccount

$subscriptions = Get-AzSubscription

# Create an empty hash table to store the DDoS protection plan objects
$ddosProtectionPlansCache = @{}

# Retrieve all DDoS protection plans across all subscriptions
foreach ($subscription in $subscriptions) {
    Select-AzSubscription -SubscriptionId $subscription.Id
    $ddosPlans = Get-AzDdosProtectionPlan
    foreach($ddosPlan in $ddosPlans) {
        if(!$ddosProtectionPlansCache.ContainsKey($ddosPlan.Name)) {
            $ddosProtectionPlansCache.Add($ddosPlan.Name, $ddosPlan)
        }
    }
}

# Get all virtual networks across all subscriptions
$vnets = Get-AzVirtualNetwork

# Create an empty array to store the output objects
$outputs = @()

# Iterate through each virtual network
foreach ($vnet in $vnets) {
    # get the subscription id of the virtual network
    $subId = (Get-AzResource -ResourceId $vnet.Id).SubscriptionId
    # set the subscription context
    Select-AzSubscription -SubscriptionId $subId
    if ($vnet.DdosProtectionPlan -ne $null) {
        # check if the DDoS protection plan object is already in the cache
        if ($ddosProtectionPlansCache.ContainsKey($vnet.DdosProtectionPlan.Id)) {
            # Get the DDoS protection plan object from the cache
            $ddos = $ddosProtectionPlansCache[$vnet.DdosProtectionPlan.Id]
        } else {
            $ddos = $null
        }
    } else {
      $ddos = $null
    }
    $tags = (Get-AzResource -ResourceId $vnet.Id).Tags
    $output = [PSCustomObject]@{
        SubscriptionName = (Get-AzSubscription -SubscriptionId $subId).Name
        VirtualNetworkName = $vnet.Name
        DdosProtectionPlan = if($ddos -ne $null){$ddos.Name} else {"NA"}
        Tags = $tags
    }
    $outputs += $output
}
$outputs | Export-Csv -Path "VirtualNetworks.csv" -NoTypeInformation
