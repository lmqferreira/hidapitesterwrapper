<#
.SYNOPSIS
    PowerShell script to retrieve files from a storage account using AzCopy.

.DESCRIPTION
    This script takes a source URL and a destination root folder. It constructs and runs an AzCopy command to copy the files from the source URL to the destination root folder, maintaining the folder structure. If the dry-run switch is used, it will add the --dry-run option to the AzCopy command. If the deltaCopy switch is used, it will add the --overwrite=ifSourceNewer option to the AzCopy command.

.PARAMETER SourceURL
    Source URL for AzCopy.

.PARAMETER DestinationRoot
    Destination root folder for AzCopy.

.PARAMETER dryRun
    Switch to enable dry-run mode.

.PARAMETER deltaCopy
    Switch to enable delta copy mode.

.EXAMPLE
    .\retreive-fromStorageAccount.ps1 -SourceURL "https://example.blob.core.windows.net/container/*?sv=..." -DestinationRoot "C:\DFSRoots" -dryRun -deltaCopy

    ## .\retreive-fromStorageAccount.ps1 -SourceURL "https://tdkmigtest.file.core.windows.net/tdkmigtest01/*?sv=2022tfx3VqBXba7E%3D" -DestinationRoot c:\x

    ## IMPORTANT NOTE ## url should contain containername/sourcedomainname/*
    ## sourcedominname was used during the backup process 
#>

param (
    [Parameter(Mandatory=$True, HelpMessage='Source URL for AzCopy')]
    [string]$SourceURL,

    [Parameter(Mandatory=$True, HelpMessage='Destination root folder for AzCopy')]
    [string]$DestinationRoot,

    [Parameter(Mandatory=$False, HelpMessage='Switch to enable dry-run mode')]
    [switch]$dryRun,

    [Parameter(Mandatory=$False, HelpMessage='Switch to enable delta copy mode')]
    [switch]$deltaCopy
)

# Construct the AzCopy command dynamically
$AzCopyCommand = "azcopy copy `"$SourceURL`" `"$DestinationRoot`" --recursive=true"

# Add --dry-run if the switch is used
if ($dryRun) {
    $AzCopyCommand += " --dry-run"
}

# Add --overwrite=ifSourceNewer if the deltaCopy switch is used
if ($deltaCopy) {
    $AzCopyCommand += " --overwrite=ifSourceNewer"
}

# Display the constructed command (for debugging)
Write-Host "Running Command: $AzCopyCommand"

# Execute the AzCopy command
Invoke-Expression $AzCopyCommand