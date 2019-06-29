param($Parameters)

$text = ""
$count = 0

Get-ChildItem Stats -Recurse | Where-Object {$_.Name -like '*PowerUsage.txt'} | Foreach-Object {
  $FileName = $_.FullName
  $Stats = Get-Content $Filename | ConvertFrom-Json
  
  if($Stats.Minute -eq 0) {
    Remove-Item $FileName
    $text += "$($_.Name)`n"
    $count++
  }
}  

Write-Output "Removed $count power usage files:"
Write-Output "<pre>"
$text | Write-Output
Write-Output "</pre>"
