-- =============================================  
-- Author: Sait ORHAN  
-- Create date: 2020-12-10
-- Description: Getting indexes, avg fragmentations, gives advice for index, creates reorganize and rebuild queries, table space in MB 
-- LinkedIn: https://www.linkedin.com/in/saitorhan/  
-- Twitter: https://twitter.com/saitorhan
-- GitHub: https://github.com/saitorhan
-- YouTube: https://www.youtube.com/saitorhan
-- ============================================= 

declare @indexName nvarchar(255)
declare @schemaName nvarchar(255)
declare @tableName nvarchar(255)

declare @rowCount int
declare @UsedMB numeric(36, 2)
declare @UnusedMB numeric(36, 2)
declare @TotalMB numeric(36, 2)

if OBJECT_ID('tempdb..#Indexes') is not null
begin
drop table #Indexes
end
-- Create temp table
create table #Indexes(
Id int primary key identity,
SchemaName nvarchar(255),
TableName nvarchar(255),
IndexName nvarchar(255),
IndexType nvarchar(255),
Avg_fragmentation float,
ActionNeed nvarchar(255),
StatsUpdated datetime,
[RowCount] int,
TableUsedMB numeric(36, 3),
TableUnusedMB numeric(36, 3),
TableTotalMB numeric(36, 3),
ReorganizeIndex nvarchar(1000),
ReorganizeTable nvarchar(1000),
RebuildIndex nvarchar(1000),
RebuildTable nvarchar(1000),
UpdateStats nvarchar(1000),
)

-- getting infos
insert into #Indexes(
SchemaName,
TableName,
IndexName,
IndexType,
Avg_fragmentation ,
ActionNeed,
StatsUpdated,
ReorganizeIndex,
ReorganizeTable,
RebuildIndex ,
RebuildTable,
UpdateStats
)

select 
s.name [Schema], -- schema name
t.name TableName, -- table name
i.name IndexName, -- index name
frag.index_type_desc IndexType, -- index type
frag.avg_fragmentation_in_percent, -- fragmentation in percent


(case
	when frag.avg_fragmentation_in_percent < 5 then 'Nothing'
	when frag.avg_fragmentation_in_percent between 5 and 30 then 'Reorganize'
	when frag.avg_fragmentation_in_percent > 30 then 'Rebuild' end), -- advice for action
	STATS_DATE(t.object_id, i.index_id),
CONCAT('ALTER INDEX [',i.name ,'] ON [', s.name, '].[' , t.name , '] REORGANIZE;') [ReorganizeIndex], -- index reorganize query
CONCAT('ALTER INDEX ALL ON [', s.name, '].[' , t.name ,'] REORGANIZE;') [ReorganizeAllTable], -- reorganize all index on table
CONCAT('ALTER INDEX [', i.name, '] ON [', s.name, '].[' , t.name, '] REBUILD ;') [RebuildIndex], -- index rebuid query
CONCAT('ALTER INDEX ALL ON [', s.name, '].[' ,  t.name ,'] REBUILD WITH (FILLFACTOR = 80, SORT_IN_TEMPDB = ON, STATISTICS_NORECOMPUTE = ON, ONLINE = ON);') [RebuildTable], -- rebuild all index on table
CONCAT('UPDATE STATISTICS [' , s.name , '].[' , t.name, ']')
from sys.tables t 
join sys.schemas s on t.schema_id = s.schema_id
join sys.indexes i on t.object_id = i.object_id
join sys.dm_db_index_physical_stats(DB_ID(), null, null, null, null) as frag on frag.object_id = t.object_id and frag.index_id = i.index_id
where t.type = 'U' and frag.alloc_unit_type_desc = 'IN_ROW_DATA'
order by frag.avg_fragmentation_in_percent desc 

declare saitorhan_cls cursor for

SELECT
i.name,
s.Name, -- AS SchemaName,
t.Name, -- AS TableName,
p.rows, -- AS RowCounts,
CAST(ROUND((SUM(a.used_pages) / 128.00), 3) AS NUMERIC(36, 3)), -- AS Used_MB,
CAST(ROUND((SUM(a.total_pages) - SUM(a.used_pages)) / 128.00, 3) AS NUMERIC(36, 2)),-- AS Unused_MB,
CAST(ROUND((SUM(a.total_pages) / 128.00), 2) AS NUMERIC(36, 3)) -- AS Total_MB
FROM sys.tables t
INNER JOIN sys.indexes i ON t.object_id = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
GROUP BY t.Name, s.Name, p.Rows, i.name
ORDER BY s.Name, t.Name

open saitorhan_cls
fetch next from saitorhan_cls into @indexName, @schemaName, @tableName ,@rowCount, @UsedMB, @UnusedMB, @TotalMB

while @@FETCH_STATUS = 0
begin

update #Indexes set [RowCount] = @rowCount, TableUsedMB = @UsedMB, TableUnusedMB = @UnusedMB, TableTotalMB = @TotalMB where TableName = @tableName and SchemaName = @schemaName

fetch next from saitorhan_cls into @indexName, @schemaName, @tableName ,@rowCount, @UsedMB, @UnusedMB, @TotalMB
end
close saitorhan_cls
deallocate saitorhan_cls


select * from #Indexes order by TableTotalMB desc

