-- ═══════════════════════════════════════════════════════════════════════════
-- Agentic BAM Portal Queries
-- KQL and SQL queries used by dashboards to render the BAM portal views.
-- These power the business-user-facing dashboards.
-- ═══════════════════════════════════════════════════════════════════════════


-- ─── QUERY 1: Active Orders Pipeline View ─────────────────────────────────
-- Shows all in-progress orders with milestone status indicators
-- Used by: Operations View dashboard

SELECT
    OrderID,
    CustomerName,
    FORMAT(OrderAmount, 'C', 'en-GB') AS OrderValue,
    Region,
    -- Milestone status indicators
    CASE WHEN Received IS NOT NULL THEN '✅' ELSE '⚪' END AS [Recv],
    CASE WHEN Validated IS NOT NULL THEN
        CASE WHEN Validated_Status = 'Failed' THEN '🔴' ELSE '✅' END
    ELSE
        CASE WHEN Received IS NOT NULL THEN '🟡' ELSE '⚪' END
    END AS [Valid],
    CASE WHEN CreditChecked IS NOT NULL THEN '✅'
        WHEN Validated IS NOT NULL AND Validated_Status != 'Failed' THEN '🟡'
        ELSE '⚪'
    END AS [Credit],
    CASE WHEN Approved IS NOT NULL THEN '✅'
        WHEN CreditChecked IS NOT NULL THEN '🟡'
        ELSE '⚪'
    END AS [Apprvd],
    CASE WHEN Dispatched IS NOT NULL THEN '✅'
        WHEN Approved IS NOT NULL THEN '🟡'
        ELSE '⚪'
    END AS [Disp],
    CASE WHEN Invoiced IS NOT NULL THEN '✅'
        WHEN Dispatched IS NOT NULL THEN '🟡'
        ELSE '⚪'
    END AS [Inv],
    -- Time in current stage
    CONCAT(
        DATEDIFF(MINUTE, LastModifiedAt, SYSUTCDATETIME()),
        ' min'
    ) AS [TimeInStage]
FROM bam_SalesOrder_Active
WHERE Status = 'Active'
ORDER BY CreatedAt DESC;


-- ─── QUERY 2: SLA Dashboard ──────────────────────────────────────────────
-- Shows orders at risk of breaching SLA

SELECT
    OrderID,
    CustomerName,
    Region,
    CurrentMilestone AS [CurrentStage],
    DATEDIFF(MINUTE, LastModifiedAt, SYSUTCDATETIME()) AS [MinutesInStage],
    CASE CurrentMilestone
        WHEN 'Received'      THEN 2
        WHEN 'Validated'     THEN 5
        WHEN 'CreditChecked' THEN 30
        WHEN 'Approved'      THEN 240
        WHEN 'Dispatched'    THEN 60
    END AS [SLAMinutes],
    CASE
        WHEN DATEDIFF(MINUTE, LastModifiedAt, SYSUTCDATETIME()) >
            CASE CurrentMilestone
                WHEN 'Received' THEN 2
                WHEN 'Validated' THEN 5
                WHEN 'CreditChecked' THEN 30
                WHEN 'Approved' THEN 240
                WHEN 'Dispatched' THEN 60
            END
        THEN '🔴 BREACHED'
        WHEN DATEDIFF(MINUTE, LastModifiedAt, SYSUTCDATETIME()) >
            CASE CurrentMilestone
                WHEN 'Received' THEN 1
                WHEN 'Validated' THEN 3
                WHEN 'CreditChecked' THEN 20
                WHEN 'Approved' THEN 180
                WHEN 'Dispatched' THEN 45
            END
        THEN '🟡 AT RISK'
        ELSE '🟢 ON TRACK'
    END AS [SLAStatus]
FROM bam_SalesOrder_Active
WHERE Status = 'Active'
ORDER BY
    CASE
        WHEN DATEDIFF(MINUTE, LastModifiedAt, SYSUTCDATETIME()) >
            CASE CurrentMilestone
                WHEN 'Received' THEN 2
                WHEN 'Validated' THEN 5
                WHEN 'CreditChecked' THEN 30
                WHEN 'Approved' THEN 240
                WHEN 'Dispatched' THEN 60
            END
        THEN 0  -- Breached first
        ELSE 1
    END,
    DATEDIFF(MINUTE, LastModifiedAt, SYSUTCDATETIME()) DESC;


-- ─── QUERY 3: Daily Aggregations ─────────────────────────────────────────
-- Summary KPIs for today's orders
-- Used by: Top-of-dashboard summary cards

SELECT
    COUNT(*) AS [OrdersToday],
    COUNT(CASE WHEN Invoiced IS NOT NULL THEN 1 END) AS [Completed],
    COUNT(CASE WHEN Status = 'Active' THEN 1 END) AS [InProgress],
    COUNT(CASE WHEN Validated_Status = 'Failed' THEN 1 END) AS [FailedValidation],
    FORMAT(SUM(OrderAmount), 'C', 'en-GB') AS [TotalValue],
    CONCAT(AVG(DATEDIFF(SECOND, Received, Approved)) / 60, ' min') AS [AvgToApproval],
    CONCAT(
        AVG(DATEDIFF(SECOND, Received,
            COALESCE(Invoiced, SYSUTCDATETIME()))) / 60,
        ' min'
    ) AS [AvgTotal]
FROM bam_SalesOrder_Active
WHERE CAST(CreatedAt AS DATE) = CAST(SYSUTCDATETIME() AS DATE);


-- ─── QUERY 4: Drill-down by Correlation Token ────────────────────────────
-- Shows full timeline for a specific business activity instance
-- Used by: clicking a row in the portal to see detail

DECLARE @Token NVARCHAR(100) = 'EMEA-SO-4821-20260714T140103Z';

SELECT
    CorrelationToken,
    OrderID,
    CustomerName,
    OrderAmount,
    Currency,
    Region,

    -- Timeline
    Received,
    DATEDIFF(SECOND, Received, Validated) AS [Recv→Valid (sec)],
    Validated,
    DATEDIFF(SECOND, Validated, CreditChecked) AS [Valid→Credit (sec)],
    CreditChecked,
    CreditScore,
    CreditLimit,
    DATEDIFF(SECOND, CreditChecked, Approved) AS [Credit→Apprvd (sec)],
    Approved,
    ApprovedBy,
    ApprovalType,
    DATEDIFF(SECOND, Approved, Dispatched) AS [Apprvd→Disp (sec)],
    Dispatched,
    CarrierName,
    TrackingNumber,
    DATEDIFF(SECOND, Dispatched, Invoiced) AS [Disp→Inv (sec)],
    Invoiced,
    InvoiceNumber,

    -- Total duration
    DATEDIFF(SECOND, Received, COALESCE(Invoiced, SYSUTCDATETIME())) AS [TotalDuration (sec)]

FROM bam_SalesOrder_Active
WHERE CorrelationToken = @Token

UNION ALL

SELECT
    CorrelationToken, OrderID, CustomerName, OrderAmount, Currency, Region,
    Received,
    DATEDIFF(SECOND, Received, Validated),
    Validated,
    DATEDIFF(SECOND, Validated, CreditChecked),
    CreditChecked, CreditScore, CreditLimit,
    DATEDIFF(SECOND, CreditChecked, Approved),
    Approved, ApprovedBy, ApprovalType,
    DATEDIFF(SECOND, Approved, Dispatched),
    Dispatched, CarrierName, TrackingNumber,
    DATEDIFF(SECOND, Dispatched, Invoiced),
    Invoiced, InvoiceNumber,
    Duration_Total
FROM bam_SalesOrder_Completed
WHERE CorrelationToken = @Token;


-- ─── QUERY 5: Regional Breakdown ─────────────────────────────────────────
-- Performance comparison across regions

SELECT
    Region,
    COUNT(*) AS [Orders],
    FORMAT(SUM(OrderAmount), 'C', 'en-GB') AS [TotalValue],
    AVG(DATEDIFF(MINUTE, Received, Approved)) AS [AvgMinToApproval],
    COUNT(CASE WHEN Validated_Status = 'Failed' THEN 1 END) AS [ValidationFailures],
    COUNT(CASE WHEN DATEDIFF(MINUTE, LastModifiedAt, SYSUTCDATETIME()) >
        CASE CurrentMilestone
            WHEN 'Received' THEN 2
            WHEN 'Validated' THEN 5
            WHEN 'CreditChecked' THEN 30
            WHEN 'Approved' THEN 240
            WHEN 'Dispatched' THEN 60
        END THEN 1 END) AS [SLABreaches]
FROM bam_SalesOrder_Active
WHERE CAST(CreatedAt AS DATE) = CAST(SYSUTCDATETIME() AS DATE)
GROUP BY Region
ORDER BY [Orders] DESC;
