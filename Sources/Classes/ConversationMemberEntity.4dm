Class extends Entity

exposed Function create($conversation : cs:C1710.ConversationEntity; $user : cs:C1710.UserEntity; $group : cs:C1710.GroupEntity)
	This:C1470.ConversationID:=$conversation.ID
	If ($user#Null:C1517)
		This:C1470.UserID:=$user.ID
	Else 
		This:C1470.groupID:=$group.ID
	End if 
	This:C1470.save()