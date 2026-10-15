param(
	[string]$Vanilla = "C:\Program Files (x86)\Super Smash Flash 2 Beta",
	[string]$Next2Flash = (Join-Path (Split-Path -Parent $PSScriptRoot) "Next2Flash"),
	[string]$Out = ""
)
$ErrorActionPreference = "Stop"
$pyArgs = @("$PSScriptRoot\tools\shellbase.py", "build", "--vanilla", $Vanilla, "--n2f", $Next2Flash)
if ($Out) { $pyArgs += @("--out", $Out) }
python @pyArgs
exit $LASTEXITCODE
