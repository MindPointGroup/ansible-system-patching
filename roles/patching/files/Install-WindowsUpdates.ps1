<# 
    .SYNOPSIS 
        Powershell Script to Install Updates
    .DESCRIPTION 
        Uses the Windows Update API to search, filter, and install updates.
    .PARAMETER Restart 
        Whether to reboot the machine if one is required after installation.
    .PARAMETER List 
        Only list the updates that are available for download/install.
    .PARAMETER UpdateCategories 
        Comma separated list of update categories that you want to install.
    .PARAMETER KB
        Specify a single or comma separate list of KB's to install
    .EXAMPLE 
            Install-Updates.ps1 -Restart True -UpdateCategories Definition, Critical, Security
            Install-Updates.ps1 -Restart True -KB KB2345678, KB3107780
    .Notes 
        Author: Daniel Shepherd
        email: <daniels@mindpointgroup.com>
        website: http://www.mindpointgroup.com/ 
 
        Version History 
        0.1  6/2/2014 
            - Initial Release  
#> 
[CmdletBinding()] 
param(
$Path = (Get-Location), 
[switch]$Restart = $False,  
[Bool]$List = $False,  
[ValidateSet("Critical", "Definition", "Application", "FeaturePacks", "Security", "ServicePacks", "Tools", "UpdateRollups", "Updates", "All")]
[String]$UpdateCategories = "all",
[String]$KB = "*"
 
) 

$CurrentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent()) 
    if (($CurrentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) -eq $false) {
        $ArgList = "-noprofile -noexit -file `"{0}`" -Path `"$Path`""
        If ($Reboot) {$ArgList = $ArgList + " -Reboot"}
        If ($List) {$ArgumentList = $ArgumentList + " -List"}
        If ($UpdateCategories) {$ArgumentList = $ArgumentList + " -UpdateCategories $UpdateCategories"}
        If ($KB) {$ArgumentList = $ArgumentList + " -KB $KB"}
        Start-Process powershell.exe -Verb RunAs -ArgumentList ($ArgList -f ($myinvocation.MyCommand.Definition))
        Break
    }
#Echo "Restart =" $Restart
#Echo "List =" $List
#Echo "UpdateCats =" $UpdateCategories
#Echo "KB =" $KB

$categories = @{"critical" = "E6CF1350-C01B-414D-A61F-263D14D133B4";
                "definition" = "E0789628-CE08-4437-BE74-2495B842F43B";
                "application" = "5C9376AB-8CE6-464A-B136-22113DD69801";
                "featurepacks" = "B54E7D24-7ADD-428F-8B75-90A396FA584F";
                "security" = "0FA1201D-4330-4FA8-8AE9-B877473B6441";
                "servicepacks" = "68C5B0A3-D1A6-4553-AE49-01D3A7827828";
                "tools" = "B4832BD8-E735-4761-8DAF-37F882276DAB";
                "updaterollups" = "28BC880E-0592-4CBF-8F95-C79B17911D5F";
                "updates" = "CD5FFD1E-E932-4E3A-BF74-18BF0B1BBD83"}
$updateCatIDs = @()
$availableUpdates = @() 
$kbIDs = @()
$searchFilter = "IsInstalled=0 and IsHidden=0"

# Creating Update Session object 
$muSession = New-Object -ComObject "Microsoft.Update.Session" 

#Processing category types
#Loop through passed in categories and build arrary
foreach($cat in $UpdateCategories.split(",").Trim(" ")) {
    $cat = $cat.ToLower()
    If ($cat -eq "all") {
        $updateCatIDs = "*"
        Break
    }
    Else {
        $updateCatIDs += $categories.Item($cat)
    }
} 

#Processing List of KBs
#Loop through passed in KBs and build array
foreach($id in ($KB.split(",").Trim(" "))) {
    $id = $id.ToLower()
    If (($id -eq "*") -or ($id -eq "all")) {
        $kbIDs = "*"
        Break
    }
    Else {
        $kbIDs += $id.Trim("kb")
    }
} 

# Search for updates
$muSearch = $muSession.CreateUpdateSearcher() 

If ($kbIDs -ne "*") {
    $muSearchResults = $muSearch.Search($searchFilter).Updates

    foreach($update in $muSearchResults) { 
        If ($kbIDs -contains $update.KBArticleIDs) {
            $availableUpdates += $update
        }
    }
}
ElseIf ($updateCatIDs -eq "*") {
    #Just get all the updates that are available for install
    Write-Host "Should do this"
    $availableUpdates = $muSearch.Search($searchFilter).Updates
}
Else { 
    $searchFilter = ""
    foreach($catID in $updateCatIDs) { 
        $searchFilter += "(IsInstalled=0 and IsHidden=0 and CategoryIDs contains '"+$catID+"')" 
    }

    $availableUpdates = $muSearch.Search($searchFilter).Updates
}  

Write-Host $availableUpdates.Count
# Check if we have any updates
If ($availableUpdates.Count -eq 0) {
    Write-Host "No updates: nothing changed"
    Exit 0
}
# Accept Eula for silent install and add to update Collection 
$updateCollection = New-Object -ComObject "Microsoft.Update.UpdateColl"

foreach ($update in $availableUpdates) { 
    #Write-Host "Adding update -" $update
    If ($update.EulaAccepted -eq 0) {
        $update.AcceptEula()
    }

    $updateCollection.Add($update)
}

# Download updates
$muDownloader = $muSession.CreateUpdateDownloader()
$muDownloader.Updates = $updateCollection

try {
    $muDownloader.Download()
}
catch {
    Write-Host "FAILED!! on Download"
    Exit 1
}

# Install downloaded updates
$installCollection = New-Object -ComObject "Microsoft.Update.UpdateColl"

foreach ($update in $availableUpdates) { 
    If ($update.IsDownloaded) {
    #Write-Host "Adding downloaded update - " $update
        $installCollection.Add($update) 
    } 
} 

# Check if we have any updates at this stage
If ($installCollection.Count -eq 0) {
    Write-Host "FAILED!! nothing in download collection"
    Exit 1
}

$muInstaller = $muSession.CreateUpdateInstaller() 
$muInstaller.Updates = $installCollection

try {
    $muInstallResults = $muInstaller.Install() 
}
catch {
    Write-Host "FAILED!! on Install"
    Exit 1
}

# Reboot if needed 
If ($muInstallResults.RebootRequired -and $Restart) { 
    Restart-Computer -Force
} 
