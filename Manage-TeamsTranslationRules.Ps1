$VerbosePreference = "continue"
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
    $type = Get-Type $type
    
    $cmdParamBuilder = @{            
        Identity = $gw        
    }
    if($type -eq 'InboundPstnNumberTranslationRules') {                 
        $cmdParamBuilder.add('InboundPstnNumberTranslationRules', $translationList)
        return $cmdParamBuilder            
    } 
    elseif($type -eq 'InboundTeamsNumberTranslationRules') {                 
        $cmdParamBuilder.add('InboundTeamsNumberTranslationRules', $translationList)  
        return $cmdParamBuilder            
    } 
    elseif($type -eq 'OutboundPstnNumberTranslationRules') {                 
        $cmdParamBuilder.add('OutboundPstnNumberTranslationRules', $translationList)  
        return $cmdParamBuilder            
    }
    elseif($type -eq 'OutboundTeamsNumberTranslationRules') {                 
        $cmdParamBuilder.add('OutboundTeamsNumberTranslationRules', $translationList)
        return $cmdParamBuilder              
    }
    else {
        return $null
    } 
}

function New-TeamsTrunkTranslation ($gw, $name, $description, $pattern, $translation, $type) {
    $type = Get-Type $type
    $existingTrunkTranslations = (Get-CsOnlinePSTNGateway -Identity $gw).($type)
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
        Write-Host "Found $existingTrunkTranslationsCount existing translations for trunk $gw"
        if ($existingTrunkTranslations -Contains $name) {
            Write-Host "Skipping, already exists."
        } else {
             Write-Host "Adding translation to gateway $name"
             $existingTrunkTranslations.Add($name)
             $params = CsOnlinePSTNGatewayParamBuilder -gw $gw -type $type -translationList $existingTrunkTranslations
             Set-CsOnlinePSTNGateway @params
        }
    } else {
        Write-Host "Adding 1st translation to gateway $name"
        $newTranslationList = New-Object 'System.Collections.Generic.List[string]'
        $newTranslationList.Add($name)
        $params = CsOnlinePSTNGatewayParamBuilder -gw $gw -type $type -translationList $newTranslationList
        Set-CsOnlinePSTNGateway @params
    }
}

function Remove-TeamsTrunkTranslation ($gw, $name, $type) {
    $type = Get-Type $type
    $existingTrunkTranslations = (Get-CsOnlinePSTNGateway -Identity $gw).($type)
    $existingTrunkTranslationsCount = $existingTrunkTranslations.count
    
    #Remove translation rule from trunk
    if ($existingTrunkTranslationsCount -gt 0) {
        Write-Host "Found $existingTrunkTranslationsCount existing translations for trunk $gw"
        if ($existingTrunkTranslations -Contains $name) {
            Write-Host "Removing translation from gateway $name"
            $existingTrunkTranslations.Remove($name)
            $params = CsOnlinePSTNGatewayParamBuilder -gw $gw -type $type -translationList $existingTrunkTranslations
            Set-CsOnlinePSTNGateway @params

        } else {
            Write-Host "Skipping, $name not associated to $gw"

        }
    } else {
        Write-Host "No $type exist for to gateway $gw"
    }
}
function Get-TeamsTrunkTranslations ($gw, $type) {
    $type = Get-Type $type
    $existingTrunkTranslations = (Get-CsOnlinePSTNGateway -Identity $gw).($type)
    $existingTrunkTranslationsCount = $existingTrunkTranslations.count
    return Get-CsTeamsTranslationRule | where {$existingTrunkTranslations -contains $_.Identity} | Select Pattern, Translation, Identity, Description | FT
}

class TrunkTranslation {
    $GatewayFqdn
    $TranslationId
    $Priority
    $Type
}

function Export-TeamsTrunkTranslations ($GatewayList=$null) {
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
                $Priority = ($i++)
                Type = "OutboundCallerNumber"
            }
        }
    }
    return $trunkTranslations
}

#endregion FUNCTIONS

#region RUN SCRIPT
<# STEP 1: Connect to SfBOnline
Import-Module SkypeOnlineConnector
$sfboSession = New-CsOnlineSession -UserName $Username
Import-PSSession $sfboSession 
Enable-CsOnlineSessionForReconnection
###>

#STEP 2: Set your variables
$UserName = "andrew@amorpeth.onmicrosoft.com" #Admin username for login
$gw = 'ucgeek.sbc2.voiceswitch.nz', 'ucgeek.sbc2.voiceswitch.nz' #Direct Routing gateway/trunk
$name = "FwdDualNumber_Andrew.Morpeth_6498926461_TO_6498926460_TEST1" #Name/identity
$description = "Fwd Dual Number - Andrew Morpeth - 6498926461 TO 6498926460" #Description
$pattern = '\+6498926461' #Regex pattern to match
$translation = '+6498926460' #Output pattern
$type = "InboundCalledNumber" #InboundPstnNumberTranslationRules/InboundCallerNumber | InboundTeamsNumberTranslationRules/InboundCalledNumber | OutboundPstnNumberTranslationRules/OutboundCalledNumber | OutboundTeamsNumberTranslationRules/OutboundCallerNumber
###

#STEP 3: Run command. Examples:
#New-TeamsTrunkTranslation -gw $gw -name $name -description $description -pattern $pattern -translation $translation -type $type
#Remove-TeamsTrunkTranslation -gw $gw -name $name -type $type
#Get-TeamsTrunkTranslations -gw $gw -type $type
Export-TeamsTrunkTranslations
###
#endregion RUN SCRIPT

#region TESTS & DELETES
<#
Get-CsOnlinePSTNGateway -Identity $gw
Set-CsOnlinePSTNGateway -Identity $gw -InboundTeamsNumberTranslationRules (New-Object 'System.Collections.Generic.List[string]')
Get-CsTeamsTranslationRule | Remove-CsTeamsTranslationRule
#>
#endregion TESTS & DELETES