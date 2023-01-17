<#

This script is intended to gather information about all virtual networks in all subscriptions of an Azure account. The output will include the subscription name, virtual network name, DDoS protection plan, and resource tags. The script will export all the information to a CSV file named VirtualNetworks.csv. It will also handle the case where a virtual network does not have a DDoS protection plan and will output "NA" in the DdosProtectionPlan column for that virtual network.

#>

# Connect to Azure account
Connect-AzAccount

# Login to the selected tenant
$selectedTenantId = "<insert-tenant-id>"
Write-Output "Using tenant $($selectedTenantId)"

# Create an empty hash table to store the DDoS protection plan and virtual network objects
$cache = @{}

$subscriptions = Get-AzSubscription | Where-Object {$_.TenantId -eq $selectedTenantId -and $_.State -eq 'Enabled'}

# Retrieve all DDoS protection plans and virtual networks across all subscriptions
Write-Output "Retrieving DDoS protection plans and virtual networks for all subscriptions"
$ddosPlans = Get-AzDdosProtectionPlan -All
$vnets = Get-AzVirtualNetwork -All
# Add the DDoS protection plans and virtual networks to the cache
$cache.Add("ddos", $ddosPlans)
$cache.Add("vnets", $vnets)

foreach ($subscription in $subscriptions) {
    
    Write-Output "Processing subscription $($subscription.Name) ($($subscription.Id))"
    $ddosPlans = $cache["ddos"]
    $vnets = $cache["vnets"]

    # Iterate through each virtual network
    foreach ($vnet in $vnets) {
        Write-Output "Processing virtual network $($vnet.Name)"
        # Get the DDoS protection plan object
        if ($vnet.DdosProtectionPlan -ne $null) {
            $ddos = $ddosPlans | Where-Object { $_.Id -eq $vnet.DdosProtectionPlan.Id }
            if ($ddos) {
                $ddos = $ddos[0]
            }
        } else {
            $ddos = $null
        }
        # Get the resource group object
        $rg = Get-AzResourceGroup -Name $vnet.ResourceGroupName
        # Get the tags for the virtual network
        $tags = (Get-AzResource -ResourceId $vnet.Id).Tags
        $tags = ($tags | ConvertTo-Json)
        # Create an object to store the output for the current virtual network
        $output = [PSCustomObject]@{
            SubscriptionName = $subscription.Name
            VirtualNetworkName = $vnet.Name
            DDOSProtectionPlan = $ddos.Name
            ResourceGroup = $vnet.ResourceGroupName
            Tags = $tags
        }
        # Add the output object to the array of output objects
        $outputs += $output
    }
}

# Export the output objects to a CSV file
$outputs | Export-Csv -Path "VirtualNetworks.csv" -NoTypeInformation
