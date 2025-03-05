----------------------------CREATE PROCEDURE----------------------------
USE [DB]
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'Name')
	DROP PROCEDURE Index_Rebuild_Update
GO
/****** Object:  StoredProcedure [dbo].[]******/
CREATE PROCEDURE Name
AS
BEGIN


END
GO

----------------------------ALTER PROCEDURE----------------------------
USE [DB]
GO
/****** Object:  StoredProcedure [dbo].[]******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	
	SET NOCOUNT ON;
	
	
	SET NOCOUNT OFF;
END
GO

