dim tag,name, FullresultParams,objxmlDoc,objName,objTag,rootfolder,Root,NodeList,nodeVal,res,objtype,monitorType,filesysObj

rootfolder = left(WScript.ScriptFullName,(Len(WScript.ScriptFullName))-(len(WScript.ScriptName)))
set objxmlDoc = CreateObject("Microsoft.XMLDOM")
objxmlDoc.async="false"

'Your API key and Secret Key from XML
set xmlDoc=CreateObject("Microsoft.XMLDOM")
xmlDoc.async="false"
xmlDoc.load(rootfolder & "ApiKey.xml")
apiKey = xmlDoc.GetElementsByTagName("ApiKey").item(0).text
secretKey = xmlDoc.GetElementsByTagName("SecretKey").item(0).text

'Finds current timezone to obtain GMT date 
dtGMT = GMTDate()
unixDate = CStr(DateDiff("s", "01/01/1970 00:00:00", DateSerial(Year(dtGMT), Month(dtGMT), Day(dtGMT)) + TimeSerial(Hour(dtGMT), Minute(dtGMT), Second(dtGMT)))) + "000"

'Initialize HTTP connection object
Set objHTTP = CreateObject("Microsoft.XMLHTTP")

'Request a token to use in following calls
url = "http://www.monitis.com/api?action=authToken&apikey=" + apiKey + "&secretkey=" + secretKey
objHTTP.open "GET", url, False
objHTTP.send
resp = objHTTP.responseText
token = DissectStr(resp, "authToken"":""", """")

'---------------------------------------------------------------------
xmlDoc.load(rootfolder & "metrics.xml")
Set Root = xmlDoc.documentElement 
Set NodeList = Root.selectsingleNode("/Monitor")  
'Add new monitor in Monitis server and push data

For Each Elem In NodeList.childnodes 
	nodeVal = Elem.nodename
	
	set monitorID = xmlDoc.documentElement.selectSingleNode("//"& nodeVal & "/monitorID")
	
		'Get Tag,name and host name form XML
		set objName = xmlDoc.documentElement.selectSingleNode("//"& nodeVal & "/properties/Name")
		name = objName.text
		set objTag = xmlDoc.documentElement.selectSingleNode("//" & nodeVal & "/properties/Tag")
		tag = objTag.text
		set objHost = xmlDoc.documentElement.selectSingleNode("//" & nodeVal & "/properties/HostName")
		computer = objHost.text
		set objtype = xmlDoc.documentElement.selectSingleNode("//" & nodeVal & "/properties/Type")
		monitorType = objtype.text  
		'Get monitor ID from XXL
		
'-------------------------------------------------------------------------------------------------------
		'Requests the monitor list so we can find the MonitorID of each printer monitor on the dashboard page
		url = "http://www.monitis.com/customMonitorApi?action=getMonitors&apikey=" + apiKey + "&tag=" + tag + "&output=xml"
		objHTTP.open "GET", url, False
		objHTTP.send
		resp = objHTTP.responseText
		Set objResponse = CreateObject("Microsoft.XMLDOM")
		objResponse.async = False
		objResponse.LoadXML(resp)
		'WMI status checking
		on error resume next
			Set oWMI = GetObject("WINMGMTS:\\" & computer & "\ROOT\cimv2")
			if  Err.Number <> 0  then
				computer = MsgBox ("Unable connect to the host")
				Err.Clear
			else
			'if Monitor ID doesn't exeists create new monitor and push data
			if monitorID.text = 0 then
				MsgBox "Creating new " + nodeVal + " monitor..."
				AddCustMon
				'Requests the monitor list so we can find the MonitorID of each printer monitor on the dashboard page
				url = "http://www.monitis.com/customMonitorApi?action=getMonitors&apikey=" + apiKey + "&tag=" + tag + "&output=xml"
				objHTTP.open "GET", url, False
				objHTTP.send
				resp = objHTTP.responseText
				Set objResponse = CreateObject("Microsoft.XMLDOM")
				objResponse.async = False
				objResponse.LoadXML(resp)
				res = GetNetworkData
				AddResult
				'Save monitor ID in XML
				monitorID.text = FindMonitorID(name)
				xmlDoc.save(rootfolder & "metrics.xml")
				'if monitor ID exeists only push data
			else  
				res = GetNetworkData
				AddResult
			end if
		end if
	
	xmlDoc.load(rootfolder & "metrics.xml")
Next
'---------------------------------------------------------------------
'Create custom monitor in dashboard
Function AddCustMon
FullresultParams = ""
objxmlDoc.load(rootfolder & "metrics.xml")
dim j,objChild,root,node
set classnodes = objxmlDoc.documentElement.selectNodes("//" & nodeVal &"/metrics/metric")
for i = 0 to (classnodes.length)-1
	if classnodes.item(i).text = "true" then
		FullresultParams = FullresultParams + classnodes.item(i).getAttribute("resultParams")
	end if
next

url = "http://www.monitis.com/customMonitorApi"
objHTTP.open "POST", url, False
objHTTP.setRequestHeader "Content-Type", "application/x-www-form-urlencoded"
postData = "apikey=" + apiKey + "&validation=token&authToken=" + token + "&timestamp=" + FmtDate(dtGMT) + "&action=addMonitor&resultParams=" + FullresultParams + "&name=" + name + "&tag=" + tag + "&type=" + monitorType
objHTTP.send postData
resp = objHTTP.responseText
End Function

'Create results for pushing data
Function GetNetworkData
dim node
node = "//"& nodeVal &"/metrics/metric"
objxmlDoc.load(rootfolder & "metrics.xml")
set metName = objxmlDoc.documentElement.selectNodes(node)
fullResult = ""
results = ""
dim s 			
for j = 0 to (metName.Length)-1 
	s = Left(metName.item(j).getAttribute("resultParams"),InStr(metName.item(j).getAttribute("resultParams"), ":"))
	if metName.item(j).text = "true" then
		Set oRes = oWMI.ExecQuery ("select * from " & metName.item(j).getAttribute("WMIclass"))
		if oRes.Count <> 0 then
			For each oEntry in oRes
				value = oEntry.Properties_(metName.item(j).getAttribute("methodName"))
			next 
		else
			value = "Absent"
		end if

		results = s & value & ";"
		fullResult =  fullResult & results
	end if
next
GetNetworkData =  fullResult
End Function

'add results in dashboard
Sub AddResult
url = "http://www.monitis.com/customMonitorApi"
action = "addResult"
objHTTP.open "POST", url, False
objHTTP.setRequestHeader "Content-Type", "application/x-www-form-urlencoded"
postData = "apikey=" + apiKey + "&validation=token&authToken=" + token + "&timestamp=" + FmtDate(dtGMT) + "&action=" + action + "&monitorId=" + monitorID.text + "&checktime=" + UnixDate + "&results=" + res
objHTTP.send postData
resp = objHTTP.responseText
End Sub

'find monitor ID from XML
Function FindMonitorID(monName)
For Each objNode in objResponse.documentElement.childnodes
	If objNode.selectSingleNode("name").text = monName Then
		FindMonitorID = objNode.selectSingleNode("id").text
		Exit For
	End If
Next
End Function

'------------------------------------------------------------------
Function DissectStr(cString, cStart, cEnd)
'Generic string manipulation function to extract value from JSON output
  dim nStart, nEnd
  nStart = InStr(cString, cStart)
  if nStart = 0 then 
    DissectStr = ""
  else
    nStart = nStart + len(cStart)
    if cEnd = "" then
      nEnd = len(cString)
    else
      nEnd = InStr(nStart, cString, cEnd)
      if nEnd = 0 then nEnd = nStart else nEnd = nEnd - nStart
    end if
    DissectStr = mid(cString, nStart, nEnd)
  end if
End Function
'---------------------------------------------------------------------
'Set date and time
Function FmtDate(dt)
FmtDate = cstr(Datepart("yyyy", dt)) + "-" + right("0" + cstr(Datepart("m", dt)),2) + "-" +  right("0" + cstr(Datepart ("d", dt)),2) + " " + right("0" + cstr(Datepart("h", dt)),2) + ":" + right("0" + cstr(Datepart("n", dt)),2) + ":" + right("0" + cstr(Datepart("S", dt)),2)
end function

'---------------------------------------------------------------------
'Get date and time from WMI
Function GMTDate()
dim oWMI, oRes, oEntry
Set oWMI = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
GMTDate = now
Set oRes = oWMI.ExecQuery("Select LocalDateTime from Win32_OperatingSystem")
For each oEntry in oRes
	GMTDate = DateAdd("n", -CInt(right(oEntry.LocalDateTime, 4)), GMTDate)
next
End function