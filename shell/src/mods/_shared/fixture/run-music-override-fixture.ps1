# MusicOverrideCodec fixture. Prints one "fixture OK|FAIL ..." line per check; exit 0 when the last line is OK.
$devTools = $env:SSF2_DEV_TOOLS
if (-not $devTools) { throw "Set SSF2_DEV_TOOLS to the shell-dev tools folder." }
. (Join-Path $devTools "_toolchain.ps1")
$java = Require-Ssf2Java
$sdk = Require-Ssf2AirSdk
$jar = Require-Ssf2AsconfigcJar
$here = $PSScriptRoot
Push-Location $here
try {
	$resultPath = Join-Path $env:APPDATA "MusicOverrideCodecFixture\Local Store\music-override-fixture.txt"
	if (Test-Path -LiteralPath $resultPath) { Remove-Item -LiteralPath $resultPath -Force }
	& $java -jar $jar --sdk $sdk --project (Join-Path $here "MusicOverrideCodecFixture-asconfig.json")
	if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
	$adl = Join-Path $sdk "bin\adl.exe"
	& $adl -nodebug (Join-Path $here "MusicOverrideCodecFixture-app.xml") $here
	$lines = @()
	if (Test-Path -LiteralPath $resultPath) { $lines = @(Get-Content -LiteralPath $resultPath) }
	$lines | ForEach-Object { Write-Output "fixture $_" }
	if ($lines.Count -gt 0 -and $lines[-1].Trim() -eq "OK") { exit 0 }
	exit 1
}
finally {
	Pop-Location
}
