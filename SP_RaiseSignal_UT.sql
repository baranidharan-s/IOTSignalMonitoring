--------------------------------------------------------------------------------
--Procedure Name: SP_RaiseSignal_UT
--Description: This Procedure is used unit testing to identify issues in the SP_RaiseSignal procedure
--------------------------------------------------------------------------------

CREATE PROC SP_RaiseSignal_UT
AS
BEGIN
	--Variable Declaration
	BEGIN
		DECLARE @P_JSON_InputTestData varchar(MAX) = '' --Input Test data in JSON Format
			,	@P_JSON_TestResult varchar(MAX) = '' --Store Final test result
	
		--Table to store the output data from the execution of SP_RaiseSignal procedure
		DECLARE @VT_RaiseSignal_Output TABLE (
					RSO_ID			INTEGER	
				,	RSO_Signal		VARCHAR(100)
				,	RSO_Value		VARCHAR(500)
				,	RSO_ValueType	VARCHAR(20)
				,	RSO_ERROR		VARCHAR(1000) DEFAULT ''
				)

		--Table to store the Unit Testing Test Data
		DECLARE @VT_RaiseSignal_TestData TABLE (
					RST_ID			INTEGER	
				,	RST_Signal		VARCHAR(100)
				,	RST_Value		VARCHAR(500)
				,	RST_ValueType	VARCHAR(20)
				,	RST_ERROR		VARCHAR(1000) DEFAULT ''
				)
	END

	--Converting JSON Unit testing data into Table format
	BEGIN

		SELECT @P_JSON_InputTestData = BulkColumn
		FROM OPENROWSET (BULK '<FileLocation>\raw_signal_UT.JSON', SINGLE_CLOB) as j


		INSERT INTO @VT_RaiseSignal_TestData
			(RST_ID, RST_Signal, RST_Value, RST_ValueType, RST_ERROR)
		SELECT JTO_ID, JTO_Signal, JTO_Value, JTO_ValueType, JTO_ERROR
		FROM	dbo.FN_ParseJSON(@P_JSON_InputTestData, 2)

	END

	--Stored Procedure Execution
	INSERT INTO @VT_RaiseSignal_Output
		(RSO_ID, RSO_Signal, RSO_Value, RSO_ValueType, RSO_ERROR)
	EXEC SP_RaiseSignal 1
	
	--Comparing Output Data with the Unit Testing Data
	SELECT	@P_JSON_TestResult	+= '{''Signal'':''' + RST_Signal 
							+ ''', ''Value'':''' + RST_Value
							+ ''', ''ValueType'':''' +  RST_ValueType  
							+ ''', ''Expected Output'':''' +  RST_ERROR 
							+ ''', ''Actual Output'':''' +  RSO_ERROR
							+ '''}' + CHAR(13)
	FROM	@VT_RaiseSignal_TestData
	JOIN	@VT_RaiseSignal_Output	ON	RSO_Signal = RST_Signal
									AND RSO_ValueType = RST_ValueType
									AND	RSO_Value	= RST_Value
	WHERE	NOT ISNULL(RSO_ERROR,'') = ISNULL(RST_ERROR,'') 

	--Final Output
	IF LEN(@P_JSON_TestResult) > 1
		SELECT '[' + @P_JSON_TestResult + ']' AS RESULT
	ELSE 
		SELECT '{''Result'':''Unit Testing is Success''}' AS RESULT

END