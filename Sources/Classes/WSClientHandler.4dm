Class constructor($user : cs:C1710.UserEntity)
	
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
	
	//Defines a connection behavior =>send users + groups + messages related to the connected user
Function onOpen($ws : 4D:C1709.WebSocketConnection; $info : Object)
	var $client : Object
	var $users : cs:C1710.UserSelection:=ds:C1482.User.all()
	var $groups : cs:C1710.GroupSelection:=ds:C1482.Group.all().query("users.ID = :1"; This:C1470.currentUser.ID)  //grpups to which the currentUser belongs
	var $message : cs:C1710.MessagesEntity
	var $data : Object
	var $messages : cs:C1710.MessagesSelection
	$ws.wss.handler.logFile("New client connected: "+This:C1470.currentUser.lastName)
	If (This:C1470.currentUser.group#Null:C1517)
		$messages:=ds:C1482.Messages.all().query("sender.ID = :1 or receiver.ID = :1 or receiverGroup.ID = :2"; This:C1470.currentUser.ID; This:C1470.currentUser.group.ID)
	Else 
		$messages:=ds:C1482.Messages.all().query("sender.ID = :1 or receiver.ID = :1 "; This:C1470.currentUser.ID)
	End if 
	If ($users.length#0)
		$ws.send(JSON Stringify:C1217({users: $users.toCollection()}))
	End if 
	If ($groups.length#0)
		$ws.send(JSON Stringify:C1217({groups: $groups.toCollection()}))
	End if 
	If ($messages.length#0)
		For each ($message; $messages)
			$finalReceiver:=$message.receiver#Null:C1517 ? $message.receiver : $message.receiverGroup
			$data:=This:C1470.formatData($message)
			$ws.send(JSON Stringify:C1217({sender: ds:C1482.User.get($message.senderUser).toObject(); receiver: $finalReceiver.toObject(); \
				conversation: $message.conversation.toObject(); content: $message.Content; image: $data.imageBase64; audio: $data.audioBase64; file: $data.fileBase64; \
				poll: $message.Poll; dateStamp: String:C10($message.sentThe; ISO date GMT:K1:10; Time:C179($message.sentAt))})+"\n")
		End for each 
	End if 
	
	
Function onMessage($ws : Object; $info : Object)
	var $client : Object
	var $message : cs:C1710.MessagesEntity
	var $data : Variant  //data parsed
	var $formattedData : Object  //formatted data
	var $sender; $receiver : cs:C1710.UserEntity
	var $receiverGroup : cs:C1710.GroupEntity
	var $conversation : cs:C1710.ConversationEntity
	var $conversations : cs:C1710.ConversationSelection
	var $conversationMember : cs:C1710.ConversationMemberEntity
	var $conversationMembers : cs:C1710.ConversationMemberSelection
	var $receiverLabel : Text  //selected and sent from the FE
	var $finalReceiver : Variant  //to check group or user
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
			$receiverLabel:=This:C1470.currentUser.lastName  //send to myself 
		End if 
		$sender:=This:C1470.currentUser
		//receiver is a group or a user
		Case of 
			: (ds:C1482.User.query("lastName = :1 or firstName = :1"; $receiverLabel).length#0)  //receiver = user
				$receiver:=ds:C1482.User.query("lastName = :1 or firstName = :1"; $receiverLabel).first()
				$messages:=ds:C1482.Messages.query("(sender.ID = :1 and receiver.ID = :2) or (sender.ID = :2 and receiver.ID = :1) and sentAt = :3"; $sender.ID; $receiver.ID; Current time:C178)
			: (ds:C1482.Group.query("label = :1"; $receiverLabel).length#0)
				$receiverGroup:=ds:C1482.Group.query("label = :1"; $receiverLabel).first()
				$messages:=ds:C1482.Messages.query("(sender.ID = :1 and receiverGroup.ID = :2) and sentAt = :3"; $sender.ID; $receiverGroup.ID; Current time:C178)
		End case 
		//If ($messages.length#0)
		//$message:=$messages.first()
		//Else   //create new message
		$message:=ds:C1482.Messages.new()
		$message.sentThe:=Current date:C33
		$message.sentAt:=Current time:C178
		Case of   //fill the message fields
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
		//sender?
		$message.senderUser:=$sender.ID
		$message.sender:=$sender
		//receiver ?
		If ($receiver#Null:C1517)
			$message.receiver:=$receiver
			$message.receiverUser:=$receiver.ID
			$finalReceiver:=$receiver
			//+get common conversations with the sender
			$conversations:=$sender.conversationMembers.conversation.and($receiver.conversationMembers.conversation)
		End if 
		If ($receiverGroup#Null:C1517)
			$message.receiverGroup:=$receiverGroup
			$finalReceiver:=$receiverGroup
			//+get common conversation with the sender
			$conversations:=$receiverGroup.conversationMembers.conversation
		End if 
		//get conversation
		If (($conversations#Null:C1517) && ($conversations.length#0))  //conversation exists
			$conversation:=$conversations.first()
			$message.conversationID:=$conversation.ID  //redundant ?
			$status:=$message.save()
		End if 
		If (($receiverGroup#Null:C1517) && ($conversation=Null:C1517))
			$conversation:=ds:C1482.Conversation.new()
			$conversation.save()
			$conversationMember:=ds:C1482.ConversationMember.new()
			$conversationMember.create($conversation; $sender)
			$conversationMember:=ds:C1482.ConversationMember.new()
			$conversationMember.create($conversation; Null:C1517; $receiverGroup)
			$message.conversationID:=$conversation.ID  //redundant ?
			$status:=$message.save()
		End if 
		If (($receiver#Null:C1517) && ($conversation=Null:C1517))
			$conversation:=ds:C1482.Conversation.new()
			$conversation.save()
			$conversationMember:=ds:C1482.ConversationMember.new()
			$conversationMember.create($conversation; $sender)
			If ($sender.ID#$receiver.ID)
				$conversationMember:=ds:C1482.ConversationMember.new()
				$conversationMember.create($conversation; Null:C1517; $receiverGroup)
			End if 
			$message.conversationID:=$conversation.ID
			$status:=$message.save()
			//End if 
		End if 
		$formattedData:=This:C1470.formatData($message)
		//send message to the right client only
		If (($client.handler.currentUser.ID=$receiver.ID) || ($client.handler.currentUser.ID=$sender.ID) || ($receiverGroup#Null:C1517 && ($receiverGroup.users.query("ID = :1"; $client.handler.currentUser.ID).length#0)))
			$client.send(JSON Stringify:C1217({sender: ds:C1482.User.get($message.senderUser).toObject(); receiver: $finalReceiver.toObject(); \
				conversation: $message.conversation.toObject(); content: $message.Content; image: $formattedData.imageBase64; audio: $formattedData.audioBase64; file: $formattedData.fileBase64; poll: $message.Poll; dateStamp: String:C10($message.sentThe; ISO date GMT:K1:10; Time:C179($message.sentAt))})+"\n")
		End if 
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
	$ws.wss.handler.logFile("*** Error: "+This:C1470.currentUser.lastName+" - "+JSON Stringify:C1217($info))
	
	// Called when the session is closed
Function onTerminate($ws : Object; $info : Object)
	$ws.wss.handler.logFile("Connection closed: "+This:C1470.currentUser.lastName+" - code: "+String:C10($info.code)+" "+String:C10($info.reason))
	$currentUser:=This:C1470.currentUser
	$currentUser.isActive:=False:C215
	$currentUser.save()
	