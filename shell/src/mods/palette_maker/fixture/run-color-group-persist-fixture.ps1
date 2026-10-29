# ColorGroupPersist fixture. Exit 0 when the result file is OK.
# adl often exits 9 with "error while loading initial content"; the result file is what counts.
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
if (-not (Test-Path -LiteralPath $java)) { throw "java missing under Next2Flash toolchain" }
if (-not (Test-Path -LiteralPath $jar)) { throw "asconfigc.jar missing" }
$airXml = Join-Path $sdk "templates\air\descriptor-template.xml"
if (-not (Test-Path -LiteralPath $airXml)) {
	$airDir = Split-Path -Parent $airXml
	New-Item -ItemType Directory -Force -Path $airDir | Out-Null
	@('<?xml version="1.0" encoding="utf-8"?>','<application xmlns="http://ns.adobe.com/air/application/32.0">','  <id>APPLICATIONNAMESPACE.id</id>','  <versionNumber>APPLICATIONVERSION</versionNumber>','  <filename>APPLICATIONFILENAME</filename>','  <name>APPLICATIONTITLE</name>','  <initialWindow>','    <content>APPLICATIONCONTENT</content>','    <visible>true</visible>','  </initialWindow>','</application>') | Set-Content -Encoding UTF8 -LiteralPath $airXml
}

$adl = Join-Path $sdk "bin\adl.exe"
$animateAdl = "C:\Program Files\Adobe\Adobe Animate CC 2019\AIR30.0\bin\adl.exe"
$useAir30 = $false
if (Test-Path -LiteralPath $animateAdl) {
	$adl = $animateAdl
	$useAir30 = $true
}

$resultPath = Join-Path $env:APPDATA "ColorGroupPersistFixture\Local Store\color-group-persist-fixture.txt"
Push-Location $here
try {
	if (Test-Path -LiteralPath $resultPath) { Remove-Item -LiteralPath $resultPath -Force }
	& $java -jar $jar --sdk $sdk --project (Join-Path $here "ColorGroupPersistFixture-asconfig.json")
	if ($LASTEXITCODE -ne 0) { throw "compile failed exit $LASTEXITCODE" }
	$desc = "ColorGroupPersistFixture-app.xml"
	if ($useAir30) {
		$desc = "ColorGroupPersistFixture-app-air30.xml"
		$text = @"
<?xml version="1.0" encoding="utf-8" ?>
<application xmlns="http://ns.adobe.com/air/application/30.0">
  <id>ColorGroupPersistFixture</id>
  <filename>ColorGroupPersistFixture</filename>
  <versionNumber>1.0.0</versionNumber>
  <initialWindow>
    <content>ColorGroupPersistFixture.swf</content>
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
