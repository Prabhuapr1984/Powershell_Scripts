    Invoke-WebRequest -Uri "https://aka.ms/win32-x64-user-stable" -OutFile $env:SystemRoot\temp\VSCode_x64.exe
    $UnattendedArgs = '/verysilent /suppressmsgboxes /mergetasks=!runcode'
    (Start-Process "VSCode_x64.exe" $UnattendedArgs -Wait -Passthru).ExitCode