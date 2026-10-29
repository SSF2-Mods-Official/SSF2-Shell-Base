# Compile built-in mods from shell/src/mods. Engine edits are patches/engine2, then shellbase.py build.
# A mod's asconfig.json writes shell/data/ssf2mm/<id>/mod.swf. This also copies that swf into Build.
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Only = @())
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$mods = Join-Path $root "shell\src\mods"
$n2f = Join-Path $root "..\Next2Flash\app\n2f.py"
if (-not (Test-Path -LiteralPath $n2f)) {
	$n2f = Join-Path $env:USERPROFILE "Documents\GitHub\Next2Flash\app\n2f.py"
}
if (-not (Test-Path -LiteralPath $n2f)) { throw "Next2Flash app/n2f.py not found" }
$python = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $python) { throw "python not found" }

# asconfigc needs this AIR template; some aflex_lite checkouts omit templates/.
$n2fRoot = Split-Path -Parent (Split-Path -Parent $n2f)
$airXml = Join-Path $n2fRoot "toolchain\aflex_lite\templates\air\descriptor-template.xml"
if (-not (Test-Path -LiteralPath $airXml)) {
	$airDir = Split-Path -Parent $airXml
	New-Item -ItemType Directory -Force -Path $airDir | Out-Null
	@(
		'<?xml version="1.0" encoding="utf-8" standalone="no" ?>',
		'<!-- Minimal AIR descriptor so asconfigc can compile. -->',
		'<application xmlns="http://ns.adobe.com/air/application/32.0">',
		'  <id>APPLICATIONNAMESPACE.id</id>',
		'  <versionNumber>APPLICATIONVERSION</versionNumber>',
		'  <filename>APPLICATIONFILENAME</filename>',
		'  <description/>',
		'  <name>APPLICATIONTITLE</name>',
		'  <copyright/>',
		'  <initialWindow>',
		'    <title>APPLICATIONTITLE</title>',
		'    <content>APPLICATIONCONTENT</content>',
		'    <systemChrome>standard</systemChrome>',
		'    <transparent>false</transparent>',
		'    <visible>true</visible>',
		'  </initialWindow>',
		'</application>'
	) | Set-Content -Encoding UTF8 -LiteralPath $airXml
	Write-Host "[build-mod] wrote missing AIR descriptor $airXml"
}

$dirs = @(Get-ChildItem -LiteralPath $mods -Directory | Where-Object {
	$_.Name -notlike "_*" -and (Test-Path -LiteralPath (Join-Path $_.FullName "asconfig.json"))
})
if ($Only.Count -gt 0) {
	$dirs = @($dirs | Where-Object { $Only -contains $_.Name })
}
if ($dirs.Count -eq 0) { throw "no mods to build under shell/src/mods" }

foreach ($dir in $dirs) {
	Write-Host "[build-mod] $($dir.Name)"
	Push-Location $dir.FullName
	try {
		& $python $n2f asconfig --project asconfig.json
		if ($LASTEXITCODE -ne 0) { throw "compile failed $($dir.Name) (exit $LASTEXITCODE)" }
	}
	finally {
		Pop-Location
	}
	$text = [System.IO.File]::ReadAllText((Join-Path $dir.FullName "asconfig.json"))
	$match = [regex]::Match($text, '"output"\s*:\s*"([^"]*)"')
	$rel = if ($match.Success) { $match.Groups[1].Value } else { "mod.swf" }
	$swf = if ([System.IO.Path]::IsPathRooted($rel)) { $rel } else { Join-Path $dir.FullName $rel }
	$swf = [System.IO.Path]::GetFullPath($swf)
	if (-not (Test-Path -LiteralPath $swf)) { throw "missing $swf" }
	$destDir = Join-Path $root "Build\data\ssf2mm\$($dir.Name)"
	if (Test-Path -LiteralPath $destDir) {
		Copy-Item -LiteralPath $swf -Destination (Join-Path $destDir "mod.swf") -Force
	}
	Write-Host "[build-mod] OK $($dir.Name) -> $swf"
}
