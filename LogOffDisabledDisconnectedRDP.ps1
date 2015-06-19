#LogOffDisabledDisconnectedRDP.ps1
# 1. Script will search Active Directory for a list of servers
# 2. Query each server for disconnected user sessions
# 3. Verify in AD if the user is disabled
# 4. Disconnect the user session if 2 and 3 are true

Import-Module ActiveDirectory
#Install module with default settings
#http://psterminalservices.codeplex.com/
Import-Module PSTerminalServices
# Query Active Directory for computers running a Server operating system
$Servers = Get-ADComputer -Filter {OperatingSystem -like "*server*"}
$now = Get-Date
$ADSearch = new-object DirectoryServices.DirectorySearcher([ADSI]””)

#loop through servers
ForEach ($Server in $Servers) {
    #$ServerName = "qaiinsql01"
    $ServerName = $Server.Name
    #pings each server to make sure it's available
    If(Test-Connection -Cn $ServerName -BufferSize 16 -Count 1 -ea 0 -quiet) {
        Get-TSSession -ComputerName $ServerName | ? {$_.State -eq "Disconnected"} | % {
			$username = $_ | select -ExpandProperty UserName
            $domain = "IIN\"
            #if DisconnectTime is null, Powershell v1,2,3 will throw exception.
            #try/catch block is to continue running script if value is empty
            try {
                $lastLogin = $_ | select -ExpandProperty DisconnectTime
                #make sure there is a string in the username
                If ($username -match "[a-z]") {
                    #calculate how many days user has been disconnected
                    $difference = New-Timespan -End $now -Start $lastlogin
                    #searching AD to find if user is enabled or disabled
                    $ADsearch.filter = "(&(objectClass=user)(sAMAccountName=$username))"
                    $ADfind = $ADsearch.findOne()
                    $value = $ADfind.Properties.useraccountcontrol
                    #if user is disabled, Password does not expire
                    If ($value -eq "66050") {
                        write-host $domain$username on $servername has been disconnected for $difference.days days
                        Get-TSSession -ComputerName $servername -Username $domain$username | Stop-TSSession -Computername $servername -Force
                        write-host killed $username on $servername
                    }
                    ELse {
                        write-host Active user $domain$username on $servername has been disconnected for $difference.days days
                    }            
                }
            }
            catch {
                
            }
		}
    }
    ELSE {
        write-host $ServerName "not reachable" -ForegroundColor Red
    }

}
