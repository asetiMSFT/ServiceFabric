######################################################################################################################################################
# DisableAutoUpdate.ps1
# Copyright (c) 2018 - Microsoft Corp.
#
# Author(s): Andrew Setiawan
#
# Description:
# Powershell script to disable AutoUpdate by adding special registry key & value.
# This script was created to help people to mitigate problem/bug on Windows Server 2016 (as of when this script was written) where
# the WU API interface has a regression and does not work as it's supposed to be, causing AutoUpdate to be still active.
# This script may not be needed anymore when the bug is fixed, but you may use this regardless of that.
# It is meant to be used/called once by CustomScriptExtension in your Service Fabric Cluster (see InstallCustomScriptExtension.ps1).
#
# Usage sample:
# There is no parameters needed.
# 
# ./DisableAutoUpdate.ps1 
#
# Notes:
# - This ps1 script file is re-entrant and safe to be called from CustomScriptExtension: meaning it can be executed many times without problem. 
#
# History:
# 12/2/2018  - Created.
# 12/13/2018 - Added descriptions.
######################################################################################################################################################

#Only works up to Win2012.
#https://docs.microsoft.com/en-us/windows/desktop/api/wuapi/ne-wuapi-tagautomaticupdatesnotificationlevel
#http://www.darrylvanderpeijl.com/windows-server-2016-update-settings/
$AUSettings = (New-Object -com "Microsoft.Update.AutoUpdate").Settings 
$AUSettings.NotificationLevel = 1
$AUSettings.Save

#For Win2016 and above.
#https://4sysops.com/archives/disable-windows-10-update-in-the-registry-and-with-powershell/
New-Item HKLM:\SOFTWARE\Policies\Microsoft\Windows -Name WindowsUpdate -Force
New-Item HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name AU -Force
New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name NoAutoUpdate -Value 1 -Force
