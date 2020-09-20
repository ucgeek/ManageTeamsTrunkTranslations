$VerbosePreference = "continue"
#region CLASSESS
class TrunkTranslation {
    $GatewayFqdn
    $TranslationId
    $Priority
    $Type
}
#endregion CLASSESS
#region FUNCTIONS
function Get-Type ($type) {
    switch($type) {
        'InboundCallerNumber' {'InboundPstnNumberTranslationRules'} 
        'InboundCalledNumber' {'InboundTeamsNumberTranslationRules'} 
        'OutboundCalledNumber' {'OutboundPstnNumberTranslationRules'} 
        'OutboundCallerNumber' {'OutboundTeamsNumberTranslationRules'} 
        default {$type}
    }
}
function CsOnlinePSTNGatewayParamBuilder ($gw, $type, $translationList) {
    $typeConverted = Get-Type $type
    
    $cmdParamBuilder = @{            
        Identity = $gw        
    }
    if($typeConverted -eq 'InboundPstnNumberTranslationRules') {                 
        $cmdParamBuilder.add('InboundPstnNumberTranslationRules', $translationList)
        return $cmdParamBuilder            
    } 
    elseif($typeConverted -eq 'InboundTeamsNumberTranslationRules') {                 
        $cmdParamBuilder.add('InboundTeamsNumberTranslationRules', $translationList)  
        return $cmdParamBuilder            
    } 
    elseif($typeConverted -eq 'OutboundPstnNumberTranslationRules') {                 
        $cmdParamBuilder.add('OutboundPstnNumberTranslationRules', $translationList)  
        return $cmdParamBuilder            
    }
    elseif($typeConverted -eq 'OutboundTeamsNumberTranslationRules') {                 
        $cmdParamBuilder.add('OutboundTeamsNumberTranslationRules', $translationList)
        return $cmdParamBuilder              
    }
    else {
        return $null
    } 
}

function New-TeamsTrunkTranslation {
    Param(
        [parameter(Mandatory=$true)] $Gateway,
        [parameter(Mandatory=$true)] [ValidateSet('InboundCallerNumber','InboundPstnNumberTranslationRules','InboundCalledNumber', 'InboundTeamsNumberTranslationRules', 'OutboundCalledNumber', 
        'OutboundPstnNumberTranslationRules', 'OutboundCallerNumber', 'OutboundTeamsNumberTranslationRules')] $Type,
        [parameter(Mandatory=$true)] $Name,
        [parameter(Mandatory=$true)] $Description,
        [parameter(Mandatory=$true)] $Pattern,
        [parameter(Mandatory=$true)] $Translation
    )
    <#
        .SYNOPSIS
        Adds a new translation rule to the specified Microsoft Teams PSTN gateway.
        .DESCRIPTION
        Adds a new translation rule to the specified Microsoft Teams PSTN gateway.
        .PARAMETER Gateway
        Gateway FQDN to add translation.
        .PARAMETER Type
        Translation type. Options are: 'InboundCallerNumber','InboundPstnNumberTranslationRules','InboundCalledNumber', 'InboundTeamsNumberTranslationRules', 'OutboundCalledNumber', 
        'OutboundPstnNumberTranslationRules', 'OutboundCallerNumber', 'OutboundTeamsNumberTranslationRules'
        .PARAMETER Name
        Name of translation.
        .PARAMETER Description
        Description of translation.
        .PARAMETER Pattern
        Translation pattern to match.
        .PARAMETER Translation
        Output translation.
        .OUTPUTS
        None.
        .EXAMPLE 
        C:\PS> Get-TeamsTrunkTranslations -Gateway 'gateway1.ucgeek.co' -Type InboundCalledNumber `
        -Name 'FwdDualNumber_Andrew.Morpeth_6498926461_TO_6498926460_TEST1' `
        -Description 'Fwd Dual Number - Andrew Morpeth - 6498926461 TO 6498926460' `
        -Pattern '\+6498926461' -Translation '+6498926460'      
        .EXAMPLE 
        C:\PS> Get-TeamsTrunkTranslations -Gateway 'gateway1.ucgeek.co' -Type OutboundCallerNumber `
        -Name 'CLID_AKLOfficeNumber_Andrew.Morpeth_6498926461;ext=1000_TO_6498926461_TEST1' `
        -Description 'CLID replacement for outbound call to Auckland Office mainline' `
        -Pattern '\+6498926461;ext=1000' -Translation '+6498926461'    
        EXAMPLE 
        C:\PS> Get-TeamsTrunkTranslations -Gateway 'gateway1.ucgeek.co' -Type OutboundCallerNumber `
        -Name 'CLID_AKLOfficeNumber_6498926461;ext=xxxx_TO_6498926461_TEST1' `
        -Description 'CLID replacement to Auckland Office mainline for non-DDI users' `
        -Pattern '(\+6498926461);ext=\d{4}' -Translation '$1'   
    #>    
    
    $typeConverted = Get-Type $type
    $existingTrunkTranslations = (Get-CsOnlinePSTNGateway -Identity $Gateway).($typeConverted)
    $existingTrunkTranslationsCount = $existingTrunkTranslations.count
    $existingTentantTranslations = Get-CsTeamsTranslationRule
    $existingTentantTranslationsCount = $existingTentantTranslations.count

    #Add translation rules
    if ($existingTentantTranslationsCount -gt 0 -and $existingTentantTranslations.Identity -contains $name) {
        Write-Host "Skipping - $name already exists"
    } else {
        Write-Host "Creating Translation - $name"
        New-CsTeamsTranslationRule -Identity $name -Pattern $pattern -Translation $translation -Description $description | Out-Null
    }

    #Add translation rule to trunk
    if ($existingTrunkTranslationsCount -gt 0) {
        Write-Host "Found $existingTrunkTranslationsCount existing translations for trunk $Gateway"
        if ($existingTrunkTranslations -Contains $name) {
            Write-Host "Skipping, already exists."
        } else {
             Write-Host "Adding translation to gateway $name"
             $existingTrunkTranslations.Add($name)
             $params = CsOnlinePSTNGatewayParamBuilder -gw $Gateway -type $typeConverted -translationList $existingTrunkTranslations
             Set-CsOnlinePSTNGateway @params
        }
    } else {
        Write-Host "Adding 1st translation to gateway $name"
        $newTranslationList = New-Object 'System.Collections.Generic.List[string]'
        $newTranslationList.Add($name)
        $params = CsOnlinePSTNGatewayParamBuilder -gw $Gateway -type $typeConverted -translationList $newTranslationList
        Set-CsOnlinePSTNGateway @params
    }
}
function Remove-TeamsTrunkTranslation {
    Param(
        [parameter(Mandatory=$true)] $Gateway,
        [parameter(Mandatory=$true)] [ValidateSet('InboundCallerNumber','InboundPstnNumberTranslationRules','InboundCalledNumber', 'InboundTeamsNumberTranslationRules', 'OutboundCalledNumber', 
        'OutboundPstnNumberTranslationRules', 'OutboundCallerNumber', 'OutboundTeamsNumberTranslationRules')] $Type,
        [parameter(Mandatory=$true)] $Name
    )
    <#
        .SYNOPSIS
        Removes an existing translation rule applied to Microsoft Teams PSTN gateways by type.
        .DESCRIPTION
        Removes an existing translation rule applied to Microsoft Teams PSTN gateways by type.
        .PARAMETER Gateway
        Gateway FQDN to remove translation.
        .PARAMETER Type
        Translation type. Options are: 'InboundCallerNumber','InboundPstnNumberTranslationRules','InboundCalledNumber', 'InboundTeamsNumberTranslationRules', 'OutboundCalledNumber', 
        'OutboundPstnNumberTranslationRules', 'OutboundCallerNumber', 'OutboundTeamsNumberTranslationRules'
        .PARAMETER Name
        Name of the translation rule to remove.
        .OUTPUTS
        List of gateway translations for the type specified.
        .EXAMPLE 
        Exports translations for the specified gateway:
        C:\PS> Get-TeamsTrunkTranslations -Gateway 'gateway1.ucgeek.co' -Type InboundCallerNumber      
        .EXAMPLE 
        Exports translations for the specified gateway:
        C:\PS> Get-TeamsTrunkTranslations -Gateway 'gateway1.ucgeek.co' -Type OutboundCallerNumber   
    #>
    
    
    $typeConverted = Get-Type $type
    $existingTrunkTranslations = (Get-CsOnlinePSTNGateway -Identity $Gateway).($typeConverted)
    $existingTrunkTranslationsCount = $existingTrunkTranslations.count
    
    #Remove translation rule from trunk
    if ($existingTrunkTranslationsCount -gt 0) {
        Write-Host "Found $existingTrunkTranslationsCount existing translations for trunk $Gateway"
        if ($existingTrunkTranslations -Contains $name) {
            Write-Host "Removing translation from gateway $name"
            $existingTrunkTranslations.Remove($name)
            $params = CsOnlinePSTNGatewayParamBuilder -gw $Gateway -type $typeConverted -translationList $existingTrunkTranslations
            Set-CsOnlinePSTNGateway @params

        } else {
            Write-Host "Skipping, $name not associated to $Gateway"

        }
    } else {
        Write-Host "No $typeConverted exist for to gateway $Gateway"
    }
}
function Get-TeamsTrunkTranslations {
    Param(
        [parameter(Mandatory=$true)] $Gateway,
        [parameter(Mandatory=$true)] [ValidateSet('InboundCallerNumber','InboundPstnNumberTranslationRules','InboundCalledNumber', 'InboundTeamsNumberTranslationRules', 'OutboundCalledNumber', 
        'OutboundPstnNumberTranslationRules', 'OutboundCallerNumber', 'OutboundTeamsNumberTranslationRules')] $Type
    )
    <#
        .SYNOPSIS
        Gets translation rules applied to Microsoft Teams PSTN gateways by type.
        .DESCRIPTION
        Gets translation rules applied to Microsoft Teams PSTN gateways by type.
        .PARAMETER Gateway
        Gateway FQDN to query.
        .OUTPUTS
        List of gateway translations for the type specified.
        .EXAMPLE 
        Exports translations for the specified gateway:
        C:\PS> Get-TeamsTrunkTranslations -Gateway 'gateway1.ucgeek.co' -Type InboundCallerNumber      
        .EXAMPLE 
        Exports translations for the specified gateway:
        C:\PS> Get-TeamsTrunkTranslations -Gateway 'gateway1.ucgeek.co' -Type OutboundCallerNumber   
    #>

    $typeConverted = Get-Type $type
    $existingTrunkTranslations = (Get-CsOnlinePSTNGateway -Identity $Gateway).($typeConverted)
    $existingTrunkTranslationsCount = $existingTrunkTranslations.count
    return Get-CsTeamsTranslationRule | where {$existingTrunkTranslations -contains $_.Identity} | Select Pattern, Translation, Identity, Description | FT
}
function Export-TeamsTrunkTranslations {
    Param(
        [parameter(Mandatory=$false)] $GatewayList=$null,
        [parameter(Mandatory=$false)] $FilePath="."
    )
    <#
        .SYNOPSIS
        Exports translation rules applied to Microsoft Teams PSTN gateways.
        .DESCRIPTION
        Exports translation rules applied to Microsoft Teams PSTN gateways.
        .PARAMETER GatewayList
        Comma seperated list of gateways (optional).
        .PARAMETER FilePath
        Path to save file e.g. C:\Temp (optional).
        .OUTPUTS
        Exports to CSV file.
        .EXAMPLE 
        Exports translations for listed gateways:
        C:\PS> Export-TeamsTrunkTranslations -GatewayList 'gateway1.ucgeek.co', 'gateway2.ucgeek.co'             
        .EXAMPLE 
        Exports translations for all gateways:
        C:\PS> Export-TeamsTrunkTranslations
    #>

    if ($GatewayList -eq $null) {
        $gateways = (Get-CsOnlinePSTNGateway).Identity
    }
    else {
        $gateways = $GatewayList
    }

    $trunkTranslations =@()
    foreach ($gw in $gateways) {
        Write-Host "Processing gateway $gw"
        $translations = (Get-CsOnlinePSTNGateway -Identity $gw) | select  Identity, InboundTeamsNumberTranslationRules, InboundPstnNumberTranslationRules, OutboundTeamsNumberTranslationRules, OutboundPstnNumberTranslationRules
        $inboundCallerTranslations = $translations | select -ExpandProperty InboundPstnNumberTranslationRules
        $inboundCalledTranslations = $translations | select -ExpandProperty InboundTeamsNumberTranslationRules    
        $outboundCalledTranslations = $translations | select -ExpandProperty OutboundPstnNumberTranslationRules    
        $outboundCallerTranslations = $translations | select -ExpandProperty OutboundTeamsNumberTranslationRules

        $i=0
        foreach ($inboundCallerTranslation in $inboundCallerTranslations) {
            $trunkTranslations += [TrunkTranslation]@{
                GatewayFqdn = $gw
                TranslationId = $inboundCallerTranslation
                Priority = ($i++)
                Type = "InboundCallerNumber"
            }
        }
        $i=0
        foreach ($inboundCalledTranslation in $inboundCalledTranslations) {
            $trunkTranslations += [TrunkTranslation]@{
                GatewayFqdn = $gw
                TranslationId = $inboundCalledTranslation
                Priority = ($i++)
                Type = "InboundCalledNumber"
            }
        }
        $i=0
        foreach ($outboundCalledTranslation in $outboundCalledTranslations) {
            $trunkTranslations += [TrunkTranslation]@{
                GatewayFqdn = $gw
                TranslationId = $outboundCalledTranslation
                Priority = ($i++)
                Type = "OutboundCalledNumber"
            }
        }
        $i=0
        foreach ($outboundCallerTranslation in $outboundCallerTranslations) {
            $trunkTranslations += [TrunkTranslation]@{
                GatewayFqdn = $gw
                TranslationId = $outboundCallerTranslation
                Priority = ($i++)
                Type = "OutboundCallerNumber"
            }
        }
    }

    Write-Host "Exporting trunk translations to $FilePath\TrunkTranslations.csv"
    $trunkTranslations | Export-Csv -Path "$FilePath\TrunkTranslations.csv" -NoTypeInformation 
    return $trunkTranslations
}
#endregion FUNCTIONS

#region RUN SCRIPT
<# STEP 1: Connect to SfBOnline
$UserName = "andrew@amorpeth.onmicrosoft.com" #Admin username for login
Import-Module SkypeOnlineConnector
$sfboSession = New-CsOnlineSession -UserName $Username
Import-PSSession $sfboSession 
Enable-CsOnlineSessionForReconnection
###>

#STEP 2: Set your variables
$gw = 'ucgeek.sbc2.voiceswitch.nz'#, 'ucgeek.sbc2.voiceswitch.nz' #Direct Routing gateway/trunk
$name = "FwdDualNumber_Andrew.Morpeth_6498926461_TO_6498926460_TEST1" #Name/identity
$description = "Fwd Dual Number - Andrew Morpeth - 6498926461 TO 6498926460" #Description
$pattern = '\+6498926461' #Regex pattern to match
$translation = '+6498926460' #Output pattern
$type = "InboundCalledNumber" #InboundPstnNumberTranslationRules/InboundCallerNumber | InboundTeamsNumberTranslationRules/InboundCalledNumber | OutboundPstnNumberTranslationRules/OutboundCalledNumber | OutboundTeamsNumberTranslationRules/OutboundCallerNumber
###
$gw = 'ucgeek.sbc2.voiceswitch.nz' #Direct Routing gateway/trunk
$name = "CLID_AKLOfficeNumber_Andrew.Morpeth_6498926461;ext=1000_TO_6498926461_TEST1" #Name/identity
$description = "CLID replacement for outbound call to Auckland Office mainline" #Description
$pattern = '\+6498926461;ext=1000' #Regex pattern to match
$translation = '+6498926461' #Output pattern
$type = "OutboundCallerNumber"
###
###
$gw = 'ucgeek.sbc2.voiceswitch.nz' #Direct Routing gateway/trunk
$name = "CLID_AKLOfficeNumber_6498926461;ext=xxxx_TO_6498926461_TEST1" #Name/identity
$description = "CLID replacement to Auckland Office mainline for non-DDI users" #Description
$pattern = '(\+6498926461);ext=\d{4}' #Regex pattern to match
$translation = '$1' #Output pattern
$type = "OutboundCallerNumber"
###

#STEP 3: Run command. Examples:
#New-TeamsTrunkTranslation -Gateway $gw -Name $name -Description $description -Pattern $pattern -Translation $translation -Type $type
#Remove-TeamsTrunkTranslation -Gateway $gw -Name $name -Type $type
#Get-TeamsTrunkTranslations -Gateway $gw -Type $type #Supports single gateway and type
#Export-TeamsTrunkTranslations -GatewayList $gw #-FilePath "D:\Temp" #Optional comma seperated list of gateways
###
#endregion RUN SCRIPT