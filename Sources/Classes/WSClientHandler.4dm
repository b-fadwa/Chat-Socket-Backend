Class constructor($countClient : Integer; $request : Object; $user : cs:C1710.UserEntity)
	
	This:C1470.name:="Client"+String:C10($countClient)
	This:C1470.address:=$request.remoteAddress
	This:C1470.connectedUser:=$request.headers.Host
	This:C1470.currentUser:=$user
	
	//will be used to format data
Function formatData($message : cs:C1710.MessagesEntity) : Object
	var $formattedData : Object:=New object:C1471()
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
	var $users : cs:C1710.UserSelection:=ds:C1482.User.all()
	var $groups : cs:C1710.GroupSelection:=ds:C1482.Group.all()
	var $message : cs:C1710.MessagesEntity
	var $data; $status : Object
	var $messages : cs:C1710.MessagesSelection:=ds:C1482.Messages.all()  //.query("Sender = :1 and Receiver = :2";)
	//TRACE
	$ws.wss.handler.logFile("New client connected: "+This:C1470.name+" - "+This:C1470.address)
	ALERT:C41("Client: "+This:C1470.currentUser.uniqueIP+" is connected now")
	//TRACE
	//ALERT("n connections: "; $ws.wss.connections.length)
	//to check
	If ($users.length#0)
		$ws.send(JSON Stringify:C1217({users: $users.toCollection()}))
	End if 
	If ($groups.length#0)
		$ws.send(JSON Stringify:C1217({groups: $groups.toCollection()}))
	End if 
	//
	For each ($message; $messages)
		$data:=This:C1470.formatData($message)
		$ws.send(JSON Stringify:C1217({sender: ds:C1482.User.get($message.senderUser).toObject(); receiver: ds:C1482.User.get($message.receiverUser).toObject(); \
			conversation: $message.conversation.toObject(); content: $message.Content; image: $data.imageBase64; audio: $data.audioBase64; file: $data.fileBase64; \
			poll: $message.Poll; dateStamp: String:C10($message.sentThe; ISO date GMT:K1:10; Time:C179($message.sentAt))})+"\n")
	End for each 
	
	
Function onMessage($ws : Object; $info : Object)
	var $client : Object
	var $message : cs:C1710.MessagesEntity
	var $data : Variant
	var $formattedData : Object
	var $sender; $receiver : cs:C1710.UserEntity
	var $conversation : cs:C1710.ConversationEntity
	var $conversations : cs:C1710.ConversationSelection
	var $conversationMember : cs:C1710.ConversationMemberEntity
	var $conversationMembers : cs:C1710.ConversationMemberSelection
	var $group : cs:C1710.GroupEntity
	var $receiverLabel : Text
	SET BLOB SIZE:C606(vxBlob; 0)
	For each ($client; $ws.wss.connections)
		Try
			$data:=JSON Parse:C1218($info.data)
		Catch  //if it's a string coming from postman
			$data:={content: $info.data}
		End try
		//case if the connected user selected a user from his conversation list in FE
		If ($data.receiver#Null:C1517)
			$receiverLabel:=$data.receiver
		Else 
			$receiverLabel:=$client.handler.currentUser.lastName
		End if 
		$sender:=This:C1470.currentUser
		$receiver:=ds:C1482.User.query("lastName = :1 or firstName = :1"; $receiverLabel).first()
		$messages:=ds:C1482.Messages.query("(sender.ID = :1 and receiver.ID = :2) or (sender.ID = :2 and receiver.ID = :1) and sentAt = :3"; $sender.ID; $receiver.ID; Current time:C178)
		//TRACE
		If ($messages.length#0)
			$message:=$messages.first()
		Else 
			$message:=ds:C1482.Messages.new()
			$message.sentThe:=Current date:C33
			$message.sentAt:=Current time:C178
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
				: (Not:C34(Undefined:C82($data.poll)))
					If ($data.poll.selectedOptions.length#0)
						$message:=This:C1470.onUpdatePoll($data.poll.pollID; $data.poll.selectedOptions)
						return 
					Else 
						$message.Poll:=$data.poll
					End if 
			End case 
			//TRACE
			$message.senderUser:=$sender.ID
			$message.sender:=$sender
			$message.receiver:=$receiver
			$message.receiverUser:=$receiver.ID
			//TRACE  //something is wrong here
			//get common conversation of sender and receiver
			$conversations:=$sender.conversationMembers.conversation.and($receiver.conversationMembers.conversation)
			If (($conversations#Null:C1517) && ($conversations.length#0))  //conversation exists
				$conversation:=$conversations.first()
				$message.conversationID:=$conversation.ID
			End if 
			//one connection
			If ((($ws.wss.connections.length=1) && ($receiverLabel=This:C1470.currentUser.lastName)))  //im the only connection and talking to myself 
				If ($conversation=Null:C1517)
					$conversation:=ds:C1482.Conversation.new()
					$conversation.save()
					$conversationMember:=ds:C1482.ConversationMember.new()
					$conversationMember.create($conversation; $sender)  //$sender=$receiver
				End if 
				$message.conversationID:=$conversation.ID
				$status:=$message.save()
			End if 
			If (($ws.wss.connections.length=1) && ($receiverLabel#This:C1470.currentUser.lastName))  //I'm the only one connected and selected someone else
				If ($conversation=Null:C1517)
					$conversation:=ds:C1482.Conversation.new()
					$conversation.save()
					$conversationMember:=ds:C1482.ConversationMember.new()
					$conversationMember.create($conversation; $sender)  //$sender=$receiver
					$conversationMember:=ds:C1482.ConversationMember.new()
					$conversationMember.create($conversation; $receiver)  //$sender=$receiver
				End if 
				$message.conversationID:=$conversation.ID
				$status:=$message.save()
			End if 
			If ((($ws.wss.connections.length=2) && (This:C1470.currentUser.ID#$client.handler.currentUser.ID)) || (($ws.wss.connections.length=2) && (This:C1470.currentUser.ID#$client.handler.currentUser.ID) && ($receiverLabel#Null:C1517)) || (($ws.wss.connections.length>2) && ($receiverLabel#Null:C1517)))  //two connected -> sender # receiver do not save the message for the same client as sender and receiver
				If ($conversation=Null:C1517)
					//new conversation
					$conversation:=ds:C1482.Conversation.new()
					$conversation.save()
					//2 new conversatiomemberships
					//sender membership
					$conversationMember:=ds:C1482.ConversationMember.new()
					$conversationMember.create($conversation; $sender)
					//receiver membership
					//If ($sender.ID#$receiver.ID)
					$conversationMember:=ds:C1482.ConversationMember.new()
					$conversationMember.create($conversation; $receiver)
				End if 
				$message.conversationID:=$conversation.ID
				//case when the conversationmember does not exist
				$status:=$message.save()
			End if 
			//If (($ws.wss.connections.length=2) && (This.currentUser.ID#$client.handler.currentUser.ID) && ($receiverLabel#Null))  //two connected -> sender # receiverdo not save the message for the same client as sender and receiver
			//If ($conversation=Null)
			////new conversation
			//$conversation:=ds.Conversation.new()
			//$conversation.save()
			////2 new conversatiomemberships
			////sender membership
			//$conversationMember:=ds.ConversationMember.new()
			//$conversationMember.create($conversation; $sender)
			////receiver membership
			////If ($sender.ID#$receiver.ID)
			//$conversationMember:=ds.ConversationMember.new()
			//$conversationMember.create($conversation; $receiver)
			//End if 
			//$message.conversationID:=$conversation.ID
			////case when the conversationmember does not exist
			//$status:=$message.save()
			//End if 
			//group of users //not done 
			If (($ws.wss.connections.length>2) && ($receiverLabel=Null:C1517))
				//create a new group
				$group:=ds:C1482.Group.new()
				$group.label:="Group "
				$group.save()
				$sender.group:=$group
				$receiver.group:=$group
				$sender.save()
				$receiver.save()
				$status:=$message.save()
				$formattedData:=This:C1470.formatData($message)
				$client.send(JSON Stringify:C1217({sender: ds:C1482.User.get($message.senderUser).toObject(); receiver: ds:C1482.User.get($message.receiverUser).toObject(); \
					conversation: $message.conversation.toObject(); content: $message.Content; image: $formattedData.imageBase64; audio: $formattedData.audioBase64; file: $formattedData.fileBase64; poll: $message.Poll; dateStamp: String:C10($message.sentThe; ISO date GMT:K1:10; Time:C179($message.sentAt))})+"\n")
			End if 
		End if 
		$formattedData:=This:C1470.formatData($message)
		$client.send(JSON Stringify:C1217({sender: ds:C1482.User.get($message.senderUser).toObject(); receiver: ds:C1482.User.get($message.receiverUser).toObject(); \
			conversation: $message.conversation.toObject(); content: $message.Content; image: $formattedData.imageBase64; audio: $formattedData.audioBase64; file: $formattedData.fileBase64; poll: $message.Poll; dateStamp: String:C10($message.sentThe; ISO date GMT:K1:10; Time:C179($message.sentAt))})+"\n")
		//This.send(JSON Stringify({sender: ds.User.get($message.senderUser).toObject(); receiver: ds.User.get($message.receiverUser).toObject(); \
			conversation: $message.conversation.toObject(); content: $message.Content; image: $formattedData.imageBase64; audio: $formattedData.audioBase64; file: $formattedData.fileBase64; poll: $message.Poll; dateStamp: String($message.sentThe; ISO date GMT; Time($message.sentAt))})+"\n")
	End for each 
	
	
Function onUpdatePoll($pollID : Variant; $selectedOptions : Object) : cs:C1710.MessagesEntity
	var $message : cs:C1710.MessagesEntity
	$message:=ds:C1482.Messages.query("Poll.pollID = :1"; $pollId).first()
	If ($message#Null:C1517)
		$message.Poll.selectedOptions.push({sender: String:C10(This:C1470.address); selectedOptions: $selectedOptions})
		$message.save()
		return $message
	End if 
	
	// Called when an error occured
Function onError($ws : Object; $info : Object)
	$ws.wss.handler.logFile("*** Error: "+This:C1470.name+" - "+This:C1470.address+" - "+JSON Stringify:C1217($info))
	
	// Called when the session is closed
Function onTerminate($ws : Object; $info : Object)
	var $client : Object
	//TRACE
	ALERT:C41(String:C10($ws.wss.connections.length)+" connections left!")
	$ws.wss.handler.logFile("Connection closed: "+This:C1470.name+" - "+String:C10(This:C1470.address)+" - code: "+String:C10($info.code)+" "+String:C10($info.reason))
	// resend the message "new client connected" to all clients
	For each ($client; $ws.wss.connections)
		If ($client.id#$ws.id)
			$client.send(JSON Stringify:C1217({content: String:C10(This:C1470.name)+" disconnected!"}))
		End if 
	End for each 
	