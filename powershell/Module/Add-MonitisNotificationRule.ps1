function Add-MonitisNotificationRule
{
    <#
    .Synopsis
        Adds a notification rule to monitis
    .Description
        Adds a notification rule to monitis.  Notification rules connect custom monitors
        with contacts to follow up on them.
    .Link
        Get-MonitisContact
    #>
    param(
    # The name of the monitor to remove.
    [Parameter(Mandatory=$true,        
        ParameterSetName='Name')]
    [string]$Name,
    
    # The testID of the monitor
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        ParameterSetName='TestId')]
    [Alias('MonitisTestId')]    
    [int[]]$TestId,  
    
    # The Monitis API key.  
    # If any command connects to Monitis, the ApiKey and SecretKey will be cached    
    [string]$ApiKey,
    
    # The Monitis Secret key.  
    # If any command connects to Monitis, the ApiKey and SecretKey will be cached    

    [string]$SecretKey,    
    [DayOfWeek]$StartDayOfWeek,
    [DayOfWeek]$EndDayOfWeek,
    [Datetime]$StartTime,
    [Datetime]$EndTime,
    [string]$ContactId,       
    [string]$ContactGroup,
    [switch]$SendDailyReport,    
    [int]$FailureCount = 1,
    [switch]$NotifyWhenBackup,
    [switch]$ContinuousAlert,
    
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    [string]$TriggerParameter,
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    [string]$TriggerValue,
    [switch]$TriggerOnLessThan,
    [switch]$TriggerOnGreaterThan
    )
    
    begin {
        Set-StrictMode -Off
        $xmlHttp = New-Object -ComObject Microsoft.XMLHTTP
    }
    process {
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
        
        if (-not $psboundParameters.timeZone) {
            $timeZone = [Timezone]::CurrentTimeZone.GetUtcOffset((Get-Date)).TotalMinutes
        }   
        $xmlHttp.Open("POST", "http://www.monitis.com/api", $false)
        $xmlHttp.SetRequestHeader("Content-Type","application/x-www-form-urlencoded")
        
        $order = 'apiKey', 'authToken', 'validation', 'timestamp', 'output', 
            'version', 'action', 'monitorId', 'period', 'weekdayFrom', 'weekdayTo',
            'timeFrom','timeTo', 'contactGroup', 'contactId',
            'notifyBackup','continuousAlerts','failureCount', 
            'monitorType','paramName','paramValue', 'comparingMethod'
            
        $contactType =  switch ($accountType) {
            "Email" { 1 }
            "SMS" {2}
            "ICQ" { 3}
            "Google" { 7}
            "Twitter" { 8 }
            "Phone" { 9 }
            "SmsAndPhone" { 10 }
            "Url" {  11 }         
        }
        
        if ($psBoundParameters.startTime -and $psBoundParameters.endTime) {
            if ($psBoundParameters.weekdayFrom -and $psBoundParameters.weekDayTo) {
                $period = "specifiedDays"
            } else {
                $period = "specifiedTime"
            }
        } else {
            $period = "always"
        }
        
        $comparingMethod = if ($triggerOnLessThan) {
            "less"
        } elseif ($triggerOnGreaterThan) {
            "greater"
        } else {
            "equals"
        }
        
        $postFields = @{
            apiKey = $script:ApiKey
            authToken = $script:AuthToken
            validation = "token"
            timestamp = (Get-Date).ToUniversalTime().ToString("s").Replace("T", " ")
            output = "xml"
            version = "2"            
            action = "addNotificationRule"
            monitorId = $TestId
            period = $period
            notifyBackup = if ($NotifyWhenBackup) { 1} else { 0 }
            continuousAlerts = if ($ContinuousAlert) { "1"} else { "0" } 
            failureCount = $failureCount
            monitorType = "custom"
            paramName = $TriggerParameter
            paramValue = $TriggerValue
            comparingMethod = $comparingMethod
        }
        
        if ($contactId) {
            $postFields.contactId= $contactId
        }
        
        if ($startTime -and $endTime) {
            $postfields.timeFrom = $startTime.ToString("hh:mm:ss")
            $postfields.timeTo = $endTime.ToString("hh:mm:ss")
            if ($psBoundParameters.weekdayFrom -and $psBoundParameters.weekDayTo) {
                $postfields.weekdayFrom = [int]$weekDayFrom
                $postfields.weekdayTo = [int]$weekDayTo
            }
        }      
                                                
        $postData =  New-Object Text.Stringbuilder
        foreach ($kv in $order) {
            if ($postfields.Contains($kv)) {
                $null = $postData.Append("$($kv)=$($postFields[$kv])&")
            }
        }
        $postData = "$postData".TrimEnd("&")
        
        $xmlHttp.Send($postData)        
        $response = $xmlHttp.ResponseText
        $responseXml = $response -as [xml]
        if ($responseXml.Error) {
            Write-Error -Message $responseXml.Error
        } elseif ($responseXml.Result.Status -and $responseXml.Result.Status -ne "OK") {
            Write-Error -Message $responseXml.Result.Status
        }
        
    }
} 
