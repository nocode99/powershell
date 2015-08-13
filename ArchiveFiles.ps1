# Script will zip up files older than X months
# We collect phone call recordings from our vendor and the script is used 
# to archive the data by zipping the month of calls and
# moving the archive to a remote server

# Requirements: 
# 7-zip
# Create an encrypted credentials file for SMTP email
# Run powershell command on server to add encrypted text file
# (Get-Credential).password | ConvertFrom-SecureString > mailPW.txt
# Enter in valid credentials in popup

$folderPath = "D:\FTPS\InContact\"
$archivePath = "d:\ftps\archive\"
$archiveList = "FilesToBeArchived.txt"
$destinationPath = "\\remoteServer\Backup\InContact\"
$now = get-date
$log = "D:\FTPS\archive\log.txt"
$logfiles = "d:\ftps\logs\"
$7zip = "C:\Program Files\7-Zip\7z.exe"
$month = $now.addmonths(-2)
$year = $month.Year
$intMonth = $month.Month
$mmonth = $month.Month 
$Server = "server"

#SMTP Settings
$sender = "$SERVER <noreply@domain.com>"
$recipient = "infra@domain.com"
$smtpserver = "smtp.domain.com"
$pw = Get-Content .\MailPW.txt | ConvertTo-SecureString
$cred = New-Object System.Management.Automation.PSCredential "MailUser", $pw

if (-not (test-path "$env:ProgramFiles\7-Zip\7z.exe")) {throw "$env:ProgramFiles\7-Zip\7z.exe needed"} 
set-alias sz "$env:ProgramFiles\7-Zip\7z.exe" 

#If the value of the Month is a single digit, add a '0' in front
If ( $mmonth.toString().length -eq 1 ) {
    $mmonth = "0$mmonth"
}
$zipfileName = "$year"+"_$mmonth.7z"

Function LogWrite {
   Param ([string]$logstring)
   Add-content -Path $log -Value "$now : $logstring"
   #write-host "$now : $logstring"
}

Function SendEmail 
{
    param([String]$Message)
    $pw = Get-Content .\MailPW.txt | ConvertTo-SecureString
    $cred = New-Object System.Management.Automation.PSCredential "MailUser", $pw
    Send-MailMessage `
        -Credential $cred `
        -smtpserver $smtpserver `
        -to $receipient `
        -from $sender `
        -Subject "IINFTPS01 Zip Job Alert" `
        -body $Message
    LogWrite "Email notification sent"    
}

#Clears contents of the list of files to be archived
#Then creates a new list of files to be archived
Function GetFilesForArchive 
{
    Clear-Content $archivePath$archiveList
    get-childitem -Path $folderPath | Where-Object {$_.CreationTime.Month -eq $intmonth} | Foreach-object { 
        $a = "$folderPath$_" | Out-File "$archivePath$archiveList" -Append
    } 
    LogWrite "Compiled list of files for archive to $archivePath$ArchiveList"
}

Function ZipFile 
{
    param([string]$zipfile)
    Get-Content "$archivePath$ArchiveList" | Foreach-object {
        sz a -t7z "$archivePath$zipfile" $_
        LogWrite "Adding $_ and it's subdirectories and contents to $archivePath$zipFile"
    }
}

#Function VerifyZipFile will validate the contents of the zip file and make sure file is not corrupt. 
#Returns True if contents of zip are validated
Function VerifyZipFile 
{
    param([string]$verifyZipFile)
    write-host "$now verifying zip file"
    $command = sz t "$archivePath$verifyZipFile"
    if ($command -match "Everything is Ok") 
    {
        LogWrite "SUCCESS: Zip File verification"  
        return $True
    }
    else 
    {
        LogWrite "ERROR: Zip file did not pass verification"
        return $False
    }
}

Function DeleteZippedFiles 
{
    Get-Content "$archivePath$ArchiveList" | Foreach-object {
        write-host $_ is being removed...
        Remove-Item $_ -Recurse
        LogWrite "Removed $_ and it's subcontents"
    }
}

#Will move zip files from Archive folder to remote backup if file month is older than 2
Function MoveZipFiles 
{
    Get-ChildItem -Path $archivePath | Where-object { ((Get-Date).Month - $_.CreationTime.Month) -gt 2 } | Foreach-object {
        Move-Item -LiteralPath "$archivepath$_" -Destination "$DestinationPath$_"
    }
    LogWrite "Moving $archivepath$_ to remote backup"
}

#Delete old WinSCP logs older than 30 days
Function DeleteOldLogs
{
    Get-Childitem -Path $logfiles | where-object { (New-TimeSpan -Start $_.CreationTime -End $now).Days -gt 30 } | foreach-object { Remove-Item "$logfiles$_" }
}

#******************MAIN******************
#Script will archive files from files that are X months back
Function Main 
{
    GetFilesForArchive
    ZipFile $zipFileName
    If (VerifyZipFile $zipFileName -eq $True) 
    {
        SendEmail "IINFTPS01 zip job completed for $intmonth/$year"
        DeleteZippedFiles
        MoveZipFiles
    }
    Else 
    {
        SendEmail "IINFTPS01 zip job failed.  Please check server"
        Break
    }
}