$SID = New-Object System.Security.Principal.SecurityIdentifier ("S-1-5-113")
$Account = $SID.Translate([System.Security.Principal.NTAccount])
$Account.Value