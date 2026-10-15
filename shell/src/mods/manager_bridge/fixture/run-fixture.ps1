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
	$adl = Join-Path $sdk "bin\adl.exe"
	& $adl -nodebug (Join-Path $here "LaunchScreenFixture-app.xml") $here
	$resultPath = Join-Path $env:APPDATA "LaunchScreenFixture\Local Store\launch-screen-fixture.txt"
	$result = ""
	if (Test-Path -LiteralPath $resultPath) { $result = (Get-Content -LiteralPath $resultPath -Raw).Trim() }
	Write-Output "fixture $result"
	if ($result -eq "OK") { exit 0 }
	exit 1
}
finally {
	Pop-Location
}
