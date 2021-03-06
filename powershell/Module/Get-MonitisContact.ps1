function Get-MonitisContact 
{
    <#
    .Synopsis
        Gets contacts from monitis
    .Description
        Gets contacts from monitis.  Contact information can be used for notifications
    .Example
        Get-MonitisContact    
    .Link
        Add-MonitisNotificationRule    
    #>
    [Cmdletbinding(DefaultParameterSetName='all')]
    param(       
    [Parameter(Mandatory=$true,ParameterSetName='Name')]
    [string]
    $Name,
    # The Monitis API key.  
    # If any command connects to Monitis, the ApiKey and SecretKey will be cached
    [string]$ApiKey,
    
    # The Monitis Secret key
    # If any command connects to Monitis, the ApiKey and SecretKey will be cached
    [string]$SecretKey
    )
    
    begin {
        $xmlHttp = New-Object -ComObject Microsoft.XMLHTTP
        Set-StrictMode -Off
    }
    
    process {
        if ($psCmdlet.ParameterSetName -eq 'Name')  {        
            $null = $psboundParameters.Remove('Name')
            Get-MonitisContact @psboundparameters | Where-Object { $_.Name -eq $name } 
        } else {                        
            #region Reconnect To Monitis
            if ($psBoundParameters.ApiKey -and $psBoundParameters.SecretKey) {
                Connect-Monitis -ApiKey $ApiKey -SecretKey $SecretKey
            } elseif ($script:ApiKey -and $script:SecretKey) {
                Connect-Monitis -ApiKey $script:ApiKey -SecretKey $script:SecretKey
            }
            
            if (-not $apiKey) { $apiKey = $script:ApiKey } 
            
            if (-not $script:AuthToken) 
            {
                Write-Error "Must connect to Monitis first.  Use Connect-Monitis to connect"
                return
            } 
            #endregion       
            $xmlHttp.Open("GET", "http://www.monitis.com/api?apikey=$ApiKey&output=xml&action=contactsList", $false)
            $xmlHttp.Send()
            $response = $xmlHttp.ResponseText
            $responseXml = $response -as [xml]
            if ($responseXml.Error) {
                Write-Error -Message $responseXml.Error
            } elseif ($responseXml.Status) {
                Write-Error -Message $responseXml.Status
            } else {
                $responseXml | 
                    Select-Xml //contact | 
                    ForEach-Object { 
                        $psObject = New-Object PSObject
                        $properties=  $psObject.psobject.properties
                        $properties.Add((New-Object Management.Automation.PSNoteProperty "Name", 
                            $_.Node.Name))
                        $properties.Add((New-Object Management.Automation.PSNoteProperty "ContactId", 
                            ($_.Node.contactId -as [int])))
                        $properties.Add((New-Object Management.Automation.PSNoteProperty "ContactType", 
                            $_.Node.ContactType))
                        $properties.Add((New-Object Management.Automation.PSNoteProperty "ContactAccount", 
                            $_.Node.contactAccount))
                        $properties.Add((New-Object Management.Automation.PSNoteProperty "TimeZone", 
                            $_.Node.timezone))
                        $isPortable = if ($_.Node.Portable -eq 'true') { $true}  else { $false}  
                        $properties.Add((New-Object Management.Automation.PSNoteProperty "IsNumberPortable", 
                            $isPortable))
                        $isActive = if ($_.Node.ActiveFlag -eq '1') { $true}  else { $false}  
                        $properties.Add((New-Object Management.Automation.PSNoteProperty "IsActive", 
                            $isActive))
                        $isPlainTextAlert = if ($_.Node.TextFlag -eq '1') { $false }  else { $true }  
                        $properties.Add((New-Object Management.Automation.PSNoteProperty "IsPlainTextAlert", 
                            $isPlainTextAlert))
                        $isConfirmed = if ($_.Node.confirmationFlag -eq '1') { $true}  else { $false}  
                        $properties.Add((New-Object Management.Automation.PSNoteProperty "IsConfirmed", 
                            $isConfirmed ))
                        $properties.Add((New-Object Management.Automation.PSNoteProperty "Country", 
                            $_.Node.Country ))
                        $psObject

                    }
                    
            }
        }
    }
} 
