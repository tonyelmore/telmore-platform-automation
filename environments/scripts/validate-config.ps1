#! /usr/bin/pwsh

###############################################################################################################################
# This script uses the structure where each product has all files
#
# The typical pattern uses all types of files together instead - and this script needs to modified to handle that
###############################################################################################################################

param ($iaas, $environment_name, $product)

Write-Host "Validating configuration for $product in $iaas/$INITIAL_FOUNDATION"

$deploy_type = "tile"

if ($product -eq "os-conf") {
    $deploy_type = "runtime-config"
}
if ($product -eq "clamav") {
    $deploy_type = "runtime-config"
}

$var_files_args = ''
if ($deploy_type -eq "runtime-config") {
    $var_files_args += " --vars-file ../$iaas/$environment_name/config/$product/version.yml"
}

$common_file = "../$iaas/common/$product.yml"
if (Test-Path "$common_file") {
    $vars_files_args += " --vars-file $common_file"
}

$vars_file = "../$iaas/$environment_name/config/$product/vars.yml"
if (Test-Path "$vars_file") {
    $vars_files_args += " --vars-file $vars_file"
}

$secrets_file = "../$iaas/$environment_name/config/$product/secrets/secrets.yml"
if (Test-Path "$secrets_file") {
    $vars_files_args += " --vars-file $secrets_file"
}

$template_file = "../$iaas/$environment_name/config/$product/generated/template.yml"
if ($deploy_type -eq "tile") {
    $cmd = "bosh int --var-errs-unused $template_file $var_files_args" 
    # Write-Host $cmd
    Invoke-Expression $cmd > $null
}

$default_file = "../$iaas/$environment_name/config/$product/generated/defaults.yml"
if (Test-Path $default_file) {
    $vars_files_args += " --vars-file $default_file"
}

$cmd = "bosh int --var-errs $template_file $var_files_args"
# Write-Host $cmd
Invoke-Expression $cmd > $null
