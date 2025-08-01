USE [agriuatbackup3June2025]
GO
/****** Object:  StoredProcedure [dbo].[AddtoCart_MASL]    Script Date: 7/15/2025 4:07:58 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AddtoCart_MASL]
		 
	       @UserCode NVARCHAR(20),
		   @CompanyCode BIGINT,
		   @Material_Code NVARCHAR(50),
		   @Material_Description NVARCHAR(120),
		   @Crop NVARCHAR(40),
		   @Variety NVARCHAR(40),
		   @Stage NVARCHAR(20),
		   @Grade NVARCHAR(20),
		   @Unit_Of_Measurement NVARCHAR(20),
		   @Quantity INT,
		   @CartId BIGINT, 
		   @Email NVARCHAR(120),
		   @UserId BIGINT,
		   @SrNo INT, 
		   @Role_Details NVARCHAR(MAX),
		   @IsActive_User BIT,
		   @UserName NVARCHAR(MAX),
		   @ImagePath NVARCHAR(MAX),
		   @Rate FLOAT,
		   @QtyIntoRate_Amt FLOAT,
		   @Unrestricted_Kgs DECIMAL(15,3),
		   @PackSize NVARCHAR(50),
		   @Division NVARCHAR(5),
		   @Status INT OUTPUT,         -- Output parameter for status (1 = success, 0 = failure)
		   @Message NVARCHAR(500) OUTPUT -- Output message for success/error description
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY

	DECLARE @LastWord NVARCHAR(20);
DECLARE @PackSizeValue DECIMAL(10, 4);
DECLARE @PackSizeKG DECIMAL(10, 4);


SET @LastWord = RIGHT(@Material_Description, CHARINDEX(' ', REVERSE(@Material_Description) + ' ') - 1);

-- Step 2: Convert to KG based on unit
IF UPPER(@LastWord) LIKE '%KG'
BEGIN
    SET @PackSizeValue = TRY_CAST(REPLACE(UPPER(@LastWord), 'KG', '') AS DECIMAL(10, 4));
    SET @PackSizeKG = @PackSizeValue;
END
ELSE IF UPPER(@LastWord) LIKE '%G'
BEGIN
    SET @PackSizeValue = TRY_CAST(REPLACE(UPPER(@LastWord), 'G', '') AS DECIMAL(10, 4));
    SET @PackSizeKG = @PackSizeValue / 1000;
END
ELSE
BEGIN
    SET @Status = 0;
    SET @Message = 'Unable to extract valid pack size (G or KG) from Material Description.';
    RETURN;
END

-- Step 3: Validate quantity
-- User quantity is already in KG (float)
IF @PackSizeKG IS NOT NULL AND (@Quantity < @PackSizeKG OR (@Quantity % @PackSizeKG) <> 0)
BEGIN
    SET @Status = 0;
    SET @Message = 'Quantity must be in multiples of ' + CAST(@PackSizeKG AS NVARCHAR) + ' KG as per pack size.';
    RETURN;
END

        -- Insert into cart table
	    INSERT INTO TB_Cart_Items
		(
		    UserCode,
            CompanyCode,
		    Material_Code,
		    Material_Description,
		    Crop,
		    Variety,
		    Stage,
		    Grade,
		    Unit_Of_Measurement,
		    Quantity,
     	    CartId,
		    Email,
		    UserId,
		    SrNo,
		    Role_Details,
		    IsActive_User,
		    UserName,
		    Rate,
		    Qty_Into_Rate_Amt,
		    Unrestricted_Kgs,
			ImagePath,
			PackSize,
			Division 
	    )
	    VALUES (
		    @UserCode,
            @CompanyCode,
   		    @Material_Code,
            @Material_Description,
		    @Crop,
            @Variety,
		    @Stage,
		    @Grade,
		    @Unit_Of_Measurement,
		    @Quantity,   
		    @CartId,
		    @Email,
		    @UserId,
		    @SrNo,
		    @Role_Details,
		    @IsActive_User,
		    @UserName,
		    @Rate,
		    @Rate * @Quantity,  -- Calculate amount dynamically
		    @Unrestricted_Kgs,
			@ImagePath,
			@PackSize,
			@Division 
       	);
  
        -- Return success
        SET @Status = 1;
        SET @Message = 'Item added to cart successfully.';
    END TRY
    BEGIN CATCH
        -- Log error into ErrorLog table
        INSERT INTO ErrorLog_AddtoCart (ErrorMessage, ErrorSeverity, ErrorState, ProcedureName, ErrorLine, ErrorDate)
        VALUES (
            ERROR_MESSAGE(),  -- Error description
            ERROR_SEVERITY(), -- Error severity level
            ERROR_STATE(),    -- Error state
            'AddtoCart',      -- Procedure name
            ERROR_LINE(),     -- Line number where error occurred
            GETDATE()         -- Timestamp
        );

        -- Return failure
        SET @Status = 0;
        SET @Message = 'Error adding item to cart: ' + ERROR_MESSAGE();
    END CATCH;
END;
GO
