$VerbosePreference = "continue"
<#
$UserName = "andrew@amorpeth.onmicrosoft.com"
#$UserName = "andrew@UCGeekElite100.onmicrosoft.com"
#SfBOnline
Import-Module SkypeOnlineConnector
$sfboSession = New-CsOnlineSession -UserName $Username
Import-PSSession $sfboSession 
Enable-CsOnlineSessionForReconnection
#>
function CsOnlinePSTNGatewayParamBuilder ($gw, $type, $translationList) {
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
    elseif($type -eq 'OutbundTeamsNumberTranslationRules') {                 
        $cmdParamBuilder.add('OutbundTeamsNumberTranslationRules', $translationList)
        return $cmdParamBuilder              
    }
    else {
        return $null
    } 
}
function New-TeamsTrunkTranslation ($gw, $name, $description, $pattern, $translation, $type) {
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



#Variables
$gw = 'ucgeek.sbc2.voiceswitch.nz'
$name = "FwdDualNumber_Andrew.Morpeth_6498926461_TO_6498926460_TEST1"
$description = "Fwd Dual Number - Andrew Morpeth - 6498926461 TO 6498926460"
$pattern = '\+6498926461'
$translation = '+6498926460'
$type = "InboundTeamsNumberTranslationRules" #InboundPstnNumberTranslationRules | InboundTeamsNumberTranslationRules | OutboundPstnNumberTranslationRules | OutbundTeamsNumberTranslationRules

New-TeamsTrunkTranslation -gw $gw -name $name -description $description -pattern $pattern -translation $translation -type $type
Remove-TeamsTrunkTranslation -gw $gw -name $name -type $type


<# TESTS & DELETES
Get-CsOnlinePSTNGateway -Identity $gw
Set-CsOnlinePSTNGateway -Identity $gw -InboundTeamsNumberTranslationRules (New-Object 'System.Collections.Generic.List[string]')
#Get-CsTeamsTranslationRule | Remove-CsTeamsTranslationRule
#>

<# OLD 
#$gw = 'ucgeeke100.sbc.voiceswitch.nz'
Get-CsOnlinePSTNGateway -Identity $gw

$InboundTeamsNumberTranslations = New-Object 'System.Collections.Generic.List[string]'
New-CsTeamsTranslationRule -Identity "FwdDualNumber_Andrew.Morpeth_6498926461_TO_6498926460_TEST1" -Pattern '\+6498926461' -Translation '+6498926460' -Description "Fwd Dual Number - Andrew Morpeth - 6498926461 TO 6498926460"| Out-Null
$InboundTeamsNumberTranslations.Add("FwdDualNumber_Andrew.Morpeth_6498926461_TO_6498926460_TEST1")
#$InboundTeamsNumberTranslations.Add((New-CsTeamsTranslationRule -Identity "FwdDualNumber_Andrew.Morpeth_6498926461_TO_6498926460_TEST1" -Pattern '\+6498926461' -Translation '+6498926460' -Description "Fwd Dual Number - Andrew Morpeth - 6498926461 TO 6498926460"))

#>

<# KEN's
#Create Teams Translations
Write-Host 'Creating outbound translation rules'
$OutboundTeamsNumberTranslations = New-Object 'System.Collections.Generic.List[string]'
$OutboundPSTNNumberTranslations = New-Object 'System.Collections.Generic.List[string]'
New-CsTeamsTranslationRule -Identity "NZ-Auckland-AllCalls" -Pattern '<REGEX>' -Translation '+$1$2' -Description "ABC"| Out-Null
$OutboundTeamsNumberTranslations.Add("NZ-Auckland-AllCalls")

Write-Host 'Adding translation rules to PSTN gateways'
ForEach ($PSTNGW in $PSTNGWList) {
	Set-CsOnlinePSTNGateway -Identity $PSTNGW.Identity -OutboundTeamsNumberTranslationRules $OutboundTeamsNumberTranslations -OutboundPstnNumberTranslationRules $OutboundPSTNNumberTranslations -ErrorAction SilentlyContinue
}

#Wipe all custom dial plans
Get-CsTenantDialPlan | Remove-CsTenantDialPlan
Get-CsOnlineVoiceRoute | Remove-CsOnlineVoiceRoute
Get-CsOnlineVoiceRoutingPolicy | Remove-CsOnlineVoiceRoutingPolicy
Set-CsOnlinePstnUsage Global -Usage $NULL
$GWList = Get-CsOnlinePSTNGateway
ForEach ($GW in $GWList) { Set-CsOnlinePSTNGateway -Identity $GW.FQDN -OutboundTeamsNumberTranslationRules $NULL -OutboundPSTNNumberTranslationRules $NULL -InboundTeamsNumberTranslationRules $NULL -InboundPSTNNumberTranslationRules $NULL }
Get-CsTeamsTranslationRule | Remove-CsTeamsTranslationRule 

#>