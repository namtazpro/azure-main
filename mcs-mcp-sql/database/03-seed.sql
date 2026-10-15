-- Deterministic, set-based demo data generator (default: 100k tickets, ~250k comments).
-- Usage: EXEC dbo.usp_SeedDemoData;            -- seeds only when dbo.Ticket is empty
--        EXEC dbo.usp_SeedDemoData @Force = 1; -- wipes and reseeds

CREATE OR ALTER PROCEDURE dbo.usp_SeedDemoData
    @Force         bit = 0,
    @TicketCount   int = 100000,
    @CustomerCount int = 5000
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.Ticket)
    BEGIN
        IF @Force = 0
        BEGIN
            PRINT 'Data already present. Use @Force = 1 to reseed.';
            RETURN;
        END
        DELETE dbo.TicketComment;
        DELETE dbo.Ticket;
        DELETE dbo.Customer;
        DELETE dbo.Agent;
        DELETE dbo.Team;
        DELETE dbo.Category;
    END

    DECLARE @Now datetime2(0) = SYSUTCDATETIME();
    DECLARE @AgentCount int = 40;

    DECLARE @First TABLE (i int PRIMARY KEY, v nvarchar(50));
    INSERT @First VALUES (0,N'Alice'),(1,N'Bruno'),(2,N'Chloe'),(3,N'David'),(4,N'Elena'),(5,N'Farid'),(6,N'Grace'),(7,N'Hugo'),(8,N'Ines'),(9,N'Jamal'),
        (10,N'Katya'),(11,N'Liam'),(12,N'Maya'),(13,N'Noah'),(14,N'Olivia'),(15,N'Pedro'),(16,N'Quinn'),(17,N'Rosa'),(18,N'Sven'),(19,N'Tara');

    DECLARE @Last TABLE (i int PRIMARY KEY, v nvarchar(50));
    INSERT @Last VALUES (0,N'Anderson'),(1,N'Bernard'),(2,N'Castillo'),(3,N'Dubois'),(4,N'Evans'),(5,N'Fischer'),(6,N'Garcia'),(7,N'Haddad'),(8,N'Ivanov'),(9,N'Jensen'),
        (10,N'Kowalski'),(11,N'Laurent'),(12,N'Moreau'),(13,N'Nakamura'),(14,N'Okafor'),(15,N'Petrov'),(16,N'Rossi'),(17,N'Silva'),(18,N'Taylor'),(19,N'Walker');

    DECLARE @Company TABLE (i int PRIMARY KEY, v nvarchar(100));
    INSERT @Company VALUES (0,N'Contoso'),(1,N'Fabrikam'),(2,N'Northwind'),(3,N'Adventure Works'),(4,N'Litware'),(5,N'Tailspin'),(6,N'Wingtip'),(7,N'Proseware'),
        (8,N'Woodgrove'),(9,N'Lucerne'),(10,N'Margie Travel'),(11,N'Coho Winery'),(12,N'Alpine Ski'),(13,N'Blue Yonder'),(14,N'Fourth Coffee'),(15,N'Humongous Insurance'),
        (16,N'Trey Research'),(17,N'Wide World'),(18,N'VanArsdel'),(19,N'Relecloud'),(20,N'Graphic Design'),(21,N'City Power'),(22,N'School of Fine Art'),(23,N'Southridge Video'),(24,N'Consolidated Messenger');

    INSERT dbo.Category (CategoryId, Name) VALUES
        (1,N'Network & VPN'),(2,N'Email & Calendar'),(3,N'Hardware'),(4,N'Software Installation'),(5,N'Access & Permissions'),(6,N'Password Reset'),
        (7,N'Printing'),(8,N'Cloud Services'),(9,N'Security Incident'),(10,N'Database'),(11,N'Mobile Devices'),(12,N'HR Systems');

    INSERT dbo.Team (TeamId, Name) VALUES
        (1,N'Service Desk'),(2,N'Network Operations'),(3,N'Infrastructure'),(4,N'Security Operations'),(5,N'Application Support');

    ;WITH n AS (SELECT TOP (@AgentCount) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.all_objects)
    INSERT dbo.Agent (AgentId, Name, Email, TeamId)
    SELECT n, f.v + N' ' + l.v, LOWER(f.v + N'.' + l.v) + N'.' + CAST(n AS nvarchar(10)) + N'@helpdesk.example.com', 1 + CAST((n - 1) % 5 AS int)
    FROM n
    JOIN @First f ON f.i = (n * 3) % 20
    JOIN @Last l ON l.i = (n * 7) % 20;

    ;WITH n AS (SELECT TOP (@CustomerCount) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.all_objects a CROSS JOIN sys.all_objects b)
    INSERT dbo.Customer (CustomerId, Name, Email, Company, Tier)
    SELECT n, f.v + N' ' + l.v,
           LOWER(f.v + N'.' + l.v) + CAST(n AS nvarchar(10)) + N'@' + LOWER(REPLACE(c.v, N' ', N'')) + N'.example.com',
           c.v,
           CASE n % 10 WHEN 0 THEN 'Enterprise' WHEN 1 THEN 'Premium' WHEN 2 THEN 'Premium' WHEN 3 THEN 'Premium' ELSE 'Standard' END
    FROM n
    JOIN @First f ON f.i = (n * 7) % 20
    JOIN @Last l ON l.i = (n * 13) % 20
    JOIN @Company c ON c.i = (n * 11) % 25;

    DECLARE @Problem TABLE (i int PRIMARY KEY, Template nvarchar(100));
    INSERT @Problem VALUES (0,N'Unable to access {c}'),(1,N'{c} is running slowly'),(2,N'New user request for {c}'),(3,N'Error message when using {c}'),(4,N'Intermittent outage affecting {c}');

    DECLARE @Detail TABLE (i int PRIMARY KEY, Text nvarchar(300));
    INSERT @Detail VALUES (0,N'The issue started this morning and affects my daily work.'),(1,N'Several colleagues in my office report the same behaviour.'),
        (2,N'I already restarted my device but the problem persists.'),(3,N'This is blocking a customer deliverable, please prioritise.'),(4,N'The problem happens only at certain times of the day.');

    SET IDENTITY_INSERT dbo.Ticket ON;

    ;WITH n AS (SELECT TOP (@TicketCount) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.all_objects a CROSS JOIN sys.all_objects b),
    b AS (
        SELECT n,
               CAST(1 + (n * 7919) % @CustomerCount AS int) AS CustomerId,
               CAST(1 + (n * 31) % 12 AS int) AS CategoryId,
               (n * 37) % 100 AS PriorityRoll,
               (n * 104729) % 525600 AS AgeMinutes,
               (n * 53) % 100 AS StatusRoll
        FROM n
    ),
    c AS (
        SELECT b.*,
               CASE WHEN PriorityRoll < 5 THEN 'Critical' WHEN PriorityRoll < 25 THEN 'High' WHEN PriorityRoll < 70 THEN 'Medium' ELSE 'Low' END AS Priority,
               CASE WHEN AgeMinutes > 43200 THEN
                        CASE WHEN StatusRoll < 65 THEN 'Closed' WHEN StatusRoll < 92 THEN 'Resolved' WHEN StatusRoll < 96 THEN 'InProgress' WHEN StatusRoll < 98 THEN 'Pending' ELSE 'Open' END
                    ELSE
                        CASE WHEN StatusRoll < 12 THEN 'New' WHEN StatusRoll < 35 THEN 'Open' WHEN StatusRoll < 65 THEN 'InProgress' WHEN StatusRoll < 75 THEN 'Pending' WHEN StatusRoll < 92 THEN 'Resolved' ELSE 'Closed' END
               END AS Status,
               DATEADD(minute, -AgeMinutes, @Now) AS CreatedAt
        FROM b
    ),
    d AS (
        SELECT c.*,
               CASE WHEN Status IN ('Resolved', 'Closed') THEN
                    DATEADD(minute, CASE WHEN 30 + (n * 977) % 4320 > AgeMinutes THEN AgeMinutes / 2 ELSE 30 + (n * 977) % 4320 END, CreatedAt)
               END AS ResolvedAt
        FROM c
    )
    INSERT dbo.Ticket (TicketId, CustomerId, CategoryId, AssignedAgentId, Title, Description, Status, Priority, CreatedAt, UpdatedAt, ResolvedAt, DueAt)
    SELECT CAST(d.n AS int), d.CustomerId, d.CategoryId,
           CASE WHEN d.Status = 'New' THEN NULL ELSE CAST(1 + (d.n * 17) % @AgentCount AS int) END,
           LEFT(REPLACE(p.Template, N'{c}', cat.Name), 200),
           LEFT(REPLACE(p.Template, N'{c}', cat.Name) + N'. ' + dt.Text, 2000),
           d.Status, d.Priority, d.CreatedAt,
           COALESCE(d.ResolvedAt, DATEADD(minute, (d.n * 131) % (d.AgeMinutes + 1), d.CreatedAt)),
           d.ResolvedAt,
           DATEADD(hour, CASE d.Priority WHEN 'Critical' THEN 4 WHEN 'High' THEN 8 WHEN 'Medium' THEN 24 ELSE 72 END, d.CreatedAt)
    FROM d
    JOIN dbo.Category cat ON cat.CategoryId = d.CategoryId
    JOIN @Problem p ON p.i = (d.n * 11) % 5
    JOIN @Detail dt ON dt.i = (d.n * 3) % 5
    ORDER BY d.n;

    SET IDENTITY_INSERT dbo.Ticket OFF;

    INSERT dbo.TicketComment (TicketId, AuthorType, AuthorName, Body, CreatedAt)
    SELECT t.TicketId,
           CASE WHEN s.seq % 2 = 1 THEN 'Customer' ELSE 'Agent' END,
           CASE WHEN s.seq % 2 = 1 THEN cu.Name ELSE a.Name END,
           CASE s.seq WHEN 1 THEN t.Description
                      WHEN 2 THEN N'Thanks for reporting this. We are investigating and will update you shortly.'
                      WHEN 3 THEN N'I tried your suggestion but the issue is still happening.'
                      ELSE N'A fix has been applied. Please confirm whether the issue is resolved.' END,
           CASE WHEN s.seq = 1 THEN t.CreatedAt
                WHEN DATEADD(minute, s.seq * (15 + t.TicketId % 90), t.CreatedAt) > @Now THEN @Now
                ELSE DATEADD(minute, s.seq * (15 + t.TicketId % 90), t.CreatedAt) END
    FROM dbo.Ticket t
    JOIN dbo.Customer cu ON cu.CustomerId = t.CustomerId
    LEFT JOIN dbo.Agent a ON a.AgentId = t.AssignedAgentId
    JOIN (VALUES (1), (2), (3), (4)) s(seq)
      ON s.seq <= CASE WHEN t.AssignedAgentId IS NULL THEN 1 ELSE 1 + (t.TicketId * 13) % 4 END;

    UPDATE STATISTICS dbo.Ticket;
    UPDATE STATISTICS dbo.TicketComment;

    SELECT (SELECT COUNT(*) FROM dbo.Customer) AS Customers,
           (SELECT COUNT(*) FROM dbo.Agent) AS Agents,
           (SELECT COUNT(*) FROM dbo.Ticket) AS Tickets,
           (SELECT COUNT(*) FROM dbo.TicketComment) AS Comments;
END
GO
