#Script will read through a file for user user
#each user will then be set to a disabled account
#moved into the disabled OU
#and remove all group memberships 

Import-Module ActiveDirectory

$userList = "c:\admin\userdisable.txt"
$file = Get-Content $userList
$log = "C:\admin\userdisable.log"
$now = Get-date
$count = 0

#Function to output logging to a file and print to PS terminal
Function LogWrite {
   Param ([string]$logstring)
   Add-content -Path $log -Value "$now : $logstring"
   write-host "$now : $logstring"
}
				
foreach ($user in $file) {
	#search for user in AD and see if they are enabled
	$ADsearch = [adsisearcher]""
	$ADsearch.filter = "(&(objectClass=user)(sAMAccountName=$user))"
    $ADfind = $ADsearch.findOne()
    $userAC = $ADfind.Properties.useraccountcontrol
	

	#If User is Enabled
	#66048 = user is enabled, password does not expire
	#512 = user is enabled
	if ($userAC -eq "66048" -OR $userAC -eq "512") {
		#get user membership properties
		$userProperties = Get-AdUser $user -Properties MemberOf
		#cycle through the memberships user is apart of 
		$userGroups = $userProperties.memberof | Foreach-Object { 
			$userCNIndex = $_.indexof(",")
			#if there is a membership match, remove them
			If ($_ -match "[a-z]") {
				Remove-ADGroupMember -Identity $_ -members $userProperties -Confirm:$false
				Logwrite "Removed $user from $_"  
			}
			Else {
				Logwrite "$user has no group memberships to remove from."  
			}
		}	
		#once user memberships are removed, disable user and move to Disabled Group OU
		get-aduser $user | move-adobject -TargetPath 'ou=Disabled,DC=iin,DC=private' ; set-adaccountcontrol -Identity $user -Enabled $false
        LogWrite "Moved $user to Disabled OU and set account to disabled"
	}
	Elseif ($userAC -eq "66050" -OR $userAC -eq "514") {
		Logwrite "$user is disabled.  Checking for group memberships..."
		#get user membership properties
		$userProperties = Get-AdUser $user -Properties MemberOf
		#cycle through the memberships user is apart of 
		$userGroups = $userProperties.memberof | Foreach-Object { 
			$userCNIndex = $_.indexof(",")
			#if there is a membership match, remove them
			If ($_ -match "[a-z]") {
				Remove-ADGroupMember -Identity $_ -members $userProperties -Confirm:$false
				LogWrite "Removed $user from $_"
			} #if
			Else {
			    Logwrite "$now User has no group memberships and is already disabled"  
			} #else
		} #for
		#move to Disabled OU if not already
		get-aduser $user | move-adobject -TargetPath 'ou=Disabled,DC=iin,DC=private' 
        Logwrite "Moved $user to Disabled OU even if already there"
    }  #elseif
} #foreach ($user in $file)
Logwrite "Script completed"

