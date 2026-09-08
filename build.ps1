# Packager script to compile source files into a Vectric .vgadget archive
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputVgadget = Join-Path $scriptDir "Nested_Sheet_Assist.vgadget"

if (Test-Path $outputVgadget) {
    Remove-Item -Path $outputVgadget -Force
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zipStream = [System.IO.File]::Open($outputVgadget, [System.IO.FileMode]::CreateNew)
$archive = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)

function Add-ZipEntry($archive, $entryName, $sourceFilePath) {
    $bytes = [System.IO.File]::ReadAllBytes($sourceFilePath)
    $entry = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $entryStream = $entry.Open()
    $entryStream.Write($bytes, 0, $bytes.Length)
    $entryStream.Close()
}

Add-ZipEntry $archive "Nested_Sheet_Assist/Nested_Sheet_Assist.lua" (Join-Path $scriptDir "Nested_Sheet_Assist.lua")
Add-ZipEntry $archive "Nested_Sheet_Assist/Nested_Sheet_Assist.htm" (Join-Path $scriptDir "Nested_Sheet_Assist.htm")
Add-ZipEntry $archive "Nested_Sheet_Assist/Nested_Sheet_Assist.txt" (Join-Path $scriptDir "Nested_Sheet_Assist.txt")

$archive.Dispose()
$zipStream.Dispose()

Write-Host "Created $outputVgadget"