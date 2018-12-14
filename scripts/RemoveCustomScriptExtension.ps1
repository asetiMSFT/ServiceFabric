######################################################################################################################################################
# RemoveCustomScriptExtension.ps1
# Copyright (c) 2018 - Microsoft Corp.
#
# Author(s); Andrew Setiawan
#
# Description:
# Powershell script to remove CustomScriptExtension from the specified VMSS. This script was created to help customer (in conjunction with 
# InstallCustomScriptExtension.ps1) which is provided to automatically run/distribute # DisableAutoUpdate.ps1 to auto-scale cluster which uses 
# Windows Server 2016 where POA is unable to disable automatic update due to recent known issue with Windows Server 2016 regression on 
# Windows Update interface. This script is meant to remove the CustomScriptExtension that was installed/added by InstallCustomScriptExtension.ps1.
#
# Parameters:
# -subscriptionId     : optional - your subscription ID (without enclosing braces). If you specify doAzureLogin switch parameter, you must specify subscriptionId parameter.
# -clusterFQDN        : your Cluster's Fully Qualified Domain Name. This is to help the script to locate the cert in your certificate store (User's MY store, not LOCAL COMPUTER's MY store).
# -certThumbprint     : optional - cert Thumbprint to use if you have multiple certs with the same clusterFQDN as subject, the script will use this thumbprint instead.
# -vmssName           : the target VMSS that you want to install the extension.
# -resourceGroupName  : the Resource Group name of the target VMSS.
# -vmssExtensionName  : optional - the name of extension to install Default: CustomScriptExtension.
# -location           : optional - the region name of your cluster. Default is westus.
# -extensionVersion   : optional - the version of the extension that you want to install. Default is 1.7.
# -doAzureLogin       : optional - by default, the script won’t attempt to do login to your azure account. You must specify this switch if you’re opening powershell for the first time to run this script.

#
# Usage sample:
# ./RemoveCustomScriptExtension.ps1 -subscriptionId $subId -clusterFQDN $clusterFQDN -vmssName $vmssName -resourceGroupName $myRGName `
# -location $location -extensionVersion $extensionVersion `
# -doAzureLogin 
#
# Notes:
# - if you have multiple certificates with the same subject with your clusterFQDN on it, the script will not be able to determine which one to use and assume the first one to use.
#   In future, we may update the script to improve this limitation.
# - for string parameters, please enclose them with quotes.
#
# History:
# 12/3/2018  - Created.
# 12/4/2018  - Fixed Description.
# 12/13/2018 - Updated Description, added certThumbprint parameter, fixed few bugs related with console output and parameter checking.
#            - Removed doConnectToCluster and useTableFormat parameters. Bug fixes for resource group and parameter handling.
######################################################################################################################################################

#Requires -Version 3.0
Param(
    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [string] $subscriptionId,

    [Parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()]
    [string] $clusterFQDN,

    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [string] $certThumbprint,

    [Parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()]
    [string] $vmssName,
    
    [Parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()]
    [string] $resourceGroupName,

    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [string] $vmssExtensionName = "CustomScriptExtension",

    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [string] $location = "westus",

    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [string] $extensionVersion = "1.7",

    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [switch] $doAzureLogin = $false
)

Set-StrictMode -Version 3
$sep0 = '===================================================================================================================================='
Write-Host $sep0 
Write-Host 'RemoveCustomScriptExtension.ps1' 
Write-Host $sep0 

if ($doAzureLogin.IsPresent) 
{
    if ([string]::IsNullOrWhitespace($subscriptionId))
    {
        write-host "subscriptionId parameter was not specified. Since you specified doAzureLogin switch parameter, you need to provide subscriptionId parameter."
        write-host "Exiting now..."
        Exit -1
    }

    Write-Host "Attempting to connect to Azure using Subscription: " $subscriptionId "..."

    try
    {
        $azureProfile = Connect-AzureRmAccount -Subscription $subscriptionId
    }
    catch
    {
        write-host "Caught an exception:" -ForegroundColor Red
        write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
        
        write-host "Exiting now..."
        Exit -1

    }

    Set-AzureRmContext -SubscriptionId $subscriptionId
}


Write-Host 'Finding certificate for cluster: ' $clusterFQDN '...'

$clusterEndpoint = $clusterFQDN+':19000' 
$certThumbprints = (Get-ChildItem -Path Cert:\CurrentUser\My | where {$_.Subject -like "*$clusterFQDN*" }).Thumbprint 

#Client Certificate for the cluster MUST already be installed in your user account's certificate store (don't use Local Machine's certificate store!).
#NOTE: There could be more than one certificate with the same subject. We'll use the first one found.
Write-Host 'Found Certificate(s):' $certThumbprints 
if ($certThumbprints.Length > 1)
{
    $certThumbprintToUse = $certThumbprints[0]
}
else
{
    $certThumbprintToUse = $certThumbprints
}

if (![string]::IsNullOrWhitespace($certThumbprint))
{
    Write-Host 'Using the Cert Thumbprint override parameter since it was specified:' $certThumbprint
    $certThumbprintToUse = $certThumbprint
} 

Write-Host 'Using this Certificate to connect to cluster:' $certThumbprintToUse 

Write-Host 'Attempting to connect to cluster: ' $clusterFQDN '...'
$cluster = Connect-ServiceFabricCluster -ConnectionEndpoint $clusterEndpoint -KeepAliveIntervalInSec 10 -X509Credential -ServerCertThumbprint $certThumbprintToUse -FindType FindByThumbprint -FindValue $certThumbprintToUse -StoreLocation CurrentUser -StoreName My  


$vmssExtensionType = "CustomScriptExtension"

Write-Host 'Trying to get VMSS: ' $vmssName ' from Resource Group: ' $resourceGroupName
$vmss = Get-AzureRmVmss -ResourceGroupName $resourceGroupName -VMScaleSetName $vmssName

Write-Host 'Removing ' $vmssExtensionName ' from VMSS: ' $vmssName
Remove-AzureRmVmssExtension -VirtualMachineScaleSet $vmss -Name $vmssExtensionName

Write-Host 'Updating VMSS: ' $vmssName ' ...'
Update-AzureRmVmss -ResourceGroupName $resourceGroupName -Name $vmssName -VirtualMachineScaleSet $vmss

Write-Host 'DONE.'