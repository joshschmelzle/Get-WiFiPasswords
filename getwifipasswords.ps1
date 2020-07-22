<#
 .Synopsis
  Gets Wi-FI passwords from a remote endpoint using PS Remoting.

 .Description
  Leverages PowerShell to run netsh commands on a remote computer.

 .Parameter Devices
    A list of devices to get saved Wi-Fi passwords from.

 .Example
   <script> -devices <computername> 
#>

param(
  [Parameter(Position = 0,Mandatory = $true)] [array]$devices,
  [Parameter(Position = 1,Mandatory = $false)] [string]$nested
)

try {
  function Get-WiFiPasswords ($devices) {
    $devices = $devices.split(",")
    Write-Host "GetWiFiPasswords.ps1 started at $(Get-Date)"
    foreach ($device in $devices) {
      if (Test-Connection -ComputerName $device -Count 2 -Quiet) {
        Get-Output -device $device
      }
      else {
        Write-Host ("Test-Connection to {0} failed!" -f $device)
      }
    }
    Write-Host "GetWiFiPasswords.ps1 finished at $(Get-Date)"
  }

  function Get-Output ($device) {
    $scriptblock = {
      param()

      function LastLineLen ($lines) {
        foreach ($line in $lines.split([Environment]::NewLine)) {
          $current_len = $line.Trim().Length
        }
        $current_len
      }
      function Write-Header ($lines) {
        $header = ""
        foreach ($i in 1..$lines) {
          $header += "_"
        }
        $header
      }
      function Write-Footer ($lines) {
        $footer = ""
        foreach ($i in 1..$lines) {
          $footer += "."
        }
        $footer
      }

      $header = "computer: $($env:ComputerName); user: $(Get-WMIObject -class Win32_ComputerSystem | Select-Object username)"
      Write-Header (LastLineLen ($header))
      Write-Host $header


      $netsh_wlan_show_profiles = netsh.exe wlan show profiles

      #Write-Host $netsh_wlan_show_profiles

      $group = $false
      $want = $false

      $profiles = New-Object System.Collections.ArrayList

      foreach ($line in $netsh_wlan_show_profiles) {
        $line = $line.Trim()
        if ($line.Length -eq 0) {
          continue
        }
        #Write-Host "X: " + $line
        if ($line -like '*----------*') {
          continue
        }
        if ($line -like '*User Profiles*') {
          $group = $false
          $want = $true
          continue
        }
        if ($line -like '*profiles on interface*') {
          continue
        }
        if ($line -like '*group policy profiles*') {
          $group = $true
          continue
        }

        if ($line -like '*<None>*') {
          continue;
        }
        if ($group) {
          if ($line) {
            $profile = $line.Trim() -replace '"'
            $profiles.Add($profile) > $null
          }
        } elseif ($want) {
          if ($line) {
            $profile = ($line -split ":")[1].Trim() -replace '"'
            $profiles.Add($profile) > $null
          }
        }
      }
      $passwords = New-Object System.Collections.ArrayList
      foreach ($name in $profiles) {
        $recon = netsh.exe wlan show profiles name="$name" key=clear

        $SSIDresult = $recon | Select-String -Pattern 'SSID Name'

        if ($SSIDresult) {
          $prof = ($SSIDresult -split ":")[-1].Trim() -replace '"'
        }

        $AUTHresult = $recon | Select-String -Pattern 'Authentication'
        if ($AUTHresult) {
          $auth = ($AUTHresult -split ":")[1].Trim() -replace '"'
        }

        $SECURITYKEYresult = $recon | Select-String -Pattern 'Security key'
        if ($SECURITYKEYresult) {
          $securitykey = ($SECURITYKEYresult -split ":")[1].Trim() -replace '"'
        }

        $PWresult = $recon | Select-String -Pattern 'Key Content'
        $pw = ""
        if ($PWresult) {
          $pw = ($PWresult -split ":")[1].Trim() -replace '"'
        }
        $result = [pscustomobject]@{
          profile = $prof
          authentication = $auth
          securitykey = $securitykey
          password = $pw
        }
        $passwords.Add($result) > $null
      }
      $passwords | Format-Table

      Write-Footer (LastLineLen (($passwords | Out-String).Trim()))
      Write-Host ""

    } # end $scriptblock 

    Invoke-Command -ComputerName $device -ScriptBlock $scriptblock
  }

  $IsAdministrator = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")

  Write-Verbose "Elevated? $($IsAdministrator)"

  if (-not $devices) {
    Write-Host ("You must provide devices as input to get Wi-Fi information for: " + $MyInvocation.MyCommand.Name + " -devices HOSTNAME")
  }

  Write-Verbose "Devices list? $($devices)"

  if ($IsAdministrator) {
    Get-WiFiPasswords -devices $devices
  }
  else {
    if ($nested.Contains("True")) {
      throw [System.AccessViolationException]("You must use a local administrator account")
    }

    if (-not $nested.Contains("True")) {
      $script = $MyInvocation.MyCommand.Definition

      if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
        $args = @("-NoExit","-NoProfile","-ExecutionPolicy Bypass","-File","$($script) -devices $($devices -join ",") -nested True -count $($count) -verbose")
      }
      else {
        $args = @("-NoExit","-NoProfile","-ExecutionPolicy Bypass","-File","$($script) -devices $($devices -join ",") -nested True -count $($count)")
      }

      Start-Process powershell.exe -ArgumentList $args -Verb RunAs
    }
    exit
  }
}
catch {
  Write-Host ($_.Exception.Message)
}
