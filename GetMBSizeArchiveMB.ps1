Import-Module ActiveDirectory

$inFile = Get-Content "D:\admin\ArchiveMailbox\users.txt"
$total = [decimal]0
#Check to see if MSEXCH2010 snap-in is installed.  Only needs to run once on a machine.
#If Snapin does not exist, add-snapin
If ((Get-PSSnapIn Microsoft.Exchange.Management.Powershell.E2010 -ErrorAction SilentlyContinue) -eq $null) {
    Add-PSSnapIn Microsoft.Exchange.Management.PowerShell.E2010
    write-host adding snapin
}

#Function to get the size of a user's mailbox
Function GetTotalMailboxSize {
    Param ([String]$inputUser)
    Process {
        Get-Mailboxstatistics -Identity $inputUser.trim() | foreach-object {
            #grabs TotalItemSize from mailbox and convert to a string
            [string]$mbSize = $_.TotalItemSize
            #To differentiate size types, we need to grab a subset of the string
            #and convert the data to GB as necessary
            If ($mbSize -like '*GB*') {
                #grab first 5 characters of string
                $mbsizeNew = $mbSize.substring(0,5)
                #convert back to decimal
                [decimal]$mbsize = [decimal]$mbsizeNew
            } #if
            #if string contains MB, convert to GB
            elseif ($mbSize -like '*MB*') {
                #first grab first 4 characters of string
                $mbSizeNew = $mbSize.substring(0,4)
                #convert to GB and convert to decimal
                [decimal]$mbsize = ([decimal]$mbsizeNew)/1000
            } #elseif
            #if in KB, don't bother :)
            else {
                $mbsize = 0.0
            } #else
    } #foreach-object
    #return the size of the mailbox to the function
    return $mbsize
    }#process
} #function

#Function requires a username to be passed in
#if multiple users, mailbox archive will be put into a queue
Function ArchiveMailbox { 
    Param ([String]$inputUserArch)
    Process {
        $fileshare = "\\481822-IINEXCH1\PST-Exports\$inputUserArch.pst"
        New-MailboxExportRequest -Mailbox $inputUserArch -FilePath $fileshare
    }
}

#MAIN
#for loop to run through user list and can call either function

foreach ($user in $inFile) {
    $data = GetTotalMailboxSize $user
    $total = $total + $data
    #write-host $data
    ArchiveMailbox $user
}
write-host Total size of mailbox archive will be $total
write-host All mailbox queued for archiving.  
write-host "To check the status of the queue, type: Get-MailboxExportRequest -Queued"
write-host "To check if completed, type: Get-MailboxExportRequest -Completed"