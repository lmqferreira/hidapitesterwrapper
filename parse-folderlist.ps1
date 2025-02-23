param (
    [string]$inputCsvPath
)

# Determine the output CSV file path
$outputFolderPath = Split-Path -Path $inputCsvPath
$outputFileName = [System.IO.Path]::GetFileNameWithoutExtension($inputCsvPath) + "-processed_data.csv"
$outputCsvPath = Join-Path -Path $outputFolderPath -ChildPath $outputFileName

# Ensure the output file does not overwrite an existing file
$counter = 1
while (Test-Path -Path $outputCsvPath) {
    $outputFileName = [System.IO.Path]::GetFileNameWithoutExtension($inputCsvPath) + "-processed_data-{0:D2}.csv" -f $counter
    $outputCsvPath = Join-Path -Path $outputFolderPath -ChildPath $outputFileName
    $counter++
}

# Import the input CSV file
$csvContent = Import-Csv -Path $inputCsvPath

# Initialize an array to store the processed data
$processedData = @()

# Process each row in the CSV
foreach ($row in $csvContent) {
    $folderPath = $row.Folder

    # Extract domain, namespace, folder, and parent
    if ($folderPath -match '\\\\([^\\]+)\\([^\\]+)\\(.+)') {
        $domain = $matches[1]
        $namespace = $matches[2]
        $remainingPath = $matches[3]

        $pathParts = $remainingPath -split '\\'
        $folder = $pathParts[-1]
        $parent = if ($pathParts.Length -gt 1) { $pathParts[-2] } else { "ROOT" }
        $fullPath = $folderPath

        # Extract the part without the domain
        $woDomain = $fullPath -replace "^\\\\$domain\\", ""

        # Create a custom object with the extracted information
        $processedRow = [PSCustomObject]@{
            FullPath = $fullPath
            Domain = $domain
            Namespace = $namespace
            ShareName = $folder
            Parent = $parent
            woDomain = $woDomain
        }

        # Add the processed row to the array
        $processedData += $processedRow
    }
}

# Export the processed data to the output CSV file
$processedData | Export-Csv -Path $outputCsvPath -NoTypeInformation -Encoding UTF8

Write-Host "Processed data has been written to $outputCsvPath"