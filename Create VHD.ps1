$VirtualMachinePath = ("{0}\Virtual Machines" -f [Environment]::GetFolderPath("Desktop"))
Set-Location $VirtualMachinePath

$servernames = @(
"CORPS-DC",
"1CAV-DC1",
"1CAV-COREDC",
"1CAV-APP-SVR1",
"1CAV-DC2",
"1CAV-RODC",
"1CAV-APP-SVR2"
"RRAS"
) | ForEach-Object { New-VHD -ParentPath C:\Lab\BaseVHD\W2K12R2.vhdx -Differencing -Path ("{0}.vhdx" -f $_ )}

$clientnames = @(
"1CAV-DTAC-CLIENT",
"1CAV-DMAIN-CLIENT"
) | ForEach-Object { New-VHD -ParentPath C:\Lab\BaseVHD\WIN10.vhdx -Differencing -Path ("{0}.vhdx" -f $_ )}