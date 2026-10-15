-- ITSM demo schema. Idempotent: safe to re-run.

IF OBJECT_ID('dbo.Category') IS NULL
CREATE TABLE dbo.Category (
    CategoryId   int           NOT NULL CONSTRAINT PK_Category PRIMARY KEY,
    Name         nvarchar(100) NOT NULL CONSTRAINT UQ_Category_Name UNIQUE
);
GO

IF OBJECT_ID('dbo.Team') IS NULL
CREATE TABLE dbo.Team (
    TeamId int           NOT NULL CONSTRAINT PK_Team PRIMARY KEY,
    Name   nvarchar(100) NOT NULL CONSTRAINT UQ_Team_Name UNIQUE
);
GO

IF OBJECT_ID('dbo.Agent') IS NULL
CREATE TABLE dbo.Agent (
    AgentId int           NOT NULL CONSTRAINT PK_Agent PRIMARY KEY,
    Name    nvarchar(100) NOT NULL,
    Email   nvarchar(200) NOT NULL,
    TeamId  int           NOT NULL CONSTRAINT FK_Agent_Team REFERENCES dbo.Team(TeamId)
);
GO

IF OBJECT_ID('dbo.Customer') IS NULL
CREATE TABLE dbo.Customer (
    CustomerId int           NOT NULL CONSTRAINT PK_Customer PRIMARY KEY,
    Name       nvarchar(100) NOT NULL,
    Email      nvarchar(200) NOT NULL,
    Company    nvarchar(100) NOT NULL,
    Tier       varchar(10)   NOT NULL CONSTRAINT CK_Customer_Tier CHECK (Tier IN ('Standard', 'Premium', 'Enterprise'))
);
GO

IF OBJECT_ID('dbo.Ticket') IS NULL
CREATE TABLE dbo.Ticket (
    TicketId        int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Ticket PRIMARY KEY,
    TicketNumber    AS ('INC-' + RIGHT('000000' + CONVERT(varchar(10), TicketId), 6)) PERSISTED NOT NULL,
    CustomerId      int            NOT NULL CONSTRAINT FK_Ticket_Customer REFERENCES dbo.Customer(CustomerId),
    CategoryId      int            NOT NULL CONSTRAINT FK_Ticket_Category REFERENCES dbo.Category(CategoryId),
    AssignedAgentId int            NULL     CONSTRAINT FK_Ticket_Agent REFERENCES dbo.Agent(AgentId),
    Title           nvarchar(200)  NOT NULL,
    Description     nvarchar(2000) NOT NULL,
    Status          varchar(20)    NOT NULL CONSTRAINT CK_Ticket_Status CHECK (Status IN ('New', 'Open', 'InProgress', 'Pending', 'Resolved', 'Closed')),
    Priority        varchar(10)    NOT NULL CONSTRAINT CK_Ticket_Priority CHECK (Priority IN ('Critical', 'High', 'Medium', 'Low')),
    CreatedAt       datetime2(0)   NOT NULL,
    UpdatedAt       datetime2(0)   NOT NULL,
    ResolvedAt      datetime2(0)   NULL,
    DueAt           datetime2(0)   NOT NULL
);
GO

IF OBJECT_ID('dbo.TicketComment') IS NULL
CREATE TABLE dbo.TicketComment (
    CommentId  int IDENTITY(1,1) NOT NULL CONSTRAINT PK_TicketComment PRIMARY KEY,
    TicketId   int            NOT NULL CONSTRAINT FK_TicketComment_Ticket REFERENCES dbo.Ticket(TicketId),
    AuthorType varchar(10)    NOT NULL CONSTRAINT CK_TicketComment_AuthorType CHECK (AuthorType IN ('Customer', 'Agent', 'System')),
    AuthorName nvarchar(100)  NOT NULL,
    Body       nvarchar(2000) NOT NULL,
    CreatedAt  datetime2(0)   NOT NULL
);
GO

-- Indexes supporting the stored procedures
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Ticket_TicketNumber')
    CREATE UNIQUE INDEX UX_Ticket_TicketNumber ON dbo.Ticket(TicketNumber);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ticket_Customer_Created')
    CREATE INDEX IX_Ticket_Customer_Created ON dbo.Ticket(CustomerId, CreatedAt DESC) INCLUDE (Status, Priority);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ticket_Agent_Status')
    CREATE INDEX IX_Ticket_Agent_Status ON dbo.Ticket(AssignedAgentId, Status) INCLUDE (Priority, CreatedAt, DueAt);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ticket_Status_Priority_Created')
    CREATE INDEX IX_Ticket_Status_Priority_Created ON dbo.Ticket(Status, Priority, CreatedAt DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ticket_CreatedAt')
    CREATE INDEX IX_Ticket_CreatedAt ON dbo.Ticket(CreatedAt DESC) INCLUDE (CategoryId, Status, Priority, ResolvedAt);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ticket_OpenDue')
    CREATE INDEX IX_Ticket_OpenDue ON dbo.Ticket(DueAt) INCLUDE (Priority, AssignedAgentId)
        WHERE Status IN ('New', 'Open', 'InProgress', 'Pending');
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TicketComment_Ticket')
    CREATE INDEX IX_TicketComment_Ticket ON dbo.TicketComment(TicketId, CreatedAt);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Customer_Name')
    CREATE INDEX IX_Customer_Name ON dbo.Customer(Name) INCLUDE (Email, Company);
GO

CREATE OR ALTER VIEW dbo.vw_TicketDetail
AS
SELECT
    t.TicketId,
    t.TicketNumber,
    t.Title,
    t.Description,
    t.Status,
    t.Priority,
    c.Name        AS Category,
    t.CustomerId,
    cu.Name       AS CustomerName,
    cu.Company    AS CustomerCompany,
    t.AssignedAgentId,
    a.Name        AS AssignedAgentName,
    tm.Name       AS Team,
    t.CreatedAt,
    t.UpdatedAt,
    t.ResolvedAt,
    t.DueAt,
    CAST(CASE WHEN t.Status IN ('New', 'Open', 'InProgress', 'Pending') AND t.DueAt < SYSUTCDATETIME() THEN 1 ELSE 0 END AS bit) AS IsOverdue
FROM dbo.Ticket t
JOIN dbo.Category c  ON c.CategoryId = t.CategoryId
JOIN dbo.Customer cu ON cu.CustomerId = t.CustomerId
LEFT JOIN dbo.Agent a ON a.AgentId = t.AssignedAgentId
LEFT JOIN dbo.Team tm ON tm.TeamId = a.TeamId;
GO
