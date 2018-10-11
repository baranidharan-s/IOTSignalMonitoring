--------------------------------------------------------------------------------
--Procedure Name: SP_RaiseSignal
--Description: This Procedure is used to identify issues in the signal by matching the rules provided by user.
--------------------------------------------------------------------------------

CREATE PROC SP_RaiseSignal(
	@P_IsUT	 BIT = 0 --0-> Normal Execution, 1-> Execution for Unit Testing
)
AS
BEGIN
	--Variable Declaration
	BEGIN
		DECLARE @P_JSON_Input varchar(MAX) = '' --Input Data collected from various Signals in JSON file format
			,	@P_JSON_Output varchar(MAX) = '' --Output JSON file which stores abnormal activity in the Signal
			,	@P_JSON_Condition VARCHAR(MAX) = '' --JSON file which contains User Rules
	
		--This table is used to store converted JSON Input file and error Messages
		DECLARE @VT_JsonTableOutput TABLE (
					JTO_ID			INTEGER	
				,	JTO_Signal		VARCHAR(100)
				,	JTO_Value		VARCHAR(500)
				,	JTO_ValueType	VARCHAR(20)
				,	JTO_ERROR		VARCHAR(1000) DEFAULT ''
				)

		--This table is used to store User rules
		DECLARE @VT_JsonTableCondition TABLE (
					JTC_ID			INTEGER	
				,	JTC_Signal		VARCHAR(100)
				,	JTC_Value		VARCHAR(500)
				,	JTC_ValueType	VARCHAR(20)
				,	JTC_Operator	CHAR(2)
				)

	END

	--Reading JSON files, converting in table format and storing it.
	BEGIN

		--Reading JSON File
		SELECT @P_JSON_Input = BulkColumn
		FROM OPENROWSET (BULK '<FileLocation>\raw_signal.JSON', SINGLE_CLOB) as j

		SELECT @P_JSON_Condition = BulkColumn
		FROM OPENROWSET (BULK '<FileLocation>\Signal_rules.JSON', SINGLE_CLOB) as j

		--Converting JSON file in table format
		--Function FN_ParseJSON can be replaced by ParseJSON, which is an In-build SQL Function in SQL Server 2016. Since this procedure is created in SQL Server 2012, we need use the custom ParseJSON function.
		INSERT INTO @VT_JsonTableOutput
			(JTO_ID, JTO_Signal, JTO_Value, JTO_ValueType)
		SELECT JTO_ID, JTO_Signal, JTO_Value, JTO_ValueType
		FROM	dbo.FN_ParseJSON(@P_JSON_Input, 0)

		INSERT INTO @VT_JsonTableCondition
			(JTC_ID, JTC_Signal, JTC_Value, JTC_ValueType, JTC_Operator)
		SELECT JTO_ID, JTO_Signal, JTO_Value, JTO_ValueType, JTO_Operator
		FROM	dbo.FN_ParseJSON(@P_JSON_Condition, 1)

	END

	--Signal Input has date Time value which cannot be accepted by SQL Server. So swapping Month and Day in the dataTime values.
	UPDATE	@VT_JsonTableOutput
	SET		JTO_Value = SUBSTRING(JTO_Value,4,2) 
						+ '/'+ LEFT(JTO_Value,2) 
						+ SUBSTRING(JTO_Value,6,LEN(JTO_Value))
	WHERE	JTO_ValueType = 'DateTime'
	
	--Validating the Signal values with User Rules
	UPDATE	JTO
	SET		JTO_ERROR += 
					CASE 
						WHEN NOT JTC_Operator IN ('>','>=','=','!=','<','<=') --Validating operator from the User Rules
							THEN 'Invalid Operator ' + JTC_Operator +'; ' + CHAR(13)
						WHEN JTO_ValueType = 'DateTime'
							THEN (
								CASE 
									WHEN (	ISDATE(LEFT(JTO_Value,23)) = 0 --SQL Server accepts only 23 character Datatime format, but signal provides 24 character datetime value
										OR	NOT JTO_Value LIKE '%__:__:__:____%'
										OR ISNUMERIC(REPLACE(LTRIM(SUBSTRING(JTO_Value,11,LEN(JTO_Value))),':','')) = 0
										)--Validating Signal Input Date format
										THEN 'Value is not in DateTime format;'+ CHAR(13)
									WHEN JTC_Value = 'today' --If user rule is to validate the date as Today
										THEN (CASE
												WHEN JTC_Operator = '<'
													AND CAST(LEFT(JTO_Value,23) AS DATETIME) < GETDATE()
													THEN 'Value should not be less than' + CONVERT(VARCHAR, GETDATE(), 106) + ' '+ CONVERT(VARCHAR, GETDATE(), 114) +'; ' + CHAR(13)
												WHEN JTC_Operator = '<='
													AND CAST(LEFT(JTO_Value,23) AS DATETIME) < GETDATE()
													THEN 'Value should not be less than or Equal to ' + CONVERT(VARCHAR, GETDATE(), 106) + ' '+ CONVERT(VARCHAR, GETDATE(), 114) +'; ' + CHAR(13)
												WHEN JTC_Operator = '='
													AND CAST(LEFT(JTO_Value,23) AS DATETIME) < GETDATE()
													THEN 'Value should not be Equal to ' + CONVERT(VARCHAR, GETDATE(), 106) + ' '+ CONVERT(VARCHAR, GETDATE(), 114) +'; ' + CHAR(13)
												WHEN JTC_Operator = '>'
													AND CAST(LEFT(JTO_Value,23) AS DATETIME) > GETDATE()
													THEN 'Value should not be greater than' + CONVERT(VARCHAR, GETDATE(), 106) + ' '+ CONVERT(VARCHAR, GETDATE(), 114) +'; ' + CHAR(13)
												WHEN JTC_Operator = '>='
													AND CAST(LEFT(JTO_Value,23) AS DATETIME) >= GETDATE()
													THEN 'Value should not be greater than or Equal to ' + CONVERT(VARCHAR, GETDATE(), 106) + ' '+ CONVERT(VARCHAR, GETDATE(), 114) +'; ' + CHAR(13)
												WHEN JTC_Operator = '!='
													AND CAST(LEFT(JTO_Value,23) AS DATETIME) != GETDATE()
													THEN 'Value should be Equal to ' + CONVERT(VARCHAR, GETDATE(), 106) + ' '+ CONVERT(VARCHAR, GETDATE(), 114) +'; ' + CHAR(13)
												ELSE ''
											END
											)
									WHEN NOT JTC_Value = 'today' --If user rule is to validate a specific date
										AND ISDATE(LEFT(JTC_Value,23)) = 1
										AND JTO_Value LIKE '%__:__:__:____%'
										AND ISNUMERIC(REPLACE(LTRIM(SUBSTRING(JTO_Value,11,LEN(JTO_Value))),':','')) = 1 --User entered datetime gets validated
										THEN (	CASE
													WHEN JTC_Operator = '<'
														AND CAST(LEFT(JTO_Value,23) AS DATETIME) < CAST(LEFT(JTC_Value,23) AS DATETIME)
														THEN 'Value should not be less than' + JTC_Value +'; ' + CHAR(13)
													WHEN JTC_Operator = '<='
														AND CAST(LEFT(JTO_Value,23) AS DATETIME) < CAST(LEFT(JTC_Value,23) AS DATETIME)
														THEN 'Value should not be less than or Equal to ' + JTC_Value +'; ' + CHAR(13)
													WHEN JTC_Operator = '='
														AND CAST(LEFT(JTO_Value,23) AS DATETIME) < CAST(LEFT(JTC_Value,23) AS DATETIME)
														THEN 'Value should not be Equal to ' + JTC_Value +'; ' + CHAR(13)
													WHEN JTC_Operator = '>'
														AND CAST(LEFT(JTO_Value,23) AS DATETIME) > CAST(LEFT(JTC_Value,23) AS DATETIME)
														THEN 'Value should not be greater than' + JTC_Value +'; ' + CHAR(13)
													WHEN JTC_Operator = '>='
														AND CAST(LEFT(JTO_Value,23) AS DATETIME) >= CAST(LEFT(JTC_Value,23) AS DATETIME)
														THEN 'Value should not be greater than or Equal to ' + JTC_Value +'; ' + CHAR(13)
													WHEN JTC_Operator = '!='
														AND CAST(LEFT(JTO_Value,23) AS DATETIME) != CAST(LEFT(JTC_Value,23) AS DATETIME)
														THEN 'Value should be Equal to ' + JTC_Value +'; ' + CHAR(13)
													ELSE ''
						
												END
												)
									WHEN NOT JTC_Value = 'today' 
										AND (ISDATE(LEFT(JTC_Value,23)) = 0
										OR NOT JTO_Value LIKE '%__:__:__:____%'
										OR ISNUMERIC(REPLACE(LTRIM(SUBSTRING(JTO_Value,11,LEN(JTO_Value))),':','')) = 0 --User Entered datetime value to compare signal data is invalid.
										)
										THEN 'Invalid Date Value provided to compare ' + JTC_Value +'; ' + CHAR(13)
								
									ELSE ''
								END
								)
						WHEN JTO_ValueType = 'Integer'
							THEN (
								CASE 
									WHEN ISNUMERIC(JTO_Value) = 0
										THEN 'Value is not in Numeric;' + CHAR(13)
									WHEN JTC_Operator = '<'
										AND CAST(JTO_Value AS DECIMAL(15,2)) < CAST(JTC_Value AS DECIMAL(15,2))
										THEN 'Value should not be less than' + JTC_Value +'; ' + CHAR(13)
									WHEN JTC_Operator = '<='
										AND CAST(JTO_Value AS DECIMAL(15,2)) < CAST(JTC_Value AS DECIMAL(15,2))
										THEN 'Value should not be less than or Equal to ' + JTC_Value +'; ' + CHAR(13)
									WHEN JTC_Operator = '='
										AND CAST(JTO_Value AS DECIMAL(15,2)) < CAST(JTC_Value AS DECIMAL(15,2))
										THEN 'Value should not be Equal to ' + JTC_Value +'; '  + CHAR(13)
									WHEN JTC_Operator = '>'
										AND CAST(JTO_Value AS DECIMAL(15,2)) > CAST(JTC_Value AS DECIMAL(15,2))
										THEN 'Value should not be greater than' + JTC_Value +'; ' + CHAR(13)
									WHEN JTC_Operator = '>='
										AND CAST(JTO_Value AS DECIMAL(15,2)) >= CAST(JTC_Value AS DECIMAL(15,2))
										THEN 'Value should not be greater than or Equal to ' + JTC_Value +'; ' + CHAR(13)
									WHEN JTC_Operator = '!='
										AND CAST(JTO_Value AS DECIMAL(15,2)) != CAST(JTC_Value AS DECIMAL(15,2))
										THEN 'Value should be Equal to ' + JTC_Value +'; ' + CHAR(13)
								
									ELSE ''
								END
								)
						WHEN JTO_ValueType = 'String'
						THEN (
							CASE --For String data type, we are only validating Equals and Not Equals as other comparators has no meaning as of now. If required, it needs to be added here.
								WHEN JTC_Operator = '!='
									AND JTO_Value != JTC_Value
									THEN 'Value should be Equal to ' + JTC_Value +'; ' + CHAR(13)
								WHEN JTC_Operator = '='
									AND JTO_Value = JTC_Value
									THEN 'Value should not be Equal to ' + JTC_Value +'; ' + CHAR(13)
								WHEN NOT JTC_Operator IN ('=','!=')
									THEN 'Invalid Operator ' + JTC_Operator +'; ' + CHAR(13)
								ELSE ''
							END
							)

						ELSE ''
					END
	FROM	@VT_JsonTableOutput		JTO
	JOIN	@VT_JsonTableCondition	ON JTO_Signal = JTC_Signal
									AND JTO_ValueType = JTC_ValueType

	IF @P_IsUT = 0 --If it is a normal execution
	BEGIN

		--Converting output in JSON format
		SELECT	@P_JSON_Output	+= '{''Signal'':''' + JTO_Signal 
								+ ''', ''Value'':''' + JTO_Value
								+ ''', ''ValueType'':''' +  JTO_ValueType  
								+ ''', ''Error'':''' +  JTO_ERROR 
								+ '''}' + CHAR(13)
		FROM	@VT_JsonTableOutput
		WHERE	LEN(JTO_ERROR) > 1

		SELECT '[' + @P_JSON_Output  + ']' AS RESULT

	END
	ELSE --If the execution is for Unit testing
	BEGIN

		SELECT	JTO_Signal
			,	JTO_Value
			,	JTO_ValueType
			,	JTO_ERROR
		FROM @VT_JsonTableOutput
		WHERE	LEN(JTO_ERROR) > 1

	END

END