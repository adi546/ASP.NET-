USE [agriuatbackup3June2025]
GO
/****** Object:  StoredProcedure [dbo].[GetPackSizeFromMaterialDescription]    Script Date: 7/21/2025 2:35:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GetPackSizeFromMaterialDescription]
    @CompanyCode BIGINT,
    @CartId BIGINT,
    @CartItemId BIGINT
AS
BEGIN
    DECLARE @Material_Description NVARCHAR(255);
    DECLARE @LastWord NVARCHAR(20);
    DECLARE @PackSizeValue DECIMAL(10, 4);
    DECLARE @PackSizeKG DECIMAL(10, 4);
    DECLARE @Status INT = 1; -- Success
    DECLARE @Message NVARCHAR(100);

    -- Step 1: Retrieve the Material_Description for the CartItem
    SELECT @Material_Description = Material_Description
    FROM [dbo].[TB_Cart_Items]
    WHERE CompanyCode = @CompanyCode AND CartId = @CartId AND CartItemId = @CartItemId;

    -- Check if Material_Description is valid
    IF @Material_Description IS NULL OR LEN(@Material_Description) = 0
    BEGIN
        SET @Status = 0;
        SET @Message = 'Material Description cannot be null or empty.';
        SELECT @Status AS Status, @Message AS Message;
        RETURN;
    END

    -- Step 2: Extract the last word from Material_Description
    SET @LastWord = RIGHT(@Material_Description, CHARINDEX(' ', REVERSE(@Material_Description) + ' ') - 1);

    -- Step 3: Convert to KG based on unit (KG or G)
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
        SET @Message = 'Unable to extract valid pack size (G or KG) from Material Description: ' + @Material_Description;
        SELECT @Status AS Status, @Message AS Message;
        RETURN;
    END

    -- Step 4: Return the extracted pack size
    IF @PackSizeKG IS NOT NULL
    BEGIN
        SELECT @PackSizeKG AS PackSizeKG, @Status AS Status, 'Pack size extracted successfully' AS Message;
    END
    ELSE
    BEGIN
        SET @Status = 0;
        SET @Message = 'Failed to extract valid pack size.';
        SELECT @Status AS Status, @Message AS Message;
    END
END

GO
