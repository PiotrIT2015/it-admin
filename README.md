Przygotujmy kompletny skrypt PowerShell do zarządzania wyjątkami Microsoft Defender w Windows 11. Będzie obsługiwał foldery, pliki i procesy, umożliwiał usuwanie wyjątków oraz sprawdzał wynik każdej operacji.

Zaprojektuję go tak, aby można było korzystać z niego zarówno przez argumenty w CMD lub PowerShell, jak i w trybie interaktywnym.

**Ważne:** wyjątek procesu może ograniczyć skanowanie plików otwieranych przez wskazany program. Nie wyłącza jednak wszystkich zabezpieczeń tego programu ani nie oznacza automatycznego wykluczenia jego pliku `.exe`. Dlatego skrypt nie będzie miał opcji wyłączającej skanowanie wszystkich procesów naraz.

# 1. Architektura skryptu

Skrypt `Manage-DefenderExclusions.ps1` będzie obsługiwał następujące operacje:

| Argument `-Mode` | Działanie                           | Polecenie Defendera                     |
| ---------------- | ----------------------------------- | --------------------------------------- |
| `Folder`         | Dodanie wyjątku folderu             | `Add-MpPreference -ExclusionPath`       |
| `File`           | Dodanie wyjątku pliku               | `Add-MpPreference -ExclusionPath`       |
| `Process`        | Dodanie wyjątku procesu             | `Add-MpPreference -ExclusionProcess`    |
| `Remove`         | Usunięcie wyjątku pliku lub folderu | `Remove-MpPreference -ExclusionPath`    |
| `RemoveProcess`  | Usunięcie wyjątku procesu           | `Remove-MpPreference -ExclusionProcess` |
| `List`           | Wyświetlenie wyjątków               | `Get-MpPreference`                      |
| `Menu`           | Uruchomienie menu interaktywnego    | Zależnie od wyboru                      |

Skrypt będzie również:

* sprawdzał uprawnienia administratora;
* weryfikował ścieżki i rodzaj obiektu;
* wymagał potwierdzenia przed zmianą konfiguracji;
* sprawdzał, czy wyjątek istnieje przed jego dodaniem lub usunięciem;
* weryfikował wynik operacji;
* obsługiwał błędy bez niepotrzebnego przerywania działania.

---

# 2. Kompletny skrypt `Manage-DefenderExclusions.ps1`

Zapisz poniższy kod jako `Manage-DefenderExclusions.ps1`.

```powershell
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet(
        "Folder",
        "File",
        "Process",
        "Remove",
        "RemoveProcess",
        "List",
        "Menu"
    )]
    [string]$Mode = "Menu",

    [Parameter(Position = 1)]
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

---

# 3. Plik uruchamiający `Run-DefenderExclusions.cmd`

Przygotuj drugi plik w tym samym folderze. Pozwoli Ci uruchamiać skrypt bez ręcznego wpisywania długiego polecenia PowerShell.

Zapisz go jako `Run-DefenderExclusions.cmd`.

```bat
@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manage-DefenderExclusions.ps1" %*

echo.
pause
```

Ten plik:

* uruchamia skrypt PowerShell;
* przekazuje wszystkie argumenty;
* stosuje `ExecutionPolicy Bypass` wyłącznie do uruchomionego procesu PowerShell;
* pozwala przeczytać wynik po zakończeniu działania.

**Uwaga:** uruchom CMD jako administrator. Skrypt nie będzie automatycznie omijał kontroli uprawnień UAC.

---

# 4. Jak uruchamiać poszczególne tryby?

Załóżmy, że oba pliki znajdują się w:

```text
D:\Scripts\
```

## A. Menu interaktywne

W PowerShell uruchomionym jako administrator:

```powershell
& "D:\Scripts\Manage-DefenderExclusions.ps1" -Mode Menu
```

Możesz również uruchomić `Run-DefenderExclusions.cmd` bez argumentów.

Pojawi się menu z opcjami dodawania, usuwania i wyświetlania wyjątków.

## B. Wykluczenie folderu

```powershell
& "D:\Scripts\Manage-DefenderExclusions.ps1" -Mode Folder -Path "D:\Projects\myapp"
```

## C. Wykluczenie pojedynczego pliku

```powershell
& "D:\Scripts\Manage-DefenderExclusions.ps1" -Mode File -Path "D:\Projects\myapp\test.py"
```

## D. Wykluczenie procesu

```powershell
& "D:\Scripts\Manage-DefenderExclusions.ps1" -Mode Process -Path "C:\Tools\myapp.exe"
```

Ta opcja wyklucza pliki otwierane przez wskazany proces w zakresie reguły Defendera. Nie oznacza wyłączenia wszystkich zabezpieczeń procesu.

## E. Przywrócenie skanowania folderu lub pliku

```powershell
& "D:\Scripts\Manage-DefenderExclusions.ps1" -Mode Remove -Path "D:\Projects\myapp"
```

Aby usunąć wyjątek pliku:

```powershell
& "D:\Scripts\Manage-DefenderExclusions.ps1" -Mode Remove -Path "D:\Projects\myapp\test.py"
```

## F. Przywrócenie standardowego skanowania dla procesu

```powershell
& "D:\Scripts\Manage-DefenderExclusions.ps1" -Mode RemoveProcess -Path "C:\Tools\myapp.exe"
```

## G. Wyświetlenie wszystkich wyjątków

```powershell
& "D:\Scripts\Manage-DefenderExclusions.ps1" -Mode List
```

---

# 5. Uruchamianie z CMD

Możesz korzystać z tych samych opcji przez plik `.cmd`.

**Przykład — dodanie wyjątku folderu:**

```cmd
D:\Scripts\Run-DefenderExclusions.cmd Folder "D:\Projects\myapp"
```

**Przykład — dodanie wyjątku procesu:**

```cmd
D:\Scripts\Run-DefenderExclusions.cmd Process "C:\Tools\myapp.exe"
```

**Przykład — usunięcie wyjątku:**

```cmd
D:\Scripts\Run-DefenderExclusions.cmd Remove "D:\Projects\myapp"
```

**Przykład — wyświetlenie wyjątków:**

```cmd
D:\Scripts\Run-DefenderExclusions.cmd List
```

---

# 6. Co warto wiedzieć przed użyciem?

### Różnica między wyjątkami

* **Folder:** obejmuje wskazany katalog i znajdujące się w nim pliki w zakresie działania wyjątku.
* **Plik:** obejmuje konkretną ścieżkę do pliku.
* **Proces:** ogranicza skanowanie plików otwieranych przez wskazany proces; nie jest równoznaczny z wykluczeniem jego pliku wykonywalnego.

### Ograniczenia

1. Wyjątki mogą być ograniczane przez Tamper Protection lub zasady organizacji.
2. Usunięcie wyjątku nie wymusza natychmiastowego pełnego skanowania.
3. Skrypt nie usuwa wyjątków z innych kategorii, takich jak wykluczenia rozszerzeń.
4. Nie należy wykluczać całych dysków, katalogów systemowych ani wszystkich procesów.

Dokumentacja Microsoft: [Microsoft Learn — Add-MpPreference](https://learn.microsoft.com/en-us/powershell/module/defender/add-mppreference?utm_source=chatgpt.com) oraz [Microsoft Learn — konfiguracja wyjątków Defendera](https://learn.microsoft.com/en-us/defender-endpoint/microsoft-defender-antivirus-exclusions-configure?utm_source=chatgpt.com).

**Moja rekomendacja:** zacznij od opcji `List`, żeby zobaczyć istniejące wyjątki, a następnie przetestuj dodawanie i usuwanie wyjątku na niewielkim folderze testowym. Dzięki temu sprawdzisz działanie skryptu bez zmieniania ochrony całego środowiska.

Aby uruchomić `Manage-DefenderExclusion.cmd` w Windows 11, wykonaj poniższe kroki.

### 1. Sprawdź, czy plik znajduje się w folderze

Twój katalog roboczy to:

```text
D:\PTT-91-50\piotr-personal-files\objective-vocation\ngo\wtz\IT\skills-presentation-2\powershell
```

W PowerShell wpisz:

```powershell
Get-ChildItem -Name *.cmd
```

Powinieneś zobaczyć `Manage-DefenderExclusion.cmd`.

### 2. Uruchom plik

Jeśli plik istnieje, wpisz:

```powershell
.\Manage-DefenderExclusion.cmd
```

Możesz też uruchomić go z pełnej ścieżki:

```powershell
& "D:\PTT-91-50\piotr-personal-files\objective-vocation\ngo\wtz\IT\skills-presentation-2\powershell\Manage-DefenderExclusion.cmd"
```

### 3. Uruchom jako administrator

Ponieważ skrypt zarządza ustawieniami zabezpieczeń, może wymagać uprawnień administratora.

1. Otwórz Eksplorator plików.
2. Przejdź do folderu `powershell`.
3. Kliknij prawym przyciskiem `Manage-DefenderExclusion.cmd`.
4. Wybierz **Uruchom jako administrator**, jeśli ta opcja jest dostępna.

Jeśli jej nie ma, otwórz PowerShell jako administrator i uruchom plik z podanej wyżej ścieżki.

### 4. Ważne w Twojej konfiguracji

Ponieważ wcześniej ustaliliśmy, że usługa Microsoft Defender jest zatrzymana, a masz inny program antywirusowy, uruchomienie pliku `.cmd` **nie naprawi problemu z usługą Defendera**. Plik uruchomi skrypt PowerShell, który może ponownie wyświetlić błąd `0x800106ba`.

Jeśli chcesz tylko sprawdzić działanie menu, możemy również zmodyfikować skrypt tak, aby wyświetlał menu i informację o niedostępności Defendera, zamiast kończyć pracę przy uruchomieniu.

Ten błąd oznacza, że PowerShell nie rozpoznaje `[CmdletBinding()]` i `param()` jako elementów deklaracji skryptu. Najczęściej dzieje się tak, gdy **przed `[CmdletBinding()]` znajduje się jakiś wykonywalny kod**, np. instrukcja `Set-ExecutionPolicy`, dodatkowy znak lub nieprawidłowo wklejony fragment.

Naprawmy to krok po kroku.

### 1. Sprawdź początek pliku

W PowerShell, będąc w katalogu `powershell`, wykonaj:

```powershell
Get-Content .\Manage-DefenderExclusion.ps1 -TotalCount 15
```

Początek pliku powinien wyglądać mniej więcej tak:

```powershell
[CmdletBinding()]
param(
    [ValidateSet('Folder', 'File', 'Process', 'Remove', 'RemoveProcess', 'List', 'Menu')]
    [string]$Mode = 'Menu',

    [string]$Path
)
```

**Ważne:** `[CmdletBinding()]` i `param(...)` powinny znajdować się na samym początku skryptu, przed instrukcjami wykonywalnymi. Dopuszczalne są komentarze oraz puste linie przed nimi.

### 2. Sprawdź, czy nie ma kodu przed deklaracją parametrów

Jeśli początek pliku wygląda na przykład tak:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

[CmdletBinding()]
param(
```

usuń pierwszą instrukcję `Set-ExecutionPolicy` z pliku. Nie jest ona potrzebna wewnątrz skryptu do rozwiązania tego problemu.

Jeśli potrzebujesz zmienić politykę wykonywania w bieżącej sesji, uruchom tę instrukcję osobno w konsoli:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Następnie uruchom skrypt:

```powershell
.\Manage-DefenderExclusion.ps1 -Mode Menu
```

### 3. Jeśli błąd nadal występuje

Wklej tutaj wynik polecenia:

```powershell
Get-Content .\Manage-DefenderExclusion.ps1 -TotalCount 25
```

Na tej podstawie wskażę dokładnie, co należy poprawić, zamiast zgadywać.

**Uwaga:** zmiana polityki wykonywania nie naprawi błędów składni. Ponadto, aby skrypt mógł modyfikować wykluczenia Microsoft Defender, PowerShell musi być uruchomiony jako administrator. Wykluczenia zmniejszają ochronę antywirusową, dlatego dodawaj tylko zaufane pliki i katalogi.

