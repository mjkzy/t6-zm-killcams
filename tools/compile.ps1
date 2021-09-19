<# script for compiling gsc & zipping it up #>
Set-PSDebug -Off

# delete file if exists
if (Test-Path -Path ".\zm-killcams.gsc" -PathType Leaf)
{
    try {
        "killcam file exists, deleting..."
        Remove-Item -Path ".\zm-killcams.gsc"
    }
    catch {
        throw $_.Exception.Message
    }
}

# get content of each gsc file and put into new file
Get-Content -Path "..\src\gsc\main.gsc" | Out-File -FilePath ".\zm-killcams.gsc"
Get-Content -Path "..\src\gsc\functions.gsc" | Out-File -FilePath ".\zm-killcams.gsc" -Append
Get-Content -Path "..\src\gsc\killcam.gsc" | Out-File -FilePath ".\zm-killcams.gsc" -Append
Get-Content -Path "..\src\gsc\utils.gsc" | Out-File -FilePath ".\zm-killcams.gsc" -Append
"zm-killcams.gsc file generated"

# compile file, then rename the compiled one to zm-killcams
Start-Process -NoNewWindow -FilePath .\Compiler.exe -ArgumentList "zm-killcams.gsc" -Wait
Remove-Item -Path ".\zm-killcams.gsc"
Rename-Item -Path ".\zm-killcams-compiled.gsc" "zm-killcams.gsc"
"zm-killcams.gsc renamed & compiled"

# compile zm_buried && zm_highrise scripts
New-Item -Path "." -Name "zm_buried" -ItemType "directory" -Force
New-Item -Path "." -Name "zm_highrise" -ItemType "directory" -Force

Get-Content -Path "..\src\gsc\zm_buried\script.gsc" | Out-File -FilePath ".\script.gsc"

Start-Process -NoNewWindow -FilePath .\Compiler.exe -ArgumentList "script.gsc" -Wait
Remove-Item -Path ".\script.gsc"
Rename-Item -Path ".\script-compiled.gsc" "script.gsc"
"script.gsc renamed & compiled"
Copy-Item ".\script.gsc" -Destination ".\zm_buried\" -Force
Copy-Item ".\script.gsc" -Destination ".\zm_highrise\" -Force
Remove-Item -Path ".\script.gsc"

$zip = @{
    Path = ".\zm-killcams.gsc", ".\zm_buried\", ".\zm_highrise\", ".\setup.txt"
    CompressionLevel = "Fastest"
    DestinationPath = ".\zm-killcams.zip"
}
Compress-Archive @zip