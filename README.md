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


# 2. Plik uruchamiający `Run-DefenderExclusions.cmd`

Ten plik:

* uruchamia skrypt PowerShell;
* przekazuje wszystkie argumenty;
* stosuje `ExecutionPolicy Bypass` wyłącznie do uruchomionego procesu PowerShell;
* pozwala przeczytać wynik po zakończeniu działania.

**Uwaga:** uruchom CMD jako administrator. Skrypt nie będzie automatycznie omijał kontroli uprawnień UAC.

---

# 3. Jak uruchamiać poszczególne tryby?

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

# 4. Uruchamianie z CMD

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

# 5. Co warto wiedzieć przed użyciem?

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

