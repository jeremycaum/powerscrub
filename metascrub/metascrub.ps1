# metascrub.ps1
# A powershell script to view/remove EXIF data from .jpg's
# Author: Jeremy Caum
# Email: jeremycaum@gmail.com or jeremy@jeremycaum.io

param(
     [string]$file = $false,
     [string]$exportcsv = $false
)

# Loads the System.Drawing DLL for usage
Add-Type -Assembly System.Drawing

Function Get-Coordinates{
     param($image, $exifCode)
     Try {
          $propertyItem = $image.GetPropertyItem($exifCode)
          $valueBytes = $propertyItem.value
          [double]$degree = (([System.BitConverter]::ToInt32($valueBytes, 0)) / ([System.BitConverter]::ToInt32($valueBytes,4)))
          [double]$minute = (([System.BitConverter]::ToInt32($valueBytes, 8)) / ([System.BitConverter]::ToInt32($valueBytes,12)))
          [double]$second = (([System.BitConverter]::ToInt32($valueBytes, 16)) / ([System.BitConverter]::ToInt32($valueBytes,20)))
          $value = $degree + ($minute / 60) + ($second / 3600)
     }
     Catch {
          $value = "<empty>"
     }
     return $value
}

Function Get-ExifContents {
     param($image, $exifCode)
     # Trys to pull the EXIF data from the file
     Try {
          # Pulls the property from the file based on the EXIF tag
          $PropertyItem = $image.GetPropertyItem($exifCode)
          # Grabs only the value from the property item
          $valueBytes = $PropertyItem.value
          # Converts the byte array in an ASCII String
          $value = [System.Text.Encoding]::ASCII.GetString($valueBytes)
     }
     # If it fails to pull the property from the photo, sets the value to "<empty>" 
     Catch{
          $value = "<empty>"     
     }
     return $value
}

Function Write-Results{
     param($label, $value)
     # Writes the property label to the output without a new line
     Write-Host "${label}: " -NoNewline
     if ($value -like "<empty>"){
          # if the EXIF data is not there writes the text in green text
          Write-Host $value -ForegroundColor DarkGreen
     }
     else {
          # If there is EXIF data write the data in red text
          Write-Host $value -ForegroundColor DarkRed
     }
}

Function Get-FileContents {
     param($file)
     # Creates the full path for the file
     $fullPath = (Resolve-Path $file).path
     # Creates a file handle to the image
     $fs = [System.IO.File]::OpenRead($fullPath)
     # Reads the image to allow parsing for EXIF data
     $image = [System.Drawing.Image]::FromStream($fs, $false, $false)
     $maker = Get-ExifContents -image $image -exifCode "271"
     $model = Get-ExifContents -image $image -exifCode "272"
     $version = Get-ExifContents -image $image -exifCode "305"
     $dateTime = Get-ExifContents -image $image -exifCode "306"
     $lat = Get-Coordinates -image $image -exifCode "2"
     $long = Get-Coordinates -image $image -exifCode "4"
     $latRef = Get-ExifContents -image $image -exifCode "1"
     $longRef = Get-ExifContents -image $image -exifCode "3"
     $altitude = Get-Coordinates -image $image -exifCode "6"
     # Puts all the EXIF data in a PSObject to return
     $exifData = [pscustomobject][ordered]@{
          File = $file
          CameraMaker = $maker
          CameraModel = $model
          SoftwareVersion = $version
          DateTaken = $dateTime
          Latitude = [string]$lat + $latRef
          Longitude = [string]$long + $longRef
          Altitude = $altitude
     }
     if ($exifData.Latitude -eq "<empty><empty>"){
          $exifData.Latitude = "<empty>"
     }
     if ($exifData.Longitude -eq "<empty><empty>"){
          $exifData.Longitude = "<empty>"
     }
     return $exifData

}

# Prompts the user for the file path if it was not given upon invocation
if (!$file){
     $file = Read-Host -Prompt "Path to photo to inspect"
}

$exportArray = [System.Collections.ArrayList]@()
$isDir = (Get-Item $file) -is [System.IO.DirectoryInfo]
# Write-Output "isDir: $isDir"
if ($isDir){
     $fileList = (Get-ChildItem $file).fullname
     foreach($childFile in $fileList){
          $ext = (Get-ChildItem $childFile).extension
          if($ext -ne ".jpg"){
               # Write-Output "$childFile is not a jpg, skipping"
               continue
          }
          $obj = Get-FileContents($childFile)
          $exportArray.add($obj) | Out-Null
     }
}
else {
     $ext = (Get-ChildItem $file).extension
     if($ext -notlike ".jpg"){
          Write-Output "$file does not have .jpg extension"
          exit
     }
     $obj = Get-FileContents($file)
     $exportArray.add($obj) | Out-Null
}

if ($exportcsv){
     $exportArray | Export-Csv -NoTypeInformation -Append $exportcsv
}

if ($exportcsv -eq $false){
     # Writes the results to the screen for veiwing
     foreach($obj in $exportArray){
          Write-Host Picture: $obj.file
          Write-Results -label "Camera Maker" -value $obj.cameramaker
          Write-Results -label "Camera Model" -value $obj.cameramodel
          Write-Results -label "Software Version" -value $obj.softwareversion
          Write-Results -label "Time Taken" -value $obj.datetaken
          Write-Results -label "Latitude" -value $obj.latitude
          Write-Results -label "Longitude" -value $obj.longitude
          Write-Results -label "Altitude" -value $obj.altitude
     }
}


