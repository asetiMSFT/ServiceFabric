######################################################################################################################################################
# GetAppDetails.ps1
# Copyright (c) 2018 - Microsoft Corp.
#
# Author(s); Andrew Setiawan
#
# Description:
# Powershell script to dump all 5 layers in the cluster as shown in Service Fabric Explorer (SFX).
# This script was created to help customer to enumerate all properties of application and the underlaying objects.
#
# Usage sample:
# 
# ./GetAppDetails.ps1 -subscriptionId $subId -clusterFQDN $clusterFQDN -doAzureLogin -useTableFormat -outputFile 'C:\TEMP\Report1.txt'
# ./GetAppDetails.ps1 -subscriptionId $subId -clusterFQDN $clusterFQDN -certThumbprint $thumbprintOverride 
#
# Parameters:
# -subscriptionId : your subscription ID (without enclosing braces).
# -clusterFQDN    : your Cluster's Fully Qualified Domain Name. This is to help the script to locate the cert in your certificate store (User's MY store, not LOCAL COMPUTER's MY store).
# -certThumbprint : optional - cert Thumbprint to use if you have multiple certs with the same clusterFQDN as subject, the script will use this thumbprint instead.
# -outputFile     : optional - Filename/path for the output of this script.
# -doAzureLogin   : optional - by default, the script won’t attempt to do login to your azure account. You must specify this switch if you’re opening powershell for the first time to run this script.
# -useTableFormat : optional - when specified, this will dump the content in table (horizontal) formatting.

# Notes:
# - if you have multiple certificates with the same subject with your clusterFQDN on it, the script will not be able to determine which one to use and assume the first one to use.
#   In future, we may update the script to improve this limitation.
# - for string parameters, please enclose them with quotes.
#
# History:
# 12/3/2018 - Created.
# 12/13/2018 - Added Description, added certThumbprint parameter, fixed few bugs related with console output and parameter checking.
######################################################################################################################################################


#Requires -Version 3.0
Param(
    [Parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()]
    [string] $subscriptionId,

    [Parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()]
    [string] $clusterFQDN,

    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [string] $certThumbprint,

    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [string] $outputFile="AppDetails.txt",

    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [switch] $doAzureLogin = $false,

    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [switch] $useTableFormat = $false

)

Set-StrictMode -Version 3
$sep0 = '===================================================================================================================================='
Write-Host $sep0 
Write-Host 'GetAppDetails.ps1' 
Write-Host $sep0 

Write-Host "Attempting to connect to Azure using Subscription: " $subscriptionId "..."

'GetAppDetails.ps1' | Out-File -filepath $outputFile
$sep0 | Out-File -filepath $outputFile -Append

$msg = 'SubscriptionId: ' + $subscriptionId
$msg | Out-File -filepath $outputFile -Append

if ($doAzureLogin.IsPresent) 
{
    Write-Host 'SubscriptionId: ' + $subscriptionId
    Connect-AzureRmAccount
    Set-AzureRmContext -SubscriptionId $subscriptionId
}


Write-Host 'Attempting to connect to cluster: ' $clusterFQDN '...'

Set-AzureRmContext -SubscriptionId $subscriptionId


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
$cluster = Connect-ServiceFabricCluster -ConnectionEndpoint $clusterEndpoint -KeepAliveIntervalInSec 10 -X509Credential -ServerCertThumbprint $certThumbprintToUse -FindType FindByThumbprint -FindValue $certThumbprintToUse -StoreLocation CurrentUser -StoreName My  | Out-File -filepath $outputFile -Append
Write-Host ($cluster | Format-Table | Out-String)


$apps = Get-ServiceFabricApplication 

$appCounter = 0

if ($apps -ne $null)
{
    foreach ($app in $apps)
    {
        ++$appCounter
        #1. Application Level
        Write-Host $sep0
        $sep0 | Out-File -filepath $outputFile -Append

        $msg =  $appCounter.ToString() + '.1. APPLICATION LEVEL' 
        $msg | Out-File -filepath $outputFile -Append
        Write-Host $msg

        Write-Host $sep0
        $sep0 | Out-File -filepath $outputFile -Append

        $app = Get-ServiceFabricApplication -ApplicationName $app.ApplicationName 
        if ($useTableFormat -eq $true) 
        {
            ($app | Format-Table | Out-String) | Out-File -filepath $outputFile -Append
            Write-Host ($app | Format-Table | Out-String)
        }
        else
        {
            $app | Out-File -filepath $outputFile -Append
            Write-Host ($app | Out-String)
        }

        $appTypes = Get-ServiceFabricApplicationType 

        foreach ($appType in $appTypes)
        {

            #2. Application Type Level
            Write-Host $sep0
            $sep0 | Out-File -filepath $outputFile -Append

            $msg = $appCounter.ToString() + '.2. APPLICATION TYPE LEVEL' 
            $msg | Out-File -filepath $outputFile -Append
            Write-Host $msg

            Write-Host $sep0
            $sep0 | Out-File -filepath $outputFile -Append

            $appType = Get-ServiceFabricApplicationType -ApplicationTypeName $appType.ApplicationTypeName 
            if ($useTableFormat -eq $true) 
            {
                ($appType | Format-Table | Out-String) | Out-File -filepath $outputFile -Append
                Write-Host ($appType | Format-Table | Out-String)
            }
            else
            {
                $appType | Out-File -filepath $outputFile -Append
                Write-Host ($appType | Out-String)
            }

            $services = Get-ServiceFabricService -ApplicationName $app.ApplicationName

            foreach ($service in $services)
            {
                #3. Application Service Level
                Write-Host $sep0
                $sep0 | Out-File -filepath $outputFile -Append

                $msg = $appCounter.ToString() + '.3. APPLICATION SERVICE LEVEL' 
                $msg | Out-File -filepath $outputFile -Append
                Write-Host $msg

                Write-Host $sep0
                $sep0 | Out-File -filepath $outputFile -Append

                $svc = Get-ServiceFabricService -ApplicationName $app.ApplicationName  -ServiceTypeName $service.ServiceTypeName 
                if ($useTableFormat -eq $true) 
                {
                    ($svc | Format-Table | Out-String) | Out-File -filepath $outputFile -Append
                    Write-Host ($svc | Format-Table | Out-String)
                }
                else
                {
                    $svc | Out-File -filepath $outputFile -Append
                    Write-Host ($svc | Out-String)
                }

                #4. Partition Level
                $partitions = Get-ServiceFabricPartition -ServiceName $service.ServiceName

                foreach ($partition in $partitions)
                {
                    Write-Host $sep0
                    $sep0 | Out-File -filepath $outputFile -Append

                    $msg = $appCounter.ToString() + '.4. PARTITION LEVEL' 
                    $msg | Out-File -filepath $outputFile -Append
                    Write-Host $msg

                    Write-Host $sep0
                    $sep0 | Out-File -filepath $outputFile -Append

                    $prt = Get-ServiceFabricPartition -PartitionId $partition.PartitionId 
                    
                    if ($useTableFormat -eq $true) 
                    {
                        ($prt | Format-Table | Out-String) | Out-File -filepath $outputFile -Append
                        Write-Host ($prt | Format-Table | Out-String)
                    }
                    else
                    {
                        $prt | Out-File -filepath $outputFile -Append
                        Write-Host ($prt | Out-String)
                    }

                    #5. Replica Level
                    $replicas = Get-ServiceFabricReplica -PartitionId $partition.PartitionId 
                
                    foreach ($replica in $replicas)
                    {
                        Write-Host $sep0
                        $sep0 | Out-File -filepath $outputFile -Append

                        $msg = $appCounter.ToString() + '.5. REPLICA LEVEL' 
                        $msg | Out-File -filepath $outputFile -Append
                        Write-Host $msg

                        Write-Host $sep0
                        $sep0 | Out-File -filepath $outputFile -Append

                        $rpl = Get-ServiceFabricReplica  -PartitionId $partition.PartitionId -ReplicaOrInstanceId $replica.ReplicaOrInstanceId 
                        
                        if ($useTableFormat -eq $true) 
                        {
                            ($rpl | Format-Table | Out-String) | Out-File -filepath $outputFile -Append
                            Write-Host ($rpl | Format-Table | Out-String)
                        }
                        else
                        {
                            $rpl | Out-File -filepath $outputFile -Append
                            Write-Host ($rpl | Out-String)
                        }


                    } 
                }
            }
        }
    }
}
else
{
    $msg = 'Cannot find any applications in your cluster. Please make sure the parameters are correct.' | Out-File -filepath $outputFile -Append
    Write-Host $msg
}

$sep0 | Out-File -filepath $outputFile -Append
Write-Host $sep0

$msg = 'End of Document' 
$msg | Out-File -filepath $outputFile -Append
Write-Host $msg

$sep0 | Out-File -filepath $outputFile -Append
Write-Host $sep0

Write-Host 'DONE.'