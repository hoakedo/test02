# Input bindings are passed in via param block.
param($Timer)

#token取得
$ClientID = "1b997575-614f-4a49-82d3-defa5d3cbf2d"
$ClientSecret = "NjK8Q~P~M1blB0zXPI.S~kyd6_45NiWPh-sSuaVa"
$loginURL = "https://login.microsoftonline.com/"
$tenantdomain = "mocauser38501gmail.onmicrosoft.com"
$TenantGUID = "bc752680-4bf8-4550-a185-fec14c17c3fa"
$resource = "https://manage.office.com"
$body = @{grant_type="client_credentials";resource=$resource;client_id=$ClientID;client_secret=$ClientSecret}
$oauth = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body
$headerParams = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"} 


#コンテンツ取得
$startTime = (Get-Date).ToUniversalTime().AddHours(-12).ToString("o")
$endTime   = (Get-Date).ToUniversalTime().ToString("o")
$uri = "https://manage.office.com/api/v1.0/$tenantGuid/activity/feed/subscriptions/content" + "?contentType=Audit.General&startTime=$startTime&endTime=$endTime"
$uri
$content = Invoke-RestMethod -Method Get -Headers $headerParams -Uri $uri
$content

if (-not $content) {
  Write-Host "No content found in the specified time range."
  return
}

#実データ取得
$events = @()
foreach($item in $content){if($null -ne $item.contentUri -and $item.contentUri -ne ""){$data=Invoke-RestMethod -Method Get -Headers $headerParams -Uri $item.contentUri;if($data){if($data -is [System.Array]){$events+=$data}else{$events+=,$data}}}}
if ($events.Count -eq 0) {Write-Host "No events fetched from contentUri." return}

$events | ForEach-Object {
  $_ | Add-Member -NotePropertyName TimeGenerated -NotePropertyValue (Get-Date).ToUniversalTime().ToString("o") -Force
}

#送信
$workspaceId = "4eace82d-dbcb-4117-9bef-872f18ed14cf"
$workspaceKey = "tNHrdV//E0d5RK3myY/xmHMZ1m1K+OQ1oU44rv3evAaC+EwOZ0T2pYD8zd+qkACtxns2kAGIrpkVUGpuFcNdBw=="
$logType = "O365Audit"

$payload = ($events | ConvertTo-Json -Depth 50)
$bodyBytes = [Text.Encoding]::UTF8.GetBytes($payload)
$rfc1123   = (Get-Date).ToUniversalTime().ToString("r")
$stringToSign = "POST`n$($bodyBytes.Length)`napplication/json`nx-ms-date:$rfc1123`n/api/logs"
$hmac = New-Object System.Security.Cryptography.HMACSHA256
$hmac.Key = [Convert]::FromBase64String($workspaceKey)
$signature = [Convert]::ToBase64String(
  $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
)

Invoke-RestMethod -Method Post -Uri "https://$workspaceId.ods.opinsights.azure.com/api/logs?api-version=2016-04-01" -Headers @{Authorization="SharedKey ${workspaceId}:${signature}";"Log-Type"=$logType;"x-ms-date"=$rfc1123} -ContentType "application/json" -Body ([Text.Encoding]::UTF8.GetBytes($payload))




