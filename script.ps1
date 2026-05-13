# Sync-DL_Entra_POC.ps1
# Null-safe monitoring van lokale AD-groep en triggeren van Entra Connect delta sync

Import-Module ActiveDirectory -ErrorAction Stop
Import-Module ADSync -ErrorAction Stop

$GroupName = "DL_Entra_POC"
$ScriptFolder = "C:\Scripts"
$StateFile = Join-Path $ScriptFolder "DL_Entra_POC_Members.txt"
$LogFile = Join-Path $ScriptFolder "Sync-DL_Entra_POC.log"
$SleepSeconds = 60

function Log {
    param([string]$Message)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$time`t$Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

function Get-CurrentGroupMembers {
    try {
        $members = Get-ADGroupMember -Identity $GroupName -Recursive -ErrorAction Stop |
                   Where-Object { $_.objectClass -eq "user" } |
                   ForEach-Object {
                       (Get-ADUser $_.DistinguishedName -Properties samAccountName -ErrorAction SilentlyContinue).samAccountName
                   } | Where-Object { $_ }  # filter nulls
        return ,@($members)  # force array
    }
    catch {
        Log "ERROR: Kan huidige leden niet ophalen: $($_.Exception.Message)"
        return @()
    }
}

function Get-PreviousGroupMembers {
    if (Test-Path $StateFile) {
        try {
            $content = Get-Content -Path $StateFile -ErrorAction Stop
            return ,@($content | Where-Object { $_ })  # force array, filter lege regels
        }
        catch {
            Log "WARNING: Kan state file niet lezen: $($_.Exception.Message)"
            return @()
        }
    }
    else {
        return @()
    }
}

function Save-GroupMembers {
    param([string[]]$Members)
    try {
        $Members | Sort-Object | Out-File -FilePath $StateFile -Encoding UTF8
    }
    catch {
        Log "ERROR: Kan state file niet schrijven: $($_.Exception.Message)"
    }
}

Log "Script gestart. Monitoring van groep '$GroupName'."

while ($true) {
    try {
        $currentMembers  = Get-CurrentGroupMembers
        $previousMembers = Get-PreviousGroupMembers

        # Zorg dat variabelen nooit $null zijn
        if (-not $currentMembers)  { $currentMembers = @() }
        if (-not $previousMembers) { $previousMembers = @() }

        # Null-safe verschilberekening
        $added   = $currentMembers | Where-Object { $_ -notin $previousMembers }
        $removed = $previousMembers | Where-Object { $_ -notin $currentMembers }

        if ($added.Count -gt 0 -or $removed.Count -gt 0) {
            Log "Wijziging gedetecteerd. Toegevoegd: $($added -join ', '); Verwijderd: $($removed -join ', ')"
            Log "Start Entra Connect delta sync..."
            try {
                Start-ADSyncSyncCycle -PolicyType Delta -ErrorAction Stop
                Log "Delta sync gestart."
            }
            catch {
                Log "ERROR: Kon delta sync niet starten: $($_.Exception.Message)"
            }
            Save-GroupMembers -Members $currentMembers
        }
        else {
            Log "Geen wijzigingen. Laatste check: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        }
    }
    catch {
        Log "FOUT in hoofdloop: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds $SleepSeconds
}
    
