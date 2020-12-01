USE [MinistryPlatform]
GO
/****** Object:  StoredProcedure [dbo].[service_wifi_activity_log]    Script Date: 12/1/2020 2:59:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[service_wifi_activity_log]

	@DomainID INT

AS

/****************************************
***** WiFi Session to Activity Log ******
*****************************************
A custom Dream City Church procedure for Ministry Platform
Version: 1.0
Author: Stephan Swinford
Date: 12/1/2020

This procedure is provided "as is" with no warranties expressed or implied.

-- Description --
This procedure creates Activity Log entries from WiFi Sessions.

-- Requirements --

1. FrontPorch integration.

2. We have added a custom "Abbreviation" VARCHAR column to our Congregations
table. We use that abbreviation for several purposes, but for this procedure
in particular we use it to match a FrontPorch space to a Congregation in MP.

3. A SQL Server Agent Job that calls this procedure needs to be created, or 
a step needs to be added to an existing daily job. NOTE: Do not use any of the 
built-in MinistryPlatform jobs as ThinkMinistry may update those jobs at any 
time and remove your custom Job Step. Create a new Job with a Daily trigger.
	
	Job Step details: 
		Step Name: Wifi Session to Activity Log (your choice on name) 
		Type: Transact-SQL script (T-SQL) 
		Database: MinistryPlatform 
		Command: EXEC [dbo].[service_wifi_activity_log] @DomainID = 1

https://github.com/Dream-City-Church/mp-wifi-activity-log

*****************************************
************ BEGIN PROCEDURE ************
****************************************/

/*** Create a temporary table for the Audit Log entries ***/
CREATE TABLE #ALAuditInserted (Activity_Log_ID INT)

/*** Insert activity based on Wi-Fi device session ***/
INSERT INTO [dbo].[Activity_Log]
        	([Activity_Date]
        	,[Activity_Type]
        	,[Record_Name]
        	,[Contact_ID]
        	,[Household_ID]
        	,[Page_ID]
        	,[Record_ID]
        	,[Page_Name]
        	,[Table_Name]
        	,[Domain_ID]
        	,[Congregation_ID]
			,Ministry_ID)
OUTPUT INSERTED.Activity_Log_ID
INTO #ALAuditInserted
SELECT [Activity_Date] = WDS.Session_Start
        	,[Activity_Type] = 'WiFi Session'
        	,[Record_Name] = 'WiFi Session at ' + WDS.Wifi_Space + ' for ' + CAST(WDS.Duration_in_Minutes AS VARCHAR) + ' minutes.'
        	,[Contact_ID] = WD.Contact_ID
        	,[Household_ID] = C.Household_ID
        	,[Page_ID] = 481
        	,[Record_ID] = WDS.Wifi_Device_Session_ID
        	,[Page_Name] = 'WiFI Device Sessions'
        	,[Table_Name] = 'WiFI_Device_Sessions'
        	,[Domain_ID] = 1
        	,[Congregation_ID] = (SELECT Congregation_ID FROM Congregations WHERE LEFT(WDS.Wifi_Space,3) = Congregations.Abbreviation)
			,Ministry_ID = 3
FROM dbo.Wifi_Device_Sessions WDS
 INNER JOIN Wifi_Devices WD ON WDS.Wifi_Device_ID = WD.Wifi_Device_ID
 INNER JOIN Contacts C ON C.Contact_ID = WD.Contact_ID
 INNER JOIN Households H ON H.Household_ID = C.Household_ID
 LEFT JOIN Congregations Con ON H.Congregation_ID = Con.Congregation_ID
WHERE WDS.Session_Start >= GetDate()-1
AND WD.Contact_ID IS NOT NULL

/*** Add entries to the Audit Log for created Activity Log entries ***/
INSERT INTO dp_Audit_Log (Table_Name,Record_ID,Audit_Description,User_Name,User_ID,Date_Time)
SELECT 'Activity_Log',#ALAuditInserted.Activity_Log_ID,'Created','Svc Mngr',0,GETDATE()
FROM #ALAuditInserted

/*** Drop the temporary table ***/
DROP TABLE #ALAuditInserted