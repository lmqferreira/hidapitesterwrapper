<#
.SYNOPSIS
    PowerShell script to copy files to a storage account using AzCopy.

.DESCRIPTION
    This script takes a CSV file with paths, a destination URL, and a number of days to include files modified after. It constructs and runs an AzCopy command to copy the files. If the dry-run switch is used, it will add the --dry-run option to the AzCopy command. If the deltaCopy switch is used, it will add the --overwrite=ifSourceNewer option to the AzCopy command.

.PARAMETER CSVFile
    Path to the input CSV file.

.PARAMETER DestinationURL
    Destination URL for AzCopy.

.PARAMETER daysGone
    Number of days to include files modified after.

.PARAMETER dryRun
    Switch to enable dry-run mode.

.PARAMETER deltaCopy
    Switch to enable delta copy mode.

.EXAMPLE
    .\copy-toStorageAcc.ps1 -CSVFile "C:\path\to\input.csv" -DestinationURL "https://example.blob.core.windows.net/container" -daysGone 7 -dryRun -deltaCopy

    .\copy-toStorageInitial.ps1 -CSVFile .\folders_initial.csv -StorageAccURL "https://tdkmigtest.file.core.windows.net/tdkmigtest01/" -StorageAccSAS "https://tdkmigtest.file.core.windows.net/?sv=2022-11-02&ss=bfqt&srt=sco&ljdNo%2B03%2BAuouXEh26s8Pes%3D" -initialCopy

    .\copy-toStorageInitial.ps1 -CSVFile .\folders_sync_all.csv -StorageAccURL "https://tdkmigtest.file.core.windows.net/tdkmigtest01/" -StorageAccSAS "https://tdkmigtest.file.core.windows.net/?sv=2022-11-02&ss=bfqt&srt=Fw8oljdNo%2B03%2BAuouXEh26s8Pes%3D" -deltaCopy -deleteMisingFiles

    #>

param (
    [Parameter(ParameterSetName='InitialCopy', Mandatory=$True, HelpMessage='Switch to enable initial copy mode')]
    [switch]$initialCopy,

    [Parameter(ParameterSetName='DeltaCopy', Mandatory=$True, HelpMessage='Switch to enable delta copy mode')]
    [switch]$deltaCopy,

    [Parameter(ParameterSetName='InitialCopy', Mandatory=$True, HelpMessage='Path to the input CSV file')]
    [Parameter(ParameterSetName='DeltaCopy', Mandatory=$True, HelpMessage='Path to the input CSV file')]
    [string]$CSVFile,

    [Parameter(ParameterSetName='InitialCopy', Mandatory=$True, HelpMessage='Destination URL for AzCopy')]
    [Parameter(ParameterSetName='DeltaCopy', Mandatory=$True, HelpMessage='Path to the input CSV file')]
    [string]$StorageAccURL,

    [Parameter(ParameterSetName='InitialCopy', Mandatory=$True, HelpMessage='Destination URL for AzCopy')]
    [Parameter(ParameterSetName='DeltaCopy', Mandatory=$True, HelpMessage='Path to the input CSV file')]
    [string]$StorageAccSAS,

    [Parameter(ParameterSetName='InitialCopy', Mandatory=$False, HelpMessage='Number of days to include files modified after')]
    [int]$daysGone,

    [Parameter(ParameterSetName='DeltaCopy', Mandatory=$False, HelpMessage='Switch to enable dry-run mode')]
    [switch]$deleteMisingFiles,

    [Parameter(ParameterSetName='InitialCopy', Mandatory=$False, HelpMessage='Switch to enable dry-run mode')]
    [Parameter(ParameterSetName='DeltaCopy', Mandatory=$False, HelpMessage='Switch to enable dry-run mode')]
    [switch]$dryRun
)

# Start timing the execution
$startTime = Get-Date

# Import the CSV and filter rows where "Parent" equals "root"
$csvContent = Import-Csv -Path $CSVFile | Where-Object { $_.Parent -eq "root" }

if ($initialCopy) {
    # Loop through each filtered row and construct the AzCopy command
    foreach ($row in $csvContent) {
        $SourcePath = $row.fullPath

        # Ensure StorageAccURL ends with a "/"
        if (-not $StorageAccURL.EndsWith("/")) {
            $StorageAccURL += "/"
        }

        # Remove everything before "?" in StorageAccSAS
        $SAS = $StorageAccSAS.Substring($StorageAccSAS.IndexOf("?"))

        # Construct the DestinationURL by joining StorageAccURL and row.namespace
        $DestinationURL = "$StorageAccURL$($row.namespace)"

        # Append the SAS token to the DestinationURL
        $DestinationURL += $SAS

        # Construct the AzCopy command dynamically
        $AzCopyCommand = ".\azcopy copy `"$SourcePath`" `"$DestinationURL`" --recursive"

        # Add --include-after if daysGone parameter is provided
        if ($PSBoundParameters.ContainsKey('daysGone')) {
            $IncludeAfter = (Get-Date).AddDays(-$daysGone).ToString("yyyy-MM-ddTHH:mm:ssZ")
            $AzCopyCommand += " --include-after=$IncludeAfter"
        }

        # Add --dry-run if the switch is used
        if ($dryRun) {
            $AzCopyCommand += " --dry-run"
        }

        # Display the constructed command (for debugging)
        Write-Host "Running Command: $AzCopyCommand"

        # Execute the AzCopy command
        Invoke-Expression $AzCopyCommand
    }
}

if ($deltaCopy) {
    # Loop through each unique combination
    foreach ($row in $csvContent) {
        $SourcePath = $row.fullPath

        # Ensure StorageAccURL ends with a "/"
        if (-not $StorageAccURL.EndsWith("/")) {
            $StorageAccURL += "/"
        }

        # Remove everything before "?" in StorageAccSAS
        $SAS = $StorageAccSAS.Substring($StorageAccSAS.IndexOf("?"))

        # Construct the DestinationURL by joining StorageAccURL and row.namespace
        $DestinationURL = "$StorageAccURL$($row.namespace)/$($row.sharename)"

        # Append the SAS token to the DestinationURL
        $DestinationURL += $SAS

        # Construct the AzCopy command dynamically
        $AzCopyCommand = ".\azcopy sync `"$SourcePath`" `"$DestinationURL`" --recursive"

        # Add --delete-destination=true if the deleteMisingFiles switch is used
        if ($deleteMisingFiles) {
            $AzCopyCommand += " --delete-destination=true"
        }

        # Add --dry-run if the switch is used
        if ($dryRun) {
            $AzCopyCommand += " --dry-run"
        }

        # Display the constructed command (for debugging)
        Write-Host "Running Command: $AzCopyCommand"

        # Execute the AzCopy command
        Invoke-Expression $AzCopyCommand
    }
}



# End timing the execution
$endTime = Get-Date
$executionTime = $endTime - $startTime

# Report the execution time
Write-Host "Execution Time: $executionTime"