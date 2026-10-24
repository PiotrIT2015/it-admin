
### 1. Jak teraz uruchamiać operacje?

W PowerShell możesz korzystać z poniższych poleceń.

**Otworzenie menu:**

```powershell
.\Manage-DefenderExclusion.bat
```

**Dodanie wykluczenia folderu:**

```powershell
.\Manage-DefenderExclusion.bat Folder "D:\Projects\myapp"
```

**Dodanie wykluczenia pliku:**

```powershell
.\Manage-DefenderExclusion.bat File "D:\Projects\myapp\app.exe"
```

**Dodanie wykluczenia procesu:**

```powershell
.\Manage-DefenderExclusion.bat Process "D:\Apps\myapp.exe"
```

**Usunięcie wykluczenia folderu lub pliku:**

```powershell
.\Manage-DefenderExclusion.bat Remove "D:\Projects\myapp"
```

**Wyświetlenie aktualnych wykluczeń:**

```powershell
.\Manage-DefenderExclusion.bat List
```

W każdej z tych sytuacji plik [*.bat] sam uruchamia odpowiedni skrypt PowerShell i przekazuje mu parametry. Nie musisz wpisywać drugiego polecenia.

### 2. Jak działa przekazywanie parametrów?

W tej instrukcji:

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Mode "%~1" -Path "%~2"
```

* `%SCRIPT%` wskazuje plik PowerShell znajdujący się w tym samym katalogu co plik CMD.
* `%~1` przekazuje pierwszy argument, np. `Folder`.
* `%~2` przekazuje drugi argument, np. `D:\Projects\myapp`.
* `-Mode` i `-Path` to parametry zdefiniowane w Twoim skrypcie `.ps1`.

### 3. Ważne w Twoim przypadku

Ponadto dodawanie wykluczeń wymaga uprawnień administratora. Wykluczenia mogą ograniczać ochronę antywirusową, dlatego dodawaj tylko zaufane ścieżki.

Po zapisaniu pliku możesz najpierw przetestować bezpieczną operację odczytu:

```powershell
.\Manage-DefenderExclusion.bat List
```

### 4. Uruchomienie z `cmd.exe`

Jeśli jesteś w katalogu ze skryptem:

```bat
Manage-DefenderExclusion.bat
```

Menu uruchomi się automatycznie.

Dodanie wykluczenia folderu:

```bat
Manage-DefenderExclusion.bat Folder "D:\Projects\myapp"
```

Wyświetlenie wykluczeń:

```bat
Manage-DefenderExclusion.bat List
```

Usunięcie wykluczenia:

```bat
Manage-DefenderExclusion.bat Remove "D:\Projects\myapp"
```

### 5. Uruchomienie z innego katalogu

Możesz podać pełną ścieżkę:

```bat
"D:\Scripts\Manage-DefenderExclusion.bat" Folder "D:\Projects\myapp"
```

Jeśli ścieżka do samego pliku [*.bat] zawiera spacje, ujmij ją w cudzysłowy.

### 6. Najważniejsza różnica

| Czynność                          | PowerShell                                                  | Wiersz polecenia (`cmd.exe`)                              |
| --------------------------------- | ----------------------------------------------------------- | --------------------------------------------------------- |
| Uruchomienie z bieżącego katalogu | `.\Manage-DefenderExclusion.bat`                            | `Manage-DefenderExclusion.bat`                            |
| Uruchomienie pełną ścieżką        | `& "D:\Scripts\Manage-DefenderExclusion.bat"`               | `"D:\Scripts\Manage-DefenderExclusion.bat"`               |
| Przekazanie argumentów            | `.\Manage-DefenderExclusion.bat Folder "D:\Projects\myapp"` | `Manage-DefenderExclusion.bat Folder "D:\Projects\myapp"` |

**Ważne:** niezależnie od tego, czy uruchomisz plik z PowerShell, czy z `cmd.exe`, sam skrypt może wymagać uprawnień administratora. 




