' Create an HTTP object
myURL = "https://github.com/msys2/msys2-installer/releases/download/2022-03-19/msys2-x86_64-20220319.exe"
Set objHTTP = CreateObject( "WinHttp.WinHttpRequest.5.1" )
Set FSO = CreateObject("Scripting.FileSystemObject")
scriptPath = FSO.GetParentFolderName(WScript.ScriptFullName)
target = FSO.BuildPath(scriptPath, "msys2-x86_64-20220319.exe")

' Download the specified URL
objHTTP.Open "GET", myURL, False
objHTTP.Send
intStatus = objHTTP.Status

If intStatus = 200 Then
  WScript.Echo " " & intStatus & " A OK " +myURL
Else
  WScript.Echo "OOPS" +myURL
End If

Set adoStream = CreateObject("ADODB.Stream")
adoStream.Open
adoStream.Type = 1
adoStream.Write objHTTP.ResponseBody
adoStream.Position = 0
Set fileSystem = CreateObject("Scripting.FileSystemObject")
If fileSystem.FileExists(target) Then fileSystem.DeleteFile target
adoStream.SaveToFile target
adoStream.Close

