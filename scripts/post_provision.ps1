# Name: post_provision.ps1
# Description: This script is executed at startup after provisioning to 
# - complete domain join, 
# - machine certificate enrollment, and 
# - enable WinRM over HTTPS.

# Wait for domain join completion
function Wait-DomainJoin {
  $maxRetries = 30
  $retryCount = 0
  
  while ($retryCount -lt $maxRetries) {
    $domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
    if ($domain -ne "WORKGROUP") {
      Write-Host "Domain joined: $domain"
      return $true
    }
    Write-Host "Waiting for domain join... ($retryCount/$maxRetries)"
    Start-Sleep -Seconds 10
    $retryCount++
  }
  return $false
}

# Wait for machine certificate from GPO auto-enrollment
function Wait-MachineCertificate {
  $maxRetries = 10
  $retryCount = 0
  $flagFile = "$env:SystemDrive\scripts\restart.flag"
  while ($retryCount -lt $maxRetries) {
    $cert = Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue | 
        Where-Object { $_.Subject -match $env:COMPUTERNAME }
    
    if ($cert) {
      Write-Host "Machine certificate found: $($cert.Thumbprint)"
      return $cert
    }
    
    Write-Host "Waiting for machine certificate from GPO... ($retryCount/$maxRetries)"
    
    if ($retryCount -gt 0 -and $retryCount % 3 -eq 0) {
      Write-Host "Updating GPO policy..."
      gpupdate /force /wait:5
    }
    
    Start-Sleep -Seconds 5
    $retryCount++
  }
  
  if (-not (Test-Path -Path $flagFile)) {
    Write-Host "Certificate not found after $maxRetries attempts. Rebooting..."
    New-Item -Path $flagFile -ItemType File -Force | Out-Null
    Restart-Computer -Force
  }
  else {
    Write-Host "Certificate still not found after reboot. Please investigate manually."
    return $null
  }
}

# Enable WinRM over HTTPS
function Enable-WinRMHTTPS {
  param([string]$CertThumbprint)
  
  Write-Host "Enabling WinRM over HTTPS on port 5986..."
  $httpsListeners = Get-ChildItem -Path WSMan:\localhost\Listener -ErrorAction SilentlyContinue | 
      Where-Object { $_.Keys -match "Transport=HTTPS" }
  $cert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -match  "cloudapp.net"}
  if  ($httpsListeners) {
    foreach ($listener in $httpsListeners) {
      Write-Host "Removing existing WinRM HTTPS listener with thumbprint: $($listener.CertificateThumbprint)"
      Remove-Item -Path $listener.PSPath -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
      Write-Host "Existing WinRM HTTPS listener removed."
    }
  }
  if ($cert) {
    Write-Host "Remove WinRM HTTPS certificate generated in image build..."
    Remove-Item -Path "Cert:\LocalMachine\My\$($cert.Thumbprint)" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Existing certificate removed."
  }

  $winrmConfig = @{
    CertificateThumbprint = $CertThumbprint
    ListeningAddress      = "*"
  }
  
  New-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Transport="HTTPS"; Address="*"} -ValueSet $winrmConfig -ErrorAction SilentlyContinue
  
  # Verify WinRM HTTPS is running
  Get-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Transport="HTTPS"; Address="*"}
  
  Write-Host "WinRM HTTPS enabled successfully on port 5986"

  Set-Item -Path WSMan:\localhost\Service\Auth\Kerberos -Value $true
  Set-Item -Path WSMan:\localhost\Service\Auth\Negotiate -Value $true

  Write-Host "Enabling firewall rule for winRM HTTPS if not"
  if (-not (Get-NetFirewallRule -DisplayName "Allow WinRM over HTTPS" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name "WinRM_HTTPS" -DisplayName "Allow WinRM over HTTPS" -Group "Custom Rules" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5986
    Write-Host "Firewall rule for WinRM HTTPS created."
  } else {
    Write-Host "Firewall rule for WinRM HTTPS already exists."
  }

  Write-Host "Restaeting WinRM service to apply changes..."
  Restart-Service -Name WinRM -Force
}

# Main execution
Write-Host "Starting post-provision script..."

if (Wait-DomainJoin) {
  Start-Sleep -Seconds 10
  $cert = Wait-MachineCertificate
  
  if ($cert) {
    Enable-WinRMHTTPS -CertThumbprint $cert.Thumbprint
    Write-Host "Post-provision configuration completed successfully"
  }
} else {
  Write-Host "Failed to join domain. Exiting."
  exit 1
}