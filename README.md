# Get-WiFiPasswords

PowerShell script for getting stored Wi-Fi passwords from netsh

Usage:

```
.\getwifipasswords.ps1 -devices <computername> 
```

Example:

```
> .\getwifipasswords.ps1 -devices CORP001 -verbose
VERBOSE: Elevated? True
VERBOSE: Devices list? CORP001
GetWiFiPasswords.ps1 started at 07/22/2020 19:07:42
___________________________________________________________
computer: CORP001; user: @{username=domain\fake}

profile     authentication  securitykey password
-------     --------------  ----------- --------
corp        WPA2-Enterprise Absent
home WIFI   WPA2-Personal   Present     Awesome2016


....................................................
```

# Notes

Use at your own risk.
