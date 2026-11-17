# Refuse an apply unless a person passes both switches on purpose.
# Automation must not pass these switches.

param(
    [switch]$IUnderstandThisCreatesPaidResources,
    [switch]$Approve
)

if (-not $IUnderstandThisCreatesPaidResources -or -not $Approve) {
    Write-Error "Refuse to apply Terraform. Paid AWS resources stay uncreated until you approve a named stack."
    exit 1
}

Write-Error "Refuse to apply from this script. An approved apply is a separate reviewed command, not an automatic one."
exit 1
