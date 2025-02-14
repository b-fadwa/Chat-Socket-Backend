Class constructor($countClient : Integer; $request : Object)
	/// Class that defines a connection behavior 
	// Creates the user name that appear in conversation
	This:C1470.name:="Client"+String:C10($countClient)
	// Stores the remote address
	This:C1470.address:=$request.remoteAddress
	This:C1470.connectedUser:=$request.headers.Host
	
	//will be used to format data
Function formatData($message : cs:C1710.MessagesEntity) : Object
	var $formattedData : Object:=New object:C1471()
	//TRACE
	If (($message.Audio#Null:C1517) && (BLOB size:C605($message.Audio)>0))
		$formattedData.audioBase64:=BLOB to text:C555($message.Audio; Base64 encoding)
	Else 
		$formattedData.audioBase64:=""  // Handle missing audio
	End if 
	If (($message.Image#Null:C1517) && (BLOB size:C605($message.Image)>0))
		$formattedData.imageBase64:=BLOB to text:C555($message.Image; Base64 encoding)
	Else 
		$formattedData.imageBase64:=""  // Handle missing image
	End if 
	If (($message.File#Null:C1517) && (BLOB size:C605($message.File)>0))
		$formattedData.fileBase64:=BLOB to text:C555($message.File; Base64 encoding)
	Else 
		$formattedData.fileBase64:=""  // Handle missing file
	End if 
	return $formattedData
	
	//Defines a connection behavior
Function onOpen($ws : 4D:C1709.WebSocketConnection; $info : Object)
	var $client : Object
	var $message : cs:C1710.MessagesEntity
	var $data; $status : Object
	//var $conversation : cs.ConversationEntity
	//var $conversations : cs.ConversationSelection:=ds.Conversation.all()
	var $messages : cs:C1710.MessagesSelection:=ds:C1482.Messages.all()  //.query("Sender = :1 and Receiver = :2";)
	$ws.wss.handler.logFile("New client connected: "+This:C1470.name+" - "+This:C1470.address)
	
	//For each ($conversation; $conversations)
	//$ws.send(JSON Stringify({conversation: $conversation.toObject(); convoMessages: $conversation.messages.toCollection()})+"\n")
	//End for each 
	//For each ($client; $ws.wss.connections)
	//If ($client.id#$ws.id)
	For each ($message; $messages)
		$data:=This:C1470.formatData($message)
		//update the sender and receiver to cs classes here
		$ws.send(JSON Stringify:C1217({sender: $message.Sender; receiver: $message.Receiver; \
			conversation: $message.conversation.toObject(); content: $message.Content; image: $data.imageBase64; audio: $data.audioBase64; file: $data.fileBase64; \
			poll: $message.Poll; dateStamp: String:C10($message.sentThe; ISO date GMT:K1:10; Time:C179($message.sentAt))})+"\n")
	End for each 
	////End if 
	//End for each 
	
Function onMessage($ws : Object; $info : Object)
	var $client : Object
	var $message : cs:C1710.MessagesEntity
	var $data : Variant
	var $formattedData : Object
	var $sender; $receiver : cs:C1710.UserEntity
	var $senders; $receivers : cs:C1710.UserSelection
	var $conversation : cs:C1710.ConversationEntity
	var $conversations : cs:C1710.ConversationSelection
	var $conversationMember : cs:C1710.ConversationMemberEntity
	var $conversationMembers : cs:C1710.ConversationMemberSelection
	SET BLOB SIZE:C606(vxBlob; 0)
	For each ($client; $ws.wss.connections)
		$message:=ds:C1482.Messages.new()
		$message.ReceiverAddr:=$client.handler.address
		$message.SenderAddr:=This:C1470.address
		$message.sentThe:=Current date:C33
		$message.sentAt:=Current time:C178
		$message.Sender:=This:C1470.name
		$message.Receiver:=$client.handler.name
		Try
			$data:=JSON Parse:C1218($info.data)
		Catch
			$data:={content: $info.data}
		End try
		Case of 
			: (String:C10($data.content)#"" && Not:C34(Undefined:C82($data.content)))
				$message.Content:=$data.content
			: ($data.image#"" && Not:C34(Undefined:C82($data.image)))
				TEXT TO BLOB:C554($data.image; vxBlob)
				$message.Image:=vxBlob
			: ($data.file#"" && Not:C34(Undefined:C82($data.file)))
				TEXT TO BLOB:C554($data.file; vxBlob)
				$message.File:=vxBlob
			: ($data.audio#"" && Not:C34(Undefined:C82($data.audio)))
				TEXT TO BLOB:C554($data.audio; vxBlob; UTF8 C string:K22:15)
				$message.Audio:=vxBlob
		End case 
		TRACE:C157
		//case when sender and receiver do not exist
		$sender:=ds:C1482.User.query("firstName = :1"; This:C1470.name).first()
		If ($sender=Null:C1517)
			$sender:=ds:C1482.User.new()
			$sender.firstName:=This:C1470.name
			$sender.uniqueIP:=This:C1470.connectedUser
			$sender.save()
		End if 
		$receiver:=ds:C1482.User.query("firstName = :1"; $client.handler.name).first()
		If ($receiver=Null:C1517)
			$receiver:=ds:C1482.User.new()
			$receiver.firstName:=$client.handler.name
			$receiver.uniqueIP:=This:C1470.connectedUser
			$receiver.save()
		End if 
		$conversations:=$sender.conversationMembers.conversation.and($receiver.conversationMembers.conversation)
		If ($conversations.length>0)
			$conversation:=$conversations.first()
		Else 
			//new conversation
			$conversation:=ds:C1482.Conversation.new()
			$conversation.save()
			//2 new conversatiomemberships
			//sender membership
			$conversationMember:=ds:C1482.ConversationMember.new()
			$conversationMember.ConversationID:=$conversation.ID
			$conversationMember.UserID:=$sender.ID
			$conversationMember.save()
			//receiver membership
			$conversationMember:=ds:C1482.ConversationMember.new()
			$conversationMember.ConversationID:=$conversation.ID
			$conversationMember.UserID:=$receiver.ID
			$conversationMember.save()
		End if 
		$message.conversationID:=$conversation.ID
		$message.senderUser:=$sender.ID
		$message.receiverUser:=$receiver.ID
		//case when the conversationmember does not exist
		//more then once connection -> do not save the message for the same client as sender and receiver
		If (($ws.wss.connections.length>1) && (This:C1470.name#$client.handler.name))
			$status:=$message.save()
		End if 
		//one connection
		If ($ws.wss.connections.length=1)
			$status:=$message.save()
			$formattedData:=This:C1470.formatData($message)
		End if 
		$formattedData:=This:C1470.formatData($message)
		$client.send(JSON Stringify:C1217({sender: $message.Sender; receiver: $message.Receiver; \
			conversation: $message.conversation.toObject(); content: $message.Content; image: $data.imageBase64; audio: $data.audioBase64; file: $data.fileBase64; dateStamp: String:C10($message.sentThe; ISO date GMT:K1:10; Time:C179($message.sentAt))})+"\n")
	End for each 
	
	// Called when an error occured
Function onError($ws : Object; $info : Object)
	$ws.wss.handler.logFile("*** Error: "+This:C1470.name+" - "+This:C1470.address+" - "+JSON Stringify:C1217($info))
	
	// Called when the session is closed
Function onTerminate($ws : Object; $info : Object)
	var $client : Object
	//TRACE
	$ws.wss.handler.logFile("Connection closed: "+This:C1470.name+" - "+String:C10(This:C1470.address)+" - code: "+String:C10($info.code)+" "+String:C10($info.reason))
	// resend the message "new client connected" to all clients
	For each ($client; $ws.wss.connections)
		If ($client.id#$ws.id)
			$client.send(JSON Stringify:C1217({content: String:C10(This:C1470.name)+" disconnected!"}))
		End if 
		//remove the user and decrement count in wshandler
		Use (Session:C1714.storage)
			//Session.storage.socketClients.remove(This.address)
			//$ws.wss.handler.countClient-=1
		End use 
	End for each 
	