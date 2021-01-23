$VirtualMachinePath = ("{0}\Virtual Machines" -f [Environment]::GetFolderPath("Desktop"))
Set-Location $VirtualMachinePath

$dmainClients = @(
    "1CAV-DC1",
    "1CAV-COREDC",
    "1CAV-APP-SVR1",
    "1CAV-DMAIN-CLIENT"
)
$dtacClients = @(
    "1CAV-DC2",
    "1CAV-RODC",
    "1CAV-APP-SVR2",
    "1CAV-DTAC-CLIENT"
)

$iiiCorpsClients = @("CORPS-DC")

Function Write-HostWithKeywordColor () {
    param(
        [string]$Message, 
        [string]$Keyword, 
        [System.ConsoleColor]$DefaultTextColor = [System.ConsoleColor]::White,
        [System.ConsoleColor]$KeywordColor, 
        [switch]$NoNewLine
    )

    $messageToWrite = [System.Collections.ArrayList]::new()
        
    #TODO: This produces buggy results. Try implementing a REGEX pattern to match whole words before continuing
    $splitMessage = $Message -csplit $Keyword

    for ($i = 0; $i -lt $splitMessage.Count; $i++) {           
            
        # Add the message to the screen with the requested default color.
        $messageToWrite.Add(
            [PSCustomObject]@{
                TextValue = $splitMessage[$i]
                TextColor = $DefaultTextColor
            }
        ) | Out-Null

        # Only include the keyword if it isn't the last item in the loop
        if ($i  -ne ($splitMessage.Count -1)) {
            $messageToWrite.Add(
                [PSCustomObject]@{
                    TextValue = $Keyword
                    TextColor = $KeywordColor
                }
            ) | Out-Null
        }
    }

    foreach ($messageObject in $messageToWrite) {
        Write-Host $messageObject.TextValue -ForegroundColor $messageObject.TextColor -NoNewline    
    }

    if (!$NoNewLine) {
        Write-Host
    }    
}

$vmKeywordColor = [System.ConsoleColor]::Cyan

Function Create-VirtualMachines ([array]$clientNames, [array]$switchNames) {

    #Step 1: Create Switches
    foreach ($switchName in $switchNames) {
        $exists = if (Get-VMSwitch $switchName -ErrorAction SilentlyContinue) { $true } else { $false }
        if ($exists) {
            Write-HostWithKeywordColor -Message "vSwitch $switchName already exists..." -Keyword $switchName -KeywordColor Yellow
        } else {
            Write-HostWithKeywordColor -Message "Creating vSwitch $switchName" -Keyword $switchName -KeywordColor Yellow
            New-VMSwitch -Name $switchName -SwitchType Private | Out-Null
        }            
    }

    foreach ($clientName in $clientNames) {        
        
        #Step 2: Create VM
        Write-HostWithKeywordColor "Create a new VM named $clientName" -Keyword $clientName -KeywordColor $vmKeywordColor
        New-VM -Name $clientName -SwitchName $switchNames[0] -VHDPath ("{0}\{1}.vhdx" -f $VirtualMachinePath, $clientName) -Generation 2  | Out-Null

        #Step 3: Create Additional NICs if more than one switch is provided
        if ($switchNames.Count -gt 1) {
            for ($i = 1; $i -lt $switchNames.Count; $i++) {
                Write-HostWithKeywordColor "Adding additional NIC to $clientName " -Keyword $clientName -KeywordColor $vmKeywordColor -NoNewLine
                Write-HostWithKeywordColor "attached to vSwitch $($switchNames[$i])" -Keyword $switchNames[$i] -KeywordColor Yellow
                Add-VMNetworkAdapter -VMName $clientName -SwitchName $switchNames[$i]
            }            
        }

        #Step 4: Configuring Memory
        Write-HostWithKeywordColor "Configuring memory settings for $clientName" -Keyword $clientName -KeywordColor $vmKeywordColor
        Set-VMMemory -VMName $clientName -StartupBytes 512MB -DynamicMemoryEnabled $true -MinimumBytes 512MB -MaximumBytes 4GB

        #Step 5: Configure CPU
        Write-HostWithKeywordColor "Configuring CPU settings for $clientName" -Keyword $clientName -KeywordColor $vmKeywordColor
        Set-VMProcessor -VMName $clientName -Count 4

        #Step 6: Checkpoint
        Write-HostWithKeywordColor "Creating baseline checkpoint for $clientName" -Keyword $clientName -KeywordColor $vmKeywordColor
        Checkpoint-VM -Name $clientName -SnapshotName "Baseline"

        #Step 7: Power On
        #Write-Host "Powering on $clientName"
        #Start-VM -Name $clientName

        Write-HostWithKeywordColor "Created $clientName !!" -Keyword $clientName -KeywordColor $vmKeywordColor -DefaultTextColor Green
    }    
}


#Loop Through the Arrays
Create-VirtualMachines -clientNames $iiiCorpsClients -switchName @("III CORPS")
Create-VirtualMachines -clientNames $dtacClients -switchName @("DTAC")
Create-VirtualMachines -clientNames $dmainClients -switchName @("DMAIN")

#Create the RRAS
Create-VirtualMachines -clientNames @("RRAS") -switchNames @("III CORPS", "DTAC", "DMAIN")

#Delete everything!
#Get-VM | Remove-VM -Force -Confirm:$false
#Get-VMSwitch | Remove-VMSwitch -Force -Confirm:$false


Write-Host "Complete!" -ForegroundColor Green