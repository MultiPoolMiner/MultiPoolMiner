param($Parameters)

$files = Get-ChildItem Stats -Recurse | Where-Object {$_.Name -like '*HashRate.txt'}

$count = $files.Count

$files | Foreach-Object {
  Remove-Item $_.FullName
}

Write-Output "Removed $count stats files"