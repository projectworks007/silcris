# SILCRIS - feltoltes a silcris.hu tarhelyre (Rackhost, FTP)
# Inditas: jobb klikk -> "Futtatas PowerShell-lel", vagy a terminalban: .\feltoltes.ps1
# Csak azokat a fajlokat tolti fel, amik a legutobbi feltoltes ota megvaltoztak.
# A jelszot a curl kerdezi be, a script SEHOL nem tarolja el.

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$Felhasznalo = 'c112864jani.prog001@gmail.com'
$Kiszolgalo  = 'wh27.rackhost.hu'
$AllapotFajl = Join-Path $PSScriptRoot '.feltoltes-allapot.json'

# --- 1. Melyik fajlok tartoznak az oldalhoz? ---
$fajlok = @('index.html', '.nojekyll')
$fajlok += Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'images') -File |
           Sort-Object Name | ForEach-Object { 'images/' + $_.Name }

# --- 2. Mostani allapot (fajlnev -> SHA256) ---
$most = @{}
foreach ($f in $fajlok) {
    $teljes = Join-Path $PSScriptRoot ($f -replace '/', '\')
    if (Test-Path -LiteralPath $teljes) {
        $most[$f] = (Get-FileHash -LiteralPath $teljes -Algorithm SHA256).Hash
    }
}

# --- 3. Legutobbi feltoltes allapota ---
$elozo = @{}
if (Test-Path -LiteralPath $AllapotFajl) {
    $betoltve = Get-Content -LiteralPath $AllapotFajl -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $betoltve.PSObject.Properties) { $elozo[$p.Name] = $p.Value }
}

# --- 4. Mi valtozott? ---
$feltoltendo = @($most.Keys | Where-Object { $elozo[$_] -ne $most[$_] } | Sort-Object)
$torlendo    = @($elozo.Keys | Where-Object { -not $most.ContainsKey($_) } | Sort-Object)

if ($feltoltendo.Count -eq 0 -and $torlendo.Count -eq 0) {
    Write-Host "Nincs valtozas, nincs mit feltolteni." -ForegroundColor Green
    exit 0
}

Write-Host ""
if ($feltoltendo.Count -gt 0) {
    Write-Host "Feltoltendo ($($feltoltendo.Count) db):" -ForegroundColor Cyan
    $feltoltendo | ForEach-Object { Write-Host "   $_" }
}
if ($torlendo.Count -gt 0) {
    Write-Host "Torlendo a szerverrol ($($torlendo.Count) db):" -ForegroundColor Yellow
    $torlendo | ForEach-Object { Write-Host "   $_" }
}
Write-Host ""
$valasz = Read-Host "Mehet? (i/n)"
if ($valasz -notmatch '^(i|I|y|Y)$') { Write-Host "Megszakitva."; exit 0 }

# --- 5. Egyetlen curl-hivas: igy a jelszot csak EGYSZER kell begepelni ---
$argumentumok = @('-u', $Felhasznalo, '--ftp-create-dirs')
foreach ($f in $feltoltendo) {
    $konyvtar = if ($f -like 'images/*') { "ftp://$Kiszolgalo/images/" } else { "ftp://$Kiszolgalo/" }
    $argumentumok += @('-T', $f, $konyvtar)
}
foreach ($f in $torlendo) {
    $argumentumok += @('-Q', "DELE $f")
}
if ($feltoltendo.Count -eq 0) { $argumentumok += "ftp://$Kiszolgalo/" }

Write-Host "A jelszot a curl fogja bekerni (gepeles kozben nem latszik)." -ForegroundColor Cyan
& curl.exe @argumentumok
if ($LASTEXITCODE -ne 0) {
    Write-Host "HIBA: a feltoltes nem sikerult (curl hibakod: $LASTEXITCODE). Az allapotot nem irtam felul." -ForegroundColor Red
    exit $LASTEXITCODE
}

# --- 6. Sikeres feltoltes: allapot mentese ---
$most | ConvertTo-Json | Set-Content -LiteralPath $AllapotFajl -Encoding UTF8
Write-Host ""
Write-Host "Kesz. Ellenorzes: https://silcris.hu/" -ForegroundColor Green
