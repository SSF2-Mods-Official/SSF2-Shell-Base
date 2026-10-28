param(
	[string]$Manager = (Join-Path $PSScriptRoot "..\..\..\..\..\SSF2ModManager")
)
$ErrorActionPreference = "Stop"
. (Join-Path $Manager "SSF2 Mod Manager Release\runtime\shell-dev\tools\_toolchain.ps1")
$sdk = Require-Ssf2AirSdk
$here = $PSScriptRoot
$mxmlc = Join-Path $sdk "bin\mxmlc.bat"
$adl = Join-Path $sdk "bin\adl.exe"
$air = Join-Path $sdk "frameworks\air-config.xml"
$src = Join-Path $PSScriptRoot "..\..\..\..\work\build\engine2\src"
if (-not (Test-Path -LiteralPath $src)) {
	throw "Patched engine source is missing at work/build/engine2/src. Run tools/shellbase.py build. Engine edits are patches/engine2."
}
Push-Location $here
try {
	& $mxmlc -load-config+="$air" -source-path+="$src" -output FrameGateFixture.swf -warnings=false FrameGateFixture.as
	if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
	& $adl -nodebug (Join-Path $here "run-app.xml") $here
	$resultPath = Join-Path $env:APPDATA "FrameGateFixture\Local Store\frame-gate-fixture.txt"
	$result = ""
	if (Test-Path -LiteralPath $resultPath) { $result = (Get-Content -LiteralPath $resultPath -Raw).Trim() }
	Write-Output "fixture $result"
	if ($result -eq "OK") { exit 0 }
	exit 1
}
finally {
	Pop-Location
}
