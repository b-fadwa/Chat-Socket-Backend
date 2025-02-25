Class extends DataClass

exposed Function login($ipAddress : Text; $count : Real) : cs:C1710.UserEntity
	var $users : cs:C1710.UserSelection
	var $user : cs:C1710.UserEntity
	$users:=ds:C1482.User.query("uniqueIP = :1"; $ipAddress)
	If ($users.length#0)
		$user:=$users.first()
	Else 
		$user:=ds:C1482.User.new()
		$user.uniqueIP:=$ipAddress
		$user.firstName:="Client"+String:C10($count)
		$user.lastName:=$ipAddress  //"User "+String($user.ID)
		$user.isActive:=True:C214
		$user.save()
	End if 
	//Use (Session.storage)
	//Session.storage.auth:=New shared object("id"; $user.ID)
	//End use 
	return $user
	