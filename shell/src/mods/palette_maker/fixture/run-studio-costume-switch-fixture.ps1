# StudioCostumeSwitch fixture. Exit 0 when the result file is OK.
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$n2f = Join-Path $here "..\..\..\..\..\Next2Flash\app\n2f.py"
if (-not (Test-Path -LiteralPath $n2f)) {
	$n2f = Join-Path $env:USERPROFILE "Documents\GitHub\Next2Flash\app\n2f.py"
}
if (-not (Test-Path -LiteralPath $n2f)) { throw "Next2Flash app/n2f.py not found" }
$n2fRoot = Split-Path -Parent (Split-Path -Parent $n2f)
$java = Join-Path $n2fRoot "toolchain\jre\bin\java.exe"
$sdk = Join-Path $n2fRoot "toolchain\aflex_lite"
$jar = Join-Path $n2fRoot "toolchain\asconfigc\asconfigc.jar"
$adl = Join-Path $sdk "bin\adl.exe"
$animateAdl = "C:\Program Files\Adobe\Adobe Animate CC 2019\AIR30.0\bin\adl.exe"
$useAir30 = $false
if (Test-Path -LiteralPath $animateAdl) {
	$adl = $animateAdl
	$useAir30 = $true
}
$resultPath = Join-Path $env:APPDATA "StudioCostumeSwitchFixture\Local Store\studio-costume-switch-fixture.txt"
Push-Location $here
try {
	if (Test-Path -LiteralPath $resultPath) { Remove-Item -LiteralPath $resultPath -Force }
	& $java -jar $jar --sdk $sdk --project (Join-Path $here "StudioCostumeSwitchFixture-asconfig.json")
	if ($LASTEXITCODE -ne 0) { throw "compile failed exit $LASTEXITCODE" }
	$desc = "StudioCostumeSwitchFixture-app.xml"
	if ($useAir30) {
		$desc = "StudioCostumeSwitchFixture-app-air30.xml"
		$text = @"
<?xml version="1.0" encoding="utf-8" ?>
<application xmlns="http://ns.adobe.com/air/application/30.0">
  <id>StudioCostumeSwitchFixture</id>
  <filename>StudioCostumeSwitchFixture</filename>
  <versionNumber>1.0.0</versionNumber>
  <initialWindow>
    <content>StudioCostumeSwitchFixture.swf</content>
    <visible>true</visible>
  </initialWindow>
</application>
"@
		[System.IO.File]::WriteAllText((Join-Path $here $desc), $text)
	} else {
		$text = @"
<?xml version="1.0" encoding="utf-8" ?>
<application xmlns="http://ns.adobe.com/air/application/32.0">
  <id>StudioCostumeSwitchFixture</id>
  <filename>StudioCostumeSwitchFixture</filename>
  <versionNumber>1.0.0</versionNumber>
  <initialWindow>
    <content>StudioCostumeSwitchFixture.swf</content>
    <visible>true</visible>
  </initialWindow>
</application>
"@
		[System.IO.File]::WriteAllText((Join-Path $here $desc), $text)
	}
	& $adl -nodebug $desc "."
	$result = ""
	if (Test-Path -LiteralPath $resultPath) { $result = (Get-Content -LiteralPath $resultPath -Raw).Trim() }
	Write-Output "fixture $result"
	if ($result -eq "OK") { exit 0 }
	exit 1
}
finally {
	Pop-Location
}
