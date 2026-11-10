# Win32 app templates

Copy `Install-App.ps1`, `Uninstall-App.ps1` and `Detect-App.ps1` next to your installer, edit the settings block at the top of each, then package the folder with Microsoft's Win32 Content Prep Tool (`IntuneWinAppUtil.exe`, not included here):

```powershell
.\IntuneWinAppUtil.exe -c .\MyApp -s Install-App.ps1 -o .\out
```

In the Intune admin centre use:

- Install command: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-App.ps1`
- Uninstall command: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-App.ps1`
- Detection rule: custom script, `Detect-App.ps1`
- Return codes: 0 success, 3010 soft reboot (the template maps both to 0, so adjust one or the other, not both)

The vendor's silent switch differs per installer. Check it before relying on the defaults.
