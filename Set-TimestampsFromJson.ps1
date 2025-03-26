<#
.SYNOPSIS
    Updates file and directory timestamps based on a JSON file, using raw FILETIME values.

.DESCRIPTION
    This script reads a JSON file that contains entries with a RelativePath (relative to a provided parent path)
    and raw timestamp values (e.g. CreationTimeRaw, LastAccessTimeRaw, LastWriteTimeRaw). It then converts these raw
    FILETIME values into DateTime objects using [DateTime]::FromFileTimeUtc() and sets the corresponding UTC timestamp
    properties (CreationTimeUtc, LastAccessTimeUtc, LastWriteTimeUtc) on the target file or folder.
    
    The script supports a dry run mode and logs errors if an item does not exist or if the conversion fails.

.PARAMETER ParentPath
    The parent path where the target files/folders are located.
    For example, if ParentPath is 'C:\Target' and a JSON entry has "RelativePath": "BITRANS\behold.csv",
    the target will be 'C:\Target\BITRANS\behold.csv'.

.PARAMETER JsonFile
    The path to the JSON file containing the file/folder details and raw timestamps.

.PARAMETER DryRun
    If specified, the script will only simulate the changes and report what would be done without making any changes.

.EXAMPLE
    .\Set-TimestampsFromJson.ps1 -ParentPath "C:\Target" -JsonFile ".\timestamps.json"

    Updates timestamps for files and folders under C:\Target as specified in timestamps.json.

.EXAMPLE
    .\Set-TimestampsFromJson.ps1 -ParentPath "C:\Target" -JsonFile ".\timestamps.json" -DryRun -Verbose

    Runs in dry-run mode with verbose logging.
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param (
    [Parameter(Mandatory = $true)]
    [string]$ParentPath,

    [Parameter(Mandatory = $true)]
    [string]$JsonFile,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Converts a raw FILETIME value (in 100-nanosecond intervals since January 1, 1601 UTC)
# into a DateTime object in UTC.
function Convert-FileTimeRawToUTC {
    param (
        [Parameter(Mandatory = $true)]
        [Int64]$FileTimeRaw
    )
    try {
        $dt = [DateTime]::FromFileTimeUtc($FileTimeRaw)
        return $dt
    }
    catch {
        Write-Verbose "Failed to convert raw FILETIME: $FileTimeRaw"
        throw "Conversion failed for raw FILETIME value: $FileTimeRaw"
    }
}

# Verify that the parent path exists
if (-not (Test-Path -LiteralPath $ParentPath)) {
    Write-Error "Parent path '$ParentPath' does not exist. Exiting..."
    exit 1
}

# Verify that the JSON file exists
if (-not (Test-Path -LiteralPath $JsonFile)) {
    Write-Error "JSON file '$JsonFile' does not exist. Exiting..."
    exit 1
}

try {
    Write-Verbose "Reading JSON file: $JsonFile"
    $jsonContent = Get-Content -LiteralPath $JsonFile -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Failed to read or parse JSON file: $_"
    exit 1
}

foreach ($entry in $jsonContent) {
    # Construct the target path from the ParentPath and the entry's RelativePath.
    $targetPath = Join-Path -Path $ParentPath -ChildPath $entry.RelativePath

    Write-Verbose "Processing entry with RelativePath: $($entry.RelativePath)"
    Write-Verbose "Computed target path: $targetPath"

    if (-not (Test-Path -LiteralPath $targetPath)) {
        Write-Error "Target path '$targetPath' not found."
        continue
    }

    try {
        # Use -Force to access items that may be hidden or special.
        $item = Get-Item -LiteralPath $targetPath -Force -ErrorAction Stop

        # Convert the raw FILETIME values to UTC DateTime.
        $creationTimeUtc   = Convert-FileTimeRawToUTC -FileTimeRaw $entry.CreationTimeRaw
        $lastAccessTimeUtc = Convert-FileTimeRawToUTC -FileTimeRaw $entry.LastAccessTimeRaw
        $lastWriteTimeUtc  = Convert-FileTimeRawToUTC -FileTimeRaw $entry.LastWriteTimeRaw

        if ($DryRun) {
            Write-Host "[DryRun] Would update '$targetPath':"
            Write-Host "    CreationTimeUtc   => $creationTimeUtc"
            Write-Host "    LastAccessTimeUtc => $lastAccessTimeUtc"
            Write-Host "    LastWriteTimeUtc  => $lastWriteTimeUtc"
        }
        else {
            if ($PSCmdlet.ShouldProcess($targetPath, "Update timestamps using raw FILETIME values")) {
                Write-Verbose "Updating timestamps for '$targetPath'"
                $item.CreationTimeUtc   = $creationTimeUtc
                $item.LastAccessTimeUtc = $lastAccessTimeUtc
                $item.LastWriteTimeUtc  = $lastWriteTimeUtc
                Write-Host "Updated '$targetPath'"
            }
        }
    }
    catch {
        Write-Error "Failed to update '$targetPath': $_"
    }
}
