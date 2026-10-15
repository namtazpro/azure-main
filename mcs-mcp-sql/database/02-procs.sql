-- Stored procedures exposed by the REST API. Error numbers: 50001 = not found, 50002 = invalid input.

CREATE OR ALTER PROCEDURE dbo.usp_GetTicket
    @TicketNumber varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vw_TicketDetail WHERE TicketNumber = @TicketNumber;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_SearchTickets
    @Status          varchar(20)   = NULL,
    @Priority        varchar(10)   = NULL,
    @Category        nvarchar(100) = NULL,
    @AssignedAgentId int           = NULL,
    @CustomerId      int           = NULL,
    @CreatedFrom     datetime2(0)  = NULL,
    @CreatedTo       datetime2(0)  = NULL,
    @SearchText      nvarchar(200) = NULL,
    @OverdueOnly     bit           = 0,
    @PageNumber      int           = 1,
    @PageSize        int           = 20
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize < 1 OR @PageSize > 100 SET @PageSize = 20;

    SELECT
        v.TicketNumber, v.Title, v.Status, v.Priority, v.Category,
        v.CustomerId, v.CustomerName, v.CustomerCompany,
        v.AssignedAgentId, v.AssignedAgentName, v.Team,
        v.CreatedAt, v.UpdatedAt, v.ResolvedAt, v.DueAt, v.IsOverdue,
        COUNT(*) OVER() AS TotalCount
    FROM dbo.vw_TicketDetail v
    WHERE (@Status IS NULL OR v.Status = @Status)
      AND (@Priority IS NULL OR v.Priority = @Priority)
      AND (@Category IS NULL OR v.Category = @Category)
      AND (@AssignedAgentId IS NULL OR v.AssignedAgentId = @AssignedAgentId)
      AND (@CustomerId IS NULL OR v.CustomerId = @CustomerId)
      AND (@CreatedFrom IS NULL OR v.CreatedAt >= @CreatedFrom)
      AND (@CreatedTo IS NULL OR v.CreatedAt < @CreatedTo)
      AND (@SearchText IS NULL OR v.Title LIKE N'%' + @SearchText + N'%')
      AND (@OverdueOnly = 0 OR v.IsOverdue = 1)
    ORDER BY v.CreatedAt DESC, v.TicketId DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY
    OPTION (RECOMPILE);
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetTicketComments
    @TicketNumber varchar(20),
    @Top          int = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @Top < 1 OR @Top > 200 SET @Top = 50;

    DECLARE @TicketId int = (SELECT TicketId FROM dbo.Ticket WHERE TicketNumber = @TicketNumber);
    IF @TicketId IS NULL THROW 50001, 'Ticket not found.', 1;

    SELECT TOP (@Top) c.CommentId, @TicketNumber AS TicketNumber, c.AuthorType, c.AuthorName, c.Body, c.CreatedAt
    FROM dbo.TicketComment c
    WHERE c.TicketId = @TicketId
    ORDER BY c.CreatedAt, c.CommentId;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_SearchCustomers
    @Name    nvarchar(100) = NULL,
    @Email   nvarchar(200) = NULL,
    @Company nvarchar(100) = NULL,
    @Top     int           = 20
AS
BEGIN
    SET NOCOUNT ON;
    IF @Top < 1 OR @Top > 100 SET @Top = 20;

    SELECT TOP (@Top)
        cu.CustomerId, cu.Name, cu.Email, cu.Company, cu.Tier,
        (SELECT COUNT(*) FROM dbo.Ticket t
          WHERE t.CustomerId = cu.CustomerId AND t.Status IN ('New', 'Open', 'InProgress', 'Pending')) AS OpenTickets
    FROM dbo.Customer cu
    WHERE (@Name IS NULL OR cu.Name LIKE @Name + N'%')
      AND (@Email IS NULL OR cu.Email = @Email)
      AND (@Company IS NULL OR cu.Company LIKE @Company + N'%')
    ORDER BY cu.Name, cu.CustomerId;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetTicketsByCustomer
    @CustomerId int,
    @Status     varchar(20) = NULL,
    @Top        int         = 25
AS
BEGIN
    SET NOCOUNT ON;
    IF @Top < 1 OR @Top > 100 SET @Top = 25;
    IF NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE CustomerId = @CustomerId) THROW 50001, 'Customer not found.', 1;

    SELECT TOP (@Top)
        v.TicketNumber, v.Title, v.Status, v.Priority, v.Category,
        v.AssignedAgentName, v.Team, v.CreatedAt, v.UpdatedAt, v.ResolvedAt, v.DueAt, v.IsOverdue
    FROM dbo.vw_TicketDetail v
    WHERE v.CustomerId = @CustomerId
      AND (@Status IS NULL OR v.Status = @Status)
    ORDER BY v.CreatedAt DESC, v.TicketId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetAgentWorkload
    @AgentId int          = NULL,
    @Team    nvarchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        a.AgentId, a.Name AS AgentName, tm.Name AS Team,
        COUNT(t.TicketId) AS OpenTickets,
        ISNULL(SUM(CASE WHEN t.Priority = 'Critical' THEN 1 ELSE 0 END), 0) AS CriticalTickets,
        ISNULL(SUM(CASE WHEN t.Priority = 'High' THEN 1 ELSE 0 END), 0) AS HighTickets,
        ISNULL(SUM(CASE WHEN t.DueAt < SYSUTCDATETIME() THEN 1 ELSE 0 END), 0) AS OverdueTickets,
        MIN(t.CreatedAt) AS OldestOpenTicketCreatedAt
    FROM dbo.Agent a
    JOIN dbo.Team tm ON tm.TeamId = a.TeamId
    LEFT JOIN dbo.Ticket t ON t.AssignedAgentId = a.AgentId AND t.Status IN ('New', 'Open', 'InProgress', 'Pending')
    WHERE (@AgentId IS NULL OR a.AgentId = @AgentId)
      AND (@Team IS NULL OR tm.Name = @Team)
    GROUP BY a.AgentId, a.Name, tm.Name
    ORDER BY OpenTickets DESC, a.AgentId;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetTicketSummary
    @From datetime2(0)  = NULL,
    @To   datetime2(0)  = NULL,
    @Team nvarchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @To = ISNULL(@To, DATEADD(day, 1, SYSUTCDATETIME()));
    SET @From = ISNULL(@From, DATEADD(day, -30, @To));

    CREATE TABLE #f (Status varchar(20), Priority varchar(10), Category nvarchar(100), ResolutionHours decimal(10,2) NULL);

    INSERT #f (Status, Priority, Category, ResolutionHours)
    SELECT t.Status, t.Priority, c.Name,
           CASE WHEN t.ResolvedAt IS NOT NULL THEN DATEDIFF(minute, t.CreatedAt, t.ResolvedAt) / 60.0 END
    FROM dbo.Ticket t
    JOIN dbo.Category c ON c.CategoryId = t.CategoryId
    LEFT JOIN dbo.Agent a ON a.AgentId = t.AssignedAgentId
    LEFT JOIN dbo.Team tm ON tm.TeamId = a.TeamId
    WHERE t.CreatedAt >= @From AND t.CreatedAt < @To
      AND (@Team IS NULL OR tm.Name = @Team);

    SELECT 'Status' AS Dimension, Status AS Name, COUNT(*) AS TicketCount, CAST(AVG(ResolutionHours) AS decimal(10,2)) AS AvgResolutionHours FROM #f GROUP BY Status
    UNION ALL
    SELECT 'Priority', Priority, COUNT(*), CAST(AVG(ResolutionHours) AS decimal(10,2)) FROM #f GROUP BY Priority
    UNION ALL
    SELECT 'Category', Category, COUNT(*), CAST(AVG(ResolutionHours) AS decimal(10,2)) FROM #f GROUP BY Category;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetSlaBreaches
    @Priority varchar(10) = NULL,
    @Top      int         = 25
AS
BEGIN
    SET NOCOUNT ON;
    IF @Top < 1 OR @Top > 100 SET @Top = 25;

    SELECT TOP (@Top)
        v.TicketNumber, v.Title, v.Status, v.Priority, v.Category,
        v.CustomerName, v.CustomerCompany, v.AssignedAgentName, v.Team,
        v.CreatedAt, v.DueAt,
        DATEDIFF(hour, v.DueAt, SYSUTCDATETIME()) AS HoursOverdue,
        COUNT(*) OVER() AS TotalCount
    FROM dbo.vw_TicketDetail v
    WHERE v.IsOverdue = 1
      AND (@Priority IS NULL OR v.Priority = @Priority)
    ORDER BY CASE v.Priority WHEN 'Critical' THEN 1 WHEN 'High' THEN 2 WHEN 'Medium' THEN 3 ELSE 4 END, v.DueAt;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_CreateTicket
    @CustomerId  int,
    @Category    nvarchar(100),
    @Title       nvarchar(200),
    @Description nvarchar(2000),
    @Priority    varchar(10) = 'Medium'
AS
BEGIN
    SET NOCOUNT ON;
    IF @Priority NOT IN ('Critical', 'High', 'Medium', 'Low') THROW 50002, 'Invalid priority.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE CustomerId = @CustomerId) THROW 50001, 'Customer not found.', 1;

    DECLARE @CategoryId int = (SELECT CategoryId FROM dbo.Category WHERE Name = @Category);
    IF @CategoryId IS NULL THROW 50002, 'Unknown category.', 1;

    DECLARE @Now datetime2(0) = SYSUTCDATETIME();
    DECLARE @SlaHours int = CASE @Priority WHEN 'Critical' THEN 4 WHEN 'High' THEN 8 WHEN 'Medium' THEN 24 ELSE 72 END;

    INSERT dbo.Ticket (CustomerId, CategoryId, AssignedAgentId, Title, Description, Status, Priority, CreatedAt, UpdatedAt, ResolvedAt, DueAt)
    VALUES (@CustomerId, @CategoryId, NULL, @Title, @Description, 'New', @Priority, @Now, @Now, NULL, DATEADD(hour, @SlaHours, @Now));

    DECLARE @TicketId int = SCOPE_IDENTITY();
    INSERT dbo.TicketComment (TicketId, AuthorType, AuthorName, Body, CreatedAt)
    SELECT @TicketId, 'Customer', cu.Name, @Description, @Now FROM dbo.Customer cu WHERE cu.CustomerId = @CustomerId;

    SELECT * FROM dbo.vw_TicketDetail WHERE TicketId = @TicketId;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_UpdateTicketStatus
    @TicketNumber    varchar(20),
    @Status          varchar(20),
    @AssignedAgentId int           = NULL,
    @Comment         nvarchar(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Status NOT IN ('New', 'Open', 'InProgress', 'Pending', 'Resolved', 'Closed') THROW 50002, 'Invalid status.', 1;

    DECLARE @TicketId int = (SELECT TicketId FROM dbo.Ticket WHERE TicketNumber = @TicketNumber);
    IF @TicketId IS NULL THROW 50001, 'Ticket not found.', 1;
    IF @AssignedAgentId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Agent WHERE AgentId = @AssignedAgentId) THROW 50002, 'Unknown agent.', 1;

    DECLARE @Now datetime2(0) = SYSUTCDATETIME();

    UPDATE dbo.Ticket
    SET Status = @Status,
        AssignedAgentId = ISNULL(@AssignedAgentId, AssignedAgentId),
        UpdatedAt = @Now,
        ResolvedAt = CASE WHEN @Status IN ('Resolved', 'Closed') THEN ISNULL(ResolvedAt, @Now) ELSE NULL END
    WHERE TicketId = @TicketId;

    INSERT dbo.TicketComment (TicketId, AuthorType, AuthorName, Body, CreatedAt)
    VALUES (@TicketId, 'System', N'Service Desk', ISNULL(@Comment, N'Status changed to ' + @Status + N'.'), @Now);

    SELECT * FROM dbo.vw_TicketDetail WHERE TicketId = @TicketId;
END
GO
