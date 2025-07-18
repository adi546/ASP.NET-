USE [agriuatbackup3June2025]
GO
/****** Object:  StoredProcedure [dbo].[Reject_Order_MASL]    Script Date: 7/16/2025 12:19:33 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Reject_Order_MASL]
    @CompanyCode BIGINT,
    @CreateOrderNumber BIGINT,
    @UserCode VARCHAR(50),
    @Email NVARCHAR(120),
    @UserId BIGINT,
    @TMName NVARCHAR(150),
    @Rejectedreason NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
    DECLARE @TotalPrice DECIMAL(18, 2), @CustomerCode VARCHAR(50), @SalesOrganisation VARCHAR(50), @Division VARCHAR(50), @CartId BIGINT;

    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Get the total price, customer code, and cartId for the order to be rejected
        SELECT 
            @TotalPrice = Total_Price, 
            @CustomerCode = CustomerCode,
            @SalesOrganisation = SalesOrganisation,
            @CartId = CartId
        FROM TB_Create_Dealer_Order
        WHERE 
            CompanyCode = @CompanyCode 
            AND CreateOrderNumber = @CreateOrderNumber 
            AND Email = @Email 
            AND UserId = @UserId 
            AND UserCode = @UserCode;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT -1 AS ResultCode, 'No matching record found to fetch order details' AS Message;
            RETURN;
        END
        
        -- Get the division from TB_Cart_Items table using the CartId
        SELECT @Division = Division
        FROM TB_Cart_Items
        WHERE CartId = @CartId;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT -1 AS ResultCode, 'No matching CartId found in TB_Cart_Items' AS Message;
            RETURN;
        END
        
        -- Update the TB_Create_Dealer_Order table for rejection
        UPDATE TB_Create_Dealer_Order
        SET 
            OrderRejectStatus = 1,
            OrderRejectDate = GETDATE(),
            OrderRejectName = @TMName,
            SalesIndentStatus = 'Reject',
            Rejectedreason = @Rejectedreason
        WHERE 
            CompanyCode = @CompanyCode 
            AND CreateOrderNumber = @CreateOrderNumber 
            AND Email = @Email 
            AND UserId = @UserId 
            AND UserCode = @UserCode;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT -1 AS ResultCode, 'Failed to update the order rejection status' AS Message;
            RETURN;
        END
        
        -- Refund the amount to the customer by updating the TB_CreditLimitOfDealer table
        UPDATE TB_CreditLimitOfDealer
        SET 
            AvailableCreditLimit = AvailableCreditLimit + @TotalPrice,
            CreditExposure = CreditExposure - @TotalPrice
        WHERE 
            CustomerCode = @CustomerCode 
            AND SalesOrganisation = @SalesOrganisation 
            AND Division = @Division;

        -- Check if the refund was successful
        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT -1 AS ResultCode, 'Failed to update the credit limit after rejection' AS Message;
            RETURN;
        END

        COMMIT TRANSACTION;
        SELECT 0 AS ResultCode, 'Order rejection and refund successful' AS Message;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        -- Capture error details
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @ErrorSeverity = ERROR_SEVERITY();
        SET @ErrorState = ERROR_STATE();

        -- Log error details into an error log table
        INSERT INTO Error_Log (ProcedureName, ErrorMessage, ErrorSeverity, ErrorState, ErrorDate)
        VALUES ('Reject_Order', @ErrorMessage, @ErrorSeverity, @ErrorState, GETDATE());

        -- Return error details
        SELECT -2 AS ResultCode, @ErrorMessage AS Message;
    END CATCH;
END;
GO
