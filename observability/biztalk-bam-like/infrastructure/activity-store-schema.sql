-- Agentic BAM - Activity Store Schema
-- Generates the tables for a Sales Order activity.
-- Mirrors BizTalk BAM's pattern: one row per activity instance,
-- milestone timestamps as columns, data items as columns.
--
-- Run this after deploying infrastructure (deploy.bicep).
-- In production, this would be auto-generated from the .activity.yaml definition.

-- ═══════════════════════════════════════════════════════════════════════════
-- ACTIVE INSTANCES TABLE
-- Real-time queryable. One row per in-progress sales order.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE [dbo].[bam_SalesOrder_Active] (
    -- Correlation token (primary key)
    [CorrelationToken]      NVARCHAR(100)   NOT NULL PRIMARY KEY,

    -- Milestone timestamps (NULL = not yet reached)
    [Received]              DATETIME2       NULL,
    [Received_Status]       NVARCHAR(20)    NULL DEFAULT 'Completed',
    [Validated]             DATETIME2       NULL,
    [Validated_Status]      NVARCHAR(20)    NULL DEFAULT 'Completed',
    [CreditChecked]         DATETIME2       NULL,
    [CreditChecked_Status]  NVARCHAR(20)    NULL DEFAULT 'Completed',
    [Approved]              DATETIME2       NULL,
    [Approved_Status]       NVARCHAR(20)    NULL DEFAULT 'Completed',
    [Dispatched]            DATETIME2       NULL,
    [Dispatched_Status]     NVARCHAR(20)    NULL DEFAULT 'Completed',
    [Invoiced]              DATETIME2       NULL,
    [Invoiced_Status]       NVARCHAR(20)    NULL DEFAULT 'Completed',

    -- Data items (business data captured at milestones)
    [OrderID]               NVARCHAR(50)    NULL,
    [CustomerName]          NVARCHAR(200)   NULL,
    [CustomerID]            NVARCHAR(50)    NULL,
    [OrderAmount]           DECIMAL(18,2)   NULL,
    [Currency]              NVARCHAR(3)     NULL,
    [Region]                NVARCHAR(10)    NULL,
    [LineItemCount]         INT             NULL,
    [CreditScore]           INT             NULL,
    [CreditLimit]           DECIMAL(18,2)   NULL,
    [ApprovedBy]            NVARCHAR(100)   NULL,
    [ApprovalType]          NVARCHAR(20)    NULL,
    [CarrierName]           NVARCHAR(100)   NULL,
    [TrackingNumber]        NVARCHAR(100)   NULL,
    [InvoiceNumber]         NVARCHAR(50)    NULL,

    -- Metadata (not shown to business users, used for operations)
    [CurrentMilestone]      NVARCHAR(50)    NULL,
    [Status]                NVARCHAR(20)    NOT NULL DEFAULT 'Active',
    [CreatedAt]             DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
    [LastModifiedAt]        DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),

    -- Audit: which agent wrote each milestone (operational, not business)
    [Received_Agent]        NVARCHAR(100)   NULL,
    [Validated_Agent]       NVARCHAR(100)   NULL,
    [CreditChecked_Agent]   NVARCHAR(100)   NULL,
    [Approved_Agent]        NVARCHAR(100)   NULL,
    [Dispatched_Agent]      NVARCHAR(100)   NULL,
    [Invoiced_Agent]        NVARCHAR(100)   NULL
);

-- Indexes for common query patterns
CREATE INDEX [IX_SalesOrder_Active_OrderID]
    ON [dbo].[bam_SalesOrder_Active] ([OrderID]);

CREATE INDEX [IX_SalesOrder_Active_Region]
    ON [dbo].[bam_SalesOrder_Active] ([Region]);

CREATE INDEX [IX_SalesOrder_Active_CurrentMilestone]
    ON [dbo].[bam_SalesOrder_Active] ([CurrentMilestone]);

CREATE INDEX [IX_SalesOrder_Active_CreatedAt]
    ON [dbo].[bam_SalesOrder_Active] ([CreatedAt] DESC);

CREATE INDEX [IX_SalesOrder_Active_Status]
    ON [dbo].[bam_SalesOrder_Active] ([Status])
    WHERE [Status] = 'Active';


-- ═══════════════════════════════════════════════════════════════════════════
-- COMPLETED INSTANCES TABLE
-- Archived instances for historical analysis. Same schema as Active.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE [dbo].[bam_SalesOrder_Completed] (
    [CorrelationToken]      NVARCHAR(100)   NOT NULL PRIMARY KEY,

    [Received]              DATETIME2       NULL,
    [Received_Status]       NVARCHAR(20)    NULL,
    [Validated]             DATETIME2       NULL,
    [Validated_Status]      NVARCHAR(20)    NULL,
    [CreditChecked]         DATETIME2       NULL,
    [CreditChecked_Status]  NVARCHAR(20)    NULL,
    [Approved]              DATETIME2       NULL,
    [Approved_Status]       NVARCHAR(20)    NULL,
    [Dispatched]            DATETIME2       NULL,
    [Dispatched_Status]     NVARCHAR(20)    NULL,
    [Invoiced]              DATETIME2       NULL,
    [Invoiced_Status]       NVARCHAR(20)    NULL,

    [OrderID]               NVARCHAR(50)    NULL,
    [CustomerName]          NVARCHAR(200)   NULL,
    [CustomerID]            NVARCHAR(50)    NULL,
    [OrderAmount]           DECIMAL(18,2)   NULL,
    [Currency]              NVARCHAR(3)     NULL,
    [Region]                NVARCHAR(10)    NULL,
    [LineItemCount]         INT             NULL,
    [CreditScore]           INT             NULL,
    [CreditLimit]           DECIMAL(18,2)   NULL,
    [ApprovedBy]            NVARCHAR(100)   NULL,
    [ApprovalType]          NVARCHAR(20)    NULL,
    [CarrierName]           NVARCHAR(100)   NULL,
    [TrackingNumber]        NVARCHAR(100)   NULL,
    [InvoiceNumber]         NVARCHAR(50)    NULL,

    [CurrentMilestone]      NVARCHAR(50)    NULL,
    [Status]                NVARCHAR(20)    NOT NULL DEFAULT 'Completed',
    [CreatedAt]             DATETIME2       NOT NULL,
    [LastModifiedAt]        DATETIME2       NOT NULL,
    [CompletedAt]           DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),

    [Received_Agent]        NVARCHAR(100)   NULL,
    [Validated_Agent]       NVARCHAR(100)   NULL,
    [CreditChecked_Agent]   NVARCHAR(100)   NULL,
    [Approved_Agent]        NVARCHAR(100)   NULL,
    [Dispatched_Agent]      NVARCHAR(100)   NULL,
    [Invoiced_Agent]        NVARCHAR(100)   NULL,

    -- Duration calculations (pre-computed at archive time for fast reporting)
    [Duration_ReceivedToValidated]       INT NULL,  -- seconds
    [Duration_ValidatedToCreditChecked]  INT NULL,
    [Duration_CreditCheckedToApproved]   INT NULL,
    [Duration_ApprovedToDispatched]      INT NULL,
    [Duration_DispatchedToInvoiced]      INT NULL,
    [Duration_Total]                     INT NULL   -- Received to Invoiced
);

CREATE INDEX [IX_SalesOrder_Completed_CompletedAt]
    ON [dbo].[bam_SalesOrder_Completed] ([CompletedAt] DESC);

CREATE INDEX [IX_SalesOrder_Completed_Region]
    ON [dbo].[bam_SalesOrder_Completed] ([Region], [CompletedAt] DESC);


-- ═══════════════════════════════════════════════════════════════════════════
-- VIEWS (Business stakeholder projections)
-- These map to the "views" defined in the activity YAML
-- ═══════════════════════════════════════════════════════════════════════════

-- Operations View: full pipeline visibility
CREATE VIEW [dbo].[vw_SalesOrder_Operations] AS
SELECT
    [CorrelationToken],
    [OrderID],
    [CustomerName],
    [OrderAmount],
    [Currency],
    [Region],
    [TrackingNumber],
    [Received],
    [Validated],
    [CreditChecked],
    [Approved],
    [Dispatched],
    [Invoiced],
    [CurrentMilestone],
    [Status],
    -- Computed: time since last milestone (for "stuck" detection)
    DATEDIFF(SECOND, [LastModifiedAt], SYSUTCDATETIME()) AS [SecondsSinceLastUpdate]
FROM [dbo].[bam_SalesOrder_Active];
GO

-- Finance View: credit and invoicing focus
CREATE VIEW [dbo].[vw_SalesOrder_Finance] AS
SELECT
    [CorrelationToken],
    [OrderID],
    [CustomerName],
    [OrderAmount],
    [Currency],
    [CreditScore],
    [CreditLimit],
    [InvoiceNumber],
    [CreditChecked],
    [Approved],
    [Invoiced],
    [Status]
FROM [dbo].[bam_SalesOrder_Active]
UNION ALL
SELECT
    [CorrelationToken],
    [OrderID],
    [CustomerName],
    [OrderAmount],
    [Currency],
    [CreditScore],
    [CreditLimit],
    [InvoiceNumber],
    [CreditChecked],
    [Approved],
    [Invoiced],
    [Status]
FROM [dbo].[bam_SalesOrder_Completed]
WHERE [CompletedAt] >= DATEADD(DAY, -7, SYSUTCDATETIME());
GO

-- Fulfilment View: warehouse/logistics focus
CREATE VIEW [dbo].[vw_SalesOrder_Fulfilment] AS
SELECT
    [CorrelationToken],
    [OrderID],
    [CustomerName],
    [Region],
    [CarrierName],
    [TrackingNumber],
    [LineItemCount],
    [Approved],
    [Dispatched],
    [Invoiced],
    [CurrentMilestone],
    [Status]
FROM [dbo].[bam_SalesOrder_Active]
WHERE [Approved] IS NOT NULL;  -- Only show orders that reached approval
GO


-- ═══════════════════════════════════════════════════════════════════════════
-- STORED PROCEDURES (used by the portal for aggregations)
-- ═══════════════════════════════════════════════════════════════════════════

-- Aggregation: Orders summary for today
CREATE PROCEDURE [dbo].[sp_SalesOrder_DailySummary]
    @Date DATE = NULL
AS
BEGIN
    SET @Date = ISNULL(@Date, CAST(SYSUTCDATETIME() AS DATE));

    SELECT
        COUNT(*) AS [TotalOrders],
        COUNT(CASE WHEN [Invoiced] IS NOT NULL THEN 1 END) AS [Completed],
        COUNT(CASE WHEN [Status] = 'Active' THEN 1 END) AS [InProgress],
        COUNT(CASE WHEN [Validated_Status] = 'Failed' THEN 1 END) AS [FailedValidation],
        SUM([OrderAmount]) AS [TotalOrderValue],
        AVG(DATEDIFF(SECOND, [Received], [Approved])) AS [AvgSecondsToApproval],
        AVG(DATEDIFF(SECOND, [Received], [Invoiced])) AS [AvgSecondsTotal]
    FROM [dbo].[bam_SalesOrder_Active]
    WHERE CAST([CreatedAt] AS DATE) = @Date

    UNION ALL

    SELECT
        COUNT(*),
        COUNT(*),  -- All are completed
        0,
        COUNT(CASE WHEN [Validated_Status] = 'Failed' THEN 1 END),
        SUM([OrderAmount]),
        AVG([Duration_Total] / NULLIF(DATEDIFF(SECOND, [Received], [Approved]), 0)),
        AVG([Duration_Total])
    FROM [dbo].[bam_SalesOrder_Completed]
    WHERE CAST([CompletedAt] AS DATE) = @Date;
END;
GO

-- SLA Breach detection: find activities exceeding milestone SLAs
CREATE PROCEDURE [dbo].[sp_SalesOrder_SLABreaches]
AS
BEGIN
    SELECT
        [CorrelationToken],
        [OrderID],
        [CustomerName],
        [Region],
        [CurrentMilestone],
        [LastModifiedAt],
        DATEDIFF(MINUTE, [LastModifiedAt], SYSUTCDATETIME()) AS [MinutesSinceLastMilestone],
        CASE [CurrentMilestone]
            WHEN 'Received'      THEN 2    -- SLA: 2 min to Validated
            WHEN 'Validated'     THEN 5    -- SLA: 5 min to CreditChecked
            WHEN 'CreditChecked' THEN 30   -- SLA: 30 min to Approved
            WHEN 'Approved'      THEN 240  -- SLA: 4 hours to Dispatched
            WHEN 'Dispatched'    THEN 60   -- SLA: 1 hour to Invoiced
        END AS [SLAMinutes]
    FROM [dbo].[bam_SalesOrder_Active]
    WHERE [Status] = 'Active'
    AND DATEDIFF(MINUTE, [LastModifiedAt], SYSUTCDATETIME()) >
        CASE [CurrentMilestone]
            WHEN 'Received'      THEN 2
            WHEN 'Validated'     THEN 5
            WHEN 'CreditChecked' THEN 30
            WHEN 'Approved'      THEN 240
            WHEN 'Dispatched'    THEN 60
            ELSE 9999
        END
    ORDER BY [MinutesSinceLastMilestone] DESC;
END;
GO
