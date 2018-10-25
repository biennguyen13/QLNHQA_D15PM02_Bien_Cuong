CREATE DATABASE QuanLiNhaHangQuanAn
GO

USE QuanLiNhaHangQuanAn
GO



CREATE TABLE TableFood
(
	ID INT IDENTITY PRIMARY KEY,
	Name NVARCHAR(100) NOT NULL DEFAULT N'Chưa có tên.',
	Status NVARCHAR(100) NOT NULL DEFAULT N'Trống', -- trống || có người.
)
GO

CREATE TABLE Account
(
	ID INT IDENTITY PRIMARY KEY,
	DisplayName NVARCHAR(100) NOT NULL DEFAULT N'Chưa có tên.',
	UserName NVARCHAR(100) NOT NULL UNIQUE,
	PassWord NVARCHAR(500) NOT NULL DEFAULT '0',
	Type INT NOT NULL DEFAULT 0 --1 :admin , 0 :staff.
)
GO

INSERT dbo.Account
        ( DisplayName ,
          UserName ,
          PassWord ,
          Type
        )
VALUES  ( N'biên' , -- DisplayName - nvarchar(100)
          N'biennguyen13' , -- UserName - nvarchar(100)
          N'1' , -- PassWord - nvarchar(500)
          1  -- Type - int
        )
INSERT dbo.Account
        ( DisplayName ,
          UserName ,
          PassWord ,
          Type
        )
VALUES  ( N'biên' , -- DisplayName - nvarchar(100)
          N'biennguyen' , -- UserName - nvarchar(100)
          N'1' , -- PassWord - nvarchar(500)
          0  -- Type - int
        )


CREATE TABLE FoodCategory
(
	ID INT IDENTITY PRIMARY KEY,
	Name NVARCHAR(100) NOT NULL DEFAULT N'Chưa có tên.'
)
GO

CREATE TABLE Food
(
	ID INT IDENTITY PRIMARY KEY,
	Name NVARCHAR(100) NOT NULL DEFAULT N'Chưa có tên.', 
	IdCategory INT NOT NULL,
	Price FLOAT NOT NULL
	
	FOREIGN KEY (IdCategory) REFERENCES dbo.FoodCategory (ID)
)
GO

CREATE TABLE Bill
(
	Id INT IDENTITY PRIMARY KEY,
	DateCheckIn DATE NOT NULL DEFAULT GETDATE(),
	DateCheckOut DATE,
	IdTable INT  ,
	Status INT NOT NULL DEFAULT 0, --chưa thanh toán 0 , đã thanh toán 1.
	Discount INT DEFAULT 0,
	TotalPrice INT DEFAULT 0

	FOREIGN KEY (IdTable) REFERENCES dbo.TableFood (ID)
	
)
GO

CREATE TABLE BillInfo
(
	ID INT IDENTITY PRIMARY KEY,
	IdBill INT NOT NULL,
	IdFood INT NOT NULL,
	Count INT NOT NULL DEFAULT 0

	FOREIGN KEY (IdBill) REFERENCES dbo.Bill (Id)
	,FOREIGN KEY (IdFood) REFERENCES dbo.Food(ID)
)
GO



---------------
CREATE PROC StoreProc_Login @username nvarchar(100), @password nvarchar(500)
AS
BEGIN
	SELECT * FROM dbo.Account WHERE UserName = @username AND PassWord = @password
END
go
---------------
create PROC StoreProc_GetTableList
AS
BEGIN
	SELECT * FROM dbo.TableFood
END
go
---------------
CREATE PROC StoreProc_GetBillIdUncheck @idTable int
AS
BEGIN
	SELECT * FROM dbo.Bill WHERE IdTable = @idTable AND Status = 0
END
go
---------------
CREATE PROC StoreProc_GetListBillDetailsByBillId @billId int 
AS 
BEGIN
	SELECT dbo.Food.Name,dbo.Food.Price,dbo.BillInfo.Count,dbo.Food.Price*dbo.BillInfo.Count AS totalprice
	FROM dbo.Bill,dbo.BillInfo,dbo.Food
	WHERE dbo.Bill.Id = dbo.BillInfo.IdBill AND dbo.BillInfo.IdFood = dbo.Food.ID AND dbo.Bill.Id = @billId
END
go
--------------------
CREATE PROC StoreProc_GetFoodListByCategoryId @categoryId int
AS
BEGIN
	SELECT ID,Name,IdCategory,Price
	FROM dbo.Food
	WHERE IdCategory = @categoryId
	ORDER BY Name
END
go
------------
create PROC StoreProc_InsertBillByTableId @tableId int
AS
BEGIN
	INSERT INTO dbo.Bill
	        ( DateCheckIn ,
	          DateCheckOut ,
	          IdTable ,
	          Status,
			  discount,
			  TotalPrice
	        )
	VALUES  ( GETDATE() , -- DateCheckIn - date
	          NULL , -- DateCheckOut - date
	          @tableId , -- IdTable - int
	          0  ,-- Status - int
			  0,
			  0
	        )
END
go
----------------
CREATE PROC StoreProc_InsertBillInfo @billId int,@foodId int,@count int
AS
BEGIN

	DECLARE @billInfoId INT = 0
	DECLARE @newCount INT = 0

	SELECT @billInfoId = ID, @newCount = Count + @count
	FROM dbo.BillInfo 
	WHERE IdBill = @billId AND IdFood = @foodId

	IF @billInfoId = 0
		BEGIN
			IF @count > 0
				INSERT INTO dbo.BillInfo
					( IdBill, IdFood, Count )
				VALUES  ( @billId, -- IdBill - int
					@foodId, -- IdFood - int
					@count  -- Count - int
					)
		END
	ELSE
		IF @newCount <= 0
			DELETE dbo.BillInfo
			WHERE ID = @billInfoId
		ELSE
			UPDATE dbo.BillInfo
			SET
            Count = @newCount
			WHERE ID = @billInfoId
END
go

---------------
CREATE PROC StoreProc_CheckOutBill @billId int, @discount int , @totalPrice int
AS
BEGIN
	UPDATE dbo.Bill
	SET DateCheckOut = GETDATE() , Status = 1, discount = @discount , totalPrice = @totalPrice
	WHERE Id = @billId

	DECLARE @name nvarchar(100)
	DECLARE @checkin DATETIME
	DECLARE @checkout DATETIME

	SELECT @name = dbo.TableFood.Name , @checkin = dbo.Bill.DateCheckIn , @checkout = dbo.Bill.DateCheckOut
	FROM dbo.Bill , dbo.TableFood
	WHERE dbo.Bill.IdTable = dbo.TableFood.ID AND dbo.Bill.Id = @billId 

END
go


---------------
create PROC StoreProc_SwapBillForTable @tableId1 int,@tableId2 int
AS
BEGIN
	DECLARE @billId1 INT
	DECLARE @billId2 INT

	SELECT @billId1 = Id
    FROM dbo.Bill
	WHERE IdTable = @tableId1 AND Status = 0

	IF(@billId1 IS NULL) RETURN

	SELECT @billId2 = Id
    FROM dbo.Bill
	WHERE IdTable = @tableId2 AND Status = 0

	IF(@billId2 IS NULL)
		BEGIN
			UPDATE dbo.Bill
			SET
            IdTable = @tableId2
			WHERE  Id = @billId1

			UPDATE dbo.TableFood
			SET
            Status = N'Trống'
			WHERE ID = @tableId1
			PRINT @tableId1
		END
    ELSE
		BEGIN
			UPDATE dbo.Bill
			SET
            IdTable = @tableId2
			WHERE  Id = @billId1

			UPDATE dbo.Bill
			SET
            IdTable = @tableId1
			WHERE  Id = @billId2
		END
        
END
go
---------------
create PROC StoreProc_GetCheckOutBillListByDate @dateTime1 datetime , @dateTime2 datetime
AS
BEGIN
	SELECT  BillId AS N'ID Hóa đơn',TableName AS N'Tên bàn', CheckIn as N'Giờ vào', CheckOut AS N'Giờ ra', discount AS N'Giảm giá (%)', totalPrice AS N'Tổng tiền'
	FROM BillCopy
	WHERE CheckOut BETWEEN @dateTime1 and @dateTime2
END
go
---------------
CREATE PROC StoreProc_GetAccountByUsername @userName Nvarchar(100)
AS
begin
	SELECT * FROM dbo.Account WHERE UserName = @username
END
go
---------------
CREATE PROC StoreProc_UpdateAccount @username nvarchar(100), @displayname nvarchar(100), @password nvarchar(500),
@newpassword nvarchar(500)
AS
BEGIN
	IF EXISTS (SELECT *
				FROM dbo.Account
                WHERE UserName = @username AND PassWord = @password)
		BEGIN
			IF @newpassword IS NULL OR @newpassword = ''
				BEGIN
					UPDATE dbo.Account
					SET DisplayName = @displayname
					WHERE UserName = @username
				END
            ELSE
				BEGIN
					UPDATE dbo.Account
					SET DisplayName = @displayname,
					PassWord = @newpassword
					WHERE UserName = @username
				END
		END  
END
go
---------------
CREATE PROC StoreProc_GetCategoryById @categoryId int
AS
BEGIN
	SELECT * FROM dbo.FoodCategory WHERE ID = @categoryId
END
go
---------------
CREATE PROC StoreProc_InsertFood @foodname nvarchar(100), @categoryid int, @price float
AS
BEGIN
	INSERT INTO dbo.Food
	        ( Name, IdCategory, Price )
	VALUES  ( @foodname, -- Name - nvarchar(100)
	          @categoryid, -- IdCategory - int
	          @price  -- Price - float
	          )
END
go

---------------
CREATE PROC StoreProc_UpdateFood @foodId int, @foodname nvarchar(100), @categoryid int, @price float
AS
BEGIN
	UPDATE dbo.Food
	SET
    Name = @foodname,
    IdCategory = @categoryId,
    Price = @price
	WHERE id = @foodid
END
go
---------------
CREATE PROC StoreProc_CheckUsingFood @foodId int
AS
BEGIN
		SELECT *
		FROM dbo.Food, dbo.BillInfo, dbo.Bill
		WHERE dbo.Food.ID = @foodid AND dbo.Food.ID = dbo.BillInfo.IdFood 
		AND dbo.Bill.Id = dbo.BillInfo.IdBill AND dbo.Bill.Status = 0
END
go
--------------
CREATE PROC StoreProc_DeleteBillInfoByFoodId @foodid int
AS
BEGIN
	DELETE FROM dbo.BillInfo
	WHERE IdFood = @foodid
END
go
---------------
CREATE PROC StoreProc_DeleteFood @foodId int
AS BEGIN
	DELETE FROM dbo.Food
	WHERE ID = @foodid
END
go
---------------
CREATE FUNCTION [dbo].[GetUnsignString](@strInput NVARCHAR(4000)) 
RETURNS NVARCHAR(4000)
AS
BEGIN     
    IF @strInput IS NULL RETURN @strInput
    IF @strInput = '' RETURN @strInput
    DECLARE @RT NVARCHAR(4000)
    DECLARE @SIGN_CHARS NCHAR(136)
    DECLARE @UNSIGN_CHARS NCHAR (136)

    SET @SIGN_CHARS       = N'ăâđêôơưàảãạáằẳẵặắầẩẫậấèẻẽẹéềểễệếìỉĩịíòỏõọóồổỗộốờởỡợớùủũụúừửữựứỳỷỹỵýĂÂĐÊÔƠƯÀẢÃẠÁẰẲẴẶẮẦẨẪẬẤÈẺẼẸÉỀỂỄỆẾÌỈĨỊÍÒỎÕỌÓỒỔỖỘỐỜỞỠỢỚÙỦŨỤÚỪỬỮỰỨỲỶỸỴÝ'+NCHAR(272)+ NCHAR(208)
    SET @UNSIGN_CHARS = N'aadeoouaaaaaaaaaaaaaaaeeeeeeeeeeiiiiiooooooooooooooouuuuuuuuuuyyyyyAADEOOUAAAAAAAAAAAAAAAEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOUUUUUUUUUUYYYYYDD'

    DECLARE @COUNTER int
    DECLARE @COUNTER1 int
    SET @COUNTER = 1
 
    WHILE (@COUNTER <=LEN(@strInput))
    BEGIN   
      SET @COUNTER1 = 1
      --Tim trong chuoi mau
       WHILE (@COUNTER1 <=LEN(@SIGN_CHARS)+1)
       BEGIN
     IF UNICODE(SUBSTRING(@SIGN_CHARS, @COUNTER1,1)) = UNICODE(SUBSTRING(@strInput,@COUNTER ,1) )
     BEGIN           
          IF @COUNTER=1
              SET @strInput = SUBSTRING(@UNSIGN_CHARS, @COUNTER1,1) + SUBSTRING(@strInput, @COUNTER+1,LEN(@strInput)-1)                   
          ELSE
              SET @strInput = SUBSTRING(@strInput, 1, @COUNTER-1) +SUBSTRING(@UNSIGN_CHARS, @COUNTER1,1) + SUBSTRING(@strInput, @COUNTER+1,LEN(@strInput)- @COUNTER)    
              BREAK         
               END
             SET @COUNTER1 = @COUNTER1 +1
       END
      --Tim tiep
       SET @COUNTER = @COUNTER +1
    END
    RETURN @strInput
END
go
---------------
CREATE PROC StoreProc_SearchFoodByName @foodName nvarchar(100)
AS
BEGIN
	SELECT * FROM FOOD WHERE dbo.GetUnsignString(NAME) LIKE N'%'+dbo.GetUnsignString(@foodname)+'%' ORDER BY IdCategory,name
END
go

---------------
CREATE PROC StoreProc_InsertAccount @username nvarchar(100), @displayname nvarchar(100), @type int
AS begin
INSERT INTO dbo.Account
        ( DisplayName ,
          UserName ,
          PassWord ,
          Type
        )
VALUES  (  @displayname, -- DisplayName - nvarchar(100)
           @username, -- UserName - nvarchar(100)
          N'1' , -- PassWord - nvarchar(500)
          @type  -- Type - int
        )
END
go
---------------
CREATE PROC StoreProc_DeleteAccount @accId int
AS BEGIN
	DELETE FROM dbo.Account WHERE ID = @accId
END
go
---------------
CREATE PROC StoreProc_UpdateAccountByAdmin @accId int ,@username nvarchar(100), @displayname nvarchar(100), @type int
AS BEGIN
	UPDATE dbo.Account SET DisplayName = @displayname, UserName = @username, Type = @type
	WHERE id = @accId
END
go

---------------
CREATE PROC StoreProc_InsertCategory @categoryName nvarchar(100) 
AS BEGIN

	IF NOT EXISTS (SELECT * FROM  dbo.FoodCategory WHERE Name = @categoryName)
	begin
		INSERT INTO dbo.FoodCategory
	        ( Name )
		VALUES  ( @categoryName  -- Name - nvarchar(100)
	          )
	END
END
go
---------------
CREATE PROC StoreProc_UpdateCategory @categoryId int, @categoryName nvarchar(100) 
AS BEGIN
	IF NOT EXISTS (SELECT * FROM  dbo.FoodCategory WHERE Name = @categoryName)
	BEGIN
	    UPDATE dbo.FoodCategory SET Name = @categoryname WHERE ID = @categoryid    
	END
END
go
---------------
create PROC StoreProc_DeleteCategory @categoryId int
AS BEGIN
	DELETE dbo.BillInfo WHERE IdFood IN (SELECT ID FROM dbo.Food WHERE IdCategory = @categoryid)
	DELETE dbo.Food WHERE IdCategory = @categoryid
	DELETE dbo.FoodCategory WHERE ID = @categoryid
END
go
---------------
CREATE PROC StoreProc_InsertTable
AS BEGIN
	DECLARE @i INT = 1

	WHILE @i>0
	BEGIN
		DECLARE @tablename NVARCHAR(100) = N'Bàn số '+CAST(@i AS NVARCHAR(100))
		IF NOT EXISTS (SELECT * FROM dbo.TableFood WHERE Name = @tablename)
			BEGIN
				INSERT INTO dbo.TableFood
				        ( Name, Status )
				VALUES  ( @tablename, -- Name - nvarchar(100)
				          N'Trống'  -- Status - nvarchar(100)
				          )
				RETURN
			END
		SET @i+=1
	END
END
go
---------------
create PROC StoreProc_DeleteTable @tableId int
AS BEGIN
	
	IF EXISTS (SELECT * FROM dbo.TableFood WHERE ID = @tableId AND Status != N'Trống')
	RETURN

	DECLARE @billId INT

	SELECT @billId = ID
	FROM dbo.Bill
	WHERE IdTable = @tableId
	
	DELETE FROM dbo.BillInfo WHERE IdBill = @billId
	DELETE FROM dbo.Bill WHERE Id = @billId
	DELETE FROM dbo.TableFood WHERE ID = @tableId
END
go

---------------
create PROC StoreProc_ResetAllTableNames
AS BEGIN
       DECLARE @i INT = 1
	   DECLARE @count INT
       
	   SELECT @count = COUNT(*) FROM dbo.TableFood

	   UPDATE dbo.TableFood SET Name = N'noname'

	   WHILE @i <= @count
	   BEGIN
	       UPDATE dbo.TableFood SET Name =N'Bàn số '+CAST(@i AS NVARCHAR(100))
		   WHERE ID IN (SELECT TOP 1 ID FROM dbo.TableFood WHERE Name = 'noname')
		   SET @i+=1
	   END
END
go
------------
--SELECT TOP 10 * FROM dbo.Bill WHERE Id NOT IN (SELECT TOP 0 Id FROM dbo.Bill )



---------------
CREATE TRIGGER Trigger_InsertUpdateBill
ON Bill FOR INSERT, UPDATE
AS
BEGIN
	DECLARE @statusBill INT
	DECLARE @billId int
	--
	SELECT @statusBill = inserted.status, @billId = inserted.id
	FROM inserted
	--
	DECLARE @tableId INT

	SELECT @tableId = idtable
	FROM dbo.Bill
	WHERE id = @billId
	--
	IF(@statusBill = 0)
		BEGIN
			UPDATE dbo.TableFood
			SET
            Status = N'Có người'
			WHERE ID = @tableId
		END
    ELSE
		BEGIN
			UPDATE dbo.TableFood
			SET
            Status = N'Trống'
			WHERE ID = @tableId
		END
END
GO
---------------
CREATE TRIGGER Trigger_UpdateFood
ON Food FOR UPDATE,insert
AS
BEGIN
	DECLARE @foodname NVARCHAR(100)

	SELECT @foodname = inserted.name
	FROM inserted

	IF(SELECT COUNT(*)
		FROM dbo.Food
		WHERE Name = @foodname) >= 2
		begin
			ROLLBACK TRAN
		END
        
END
go