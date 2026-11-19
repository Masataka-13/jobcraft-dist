# JobCraft 26.3: Prism launcher pre-launch script (Windows PowerShell 5.1+)
# Prism "pre-launch command":
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/Masataka-13/jobcraft-dist/main/mc26.3/jobcraft-launch.ps1 | iex"
#
# What it does
#   1. Mods you unchecked in Prism (mods\*.jar.disabled) are renamed back to *.jar for a moment,
#      so packwiz sees them as installed and does not download them again.
#   2. Runs packwiz (updates the pack).
#   3. Renames those mods back to *.jar.disabled, so they stay unchecked.
#   Also removes leftover *.duplicate files.
#   If a disabled mod got a new version (new file name), the new version comes back checked.
# Messages are in English on purpose (the Prism log may not show Japanese correctly).

$ErrorActionPreference = 'Continue'
$pack = 'https://raw.githubusercontent.com/Masataka-13/jobcraft-dist/main/mc26.3/pack.toml'
$bootUrl = 'https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar'

$mc = $env:INST_MC_DIR
if (-not $mc) { $mc = (Get-Location).Path }
$java = $env:INST_JAVA
if (-not $java) { $java = 'java' }
$mods = Join-Path $mc 'mods'
$boot = Join-Path $mc 'packwiz-installer-bootstrap.jar'
New-Item -ItemType Directory -Force $mods | Out-Null

if (-not (Test-Path $boot)) {
	Write-Host "[JobCraft] downloading packwiz-installer-bootstrap.jar"
	Invoke-WebRequest $bootUrl -OutFile $boot -UseBasicParsing
}

# leftovers from the old way (Prism unchecked + packwiz re-downloaded)
Get-ChildItem -LiteralPath $mods -Filter '*.duplicate' -ErrorAction SilentlyContinue | ForEach-Object {
	Write-Host "[JobCraft] remove $($_.Name)"
	Remove-Item -LiteralPath $_.FullName -Force
}

# 1. unchecked mods -> *.jar for a moment
$disabled = @()
Get-ChildItem -LiteralPath $mods -Filter '*.jar.disabled' -ErrorAction SilentlyContinue | ForEach-Object {
	$jar = $_.FullName.Substring(0, $_.FullName.Length - '.disabled'.Length)
	if (Test-Path -LiteralPath $jar) {
		# both exist: keep the unchecked state, drop the extra jar
		Remove-Item -LiteralPath $jar -Force
	}
	Rename-Item -LiteralPath $_.FullName -NewName (Split-Path $jar -Leaf)
	$disabled += $jar
}
if ($disabled.Count -gt 0) { Write-Host "[JobCraft] unchecked mods: $($disabled.Count)" }

try {
	# 2. update the pack
	# Prism gives javaw.exe (no console). PowerShell does not wait for javaw, so wait with Start-Process -Wait.
	$p = Start-Process -FilePath $java -ArgumentList @('-jar', "`"$boot`"", $pack) -WorkingDirectory $mc -Wait -PassThru -NoNewWindow
	Write-Host "[JobCraft] packwiz finished (exit code $($p.ExitCode))"
}
catch {
	Write-Host "[JobCraft] packwiz could not run: $_ (starting the game anyway)"
}
finally {
	# 3. back to unchecked
	foreach ($jar in $disabled) {
		if (Test-Path -LiteralPath $jar) {
			if (Test-Path -LiteralPath ($jar + '.disabled')) { Remove-Item -LiteralPath $jar -Force }
			else { Rename-Item -LiteralPath $jar -NewName ((Split-Path $jar -Leaf) + '.disabled') }
		}
	}
}
exit 0
