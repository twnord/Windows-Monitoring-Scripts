function Get-MonitisCustomMonitor 
{
    <#
    .Synopsis
        Gets custom monitors from Monitis
    .Description
        Gets custom monitors from Monitis.  Custom Monitors let you monitor anything.
    .Example
        Get-MonitisCustomMonitor    
    .Link
        Add-MonitisCustomMonitor
    .Link
        Remove-MonitisCustomMonitor
    #>
    [Cmdletbinding(DefaultParameterSetName='all')]
    param(       
    [Parameter(Mandatory=$true,ParameterSetName='Name')]
    [string]
    $Name,
    # The ID of the monitor to remove
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        ParameterSetName='TestId')]
    [Alias('MonitisTestId')]    
    [int[]]$TestId,     
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
            Get-MonitisCustomMonitor @psboundparameters | 
                Where-Object { $_.Name -eq $name } |
                Get-MonitisCustomMonitor 
        } elseif ($psCmdlet.ParameterSetName -eq 'TestId') {
            $null = $psboundParameters.Remove('TestId')
            Get-MonitisCustomMonitor @psboundparameters | 
            Where-Object { 
                $_.MonitisTestId -eq $testId
            } |
            ForEach-Object {
                $xmlHttp.Open("GET", "http://www.monitis.com/customMonitorApi?apikey=$script:ApiKey&output=xml&action=getMonitorInfo&monitorId=$($_.MonitisTestId)", $false)
                $xmlHttp.Send() 
                
                $response = $xmlHttp.ResponseText
                $responseXml = $response -as [xml]
                if ($responseXml.Error) {
                    Write-Error -Message $responseXml.Error
                } elseif ($responseXml.Status) {
                    Write-Error -Message $responseXml.Status
                } else {
                    $responseXml | 
                        Select-Xml //monitor | 
                        ForEach-Object { 
                            New-Object PSObject -Property @{
                                MonitisTestId = $_.Node.Id
                                Name = $_.Node.Tag
                                SystemName = $_.Node.Name
                                ParameterName = @($_.Node.ResultParams | Select-Object -ExpandProperty Item | Select-Object -ExpandProperty name)
                                ParameterType = @($_.Node.ResultParams | Select-Object -ExpandProperty Item | ForEach-Object {
                                    if ($_.dataType -eq 1) {
                                        [bool]
                                    } elseif ($_.dataType -eq 2) {
                                        [int]
                                    } elseif ($_.dataType -eq 3) {
                                        [string]
                                    } elseif ($_.dataType -eq 4) {
                                        [float]
                                    }
                                })
                            }
                        }
                }
            }        
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
            $xmlHttp.Open("GET", "http://www.monitis.com/customMonitorApi?apikey=$ApiKey&output=xml&action=getMonitors", $false)
            $xmlHttp.Send()
            $response = $xmlHttp.ResponseText
            $responseXml = $response -as [xml]
            if ($responseXml.Error) {
                Write-Error -Message $responseXml.Error
            } elseif ($responseXml.Status) {
                Write-Error -Message $responseXml.Status
            } else {
                $responseXml | 
                    Select-Xml //monitor | 
                    ForEach-Object { 
                        New-Object PSObject -Property @{
                            MonitisTestId = $_.Node.Id
                            Name = $_.Node.Tag
                            SystemName = $_.Node.InnerText
                            Type = $_.Node.Type
                        }
                    }
            }
        }
    }
} 
