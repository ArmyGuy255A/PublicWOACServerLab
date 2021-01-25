$sites = @("DMAIN", "DIV-TAC")

$subnets = @(
    @{Name="Subnet1"; Subnet="192.168.0.0"; MaskBits="24"; Site=0},
    @{Name="Subnet2"; Subnet="10.0.0.0"; MaskBits="24"; Site=1}
)

$topLevelOU = "1CAV_HQ"
$firstLevelOUs = @(
    "G1",
    "G2",
    "G3",
    "G6",
    "CMD-GRP"
)

$secondLevelOUs = @(
    "Computers",
    "Users",
    "IMOs"
)

$securityGroups = @(
    "IMOs",
    "Users"
)

$computerNamePrefix = "VAK9DI"

#change this back to true for production
$protectFromAccidentalDeletion = $false

$password = Read-Host "Type in your password ..." -AsSecureString

$skip = $true

if (!$skip) {
    #Task #1 : Create Sites and Services
    Write-Host "Creating Sites and Services" -ForegroundColor Cyan

    # Create the Sites
    foreach ($site in $sites) {
        Write-Host "Creating Site $site" -ForegroundColor Yellow
        New-ADReplicationSite -Name $site

        # Create the Subnets
        foreach ($subnet in $subnets) {
            if ($sites[$subnet.Site].Equals($site)) {
                Write-Host "Adding $($subnet.Subnet) to $site" -ForegroundColor Yellow
                New-ADReplicationSubnet -Name ("{0}/{1}" -f $subnet.Subnet, $subnet.MaskBits) -Site $site
            }
        }
    }

    # Set the DEFAULTIPSITELINK replication interval
    Write-Host "Setting the DEFAULTIPSITELINK replication interval to 15 minutes" -ForegroundColor Yellow
    Get-ADReplicationSiteLink 'DEFAULTIPSITELINK' | Set-ADReplicationSiteLink -ReplicationFrequencyInMinutes 15

    #Task #1b : Move DC1 into correct site
    Write-Host "Moving DC1 into $($sites[0])"  -ForegroundColor Yellow
    $dc = Get-ADComputer "DC1"
    Move-ADDirectoryServer -Identity $dc.Name -Site $sites[0]
}

#Task #2 : Create OU Structure
Write-Host "Creating OU Structure" -ForegroundColor Cyan

#Create the top level OU
Write-Host "Creating the TOP Level OU called $topLevelOU" -ForegroundColor Yellow
$topLevelOUObject = New-ADOrganizationalUnit -Name $topLevelOU -PassThru -ProtectedFromAccidentalDeletion:$protectFromAccidentalDeletion

#Create the First level OU's
foreach ($firstLevelOU in $firstLevelOUs) {
    Write-Host "Creating $firstLevelOU" -ForegroundColor Yellow
    $firstLevelOUObject = New-ADOrganizationalUnit -Name $firstLevelOU -Path $topLevelOUObject.DistinguishedName -PassThru -ProtectedFromAccidentalDeletion:$protectFromAccidentalDeletion
    
    #Create the Second level OU's
    foreach ($secondLevelOU in $secondLevelOUs) {
        Write-Host "`tCreating OU: $secondLevelOU" -ForegroundColor DarkYellow
        $secondLevelOUObject = New-ADOrganizationalUnit -Name $secondLevelOU -Path $firstLevelOUObject.DistinguishedName -PassThru -ProtectedFromAccidentalDeletion:$protectFromAccidentalDeletion
             

        #Create User Objects
        if ($secondLevelOU.Equals("Users")) {
            Write-Host "`t`tCreating User Accounts ..." -ForegroundColor Green
            New-ADUser -DisplayName ("{0} User" -f $firstLevelOU) -Name ("{0}_USER" -f $firstLevelOU) -AccountPassword $password -Path $secondLevelOUObject.DistinguishedName -Enabled:$true
        }

        #Create User Objects
        if ($secondLevelOU.Equals("IMOs")) {
            Write-Host "`t`tCreating IMO Accounts ..." -ForegroundColor Green
            New-ADUser -DisplayName ("{0} IMO" -f $firstLevelOU) -Name ("{0}_IMO" -f $firstLevelOU) -AccountPassword $password -Path $secondLevelOUObject.DistinguishedName -Enabled:$true
        }

        #Create Computer Objects
        if ($secondLevelOU.Equals("Computers")) {
            Write-Host "`t`tCreating Computer Accounts ..." -ForegroundColor Green
            0..9 |  Foreach-Object { New-ADComputer -Name ("{0}{1}CPU{2:00}" -f $computerNamePrefix,$firstLevelOU.Replace("-",""), $_) -Path $secondLevelOUObject.DistinguishedName }   
        }
    }


    # Create Security Groups
    foreach ($securityGroup in $securityGroups) {
        Write-Host "`tCreating Security Group: $securityGroup" -ForegroundColor Yellow
        $groupName = ("{0}_{1}" -f $firstLevelOU, $securityGroup)
        $groupDisplayName= ("{0} {1}" -f $firstLevelOU, $securityGroup)
        New-ADGroup -Name $groupName -DisplayName $groupDisplayName -Path $firstLevelOUObject.DistinguishedName -GroupScope Global -GroupCategory Security


        [array]$users = Get-ADUser -Filter * -SearchBase ("OU={0},{1}" -f $securityGroup,$firstLevelOUObject.DistinguishedName)
        Write-Host "`t`tAdding $($users.Count) user(s) to $groupName" -ForegroundColor DarkYellow
        Add-ADGroupMember -Identity $groupName -Members $users
    }

}

#TODO: Create the DIV_IMOs Group

#TODO: Add the G6_IMOs Group to the DIV_IMOs Group

#TODO: Create the RODC Account

#TODO: Bonus Challenge - Delegate Permissions to the OU's


#cleanup any AD objects
$cleanup = $false
if ($cleanup) {

    <# Run this code snipped to wipe out AD
    for ($i = 0; $i -lt 4; $i++) {
        $ADObjects = Get-ADObject -Filter '*' -SearchBase "OU=1CAV_HQ,DC=1cav,DC=army,DC=mil"
        $ADObjects | Remove-ADObject -Confirm:$false -ErrorAction:SilentlyContinue
    }
    #>
}