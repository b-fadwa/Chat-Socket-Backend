Class constructor($winRef : Integer)
	
	This:C1470.countClient:=0
	This:C1470.winRef:=$winRef
	//This.connection:=New object()
	
	/// Function called when the server starts
Function onOpen($wss : Object; $param : Object)
	This:C1470.logFile("*** Server started")
	
/*Function called each time a new user log in
 In this example, we accept all the connections */
	
Function onConnection($wss : Object; $param : Object) : Object
	This:C1470.logFile("*** New connection request from: "+$param.request.remoteAddress)
	//var $test:=$param.request.headers[Sec-WebSocket-Extensions]
	//TRACE
	//This.connection:=$wss
	Use (Session:C1714.storage)
		//ngrok case tempo fix
		If (Not:C34(Undefined:C82(Session:C1714.storage.socketClients)) && (Session:C1714.storage.socketClients.find(Formula:C1597($1.value=$param.request.headers.Host))#Null:C1517) && (Position:C15("ngrok-free.app"; $param.request.headers.Host)>0))
			$wss.handler.countClient+=1
		End if 
		If (Not:C34(Undefined:C82(Session:C1714.storage.socketClients)) && (Session:C1714.storage.socketClients.length#0) && (Session:C1714.storage.socketClients.find(Formula:C1597($1.value=$param.request.headers.Host))=Null:C1517))
			Session:C1714.storage.socketClients.push($param.request.headers.Host)
			$wss.handler.countClient+=1
		End if 
		If ((Undefined:C82(Session:C1714.storage.socketClients)) || (Session:C1714.storage.socketClients.length=0))  //first connection ever
			Session:C1714.storage.socketClients:=New shared collection:C1527()
			Session:C1714.storage.socketClients.push($param.request.headers.Host)
			$wss.handler.countClient+=1
		End if 
	End use 
	return cs:C1710.WSClientHandler.new($wss.handler.countClient; $param.request)
	
	/// Function called when the server closes
Function onTerminate
	TRACE:C157  //not executed when the client is disconnected?
	//This.countClient-=1 not working
	This:C1470.connection.handler.countClient-=1
	This:C1470.logFile("*** Server closed")
	ALERT:C41("Server closed")
	
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