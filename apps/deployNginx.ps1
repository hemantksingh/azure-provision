param (
    [Parameter(mandatory = $true)][string] $keyvaultName,
    [string] $baseDir = '.\apps'
)
$ErrorActionPreference = "Stop"

function Add-DirIfDoesNotExist( [Parameter(Mandatory = $true)][string] $dir) {
    if (!(test-path $dir)) {
        Write-Host "Creating dir '$dir'"
        New-Item -ItemType Directory -Force -Path $dir
    }
    else {
        Write-Host "Directory '$dir' already exists, removing its contents"
        Remove-Item -Path "$dir\*" -Recurse
    }
}

$templates = "$((Get-Item -Path $baseDir -Verbose).FullName)/templates"
$manifests = "$((Get-Item -Path $baseDir -Verbose).FullName)/manifests"
Add-DirIfDoesNotExist $manifests

Write-Host "Transforming '$templates\nginx-deployment.yaml' ..."
(Get-Content "$templates\nginx-deployment.yaml") `
    -replace "{{ keyvault_name }}" , $keyvaultName |
    Set-Content "$manifests\nginx-deployment.yaml"

kubectl apply -f $manifests/nginx-deployment.yaml