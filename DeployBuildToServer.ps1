#Automated deployment script for Windows server 2012
param (
    [Parameter(Mandatory=$true)][string]$buildVersion,
    [Parameter(Mandatory=$true)][string]$source,
    [Parameter(Mandatory=$true)][string]$destination,
    [Parameter(Mandatory=$true)][string]$ServerName,
    [Parameter(Mandatory=$true)][string]$Username,
    [Parameter(Mandatory=$true)][securestring]$Password
)

$MySecureCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username,$SecureString

#Open a session to server
Write-Host "Opening a remote session to server $ServerName" -ForegroundColor Green
$Session = New-PSSession -ComputerName $ServerName -Credential $MySecureCreds

#Stop the IIS server
try {
    invoke-command -Session $Session -ScriptBlock {iisreset.exe /STOP} -ErrorAction Stop  
}
catch {
    Write-Host "Failed to stop IIS service on $ServerName" -ForegroundColor Red
}
#remove the previous version except folder "App_Data"
if ((Test-Path $source)){
    try {
        Write-Host "Removing older version except folder App_Data" -ForegroundColor Green
        invoke-command -Session $Session -ScriptBlock {
            Get-ChildItem -Path  $args[0] -Recurse |
            Select-Object -ExpandProperty FullName |
            Where-Object {$_ -notlike '*\App_Data*'} |
            Sort-Object length -Descending |
            Remove-Item -force -Recurse } -ArgumentList $destination -ErrorAction Stop 
        Write-Host "...done." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to remove older version." -ForegroundColor Red
    }
    # Copy build output to server
    Write-Host "Copying build output to $destination" -ForegroundColor Green
    try {
        Copy-Item -Recurse -Path $source -Destination $destination -ToSession $Session -verbose -ErrorAction Stop
        Write-Host "...done." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to copy $source to $destination on $ServerName" -ForegroundColor Red
    }
}
else {
    Write-Host "'$source' does not exist. No files have been copied nor removed." -ForegroundColor Red
}

#Start the IIS server
invoke-command -Session $Session -ScriptBlock {iisreset.exe /START}
#Stop the PSsession after script run
Get-PSSession -ComputerName $ServerName -Credential $MySecureCreds | Remove-PSSession 
Write-Host "Remote session closed." -ForegroundColor Green