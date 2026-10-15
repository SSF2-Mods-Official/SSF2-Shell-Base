$devTools = $env:SSF2_DEV_TOOLS
if (-not $devTools) { throw "Set SSF2_DEV_TOOLS to the shell-dev tools folder." }
. (Join-Path $devTools "_toolchain.ps1")
$java = Require-Ssf2Java
$sdk = Require-Ssf2AirSdk
$jar = Require-Ssf2AsconfigcJar
$here = $PSScriptRoot
Push-Location $here
try {
	& $java -jar $jar --sdk $sdk --project (Join-Path $here "asconfig.json")
	if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
	$resultPath = Join-Path $env:APPDATA "PaletteDeepFixture\Local Store\palette-deep-fixture.txt"
	if (Test-Path -LiteralPath $resultPath) { Remove-Item -LiteralPath $resultPath -Force }
	$adl = Join-Path $sdk "bin\adl.exe"
	& $adl -nodebug (Join-Path $here "PaletteDeepFixture-app.xml") $here
	$result = ""
	if (Test-Path -LiteralPath $resultPath) { $result = (Get-Content -LiteralPath $resultPath -Raw).Trim() }
	Write-Output "fixture $result"
	if ($result -eq "OK") { exit 0 }
	exit 1
}
finally {
	Pop-Location
}
