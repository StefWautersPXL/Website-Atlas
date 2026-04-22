param (
    [string]$PcPrefix,
    [int]$StartNum,
    [int]$EndNum,
    [string]$Command
)

# Genereer de lijst met PC-namen
$ComputerList = $StartNum..$EndNum | ForEach-Object { "$PcPrefix$("{0:D2}" -f $_)" }

Write-Host "Verbinding maken met: $($ComputerList -join ', ')" -ForegroundColor Cyan

# Voer het commando uit op de PC's
Invoke-Command -ComputerName $ComputerList -ScriptBlock {
    param($cmd)
    Invoke-Expression $cmd
} -ArgumentList $Command