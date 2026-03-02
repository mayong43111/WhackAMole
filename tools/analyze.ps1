param(
    [string]$LogPath,
    [string]$PlayerName,
    [int]$LastLines = 3000
)

if ([string]::IsNullOrEmpty($LogPath)) {
    $logFiles = Get-ChildItem "C:\Program Files (x86)\World of Warcraft\_classic_titan_\Logs\WoWCombatLog-*.txt" -ErrorAction SilentlyContinue
    if ($logFiles) {
        $LogPath = ($logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
        Write-Host "Found log: $(Split-Path $LogPath -Leaf)" -ForegroundColor Green
    } else {
        Write-Host "No combat log found!" -ForegroundColor Red
        exit
    }
}

if ([string]::IsNullOrEmpty($PlayerName)) {
    $PlayerName = Read-Host "Character name"
}

$spellCasts = @{}
$totalCasts = 0

Write-Host "Reading $LastLines lines..." -ForegroundColor Yellow
$lines = Get-Content $LogPath -Tail $LastLines -Encoding UTF8

foreach ($line in $lines) {
    if ($line -match "SPELL_CAST_SUCCESS") {
        if ($line -match "Player-[^,]+,`"([^`"]+)`"") {
            $sourceName = $matches[1]
            $nameOnly = $sourceName -split "-" | Select-Object -First 1
            
            if ($nameOnly -eq $PlayerName) {
                if ($line -match ",\d+,`"([^`"]+)`"") {
                    $spellName = $matches[1]
                    if ($spellCasts.ContainsKey($spellName)) {
                        $spellCasts[$spellName]++
                    } else {
                        $spellCasts[$spellName] = 1
                    }
                    $totalCasts++
                }
            }
        }
    }
}

if ($totalCasts -eq 0) {
    Write-Host "No casts found for: $PlayerName" -ForegroundColor Red
    exit
}

Write-Host "`nTotal casts: $totalCasts" -ForegroundColor Green
Write-Host "`nSpell frequencies:" -ForegroundColor Cyan

$spellCasts.GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object {
    Write-Host "$($_.Name): $($_.Value)"
}
