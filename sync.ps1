# Sync script: Copies active VCarve gadget files, rebuilds .vgadget, and syncs OneDrive
$ErrorActionPreference = "Stop"
$repoDir = "C:\Users\ezeor\Documents\GitHub\Nested-Sheet-Assist"
$installedDir = "C:\Users\Public\Documents\Vectric Files\Gadgets\VCarve Pro V12.5\Nested_Sheet_Assist"
$oneDriveDir = "C:\Users\ezeor\OneDrive\Automatic Material Dispenser System\Mould CNC"

Write-Host "Syncing from installed VCarve gadget folder..."
Copy-Item "$installedDir\Nested_Sheet_Assist.lua" "$repoDir\Nested_Sheet_Assist.lua" -Force
Copy-Item "$installedDir\Nested_Sheet_Assist.htm" "$repoDir\Nested_Sheet_Assist.htm" -Force

Write-Host "Rebuilding .vgadget package..."
powershell -ExecutionPolicy Bypass -File "$repoDir\build.ps1"

Write-Host "Syncing .vgadget to OneDrive..."
if (Test-Path $oneDriveDir) {
    Copy-Item "$repoDir\Nested_Sheet_Assist.vgadget" "$oneDriveDir\Nested_Sheet_Assist.vgadget" -Force
}

Write-Host "`nGit Status:"
& "C:\Users\ezeor\AppData\Local\Programs\Git\cmd\git.exe" -C "$repoDir" status
