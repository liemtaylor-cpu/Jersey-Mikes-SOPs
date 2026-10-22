# First-session checklist (Windows PC)

Do these in order, one at a time. Each step says why, what to run, and what
success looks like. Don't start the next step until the current one passes.

Run every command in **PowerShell** (Start menu → type `PowerShell` → open
it). Step 3 writes into `Program Files`, so do steps 2 and 3 in one window
opened with **Run as administrator**.

Lines like `$game = '...'` save a folder path for later commands. They only
last until you close that window. If a later step uses `$game` or `$work`
in a new window, re-run the line from the step that set it.

Items marked **[verify]** were written without access to your PC. If what
you see differs, stop and tell Claude what you see.

---

## 1. Install the tools

**Why:** Git saves every working step so mistakes can be undone. 7-Zip
extracts the game's Lua source. Lua 5.1 gives us `luac`, the syntax checker
we run after every edit.

```powershell
winget install --id Git.Git -e
winget install --id 7zip.7zip -e
winget install --id rjpcomputing.luaforwindows -e
```

Close PowerShell and open a new one (so it picks up the new programs), then:

```powershell
git --version
luac -v
Test-Path 'C:\Program Files\7-Zip\7z.exe'
```

**Success:** a git version, `Lua 5.1.x` [verify], and `True`.

**If `luac` isn't found:** Lua for Windows may install only `lua.exe` on the
PATH [verify]. Run `Get-ChildItem 'C:\Program Files (x86)\Lua' -Recurse
-Filter luac*.exe` and tell Claude what it prints.

## 2. Find the game folder

**Why:** Lovely's DLL has to sit next to `Balatro.exe`.

In Steam: right-click Balatro → **Manage** → **Browse local files**. Copy the
folder path from the File Explorer address bar. Most installs use the path
below. Use yours if it's different:

```powershell
$game = 'C:\Program Files (x86)\Steam\steamapps\common\Balatro'
Test-Path "$game\Balatro.exe"
```

**Success:** `True`.

## 3. Install Lovely (the mod loader)

**Why:** Lovely injects code into the game at launch. Steamodded and every
mod depend on it.

1. Go to <https://github.com/ethangreen-dev/lovely-injector/releases/latest>
   and download `lovely-x86_64-pc-windows-msvc.zip`.
2. Copy `winmm.dll` out of it, next to `Balatro.exe` (admin PowerShell,
   reusing `$game` from step 2):

```powershell
$zip = "$env:USERPROFILE\Downloads\lovely-x86_64-pc-windows-msvc.zip"
Expand-Archive $zip -DestinationPath "$env:TEMP\lovely" -Force
Copy-Item "$env:TEMP\lovely\winmm.dll" $game
Test-Path "$game\winmm.dll"
```

3. Launch Balatro **through Steam**, reach the main menu, quit.

**Success:** the last command printed `True`, and this folder now exists:

```powershell
Test-Path "$env:APPDATA\Balatro\Mods\lovely\log"
```

A console window with log text usually opens next to the game too [verify].

**If the folder doesn't exist:** Lovely didn't load. Check that `winmm.dll`
is in the same folder as `Balatro.exe`, not in a subfolder.

## 4. Install Steamodded

**Why:** Steamodded is the modding framework BestHandAdvisor (and our mod)
is written for.

1. Go to <https://github.com/Steamodded/smods/releases/latest> and download
   **Source code (zip)** [verify: pick the zip, not the tar.gz].
2. Extract it into the Mods folder:

```powershell
$smods = Get-ChildItem "$env:USERPROFILE\Downloads\smods-*.zip" |
  Sort-Object LastWriteTime | Select-Object -Last 1
Expand-Archive $smods.FullName -DestinationPath "$env:APPDATA\Balatro\Mods" -Force
Get-ChildItem "$env:APPDATA\Balatro\Mods"
```

**Success:** you see a folder named like `smods-26.1002.0`. Inside it you
should see `lovely` and `src` folders **directly**, not another `smods-…`
folder. Launch the game: the main menu has a **Mods** button [verify].

## 5. Install and test BestHandAdvisor (upstream, unmodified)

**Why:** prove the starting point works on your PC before we change it. If
something breaks later, we'll know it was our change.

```powershell
git clone https://github.com/JCMexplains/balatro-best-hand "$env:APPDATA\Balatro\Mods\balatro-best-hand"
```

Launch, start a run, then press **F2** in a blind.

**Success:** the Lovely console prints the top 2 scoring plays. Play the
top one exactly as shown. The score the game gives should equal the
prediction (unless it says `(expected value)`, which means Lucky Card or
Bloodstone randomness was involved).

## 6. Extract the game's Lua source (`balatro_src/`)

**Why:** the offline test tools run the real game's scoring code to check
ours. This is the game's code: it's gitignored and must never be committed
or shipped.

Work on a **copy** of the exe, never the original (admin not needed, we
only read from `Program Files`):

```powershell
$work = "$env:USERPROFILE\balatro_work"
New-Item -ItemType Directory -Force $work | Out-Null
Copy-Item "$game\Balatro.exe" "$work\Balatro_copy.exe"
& 'C:\Program Files\7-Zip\7z.exe' x "$work\Balatro_copy.exe" -o"$work\balatro_src" -y
Test-Path "$work\balatro_src\card.lua"
```

**Success:** `True`. We'll copy `balatro_src` into the project folder in
step 7.

## 7. Get this repo onto your PC

**Why:** the project folder lives inside the Mods folder, so every edit is
live in the game on the next launch. Upstream also detects a `.git` folder
to turn on its developer mode.

First, tell git who you are (once per PC):

```powershell
git config --global user.name 'Your Name'
git config --global user.email 'you@example.com'
```

Then clone. Use the repo's **new** name if you've renamed it on GitHub:

```powershell
$proj = "$env:APPDATA\Balatro\Mods\balatro-trainer"
git clone https://github.com/liemtaylor-cpu/balatro-trainer $proj
Copy-Item "$work\balatro_src" $proj -Recurse
cd $proj
git status
```

**Success:** `git status` says `nothing to commit, working tree clean`. That
proves `balatro_src/` is ignored. If it lists `balatro_src/`, **stop**:
don't commit, tell Claude.

## 8. Check the offline grader tests

**Why:** confirms Lua works and the Phase 1 grading rule behaves as written.

```powershell
cd $proj
lua test_grade.lua
```

**Success:** the last line reads `All N tests passed.` and nothing says
`FAIL`.

---

## Done? Next steps

Tell Claude "first-session checklist done". Phase 1 begins: copy upstream's
code into this repo and rename the mod (CLAUDE.md, Phase 1 plan, step 1).
**Remove `Mods\balatro-best-hand` then,** because two copies of the same
scorer would both hook every hand you play.
