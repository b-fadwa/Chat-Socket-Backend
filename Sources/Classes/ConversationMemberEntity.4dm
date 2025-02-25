Class extends Entity

exposed Function create($conversation : cs:C1710.ConversationEntity; $user : cs:C1710.UserEntity)
	This:C1470.ConversationID:=$conversation.ID
	This:C1470.UserID:=$user.ID
	This:C1470.save()