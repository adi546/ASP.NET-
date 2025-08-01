USE [agriuatbackup3June2025]
GO
/****** Object:  StoredProcedure [dbo].[Update_CartItems_Qty_Rate_Into_Amount]    Script Date: 7/16/2025 9:15:43 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Update_CartItems_Qty_Rate_Into_Amount]
    @CompanyCode BIGINT,
    @CartItemId BIGINT,
    @CartId BIGINT,
    @Quantity INT,
    @Rate FLOAT,
    @UserCode NVARCHAR(50),
    @TotalPrice FLOAT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @RoleId INT;
        DECLARE @CustomerCode NVARCHAR(50);
        DECLARE @SalesOrganisation NVARCHAR(50);
        DECLARE @OldOrderAmount FLOAT = 0;
        DECLARE @NewOrderAmount FLOAT = 0;
        DECLARE @RefundAmount FLOAT = 0;

        -- Get RoleId
        SELECT @RoleId = RoleId 
        FROM Users 
        WHERE UserCode = @UserCode;

        -- STEP 1: Always update TB_Cart_Items
        UPDATE [dbo].[TB_Cart_Items]
        SET
            Quantity = @Quantity,
            QtyUpdateBy = @UserCode,
            UpdatedAt = GETDATE(),
            Qty_Into_Rate_Amt = @Quantity * @Rate
        WHERE 
            CompanyCode = @CompanyCode AND 
            CartItemId = @CartItemId AND 
            CartId = @CartId;

        -- STEP 2: Recalculate total from cart
        SELECT @NewOrderAmount = CAST(SUM(Qty_Into_Rate_Amt) AS FLOAT)
        FROM [dbo].[TB_Cart_Items]
        WHERE CompanyCode = @CompanyCode AND CartId = @CartId;

        -- Assign output
        SET @TotalPrice = @NewOrderAmount;

        -- STEP 3: If RoleId ≠ 1 (i.e., TM or Admin), update dealer order and refund if applicable
        IF @RoleId <> 1
        BEGIN
            SELECT 
                @OldOrderAmount = ISNULL(Total_Price, 0),
                @CustomerCode = CustomerCode,
                @SalesOrganisation = SalesOrganisation
            FROM [dbo].[TB_Create_Dealer_Order]
            WHERE CompanyCode = @CompanyCode AND CartId = @CartId;

            -- Refund logic if applicable
            IF @OldOrderAmount > @NewOrderAmount
            BEGIN
                SET @RefundAmount = @OldOrderAmount - @NewOrderAmount;

                UPDATE [dbo].[TB_CreditLimitOfDealer]
                SET 
                    AvailableCreditLimit = AvailableCreditLimit + @RefundAmount,
                    CreditExposure = CreditExposure - @RefundAmount
                WHERE 
                    CustomerCode = @CustomerCode AND
                    SalesOrganisation = @SalesOrganisation;
            END

            -- Update dealer order table
            UPDATE [dbo].[TB_Create_Dealer_Order]
            SET 
                Total_Price = @NewOrderAmount,
                UpdatedAt = GETDATE()
            WHERE CompanyCode = @CompanyCode AND CartId = @CartId;
        END

        -- Success Result
        SELECT 0 AS ResultCode, @TotalPrice AS UpdatedTotalPrice;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMessage NVARCHAR(MAX) = ERROR_MESSAGE();
        DECLARE @ErrProcedure NVARCHAR(128) = ERROR_PROCEDURE();
        DECLARE @ErrLine NVARCHAR(10) = CAST(ERROR_LINE() AS NVARCHAR);
        DECLARE @ControllerName NVARCHAR(128) = 'Update_CartItems_Qty_Rate_Into_Amount';
        DECLARE @MethodName NVARCHAR(256) = @ErrProcedure + ' (Line: ' + @ErrLine + ')';
        DECLARE @LogTable NVARCHAR(128) = 'ErrorLog_Update_CartItems_Qty_Rate_Into_Amount';
        DECLARE @DynamicSQL NVARCHAR(MAX);

        SET @DynamicSQL = N'
            INSERT INTO [dbo].[' + @LogTable + N'] 
            (ControllerName, MethodName, ErrorMessage, CreatedAt)
            VALUES (@ControllerName, @MethodName, @ErrorMessage, GETDATE());';

        EXEC sp_executesql 
            @DynamicSQL,
            N'@ControllerName NVARCHAR(128), @MethodName NVARCHAR(256), @ErrorMessage NVARCHAR(MAX)',
            @ControllerName = @ControllerName,
            @MethodName = @MethodName,
            @ErrorMessage = @ErrMessage;

        SELECT -99 AS ResultCode, @ErrMessage AS ErrorMessage;
    END CATCH
END;
GO
