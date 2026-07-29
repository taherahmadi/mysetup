# Install JetBrainsMono Nerd Font for the current user (Windows).
# Run in PowerShell on the machine that renders your terminal:
#   powershell -ExecutionPolicy Bypass -File install-nerd-font.ps1
$ErrorActionPreference = "Stop"

$tmp = Join-Path $env:TEMP "JetBrainsMonoNF"
$zip = "$tmp.zip"
Invoke-WebRequest "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" -OutFile $zip
Expand-Archive $zip -DestinationPath $tmp -Force

$fontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null

Get-ChildItem $tmp -Filter *.ttf | ForEach-Object {
    $dest = Join-Path $fontsDir $_.Name
    Copy-Item $_.FullName $dest -Force
    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" `
        -Name ($_.BaseName + " (TrueType)") -Value $dest -PropertyType String -Force | Out-Null
}

Remove-Item $zip -Force
Remove-Item $tmp -Recurse -Force
Write-Host "Installed. Set your terminal font to 'JetBrainsMono Nerd Font'."
Write-Host "Windows Terminal: Settings > Profiles > Defaults > Appearance > Font face."
