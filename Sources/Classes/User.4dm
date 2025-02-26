Class extends DataClass

exposed Function login($userName : Text) : cs:C1710.UserEntity
	var $users : cs:C1710.UserSelection
	var $user : cs:C1710.UserEntity
	$users:=ds:C1482.User.query("uniqueIP = :1"; $userName)
	If ($users.length#0)
		$user:=$users.first()
		$user.isActive:=True:C214
		$user.save()
	Else 
		$user:=ds:C1482.User.new()
		$user.uniqueIP:=$userName
		$user.firstName:="Client"+String:C10($user.ID)
		$user.lastName:=$userName
		$user.isActive:=True:C214
		$user.save()
	End if 
	return $user
	