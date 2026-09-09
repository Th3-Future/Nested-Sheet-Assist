# Sync script: Copies active VCarve gadget files, rebuilds .vgadget, and syncs OneDrive
$ErrorActionPreference = "Stop"
$repoDir = $PSScriptRoot
$installedDir = "C:\Users\Public\Documents\Vectric Files\Gadgets\VCarve Pro V12.5\Nested_Sheet_Assist"
$vCarveDir = "C:\Users\ezeor\OneDrive\WorkProjects\vCarve"

Write-Host "Syncing from installed VCarve gadget folder..."
Copy-Item "$installedDir\Nested_Sheet_Assist.lua" "$repoDir\Nested_Sheet_Assist.lua" -Force
Copy-Item "$installedDir\Nested_Sheet_Assist.htm" "$repoDir\Nested_Sheet_Assist.htm" -Force

Write-Host "Rebuilding .vgadget package..."
powershell -ExecutionPolicy Bypass -File "$repoDir\build.ps1"

Write-Host "Syncing .vgadget to vCarve..."
if (-not (Test-Path $vCarveDir)) {
    New-Item -ItemType Directory -Path $vCarveDir -Force | Out-Null
}
Copy-Item "$repoDir\Nested_Sheet_Assist.vgadget" "$vCarveDir\Nested_Sheet_Assist.vgadget" -Force

Write-Host "`nGit Status:"
& "C:\Users\ezeor\AppData\Local\Programs\Git\cmd\git.exe" -C "$repoDir" status
