######################################################################################################################################################
# InstallCustomScriptExtension.ps1
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
# Usage sample:
# ./InstallCustomScriptExtension.ps1 -subscriptionId $subId -clusterFQDN $clusterFQDN -vmssName $vmssName -resourceGroupName $myRGName `
# -location $location -extensionVersion $extensionVersion `
# -doAzureLogin -doConnectToCluster -useTableFormat
#
# History:
# 12/3/2018 - Created.
# 12/4/2018 - Fixed Description.
######################################################################################################################################################

#Requires -Version 3.0
Param(
    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [string] $subscriptionId,

    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [string] $clusterFQDN,

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
    [switch] $doAzureLogin = $false,

    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [switch] $doConnectToCluster = $false,

    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [switch] $useTableFormat

)

Set-StrictMode -Version 3
$sep0 = '===================================================================================================================================='
Write-Host "Attempting to connect to Azure using Subscription:" $subscriptionId "..."
Write-Host 'InstallCustomScriptExtension.ps1' 
Write-Host $sep0 


if ($doAzureLogin.IsPresent) 
{
    Write-Host 'SubscriptionId: ' + $subscriptionId
    Connect-AzureRmAccount
    Set-AzureRmContext -SubscriptionId $subscriptionId
}


if ($doConnectToCluster.IsPresent) 
{

    Write-Host 'Attempting to connect to cluster: $clusterFQDN...'

    $clusterEndpoint = $clusterFQDN+':19000' 
    $certThumbprints = (Get-ChildItem -Path Cert:\CurrentUser\My | where {$_.Subject -like "*$clusterFQDN*" }).Thumbprint 

    #Client Certificate for the cluster MUST already be installed in your user account's certificate store (don't use Local Machine's certificate store!).
    #NOTE: There could be more than one certificate with the same subject. We'll use the first one found.
    Write-Host 'Found Certificate(s):' $certThumbprints 
    $certThumbprintToUse = $certThumbprints[0]
    #NOTE: If you want to use specific cert to use, copy paste that here and it'll override the previously found cert.
    #$certThumbprintToUse = '<copy paste your certificate thumbprint here>'

    Write-Host 'Using this Certificate to connect to cluster:' $certThumbprintToUse 
    $cluster = Connect-ServiceFabricCluster -ConnectionEndpoint $clusterEndpoint -KeepAliveIntervalInSec 10 -X509Credential -ServerCertThumbprint $certThumbprint -FindType FindByThumbprint -FindValue $certThumbprintToUse -StoreLocation CurrentUser -StoreName My  
    Write-Host ($cluster | Format-Table | Out-String)
}


$vmssExtensionType = "CustomScriptExtension"

$vmss = Get-AzureRmVmss -ResourceGroupName $myRG -VMScaleSetName $vmssName

Write-Host 'Removing ' $vmssExtensionName ' from VMSS: ' $vmssName
Remove-AzureRmVmssExtension -VirtualMachineScaleSet $vmss -Name $vmssExtensionName

Write-Host 'Updating VMSS: ' $vmssName ' ...'
Update-AzureRmVmss -ResourceGroupName $myRG -Name $vmssName -VirtualMachineScaleSet $vmss

Write-Host 'DONE.'