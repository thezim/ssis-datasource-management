/*

This script is used to update the password of a SQL Server
Integration Service Package (SSIS) data source. The package name,
data source name must be known and entered in to the user variables
section below as well as the desired password string.

Avoid "&'()*+,-./:;<=>?@ characters in the password to prevent
XML, connection string, and SQL reserved character sequences.

*/

USE [msdb]

/* Declare user variable for script. */
DECLARE @package NVARCHAR(MAX) = ''			/* name of package in SSIS server */
DECLARE @datasourcename NVARCHAR(MAX) = ''	/* name of data source as it appears in VS */
DECLARE @password NVARCHAR(MAX) = ''		/* password */

/* Declare XML variable. */
DECLARE @xdoc xml

/* Set password string. */
SELECT		@xdoc = CAST(CAST(p.packagedata AS VARBINARY(MAX)) AS VARCHAR(MAX))
FROM		msdb..sysssispackages p
WHERE		p.name = @package
SET @xdoc.modify('
	declare namespace	DTS="www.microsoft.com/SqlServer/Dts";
	replace value of	(/DTS:Executable/DTS:ConnectionManagers/DTS:ConnectionManager[@DTS:ObjectName=sql:variable("@datasourcename")]/DTS:ObjectData/DTS:ConnectionManager/DTS:Password/text())[1]
	with				sql:variable("@password")
')

/* Update package. */
UPDATE msdb..sysssispackages
SET packagedata = CAST(CAST(@xdoc AS VARBINARY(MAX)) AS IMAGE)
WHERE name = @package
GO