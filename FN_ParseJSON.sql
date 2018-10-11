--------------------------------------------------------------------------------
--Function Name: FN_ParseJSON
--Description: This function is used to convert JSON value to table
--	This function is required if SQL Server version is less than 2016
--------------------------------------------------------------------------------

CREATE FUNCTION dbo.FN_ParseJSON (
	 @P_JSON_Input AS varchar(MAX) --Input JSON text
	,@P_IsCondition AS TINYINT	--0=> Used to read Input JSON file and returns value for ID, Signal, Value and Value Type
								--1=> Used to read User rules JSON file and returns value for ID, Signal, Value, Value Type and Operator
								--2=> Used to read Unit Testing JSON file and returns value for ID, Signal, Value, Value Type and Error
	 )
	RETURNS @VT_JsonTableOutput TABLE (
			JTO_ID			INTEGER	IDENTITY(1,1)
		,	JTO_Signal		VARCHAR(100)
		,	JTO_Value		VARCHAR(500)
		,	JTO_ValueType	VARCHAR(20)
		,	JTO_Operator	CHAR(2)
		,	JTO_Error		VARCHAR(1000)
		)
AS
BEGIN

	DECLARE	@V_Signal		AS VARCHAR(100) = ''
		,	@V_Value		AS VARCHAR(500) = ''
		,	@V_ValueType	AS VARCHAR(20) = ''
		,	@V_Operator		AS CHAR(2) = ''
		,	@V_Error		AS VARCHAR(1000) = ''
		,	@V_Index		AS INTEGER = 0
		,	@V_RecordEnd	AS INTEGER = 0

	--Replacing JSON common characters
	SET	@P_JSON_Input = 
				REPLACE(
					REPLACE(REPLACE(REPLACE(
						REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							REPLACE( REPLACE(
								REPLACE(REPLACE(REPLACE(@P_JSON_Input,'{',''),'}',''),'''','')
							,']',''), '[','')
						,CHAR(12),','),CHAR(10),','),CHAR(13),','), CHAR(09),','),',,',',')
					,' : ',':'),' :',':'),': ',':') + ','
				,'value_type', 'Type') --Replacing Value_type to Type to avoid comparison issue

	--Below query extracts data from JSON string
	SELECT	@V_Index = CHARINDEX(':',@P_JSON_Input)

	WHILE (@V_Index > 1)
	BEGIN
	
		SELECT	@V_RecordEnd = CHARINDEX(',',@P_JSON_Input,@V_Index)

		IF LEFT(@P_JSON_Input,@V_Index) LIKE '%SIGNAL%'
		BEGIN
			SELECT	@V_Signal = LTRIM(RTRIM(SUBSTRING(@P_JSON_Input, @V_Index+1, @V_RecordEnd - @V_Index -1)))
		END
		ELSE IF LEFT(@P_JSON_Input,@V_Index) LIKE '%value%'
		BEGIN
			SELECT	@V_Value = LTRIM(RTRIM(SUBSTRING(@P_JSON_Input, @V_Index+1, @V_RecordEnd - @V_Index -1)))
		END
		ELSE IF LEFT(@P_JSON_Input,@V_Index) LIKE '%type%'
		BEGIN
			SELECT	@V_ValueType = LTRIM(RTRIM(SUBSTRING(@P_JSON_Input, @V_Index+1, @V_RecordEnd - @V_Index -1)))
			
			IF @P_IsCondition = 0 --Only to read Input JSON file
			BEGIN
				INSERT INTO @VT_JsonTableOutput
					(JTO_Signal, JTO_Value,	JTO_ValueType)
				VALUES
					(@V_Signal, @V_Value, @V_ValueType)

				SELECT	@V_Signal	= ''
					,	@V_Value	= ''
					,	@V_ValueType= ''
			END
		END
		ELSE IF LEFT(@P_JSON_Input,@V_Index) LIKE '%Operator%'
		BEGIN
			SELECT	@V_Operator = LTRIM(RTRIM(SUBSTRING(@P_JSON_Input, @V_Index+1, @V_RecordEnd - @V_Index -1)))
			
			IF @P_IsCondition = 1 --To read User rules JSON file
			BEGIN
				INSERT INTO @VT_JsonTableOutput
					(JTO_Signal, JTO_Value,	JTO_ValueType, JTO_Operator)
				VALUES
					(@V_Signal, @V_Value, @V_ValueType,@V_Operator)

				SELECT	@V_Signal	= ''
					,	@V_Value	= ''
					,	@V_ValueType= ''
					,	@V_Operator = ''
			END
		END
		ELSE IF LEFT(@P_JSON_Input,@V_Index) LIKE '%Error%'
		BEGIN
			SELECT	@V_Operator = LTRIM(RTRIM(SUBSTRING(@P_JSON_Input, @V_Index+1, @V_RecordEnd - @V_Index -1)))
			
			IF @P_IsCondition = 2 --To read Unit Testing Input JSON file
			BEGIN
				INSERT INTO @VT_JsonTableOutput
					(JTO_Signal, JTO_Value,	JTO_ValueType, JTO_Error)
				VALUES
					(@V_Signal, @V_Value, @V_ValueType, @V_Error)

				SELECT	@V_Signal	= ''
					,	@V_Value	= ''
					,	@V_ValueType= ''
					,	@V_Error	= ''
			END
		END
		SELECT	@P_JSON_Input = SUBSTRING(@P_JSON_Input, @V_RecordEnd +1,LEN(@P_JSON_Input))
			,	@V_Index = 0
			,	@V_RecordEnd = 0
	
		SELECT	@V_Index = CHARINDEX(':',@P_JSON_Input)
	
	END
	RETURN

END
