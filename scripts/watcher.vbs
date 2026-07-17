' WorkBuddy Skin Watcher - hidden background daemon
' Monitors WorkBuddy and auto-injects skin when launched
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
strScriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
strPs1 = fso.BuildPath(strScriptDir, "watcher.ps1")
strStudioRoot = fso.GetParentFolderName(strScriptDir)
WshShell.CurrentDirectory = strStudioRoot
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & strPs1 & """", 0, False