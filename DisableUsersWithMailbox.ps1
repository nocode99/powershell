#Script will check Active Directory for disabled users and see if there is an Exchange 2010 mailbox with the account
#Purpose: To Clean Up Mailboxes

import-module activedirectory

#Check to see if MSEXCH2010 snap-in is installed.  Only needs to run once on a machine.
#If Snapin does not exist, add-snapin
If ((Get-PSSnapIn Microsoft.Exchange.Management.Powershell.E2010 -ErrorAction SilentlyContinue) -eq $null) {
    Add-PSSnapIn Microsoft.Exchange.Management.PowerShell.E2010
    write-host adding snapin
}
Else {
    #searches AD for disabled user accounts
    search-adaccount -accountdisabled -usersonly | foreach-object {
        #for each user
        #check if mailbox exists
        $disabledUsersWithMailbox = Get-Mailbox $_.samaccountname -ErrorAction SilentlyContinue | select Alias
        #if user has mailbox 
        If (![string]::IsNullOrEmpty($disabledUsersWithMailbox)) {
            $user = $disabledUsersWithMailbox.Alias
            write-host $user 
            #make sure file is empty when running
            $user | Out-File -Filepath "c:\admin\disableduserswithmailbox.txt" -Append 
        }
    }
}