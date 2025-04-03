singleton Class constructor()
	
	/// Function called when the server starts
Function onOpen($wss : Object; $param : Object)
	This:C1470.logFile("*** Server started")
	
	
Function onConnection($wss : Object; $param : Object) : Object
	This:C1470.logFile("*** New connection request from: "+$param.request.remoteAddress)
	$connectedUser:=ds:C1482.User.login($param.request.query.userName)
	return cs:C1710.WSClientHandler.new($connectedUser)
	
	/// Function called when the server closes
Function onTerminate
	This:C1470.logFile("*** Server closed")
	
	/// Function called when the an error occured
Function onError($wss : Object; $param : Object)
	This:C1470.logFile("!!! Server error: "+$param.statusText)
	
	/// Write information in the log file
Function logFile($log : Text)
	var $text : Text
	var $doc : Object
	$doc:=Folder:C1567(fk logs folder:K87:17).file("websocket.log")
	$text:=$doc.exists ? Document to text:C1236($doc.platformPath) : ""
	TEXT TO DOCUMENT:C1237($doc.platformPath; $text+"\r"+String:C10(Timestamp:C1445)+"   "+$log)