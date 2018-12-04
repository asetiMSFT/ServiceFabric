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
