#! /usr/bin/pwsh

###############################################################################################################################
# This script creates the structure where each product has all files
#
# The typical pattern creates all types of files together instead - and this script needs to modified to handle that
###############################################################################################################################

param ($iaas, $product)

function Create-Directory ($dirname) {
    $OriginalErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'silentlycontinue'
    New-Item -Path "$dirname" -ItemType Directory > $null
    $ErrorActionPreference = $OriginalErrorActionPreference
}

function Touch-File ($filename) {
    $OriginalErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'silentlycontinue'
    $filename = "$filename" -replace ' ',''
    New-Item -Path "$filename" -ItemType File > $null
    $ErrorActionPreference = $OriginalErrorActionPreference
}

function Remove-File ($filename) {
    $OriginalErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'silentlycontinue'
    $filename = "$filename" -replace ' ',''
    Remove-Item -Path "$filename"
    $ErrorActionPreference = $OriginalErrorActionPreference
}

function Empty-File($filename) {
    $firstline = get-content $filename -first 1
    $returnvalue = 1;
    if ($firstline -eq "{}") {
        $returnvalue = 0
    }
    $returnvalue
}

# Check to make sure PIVNET_TOKEN is set
# To set PIVNET_TOKEN in powershell:
# $env:PIVNET_TOKEN="yourtokenhere"
if (-not (Test-Path env:PIVNET_TOKEN)) {
    Write-Host "PIVNET_TOKEN must be set"
    Exit 1
}

$configFile = "config.yml"
if (TestPath $configFile) {
    $INITIAL_FOUNDATION = (om interpolate -c $configFile --path /initial-foundation)
} else {
    Write-Host "Must create $configfile and specify initial-foundation"
    Exit 1
}

Write-Host "Generating configuration for $product in $iaas/$INITIAL_FOUNDATION"

$product_dir = "../$iaas/$INITIAL_FOUNDATION/config/$product" -replace ' ',''

$versionfile = "$product_dir/version.yml" -replace ' ',''
if (-not (Test-Path $versionfile)) {
    Write-Host "Must create $versionfile"
    Exit 1
}

$version = (om interpolate -s -c $versionfile --path /product-version)
$glob = (om interpolate -s -c $versionfile --path /pivnet-file-glob)
$slub = (om interpolate -s -c $versionfile --path /pivnet-product-slug)

Write-Host "Searching for version $version with glob $glob and slug $slug"

$tmpdir = "tile-configs/$product-config"
Create-Directory("$tmpdir")
om config-template --output-directory=$tmpdir --pivnet-api-token $env:PIVNET_TOKEN --pivnet-product-slug $slug --product-version $version --pivnet-file-glob $glob

$searchversion = "$version*" --replace ' ',''
$wrkdir = (Get-ChildItem ./$tmpdir/$product -Filter $searchversion).name
if ( -not (Test-Path ./$tmpdir/$product/$wrkdir/product.yml)) {
    Write-Host "Something wrong with configuration as expecting $wkrdir/product.yml to exist"
    Exit 1
}

Create-Directory("../$iaas/opsfiles")

$ops_file = "../$iaas/opsfiles/$product-operations" -replace ' ',''
Touch-File($ops_file)

$ops_files_args = ""
foreach ($line in Get-Content $ops_file) [
    $ops_files_args += " -o $tmpdir/$product/$wkrdir/$line"
]

$generated_dir = "$product_dir/generated"
Create-Directory($generated_dir)

$templatefile = "$generated_dir/template.yml" -replace ' ',''
$cmd = "om interpolate -s -c $tmpdir/$product/$wrkdir/product.yml $ops_files_args > $templatefile"
# Calling this via Invoke Expression to make it easier to debug by doing ...
# Write-Host $cmd
Invoke-Expression $cmd

$default_product_file = "$generated_dir/defaults.yml" -replace ' ',''
Remove-File($default_product_file)
Touch-File($default_product_file)

$default_file = "$tmpdir/$product/$wrkdir/default-vars.yml"
if (Test-Path $default_file) {
    if (Empty-File($default_file) -eq 1) {
        type $default_file >> $default_product_file
    }
}

$errands_file = "$tmpdir/$product/$wrkdir/errand-vars.yml"
if (Test-Path $errands_file) {
    if (Empty-File($errands_file) -eq 1) {
        type $errands_file >> $default_product_file        
    }
}

$resource_file = "$tmpdir/$product/$wrkdir/resource-vars.yml"
if (Test-Path $resource_file) {
    if (Empty-File($resource_file) -eq 1) {
        type $resource_file >> $default_product_file        
    }
}

$secrets_dir = "$product_dir/secrets"
Create-Directory($secrets_dir)
Touch-File("$secrets_dir/secrets.yml")

Touch-File("$product_dir/vars.yml")

Touch-File ("$product_dir/errands")

$common_dir = "../$iaas/common"
Create-Directory($common_dir)
Touch-File("$common_dir/$product.yml")
