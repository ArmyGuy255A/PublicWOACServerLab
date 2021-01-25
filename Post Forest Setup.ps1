$sites = @("DMAIN", "DIV-TAC")

$subnets = @(
    @{Name="Subnet1"; Subnet="192.168.0.0"; MaskBits="24"; Site=0},
    @{Name="Subnet2"; Subnet="10.0.0.0"; MaskBits="24"; Site=1}
)


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

#Task #2 : Create OU Structure
Write-Host "Creating OU Structure" -ForegroundColor Cyan

#Task #3 : Create User Accounts
Write-Host "Creating User Accounts" -ForegroundColor Cyan

#Task #4 : Create Security Groups
Write-Host "Creating Security Groups" -ForegroundColor Cyan

#Task #5 : Create Computer Accounts
Write-Host "Creating Computer Accounts" -ForegroundColor Cyan

#Task #6 : Create RODC Account
Write-Host "Creating RODC Account" -ForegroundColor Cyan