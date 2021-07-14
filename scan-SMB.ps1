<#
.SYNOPSIS
Detects SMB Version 1 on the entire network
.DESCRIPTION
This is a powershell script designed to detect SMBv1 by reading the settings in the
windows registry. Specifically HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters.
Any machine that does not have SMBv1 disabled will be flagged and presented to the screen
with an option to disable it right then and there.
.PARAMETER None
.EXAMPLE
PS C:\>scan-SMB.ps1
.LINK
http://www.mrhobbits.com
https://github.com/MrHobbits/Scan-SMB  
#>

[System.Collections.ArrayList]$ComputerName = @()

# in the "like" field if your machines have a prefix use it here. In my case laptops began with 'LP'
$OU_List = get-adcomputer -SearchBase "OU=CORPORATE,DC=web,DC=example,DC=com" -filter 'Name -like "LP-*"'

foreach ($i in $OU_List) {
    $ComputerName.Add($i.name) | Out-Null
}
    

function GetSMBKey ($MachineName) {
    try
    {
        $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $MachineName)
        $RegKey= $Reg.OpenSubKey("SYSTEM\\CurrentControlSet\\Services\\LanmanServer\\Parameters")
        $RegGet = $RegKey.GetValue("SMB1")
        Return $true        
    }
    catch
    {
        return $false
    }

}

function SetSMBKey ($MachineName) {
    try
    {
        $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $MachineName)
        $RegKey= $Reg.OpenSubKey("SYSTEM\\CurrentControlSet\\Services\\LanmanServer\\Parameters")
        $RegSet = $RegKey.SetValue("SMB1","0")
        Return $true
    }
    catch 
    {
        return $false
    }
    
}

function CheckConnection($MachineName) {
    if (Test-Connection -ComputerName $MachineName -Count 2 -Quiet)
    {
        return $true
    }            
    else 
    {
        Write-Host "$computer Not Online" -ForegroundColor Yellow
        return $false
    }
}

function CheckRemoteRegistry($MachineName){
    if ((Get-Service -Name "RemoteRegistry" -ComputerName $MachineName).status -ne 'running')
        {
            write-host "$MachineName --> RemoteRegistry is not running. We're going to try to start it."

            try
            {
                (Get-Service -Name "RemoteRegistry" -ComputerName $MachineName).start()
                Write-Host "$MachineName has RemoteRegistry service started."
                return $true
            }
            catch 
            {
                Write-Warning "$MachineName --> RemoteRegistry could not be started!"            
                return $false
            }
        }
        else 
        {
            return $true
        }
}


foreach ($computer in $ComputerName) {

    # can we connect to the machine?
    if ((CheckConnection($computer)) -eq $true)
    {     
          
        if ((CheckRemoteRegistry($computer)) -eq $true)
        {
        
            try
            {        
                $smbTest = GetSMBKey($computer)
                if ($smbTest -eq $false)
                {
                    Write-Host "WARNING! $computer does not have SMBv1 disabled!!" -ForegroundColor Red
                    $NetSetSMB = $RegKey.SetValue("SMB1","0")
                    $smbFailedRetry = SetSMBKey($computer)
                    if ($smbFailedRetry -eq $false)
                    {
                        Write-Host "*************************" -ForegroundColor Red
                        Write-Host "$computer FAILED SETTING SMB VALUE" -ForegroundColor Red
                        write-host "*************************" -ForegroundColor Red                
                    } 
                    elseif ($smbFailedRetry -eq $true)
                    {
                        Write-Host "$comptuer SMBv1 should now be blocked. Setting SMBv1 Succeeded." -ForegroundColor Yellow            
                    }
                }
                else
                {
                    Write-Host "$computer has SMBv1 disabled!" -ForegroundColor Green
                }
            } catch {
                write-host $_.Exception.Message -ForegroundColor Yellow        
            }
        }
    }
}
