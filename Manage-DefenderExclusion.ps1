
[CmdletBinding()]
param(
    [ValidateSet('Folder', 'File', 'Process', 'Remove', 'RemoveProcess', 'List', 'Menu')]
    [string]$Mode = 'Menu',

    [string]$Path
)

$ErrorActionPreference = "Stop"

# ============================================================
# 1. ADMINISTRATOR CHECK
# ============================================================

function Test-Administrator {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

if (-not (Test-Administrator)) {
    Write-Host ""
    Write-Host "ERROR: Uruchom PowerShell jako administrator." `
        -ForegroundColor Red
    exit 1
}

# ============================================================
# 2. DEFENDER AVAILABILITY
# ============================================================

try {
    Import-Module Defender -ErrorAction Stop

    $null = Get-MpPreference -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "ERROR: Nie mozna odczytac konfiguracji Defendera." `
        -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

# ============================================================
# 3. HELPER FUNCTIONS
# ============================================================

function Read-TargetPath {
    param(
        [string]$Prompt,
        [string]$InitialPath
    )

    if (-not [string]::IsNullOrWhiteSpace($InitialPath)) {
        $Value = $InitialPath.Trim().Trim('"')
    }
    else {
        $Value = (Read-Host $Prompt).Trim().Trim('"')
    }

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Nie podano sciezki."
    }

    return $Value
}

function Test-PathInList {
    param(
        [string[]]$Items,
        [string]$Target
    )

    foreach ($Item in $Items) {
        if ($Item -ieq $Target) {
            return $true
        }
    }

    return $false
}

function Confirm-Operation {
    param(
        [string]$Message
    )

    Write-Host ""
    Write-Warning $Message

    $Answer = Read-Host "Kontynuowac? (T/N)"

    return ($Answer -match '^(T|TAK|Y|YES)$')
}

function Get-DefenderPreferences {
    return Get-MpPreference -ErrorAction Stop
}

# ============================================================
# 4. LIST EXCLUSIONS
# ============================================================

function Show-Exclusions {
    $Preferences = Get-DefenderPreferences

    Write-Host ""
    Write-Host "========== DEFENDER EXCLUSIONS ==========" `
        -ForegroundColor Cyan

    Write-Host ""
    Write-Host "[PATH EXCLUSIONS]" -ForegroundColor Yellow

    if ($Preferences.ExclusionPath) {
        $Preferences.ExclusionPath | ForEach-Object {
            Write-Host "  $_"
        }
    }
    else {
        Write-Host "  Brak wpisow."
    }

    Write-Host ""
    Write-Host "[PROCESS EXCLUSIONS]" -ForegroundColor Yellow

    if ($Preferences.ExclusionProcess) {
        $Preferences.ExclusionProcess | ForEach-Object {
            Write-Host "  $_"
        }
    }
    else {
        Write-Host "  Brak wpisow."
    }

    Write-Host ""
    Write-Host "[EXTENSION EXCLUSIONS]" -ForegroundColor Yellow

    if ($Preferences.ExclusionExtension) {
        $Preferences.ExclusionExtension | ForEach-Object {
            Write-Host "  $_"
        }
    }
    else {
        Write-Host "  Brak wpisow."
    }

    Write-Host ""
}

# ============================================================
# 5. ADD PATH EXCLUSION
# ============================================================

function Add-PathExclusion {
    param(
        [ValidateSet("Folder", "File")]
        [string]$Type,

        [string]$InitialPath
    )

    if ($Type -eq "Folder") {
        $TargetPath = Read-TargetPath `
            -Prompt "Podaj pelna sciezke do folderu" `
            -InitialPath $InitialPath

        if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
            throw "Podana sciezka nie wskazuje istniejacego folderu."
        }
    }
    else {
        $TargetPath = Read-TargetPath `
            -Prompt "Podaj pelna sciezke do pliku" `
            -InitialPath $InitialPath

        if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
            throw "Podana sciezka nie wskazuje istniejacego pliku."
        }
    }

    $TargetPath = (Get-Item -LiteralPath $TargetPath).FullName

    $Preferences = Get-DefenderPreferences
    $Existing = @($Preferences.ExclusionPath)

    if (Test-PathInList -Items $Existing -Target $TargetPath) {
        Write-Host "Wyjatek juz istnieje: $TargetPath" `
            -ForegroundColor Yellow
        return
    }

    if (-not (Confirm-Operation `
        -Message "Dodanie wyjatku ograniczy skanowanie wskazanej sciezki.")) {
        Write-Host "Operacja anulowana."
        return
    }

    Add-MpPreference -ExclusionPath $TargetPath -ErrorAction Stop

    $Updated = Get-DefenderPreferences

    if (Test-PathInList `
        -Items @($Updated.ExclusionPath) `
        -Target $TargetPath) {

        Write-Host "Wyjatek dodany i zweryfikowany." `
            -ForegroundColor Green
        Write-Host $TargetPath
    }
    else {
        throw "Nie potwierdzono dodania wyjatku."
    }
}

# ============================================================
# 6. ADD PROCESS EXCLUSION
# ============================================================

function Add-ProcessExclusion {
    param(
        [string]$InitialPath
    )

    $TargetPath = Read-TargetPath `
        -Prompt "Podaj pelna sciezke do pliku wykonywalnego procesu" `
        -InitialPath $InitialPath

    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
        throw "Podana sciezka nie wskazuje istniejacego pliku."
    }

    $TargetPath = (Get-Item -LiteralPath $TargetPath).FullName

    if ([IO.Path]::GetExtension($TargetPath) -ine ".exe") {
        throw "W trybie Process wskaz plik wykonywalny EXE."
    }

    $Preferences = Get-DefenderPreferences
    $Existing = @($Preferences.ExclusionProcess)

    if (Test-PathInList -Items $Existing -Target $TargetPath) {
        Write-Host "Wyjatek procesu juz istnieje: $TargetPath" `
            -ForegroundColor Yellow
        return
    }

    if (-not (Confirm-Operation `
        -Message "Wykluczenie procesu ograniczy skanowanie plikow otwieranych przez ten proces.")) {
        Write-Host "Operacja anulowana."
        return
    }

    Add-MpPreference -ExclusionProcess $TargetPath -ErrorAction Stop

    $Updated = Get-DefenderPreferences

    if (Test-PathInList `
        -Items @($Updated.ExclusionProcess) `
        -Target $TargetPath) {

        Write-Host "Wyjatek procesu dodany i zweryfikowany." `
            -ForegroundColor Green
        Write-Host $TargetPath
    }
    else {
        throw "Nie potwierdzono dodania wyjatku procesu."
    }
}

# ============================================================
# 7. REMOVE PATH EXCLUSION
# ============================================================

function Remove-PathExclusion {
    param(
        [string]$InitialPath
    )

    $TargetPath = Read-TargetPath `
        -Prompt "Podaj pelna sciezke wyjatku pliku lub folderu" `
        -InitialPath $InitialPath

    $Preferences = Get-DefenderPreferences
    $Existing = @($Preferences.ExclusionPath)

    $Match = $Existing |
        Where-Object { $_ -ieq $TargetPath } |
        Select-Object -First 1

    if (-not $Match) {
        Write-Host "Nie znaleziono takiego wyjatku." `
            -ForegroundColor Yellow
        return
    }

    if (-not (Confirm-Operation `
        -Message "Usuniecie wyjatku przywraca standardowe skanowanie w zakresie tej reguly.")) {
        Write-Host "Operacja anulowana."
        return
    }

    Remove-MpPreference -ExclusionPath $Match -ErrorAction Stop

    $Updated = Get-DefenderPreferences

    if (-not (Test-PathInList `
        -Items @($Updated.ExclusionPath) `
        -Target $Match)) {

        Write-Host "Wyjatek sciezki usuniety." `
            -ForegroundColor Green
        Write-Host $Match
    }
    else {
        throw "Wyjatek nadal znajduje sie na liscie."
    }
}

# ============================================================
# 8. REMOVE PROCESS EXCLUSION
# ============================================================

function Remove-ProcessExclusion {
    param(
        [string]$InitialPath
    )

    $TargetPath = Read-TargetPath `
        -Prompt "Podaj pelna sciezke wyjatku procesu" `
        -InitialPath $InitialPath

    $Preferences = Get-DefenderPreferences
    $Existing = @($Preferences.ExclusionProcess)

    $Match = $Existing |
        Where-Object { $_ -ieq $TargetPath } |
        Select-Object -First 1

    if (-not $Match) {
        Write-Host "Nie znaleziono wyjatku procesu." `
            -ForegroundColor Yellow
        return
    }

    if (-not (Confirm-Operation `
        -Message "Usunac wyjatek procesu i przywrocic standardowe skanowanie w zakresie tej reguly?")) {
        Write-Host "Operacja anulowana."
        return
    }

    Remove-MpPreference -ExclusionProcess $Match -ErrorAction Stop

    $Updated = Get-DefenderPreferences

    if (-not (Test-PathInList `
        -Items @($Updated.ExclusionProcess) `
        -Target $Match)) {

        Write-Host "Wyjatek procesu usuniety." `
            -ForegroundColor Green
        Write-Host $Match
    }
    else {
        throw "Wyjatek procesu nadal znajduje sie na liscie."
    }
}

# ============================================================
# 9. INTERACTIVE MENU
# ============================================================

function Start-Menu {
    while ($true) {
        Write-Host ""
        Write-Host "========================================"
        Write-Host " MICROSOFT DEFENDER - EXCLUSION MANAGER"
        Write-Host "========================================"
        Write-Host "1. Dodaj wyjatek folderu"
        Write-Host "2. Dodaj wyjatek pliku"
        Write-Host "3. Dodaj wyjatek procesu"
        Write-Host "4. Usun wyjatek pliku/folderu"
        Write-Host "5. Usun wyjatek procesu"
        Write-Host "6. Wyswietl wyjatki"
        Write-Host "0. Zakoncz"
        Write-Host ""

        $Choice = Read-Host "Wybierz opcje"

        try {
            switch ($Choice) {
                "1" { Add-PathExclusion -Type Folder }
                "2" { Add-PathExclusion -Type File }
                "3" { Add-ProcessExclusion }
                "4" { Remove-PathExclusion }
                "5" { Remove-ProcessExclusion }
                "6" { Show-Exclusions }
                "0" { return }
                default {
                    Write-Host "Nieprawidlowy wybor." `
                        -ForegroundColor Yellow
                }
            }
        }
        catch {
            Write-Host "BLAD: $($_.Exception.Message)" `
                -ForegroundColor Red
        }

        Read-Host "Nacisnij Enter, aby kontynuowac" | Out-Null
    }
}

# ============================================================
# 10. MAIN
# ============================================================

try {
    switch ($Mode) {
        "Folder" {
            Add-PathExclusion -Type Folder -InitialPath $Path
        }
        "File" {
            Add-PathExclusion -Type File -InitialPath $Path
        }
        "Process" {
            Add-ProcessExclusion -InitialPath $Path
        }
        "Remove" {
            Remove-PathExclusion -InitialPath $Path
        }
        "RemoveProcess" {
            Remove-ProcessExclusion -InitialPath $Path
        }
        "List" {
            Show-Exclusions
        }
        "Menu" {
            Start-Menu
        }
    }
}
catch {
    Write-Host ""
    Write-Host "BLAD: $($_.Exception.Message)" `
        -ForegroundColor Red
    exit 1
}
```
