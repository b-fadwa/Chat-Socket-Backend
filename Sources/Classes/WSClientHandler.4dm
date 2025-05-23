property currentUser : cs:C1710.UserEntity

Class constructor($user : cs:C1710.UserEntity)
	
	This:C1470.currentUser:=$user
	
	//will be used to format data
Function formatData($message : cs:C1710.MessageEntity) : Object
	var $formattedData : Object:=New object:C1471()
	If (($message.audio#Null:C1517) && (BLOB size:C605($message.audio)>0))
		$formattedData.audioBase64:=BLOB to text:C555($message.audio; Base64 encoding)
	Else 
		$formattedData.audioBase64:=""  // Handle missing audio
	End if 
	If (($message.image#Null:C1517) && (BLOB size:C605($message.image)>0))
		$formattedData.imageBase64:=BLOB to text:C555($message.image; Base64 encoding)
	Else 
		$formattedData.imageBase64:=""  // Handle missing image
	End if 
	If (($message.file#Null:C1517) && (BLOB size:C605($message.file)>0))
		$formattedData.fileBase64:=BLOB to text:C555($message.file; Base64 encoding)
	Else 
		$formattedData.fileBase64:=""  // Handle missing file
	End if 
	return $formattedData
	
	//Defines a connection behavior =>send users + groups + messages related to the connected user
Function onOpen($ws : 4D:C1709.WebSocketConnection; $info : Object)
	var $client; $data : Object
	var $users : cs:C1710.UserSelection:=ds:C1482.User.all()
	var $groups : cs:C1710.GroupSelection:=ds:C1482.Group.all().query("users.ID = :1"; This:C1470.currentUser.ID)  //grpups to which the currentUser belongs
	var $message : cs:C1710.MessageEntity
	var $messages : cs:C1710.MessageSelection
	var $encodedSenderImage; $encodedReceiverImage : Text
	var $senderBlobPic; $receiverBlobPic : Blob
	$ws.wss.handler.logFile("New client connected: "+This:C1470.currentUser.lastName)
	If (This:C1470.currentUser.group#Null:C1517)
		$messages:=ds:C1482.Message.all().query("sender.ID = :1 or receiver.ID = :1 or receiverGroup.ID = :2"; This:C1470.currentUser.ID; This:C1470.currentUser.group.ID).orderBy("sentThe")
	Else 
		$messages:=ds:C1482.Message.all().query("sender.ID = :1 or receiver.ID = :1 "; This:C1470.currentUser.ID)
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
			//encode picture [object Picture] won't work
			If ($message.receiver#Null:C1517 && $message.receiver.avatar#Null:C1517 && Not:C34(Undefined:C82($message.receiver.avatar)))
				PICTURE TO BLOB:C692($message.receiver.avatar; $receiverBlobPic; "image/png")
				BASE64 ENCODE:C895($receiverBlobPic; $encodedReceiverImage)
			End if 
			PICTURE TO BLOB:C692($message.sender.avatar; $senderBlobPic; "image/png")
			BASE64 ENCODE:C895($senderBlobPic; $encodedSenderImage)
			$ws.send(JSON Stringify:C1217({sender: ds:C1482.User.get($message.senderUser).toObject(); receiver: $finalReceiver.toObject(); \
				senderAvatar: "data:image/png;base64,"+$encodedSenderImage; receiverAvatar: "data:image/png;base64,"+$encodedReceiverImage; \
				conversation: $message.conversation.toObject(); content: $message.content; image: $data.imageBase64; audio: $data.audioBase64; File: $data.fileBase64; \
				poll: $message.poll; isRead: $message.isRead; dateStamp: String:C10($message.sentThe; ISO date GMT:K1:10; Time:C179($message.sentAt))})+"\n")
		End for each 
	End if 
	
	
Function onMessage($ws : Object; $info : Object)
	var $client; $formattedData; $status : Object
	var $message : cs:C1710.MessageEntity
	var $sender; $receiver : cs:C1710.UserEntity
	var $receiverGroup : cs:C1710.GroupEntity
	var $conversation : cs:C1710.ConversationEntity
	var $conversations : cs:C1710.ConversationSelection
	var $conversationMember : cs:C1710.ConversationMemberEntity
	var $conversationMembers : cs:C1710.ConversationMemberSelection
	var $data; $finalReceiver : Variant  //data parsed + to check group or user
	var $encodedSenderImage; $encodedReceiverImage; $receiverLabel : Text
	var $senderBlobPic; $receiverBlobPic : Blob
	SET BLOB SIZE:C606(vxBlob; 0)
	For each ($client; $ws.wss.connections)
		Try
			$data:=JSON Parse:C1218($info.data)
		Catch  //if it's a string coming from postman
			$data:={content: $info.data}
		End try
		//just updating the reading messages
		If ($data.isRead#Null:C1517)
			$conversation:=ds:C1482.Conversation.get($data.conversationID)
			For each ($message; $conversation.messages)
				$message.isRead:=True:C214
				$message.save()
			End for each 
		Else 
			//case if the connected user selected a user from his conversation list in FE
			If ($data.receiver#Null:C1517)
				$receiverLabel:=$data.receiver
			Else 
				$receiverLabel:=This:C1470.currentUser.lastName  //send to myself 
			End if 
			$sender:=ds:C1482.User.query("lastName = :1"; This:C1470.currentUser.lastName).first()  //This.currentUser (not working correctly for convoMemberships..)
			//receiver is a group or a user
			Case of 
				: (ds:C1482.User.query("lastName = :1 or firstName = :1"; $receiverLabel).length#0)  //receiver = user
					$receiver:=ds:C1482.User.query("lastName = :1 or firstName = :1"; $receiverLabel).first()
					$messages:=ds:C1482.Message.query("(sender.ID = :1 and receiver.ID = :2) or (sender.ID = :2 and receiver.ID = :1) and sentAt = :3"; $sender.ID; $receiver.ID; Current time:C178)
				: (ds:C1482.Group.query("label = :1"; $receiverLabel).length#0)
					$receiverGroup:=ds:C1482.Group.query("label = :1"; $receiverLabel).first()
					$messages:=ds:C1482.Message.query("(sender.ID = :1 and receiverGroup.ID = :2) and sentAt = :3"; $sender.ID; $receiverGroup.ID; Current time:C178)
			End case 
			If ($messages.length#0)
				$message:=$messages.first()
			Else   //create new message
				$message:=ds:C1482.Message.new()
				$message.sentThe:=Current date:C33
				$message.sentAt:=Current time:C178
				$message.isRead:=False:C215
				Case of   //fill the message fields
					: (String:C10($data.content)#"" && Not:C34(Undefined:C82($data.content)))
						$message.content:=$data.content
					: ($data.image#"" && Not:C34(Undefined:C82($data.image)))
						TEXT TO BLOB:C554($data.image; vxBlob)
						$message.image:=vxBlob
					: ($data.file#"" && Not:C34(Undefined:C82($data.file)))
						TEXT TO BLOB:C554($data.file; vxBlob)
						$message.file:=vxBlob
					: ($data.audio#"" && Not:C34(Undefined:C82($data.audio)))
						TEXT TO BLOB:C554($data.audio; vxBlob; UTF8 C string:K22:15)
						$message.audio:=vxBlob
					: (Not:C34(Undefined:C82($data.poll)))
						If ($data.poll.selectedOptions.length#0)
							$message:=This:C1470.onUpdatePoll($data.poll)
							return 
						Else 
							$message.poll:=$data.poll
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
						$conversationMember.create($conversation; $receiver; Null:C1517)
					End if 
					$message.conversationID:=$conversation.ID
					$status:=$message.save()
				End if 
			End if 
			//send message to the right client only
			If (($client.handler.currentUser.ID=$receiver.ID) || ($client.handler.currentUser.ID=$sender.ID) || ($receiverGroup#Null:C1517 && ($receiverGroup.users.query("ID = :1"; $client.handler.currentUser.ID).length#0)))
				$formattedData:=This:C1470.formatData($message)
				If ($message.receiver#Null:C1517)
					PICTURE TO BLOB:C692($message.receiver.avatar; $receiverBlobPic; "image/png")
					BASE64 ENCODE:C895($receiverBlobPic; $encodedReceiverImage)
				End if 
				PICTURE TO BLOB:C692($message.sender.avatar; $senderBlobPic; "image/png")
				BASE64 ENCODE:C895($senderBlobPic; $encodedSenderImage)
				$client.send(JSON Stringify:C1217({sender: $message.sender.toObject(); receiver: $finalReceiver.toObject(); \
					senderAvatar: "data:image/png;base64,"+$encodedSenderImage; receiverAvatar: "data:image/png;base64,"+$encodedReceiverImage; \
					conversation: $message.conversation.toObject(); isRead: $message.isRead; content: $message.content; image: $formattedData.imageBase64; audio: $formattedData.audioBase64; file: $formattedData.fileBase64; poll: $message.poll; dateStamp: String:C10($message.sentThe; ISO date GMT:K1:10; Time:C179($message.sentAt))})+"\n")
			End if 
		End if 
	End for each 
	
	
Function onUpdatePoll($poll : Object) : cs:C1710.MessageEntity
	var $message : cs:C1710.MessageEntity
	
	If ($poll.action="add")
		$message:=ds:C1482.Message.query("poll.pollID = :1"; $poll.pollID).first()
		If ($message#Null:C1517 && Not:C34($message.poll.selectedOptions.includes($poll.selectedOptions)))
			$message.poll.selectedOptions.push({sender: String:C10(This:C1470.currentUser.lastName); selectedOptions: $poll.selectedOptions})
			$message.save()
			return $message
		End if 
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