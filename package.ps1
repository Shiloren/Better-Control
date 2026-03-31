# package.ps1
# Script to package the Better Control addon into a ZIP file

$addonName = "BetterControl"
$sourcePath = Get-Location
$distPath = Join-Path $sourcePath ".dist"
$tempPath = Join-Path $sourcePath ".temp_package"
$addonTempPath = Join-Path $tempPath $addonName
$zipFile = Join-Path $distPath "$addonName.zip"

Write-Host "Packaging Better Control..." -ForegroundColor Cyan

# Ensure dist exists
if (-not (Test-Path $distPath)) {
    New-Item -ItemType Directory -Path $distPath | Out-Null
}

# Clean temp and old zip
if (Test-Path $tempPath) { Remove-Item -Path $tempPath -Recurse -Force }
if (Test-Path $zipFile) { Remove-Item -Path $zipFile -Force }

# Create temp addon folder
New-Item -ItemType Directory -Path $addonTempPath -Force | Out-Null

$excludeList = @(
    ".git", 
    ".gitignore", 
    ".github", 
    ".agents", 
    "agents.md", 
    "node_modules", 
    "tests", 
    "implementation_plan.md", 
    "task.md", 
    "walkthrough.md", 
    "deploy.ps1", 
    ".antigravityignore",
    ".dist",
    ".temp_package",
    "package.ps1",
    ".scratch"
)

Write-Host "Copying files to temporary directory..."
Get-ChildItem -Path $sourcePath -Exclude $excludeList | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $addonTempPath -Recurse -Force
}

Write-Host "Creating ZIP file: $zipFile"
Compress-Archive -Path $addonTempPath -DestinationPath $zipFile -Force

# Cleanup temp
Remove-Item -Path $tempPath -Recurse -Force

Write-Host "Packaging complete! You can find the ZIP in the .dist folder." -ForegroundColor Green
