<#

This script is intended to gather information about all virtual networks in all subscriptions of an Azure account. The output will include the subscription name, virtual network name, DDoS protection plan, and resource tags. The script will export all the information to a CSV file named VirtualNetworks.csv. It will also handle the case where a virtual network does not have a DDoS protection plan and will output "NA" in the DdosProtectionPlan column for that virtual network.

#>

# Connect to Azure account
Connect-AzAccount

# Get all subscriptions for the account
$subscriptions = Get-AzSubscription

# Iterate through each subscription
foreach ($subscription in $subscriptions) {
    # Set the current subscription context
    Select-AzSubscription -SubscriptionId $subscription.Id

    # Get all virtual networks in the subscription
    $vnets = Get-AzVirtualNetwork

    # Iterate through each virtual network
    foreach ($vnet in $vnets) {
        # Check if the virtual network has a DDoS protection plan
        if ($vnet.DdosProtectionPlan -ne $null) {
            # Retrieve the DDoS protection plan for the virtual network
            $ddos = Get-AzDdosProtectionPlan -Name $vnet.DdosProtectionPlan.Id -ErrorAction SilentlyContinue
            if($ddos -eq $null)
            {
                # Iterate through all subscriptions to find the correct DDoS protection plan
                foreach ($sub in $subscriptions) {
                    if ($sub.Id -ne $subscription.Id) {
                        # change subscription context
                        Select-AzSubscription -SubscriptionId $sub.Id
                        # check if the ddos plan exist in this subscription
                        $ddos = Get-AzDdosProtectionPlan -Name $vnet.DdosProtectionPlan.Id -ErrorAction SilentlyContinue
                        # if found, break the loop
                        if($ddos -ne $null)
                        {
                            break
                        }
                    }
                }
            }
        } else {
          # If the virtual network does not have a DDoS protection plan, assign $null to the variable
          $ddos = $null
        }
        # Retrieve the resource tags for the virtual network
        $tags = (Get-AzResource -ResourceId $vnet.Id).Tags
        # Creating an output object with the required properties
        $output = [PSCustomObject]@{
            SubscriptionName = $subscription.Name
            VirtualNetworkName = $vnet.Name
            DdosProtectionPlan = if($ddos -ne $null){$ddos.Name} else {"NA"}
            Tags = $tags
        }
        # Output the object
        Write-Output $output
    }
}
#Exporting the output to CSV file
$output | Export-Csv -Path "VirtualNetworks.csv" -NoTypeInformation
