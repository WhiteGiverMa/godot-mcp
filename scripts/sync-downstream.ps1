param(
	[string[]]$ProjectPaths = @(
		"G:\dev\DreamerHeroines",
		"G:\dev\operation-taklamakan",
		"G:\dev\odyssey-cards"
	),
	[switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$buildScripts = Join-Path $repoRoot 'build\scripts'
$sourceFiles = @('godot_operations.gd', 'mcp_interaction_server.gd')

if (-not $SkipBuild) {
	Write-Host '==> Building fork artifacts' -ForegroundColor Cyan
	Push-Location $repoRoot
	try {
		npm run build
	}
	finally {
		Pop-Location
	}
}

foreach ($sourceFile in $sourceFiles) {
	$sourcePath = Join-Path $buildScripts $sourceFile
	if (-not (Test-Path $sourcePath)) {
		throw "Missing built script: $sourcePath"
	}
}

foreach ($projectPath in $ProjectPaths) {
	$addonPath = Join-Path $projectPath 'addons\godot_mcp'
	if (-not (Test-Path $addonPath)) {
		Write-Host "  skip $projectPath (addons\godot_mcp not found)" -ForegroundColor Yellow
		continue
	}

	Write-Host "==> Syncing $projectPath" -ForegroundColor Cyan

	foreach ($sourceFile in $sourceFiles) {
		$sourcePath = Join-Path $buildScripts $sourceFile
		$targetPath = Join-Path $addonPath $sourceFile
		Copy-Item $sourcePath $targetPath -Force

		$sourceHash = (Get-FileHash $sourcePath -Algorithm SHA256).Hash
		$targetHash = (Get-FileHash $targetPath -Algorithm SHA256).Hash

		if ($sourceHash -ne $targetHash) {
			throw "Hash mismatch after sync: $targetPath"
		}

		Write-Host "  synced $sourceFile [$sourceHash]" -ForegroundColor Green
	}
}

Write-Host '==> Downstream sync complete' -ForegroundColor Cyan
