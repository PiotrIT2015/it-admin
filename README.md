
### 1. Jak teraz uruchamiać operacje?

W PowerShell możesz korzystać z poniższych poleceń.

**Otworzenie menu:**

```powershell
.\Manage-DefenderExclusion.cmd
```

**Dodanie wykluczenia folderu:**

```powershell
.\Manage-DefenderExclusion.cmd Folder "D:\Projects\myapp"
```

**Dodanie wykluczenia pliku:**

```powershell
.\Manage-DefenderExclusion.cmd File "D:\Projects\myapp\app.exe"
```

**Dodanie wykluczenia procesu:**

```powershell
.\Manage-DefenderExclusion.cmd Process "D:\Apps\myapp.exe"
```

**Usunięcie wykluczenia folderu lub pliku:**

```powershell
.\Manage-DefenderExclusion.cmd Remove "D:\Projects\myapp"
```

**Wyświetlenie aktualnych wykluczeń:**

```powershell
.\Manage-DefenderExclusion.cmd List
```

W każdej z tych sytuacji plik CMD sam uruchamia odpowiedni skrypt PowerShell i przekazuje mu parametry. Nie musisz wpisywać drugiego polecenia.

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

Wcześniej otrzymywałeś błąd `0x800106ba`, ponieważ usługa Microsoft Defender była zatrzymana. Poprawiony plik CMD rozwiązuje problem przekazywania parametrów, ale **nie naprawia niedostępności Defendera**.

Ponadto dodawanie wykluczeń wymaga uprawnień administratora. Wykluczenia mogą ograniczać ochronę antywirusową, dlatego dodawaj tylko zaufane ścieżki.

Po zapisaniu pliku możesz najpierw przetestować bezpieczną operację odczytu:

```powershell
.\Manage-DefenderExclusion.cmd List
```

Jeżeli Defender nadal nie będzie dostępny, skrypt powinien zgłosić problem z odczytem konfiguracji.




