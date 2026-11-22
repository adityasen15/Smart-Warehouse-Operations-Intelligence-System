/*
============================================================
SMART WAREHOUSE OPERATIONS INTELLIGENCE SYSTEM
SQL ANALYSIS SCRIPT
============================================================
Database : SmartWarehouseDB
Platform : Microsoft SQL Server

Purpose:
- Validate the warehouse data model
- Analyze order volume, sales, profit and delays
- Identify bottleneck stages
- Compare warehouses, shifts and shipping modes
- Produce KPI outputs used in the Power BI dashboard

Core model:
    Fact_Orders
      -> Dim_Date
      -> Dim_Geography
      -> Dim_Shipping_Mode
      -> Dim_Warehouse
      -> Dim_Shift

============================================================
*/

USE SmartWarehouseDB;
GO

/* ============================================================
1. DATA VALIDATION
============================================================ */

-- Check total fact rows
SELECT COUNT(*) AS Total_Orders
FROM Fact_Orders;
GO

-- Check order date range
SELECT
    MIN(CAST(Order_Date AS DATE)) AS Min_Order_Date,
    MAX(CAST(Order_Date AS DATE)) AS Max_Order_Date
FROM Fact_Orders;
GO

-- Check important numeric columns for NULL values
SELECT
    SUM(CASE WHEN Order_Quantity IS NULL THEN 1 ELSE 0 END) AS Null_Order_Quantity,
    SUM(CASE WHEN Sales IS NULL THEN 1 ELSE 0 END) AS Null_Sales,
    SUM(CASE WHEN Profit IS NULL THEN 1 ELSE 0 END) AS Null_Profit,
    SUM(CASE WHEN Scheduled_Shipping_Days IS NULL THEN 1 ELSE 0 END) AS Null_Scheduled_Days,
    SUM(CASE WHEN Actual_Shipping_Days IS NULL THEN 1 ELSE 0 END) AS Null_Actual_Days,
    SUM(CASE WHEN Worker_Count IS NULL THEN 1 ELSE 0 END) AS Null_Worker_Count
FROM Fact_Orders;
GO

-- Check key dimension values
SELECT DISTINCT Shipping_Mode
FROM Fact_Orders
WHERE Shipping_Mode IS NOT NULL
ORDER BY Shipping_Mode;
GO

SELECT DISTINCT Warehouse_ID
FROM Fact_Orders
WHERE Warehouse_ID IS NOT NULL
ORDER BY Warehouse_ID;
GO

SELECT DISTINCT Shift
FROM Fact_Orders
WHERE Shift IS NOT NULL
ORDER BY Shift;
GO

SELECT DISTINCT Customer_Segment
FROM Fact_Orders
WHERE Customer_Segment IS NOT NULL
ORDER BY Customer_Segment;
GO

SELECT DISTINCT Order_Priority
FROM Fact_Orders
WHERE Order_Priority IS NOT NULL
ORDER BY Order_Priority;
GO

SELECT DISTINCT Delivery_Status
FROM Fact_Orders
WHERE Delivery_Status IS NOT NULL
ORDER BY Delivery_Status;
GO

SELECT DISTINCT SLA_Status
FROM Fact_Orders
WHERE SLA_Status IS NOT NULL
ORDER BY SLA_Status;
GO

SELECT DISTINCT Bottleneck_Stage
FROM Fact_Orders
WHERE Bottleneck_Stage IS NOT NULL
ORDER BY Bottleneck_Stage;
GO

/* ============================================================
2. CORE BUSINESS KPIs
============================================================ */

SELECT COUNT(*) AS Total_Orders
FROM Fact_Orders;
GO

SELECT
    SUM(Order_Quantity) AS Total_Units,
    SUM(Sales) AS Total_Sales,
    SUM(Profit) AS Total_Profit
FROM Fact_Orders;
GO

SELECT
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
    CAST(
        100.0 * SUM(CASE WHEN SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent,
    CAST(
        100.0 * SUM(CASE WHEN SLA_Status = 'On Time' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS SLA_Compliance_Percent
FROM Fact_Orders;
GO

SELECT
    AVG(Total_Cycle_Time_Min) AS Avg_Cycle_Time,
    AVG(Queue_Time_Min) AS Avg_Queue_Time,
    AVG(Picking_Time_Min) AS Avg_Picking_Time,
    AVG(Packing_Time_Min) AS Avg_Packing_Time,
    AVG(Dispatch_Time_Min) AS Avg_Dispatch_Time,
    AVG(Storage_Time_Min) AS Avg_Storage_Time,
    AVG(QC_Time_Min) AS Avg_QC_Time
FROM Fact_Orders;
GO

/* ============================================================
3. BOTTLENECK ANALYSIS
============================================================ */

-- Volume of orders assigned to each bottleneck stage
SELECT
    Bottleneck_Stage,
    COUNT(*) AS Orders
FROM Fact_Orders
GROUP BY Bottleneck_Stage
ORDER BY Orders DESC;
GO

-- Bottleneck stage + SLA status
SELECT
    Bottleneck_Stage,
    SLA_Status,
    COUNT(*) AS Order_Count
FROM Fact_Orders
GROUP BY Bottleneck_Stage, SLA_Status
ORDER BY Bottleneck_Stage, Order_Count DESC;
GO

-- Delay rate by bottleneck stage
SELECT
    Bottleneck_Stage,
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
    CAST(
        100.0 * SUM(CASE WHEN SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent
FROM Fact_Orders
GROUP BY Bottleneck_Stage
ORDER BY Delayed_Orders DESC;
GO

-- Contribution of each bottleneck stage to all delayed orders
WITH BottleneckStats AS
(
    SELECT
        Bottleneck_Stage,
        COUNT(*) AS Total_Orders,
        SUM(CASE WHEN SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders
    FROM Fact_Orders
    GROUP BY Bottleneck_Stage
)
SELECT
    Bottleneck_Stage,
    Total_Orders,
    Delayed_Orders,
    CAST(
        100.0 * Delayed_Orders / SUM(Delayed_Orders) OVER ()
        AS DECIMAL(5,2)
    ) AS Contribution_Percent
FROM BottleneckStats
ORDER BY Delayed_Orders DESC;
GO

-- Bottleneck rank by delay rate
WITH BottleneckStats AS
(
    SELECT
        Bottleneck_Stage,
        COUNT(*) AS Total_Orders,
        SUM(CASE WHEN SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders
    FROM Fact_Orders
    GROUP BY Bottleneck_Stage
)
SELECT
    Bottleneck_Stage,
    Total_Orders,
    Delayed_Orders,
    CAST(100.0 * Delayed_Orders / Total_Orders AS DECIMAL(5,2)) AS Delay_Rate_Percent,
    DENSE_RANK() OVER
    (
        ORDER BY 100.0 * Delayed_Orders / Total_Orders DESC
    ) AS Bottleneck_Rank
FROM BottleneckStats
ORDER BY Bottleneck_Rank;
GO

/* ============================================================
4. WAREHOUSE PERFORMANCE
============================================================ */

SELECT
    W.Warehouse_ID,
    COUNT(F.Order_ID) AS Total_Orders,
    SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
    CAST(
        100.0 * SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(F.Order_ID) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent
FROM Fact_Orders F
INNER JOIN Dim_Warehouse W
    ON F.Warehouse_Key = W.Warehouse_Key
GROUP BY W.Warehouse_ID
ORDER BY Delay_Rate_Percent DESC;
GO

-- Rank warehouses by delay rate
WITH WarehouseStats AS
(
    SELECT
        W.Warehouse_ID,
        COUNT(F.Order_ID) AS Total_Orders,
        SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
        CAST(
            100.0 * SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
            / COUNT(F.Order_ID) AS DECIMAL(5,2)
        ) AS Delay_Rate_Percent
    FROM Fact_Orders F
    INNER JOIN Dim_Warehouse W
        ON F.Warehouse_Key = W.Warehouse_Key
    GROUP BY W.Warehouse_ID
)
SELECT
    *,
    DENSE_RANK() OVER (ORDER BY Delay_Rate_Percent DESC) AS Warehouse_Rank
FROM WarehouseStats
ORDER BY Warehouse_Rank;
GO

-- Warehouse × bottleneck stage
SELECT
    W.Warehouse_ID,
    F.Bottleneck_Stage,
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
    CAST(
        100.0 * SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent
FROM Fact_Orders F
INNER JOIN Dim_Warehouse W
    ON F.Warehouse_Key = W.Warehouse_Key
GROUP BY W.Warehouse_ID, F.Bottleneck_Stage
ORDER BY W.Warehouse_ID, Delay_Rate_Percent DESC;
GO

-- Warehouse contribution / comparison against overall average
WITH WarehouseStats AS
(
    SELECT
        W.Warehouse_ID,
        COUNT(*) AS Total_Orders,
        SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
        CAST(
            100.0 * SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
            / COUNT(*) AS DECIMAL(5,2)
        ) AS Delay_Rate_Percent
    FROM Fact_Orders F
    INNER JOIN Dim_Warehouse W
        ON F.Warehouse_Key = W.Warehouse_Key
    GROUP BY W.Warehouse_ID
)
SELECT
    *,
    CAST(AVG(Delay_Rate_Percent) OVER () AS DECIMAL(5,2)) AS Avg_Warehouse_Delay_Rate
FROM WarehouseStats
ORDER BY Delay_Rate_Percent DESC;
GO

/* ============================================================
5. SHIFT ANALYSIS
============================================================ */

SELECT
    S.Shift,
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
    CAST(
        100.0 * SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent
FROM Fact_Orders F
INNER JOIN Dim_Shift S
    ON F.Shift_Key = S.Shift_Key
GROUP BY S.Shift
ORDER BY Delay_Rate_Percent DESC;
GO

-- Shift × bottleneck stage
SELECT
    S.Shift,
    F.Bottleneck_Stage,
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
    CAST(
        100.0 * SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent
FROM Fact_Orders F
INNER JOIN Dim_Shift S
    ON F.Shift_Key = S.Shift_Key
GROUP BY S.Shift, F.Bottleneck_Stage
ORDER BY S.Shift, Delay_Rate_Percent DESC;
GO

-- Average cycle and process time by shift
SELECT
    S.Shift,
    COUNT(*) AS Total_Orders,
    AVG(F.Queue_Time_Min) AS Avg_Queue_Time,
    AVG(F.Picking_Time_Min) AS Avg_Picking_Time,
    AVG(F.Packing_Time_Min) AS Avg_Packing_Time,
    AVG(F.Total_Cycle_Time_Min) AS Avg_Cycle_Time
FROM Fact_Orders F
INNER JOIN Dim_Shift S
    ON F.Shift_Key = S.Shift_Key
GROUP BY S.Shift
ORDER BY Avg_Cycle_Time DESC;
GO

-- Workforce vs shift performance
SELECT
    S.Shift,
    COUNT(*) AS Total_Orders,
    AVG(F.Worker_Count) AS Avg_Worker_Count,
    AVG(F.Order_Quantity) AS Avg_Order_Quantity,
    AVG(F.Total_Cycle_Time_Min) AS Avg_Cycle_Time
FROM Fact_Orders F
INNER JOIN Dim_Shift S
    ON F.Shift_Key = S.Shift_Key
GROUP BY S.Shift
ORDER BY Avg_Worker_Count;
GO

/* ============================================================
6. WORKER COUNT ANALYSIS
============================================================ */

SELECT
    MIN(Worker_Count) AS Min_Workers,
    MAX(Worker_Count) AS Max_Workers,
    AVG(Worker_Count) AS Avg_Workers
FROM Fact_Orders;
GO

SELECT DISTINCT Worker_Count
FROM Fact_Orders
ORDER BY Worker_Count;
GO

SELECT
    Worker_Count,
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
    CAST(
        100.0 * SUM(CASE WHEN SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent,
    AVG(Total_Cycle_Time_Min) AS Avg_Cycle_Time
FROM Fact_Orders
GROUP BY Worker_Count
ORDER BY Worker_Count;
GO

/* ============================================================
7. SHIPPING MODE ANALYSIS
============================================================ */

SELECT
    SM.Shipping_Mode,
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
    CAST(
        100.0 * SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent
FROM Fact_Orders F
INNER JOIN Dim_Shipping_Mode SM
    ON F.Shipping_Mode_Key = SM.Shipping_Mode_Key
GROUP BY SM.Shipping_Mode
ORDER BY Delay_Rate_Percent DESC;
GO

-- Actual late rate based on actual vs scheduled shipping days
SELECT
    SM.Shipping_Mode,
    COUNT(*) AS Total_Orders,
    SUM(
        CASE
            WHEN F.Actual_Shipping_Days > F.Scheduled_Shipping_Days THEN 1
            ELSE 0
        END
    ) AS Actually_Late_Orders,
    CAST(
        100.0 * SUM(
            CASE
                WHEN F.Actual_Shipping_Days > F.Scheduled_Shipping_Days THEN 1
                ELSE 0
            END
        ) / COUNT(*) AS DECIMAL(5,2)
    ) AS Actual_Late_Rate_Percent
FROM Fact_Orders F
INNER JOIN Dim_Shipping_Mode SM
    ON F.Shipping_Mode_Key = SM.Shipping_Mode_Key
GROUP BY SM.Shipping_Mode
ORDER BY Actual_Late_Rate_Percent DESC;
GO

-- Scheduled vs actual shipping duration
SELECT
    SM.Shipping_Mode,
    COUNT(*) AS Total_Orders,
    AVG(F.Scheduled_Shipping_Days) AS Avg_Scheduled_Days,
    AVG(F.Actual_Shipping_Days) AS Avg_Actual_Days,
    AVG(F.Actual_Shipping_Days - F.Scheduled_Shipping_Days) AS Avg_Delay_Days
FROM Fact_Orders F
INNER JOIN Dim_Shipping_Mode SM
    ON F.Shipping_Mode_Key = SM.Shipping_Mode_Key
GROUP BY SM.Shipping_Mode
ORDER BY Avg_Delay_Days DESC;
GO

/* ============================================================
8. ORDER PRIORITY ANALYSIS
============================================================ */

SELECT
    Order_Priority,
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
    CAST(
        100.0 * SUM(CASE WHEN SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent
FROM Fact_Orders
GROUP BY Order_Priority
ORDER BY Delay_Rate_Percent DESC;
GO

/* ============================================================
9. CUSTOMER SEGMENT ANALYSIS
============================================================ */

SELECT
    Customer_Segment,
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
    CAST(
        100.0 * SUM(CASE WHEN SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent
FROM Fact_Orders
GROUP BY Customer_Segment
ORDER BY Delay_Rate_Percent DESC;
GO

/* ============================================================
10. GEOGRAPHY / REGION ANALYSIS
============================================================ */

SELECT
    G.Order_Region,
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
    CAST(
        100.0 * SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent
FROM Fact_Orders F
INNER JOIN Dim_Geography G
    ON F.Geography_Key = G.Geography_Key
GROUP BY G.Order_Region
ORDER BY Delay_Rate_Percent DESC;
GO

/* ============================================================
11. DATE / TIME PERFORMANCE
============================================================ */

-- Monthly order and delay trend
SELECT
    D.Year,
    D.Month,
    D.Month_Name,
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
    CAST(
        100.0 * SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent
FROM Fact_Orders F
INNER JOIN Dim_Date D
    ON F.Date_Key = D.Date_Key
GROUP BY D.Year, D.Month, D.Month_Name
ORDER BY D.Year, D.Month;
GO

-- Weekday vs weekend performance
SELECT
    CASE WHEN D.Is_Weekend = 1 THEN 'Weekend' ELSE 'Weekday' END AS Day_Type,
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
    CAST(
        100.0 * SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent
FROM Fact_Orders F
INNER JOIN Dim_Date D
    ON F.Date_Key = D.Date_Key
GROUP BY D.Is_Weekend
ORDER BY Delay_Rate_Percent DESC;
GO

/* ============================================================
12. OPERATIONAL TIME ANALYSIS
============================================================ */

SELECT
    Bottleneck_Stage,
    AVG(Receiving_Time_Min) AS Avg_Receiving_Time,
    AVG(QC_Time_Min) AS Avg_QC_Time,
    AVG(Storage_Time_Min) AS Avg_Storage_Time,
    AVG(Picking_Time_Min) AS Avg_Picking_Time,
    AVG(Packing_Time_Min) AS Avg_Packing_Time,
    AVG(Dispatch_Time_Min) AS Avg_Dispatch_Time,
    AVG(Queue_Time_Min) AS Avg_Queue_Time,
    AVG(Total_Cycle_Time_Min) AS Avg_Total_Cycle_Time
FROM Fact_Orders
GROUP BY Bottleneck_Stage
ORDER BY Avg_Total_Cycle_Time DESC;
GO

/* ============================================================
13. POWER BI SUPPORTING DATASETS
These queries are designed to provide clean result sets for
Power BI visuals when needed.
============================================================ */

-- KPI dataset
SELECT
    COUNT(*) AS Total_Orders,
    SUM(Order_Quantity) AS Total_Units,
    SUM(Sales) AS Total_Sales,
    SUM(Profit) AS Total_Profit,
    AVG(Total_Cycle_Time_Min) AS Avg_Cycle_Time,
    CAST(
        100.0 * SUM(CASE WHEN SLA_Status = 'On Time' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS SLA_Compliance_Percent,
    CAST(
        100.0 * SUM(CASE WHEN SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent
FROM Fact_Orders;
GO

-- Bottleneck visual dataset
SELECT
    Bottleneck_Stage,
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders
FROM Fact_Orders
GROUP BY Bottleneck_Stage
ORDER BY Delayed_Orders DESC;
GO

-- Shift visual dataset
SELECT
    S.Shift,
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
    CAST(
        100.0 * SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent
FROM Fact_Orders F
INNER JOIN Dim_Shift S
    ON F.Shift_Key = S.Shift_Key
GROUP BY S.Shift;
GO

-- Warehouse visual dataset
SELECT
    W.Warehouse_ID,
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END) AS Delayed_Orders,
    CAST(
        100.0 * SUM(CASE WHEN F.SLA_Status = 'At Risk/Delayed' THEN 1 ELSE 0 END)
        / COUNT(*) AS DECIMAL(5,2)
    ) AS Delay_Rate_Percent
FROM Fact_Orders F
INNER JOIN Dim_Warehouse W
    ON F.Warehouse_Key = W.Warehouse_Key
GROUP BY W.Warehouse_ID;
GO

/* ============================================================
END OF ANALYSIS SCRIPT
============================================================ */
