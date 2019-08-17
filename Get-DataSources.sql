/*

This script is used to view all existing SQL Server Integration
Service Package (SSIS) data sources. This information can be used
by either Update-Password.sql or Update-ConnectionString.sql to
update SSIS data sources. Care must be taken as this script will
output clear text passwords of existing data sources. The WHERE
clause below an be uncommented if you know the package you are
interested in.

*/

USE [master]
SET NOCOUNT ON
IF OBJECT_ID('tempdb..#PATHS') IS NOT NULL BEGIN DROP TABLE #PATHS END

;WITH ChildFolders
AS
(
    SELECT      PARENT.parentfolderid,
                PARENT.folderid,
                PARENT.foldername,
                CAST('' AS sysname) AS RootFolder,
                CAST(PARENT.foldername AS VARCHAR(MAX)) AS FullPath,
                0 AS Lvl
    FROM        msdb.dbo.sysssispackagefolders PARENT
    WHERE       PARENT.parentfolderid IS NULL
    UNION ALL
    SELECT      CHILD.parentfolderid,
                CHILD.folderid,
                CHILD.foldername,
                CASE ChildFolders.Lvl
                    WHEN 0 THEN CHILD.foldername
                    ELSE ChildFolders.RootFolder
                END AS RootFolder,
                CAST(ChildFolders.FullPath + '/' + CHILD.foldername AS VARCHAR(MAX)) AS FullPath,
                ChildFolders.Lvl + 1 AS Lvl
    FROM        msdb.dbo.sysssispackagefolders CHILD
    INNER JOIN  ChildFolders ON ChildFolders.folderid = CHILD.parentfolderid
)
SELECT      CASE F.FullPath
				WHEN '' THEN '/'
				ELSE F.FullPath
			END AS FullPath,
            P.id
INTO		#PATHS
FROM        ChildFolders F
INNER JOIN  msdb.dbo.sysssispackages P on P.folderid = F.folderid

DECLARE @PACKAGES TABLE (
	PackageId VARCHAR(MAX),
	PackageName VARCHAR(MAX),
	PackageNameInternal VARCHAR(MAX),
	DataSourceName VARCHAR(MAX),
	DataSourceType VARCHAR(MAX),
	[Password] VARCHAR(MAX),
	ConnectionString VARCHAR(MAX)
)
DECLARE @id VARCHAR(MAX), @name VARCHAR(MAX), @xdoc XML
DECLARE package_cursor CURSOR FOR
	SELECT		p.id,
				p.name AS Name,
				CAST(CAST(CAST(p.packagedata AS VARBINARY(MAX)) AS VARCHAR(MAX)) AS xml) AS PackageXml
	FROM		msdb..sysssispackages p
	ORDER BY	p.name
OPEN package_cursor
FETCH NEXT FROM package_cursor INTO @id, @name, @xdoc
WHILE @@FETCH_STATUS = 0
BEGIN
	;WITH XMLNAMESPACES ('www.microsoft.com/SqlServer/Dts' as DTS)
	INSERT INTO @PACKAGES
	/* catches OLEDB data sources */
	SELECT	[PackageId] = @id,
			[PackageName] = @name,
			[PackageNameInternal]= packagedata.item.value('../../../../@DTS:ObjectName', 'varchar(MAX)'),
			[DataSourceName]= packagedata.item.value('../../@DTS:ObjectName', 'varchar(MAX)'),
			[DataSourceType]= packagedata.item.value('../../@DTS:CreationName', 'varchar(MAX)'),
			[Password]= packagedata.item.value('.', 'varchar(MAX)'),
			[ConnectionString] = packagedata.item.value('@DTS:ConnectionString', 'varchar(MAX)')
	FROM	@xdoc.nodes('//*[@DTS:ConnectionString]') AS packagedata(item)
	UNION
	/* catches SMO and SMTP data sources */
	SELECT	[PackageId] = @id,
			[PackageName] = @name,
			[PackageNameInternal]= packagedata.item.value('../../../../@DTS:ObjectName', 'varchar(MAX)'),
			[DataSourceName]= packagedata.item.value('../../@DTS:ObjectName', 'varchar(MAX)'),
			[DataSourceType]= packagedata.item.value('../../@DTS:CreationName', 'varchar(MAX)'),
			[Password]= packagedata.item.value('.', 'varchar(MAX)'),
			[ConnectionString] = packagedata.item.value('@ConnectionString', 'varchar(MAX)')
	FROM	@xdoc.nodes('//*[@ConnectionString]') AS packagedata(item)
	FETCH NEXT FROM package_cursor INTO @id, @name, @xdoc
END
CLOSE package_cursor;
DEALLOCATE package_cursor;
SET NOCOUNT OFF
SELECT			p.FullPath,
				k.PackageName,
				k.PackageNameInternal,
				k.DataSourceName,
				k.DataSourceType,
				k.[Password],
				k.ConnectionString
FROM			@PACKAGES k
LEFT OUTER JOIN	#PATHS p
				ON p.id = k.PackageId
				AND DataSourceType IN ('OLEDB', 'SMOServer')

/*
Uncomment the below if interested in only specfic
package(s), update IN statement.
*/

/*
WHERE			k.PackageName IN (
					'SOMEPACKAGENAME'
				)
*/
ORDER BY		PackageName