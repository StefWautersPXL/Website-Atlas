# Script: Sync-DL_Entra_POC.ps1
# Doel: bewaak lokale AD-groep DL_Entra_POC en forceer Entra Connect sync bij wijzigingen

Import-Module ActiveDirectory
Import-Module ADSync

# Naam van de lokale AD-groep
$GroupName = "DL_Entra_POC"

# Pad naar bestand waarin we vorige ledenlijst bewaren
$StateFile = "C:\Scripts\DL_Entra_POC_Members.txt"

# Functie: haal huidige leden (samAccountName) van de groep op
function Get-CurrentGroupMembers {
    $members = Get-ADGroupMember -Identity $GroupName -Recursive -ErrorAction Stop |
               Where-Object { $_.objectClass -eq "user" } |
               ForEach-Object {
                    (Get-ADUser $_.DistinguishedName -Properties samAccountName).samAccountName
               }

    # Sorteer voor consistente vergelijking
    return $members | Sort-Object
}

# Functie: laad vorige ledenlijst uit bestand (indien aanwezig)
function Get-PreviousGroupMembers {
    if (Test-Path $StateFile) {
        return Get-Content $StateFile | Sort-Object
    }
    else {
        return @()
    }
}

# Functie: sla huidige ledenlijst op
function Save-GroupMembers($members) {
    $members | Sort-Object | Out-File -FilePath $StateFile -Encoding UTF8
}

Write-Host "Start monitoring van groep '$GroupName' voor Entra sync..." -ForegroundColor Cyan

while ($true) {
    try {
        # 1. Huidige en vorige leden ophalen
        $currentMembers  = Get-CurrentGroupMembers
        $previousMembers = Get-PreviousGroupMembers

        # 2. Vergelijken
        $added   = Compare-Object -ReferenceObject $previousMembers -DifferenceObject $currentMembers -PassThru | Where-Object { $_ -in $currentMembers }
        $removed = Compare-Object -ReferenceObject $previousMembers -DifferenceObject $currentMembers -PassThru | Where-Object { $_ -in $previousMembers }

        if ($added -or $removed) {
            Write-Host "Wijziging gedetecteerd in DL_Entra_POC!" -ForegroundColor Yellow

            if ($added) {
                Write-Host "Toegevoegd:" $added -ForegroundColor Green
            }
            if ($removed) {
                Write-Host "Verwijderd:" $removed -ForegroundColor Red
            }

            # 3. Delta sync naar Entra ID starten
            Write-Host "Start Entra Connect delta sync..." -ForegroundColor Cyan
            Start-ADSyncSyncCycle -PolicyType Delta

            # 4. Nieuwe ledenlijst opslaan
            Save-GroupMembers -members $currentMembers

            Write-Host "Sync uitgevoerd op $(Get-Date)." -ForegroundColor Cyan
        }
        else {
            Write-Host "Geen wijzigingen in DL_Entra_POC. Laatste check: $(Get-Date)" -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "Fout: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 5. Wacht X seconden/minuten voor volgende check
    Start-Sleep -Seconds 60
}
