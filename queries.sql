-- Revenue & Operations Diagnostic
-- Disabling safe updates for bulk updating date
SET SQL_SAFE_UPDATES = 0;

-- COnverting String to Date

ALTER TABLE `sample - superstore`
ADD COLUMN order_date_clean DATE,
ADD COLUMN ship_date_clean DATE;

UPDATE `sample - superstore`
SET 
  order_date_clean = STR_TO_DATE(`Order Date`, '%m/%d/%Y'),
  ship_date_clean = STR_TO_DATE(`Ship Date`, '%m/%d/%Y');

-- Renaming Table for simplicity
RENAME TABLE `sample - superstore` TO orders;

-- Key Metrics
SELECT 
  ROUND(SUM(Sales),2) AS total_revenue,
  ROUND(SUM(Profit),2) AS total_profit,
  ROUND(SUM(Profit)/SUM(Sales),3) AS profit_margin
FROM orders;

-- Regional Performance
SELECT 
  Region,
  ROUND(SUM(Sales),2) AS revenue,
  ROUND(SUM(Profit),2) AS profit,
  ROUND(SUM(Profit)/SUM(Sales),3) AS margin
FROM orders
GROUP BY Region
ORDER BY revenue DESC;

-- Top Customers
SELECT 
  `Customer ID`,
  ROUND(SUM(Sales),2) AS total_revenue
FROM orders
GROUP BY `Customer ID`
ORDER BY total_revenue DESC
LIMIT 10;

-- Customer Retention Rate
SELECT 
  ROUND(
    COUNT(DISTINCT CASE WHEN order_count > 1 THEN `Customer ID` END) 
    / COUNT(DISTINCT `Customer ID`), 
  3) AS retention_rate
FROM (
  SELECT `Customer ID`, COUNT(`Order ID`) AS order_count
  FROM orders
  GROUP BY `Customer ID`
) customer_orders;

-- Category Performance
SELECT 
  Category,
  ROUND(SUM(Sales),2) AS revenue,
  ROUND(SUM(Profit),2) AS profit,
  ROUND(SUM(Profit)/SUM(Sales),3) AS margin
FROM orders
GROUP BY Category
ORDER BY revenue DESC;

-- Loss-making Sub-Categories
SELECT 
  `Sub-Category`,
  ROUND(SUM(Profit),2) AS total_profit
FROM orders
GROUP BY `Sub-Category`
HAVING total_profit < 0
ORDER BY total_profit;

-- Discount vs Profit
SELECT 
  ROUND(Discount,2) AS discount_level,
  ROUND(AVG(Profit),2) AS avg_profit
FROM orders
GROUP BY discount_level
ORDER BY discount_level;

-- Average delivery time per Ship Mode
WITH shipping_avg AS (
  SELECT 
    `Ship Mode`,
    AVG(DATEDIFF(ship_date_clean, order_date_clean)) AS avg_delivery
  FROM orders
  GROUP BY `Ship Mode`
)

-- Dynamic Late Delivery Rate
SELECT 
  s.`Ship Mode`,
  ROUND(
    COUNT(
      CASE 
        WHEN DATEDIFF(s.ship_date_clean, s.order_date_clean) > sa.avg_delivery 
        THEN 1 
      END
    ) / COUNT(*), 
  3) AS late_delivery_rate
FROM orders s
JOIN shipping_avg sa
ON s.`Ship Mode` = sa.`Ship Mode`
GROUP BY s.`Ship Mode`;

-- Z-Score Anomaly Detection
WITH stats AS (
  SELECT 
    `Ship Mode`,
    AVG(DATEDIFF(ship_date_clean, order_date_clean)) AS avg_delivery,
    STDDEV(DATEDIFF(ship_date_clean, order_date_clean)) AS std_dev
  FROM orders
  GROUP BY `Ship Mode`
)

-- Z-score for each order
SELECT 
  s.`Order ID`,
  s.`Ship Mode`,
  DATEDIFF(s.ship_date_clean, s.order_date_clean) AS delivery_days,
  ROUND(
    (DATEDIFF(s.ship_date_clean, s.order_date_clean) - stats.avg_delivery) 
    / stats.std_dev, 
  2) AS z_score
FROM orders s
JOIN stats 
ON s.`Ship Mode` = stats.`Ship Mode`;

WITH stats AS (
  SELECT 
    `Ship Mode`,
    AVG(DATEDIFF(ship_date_clean, order_date_clean)) AS avg_delivery,
    STDDEV(DATEDIFF(ship_date_clean, order_date_clean)) AS std_dev
  FROM orders
  GROUP BY `Ship Mode`
)

SELECT 
  s.`Ship Mode`,
  COUNT(*) AS total_orders,
  COUNT(
    CASE 
      WHEN 
        ABS(
          (DATEDIFF(s.ship_date_clean, s.order_date_clean) - stats.avg_delivery) 
          / stats.std_dev
        ) > 2 
      THEN 1 
    END
  ) AS anomalous_orders,
  ROUND(
    COUNT(
      CASE 
        WHEN 
          ABS(
            (DATEDIFF(s.ship_date_clean, s.order_date_clean) - stats.avg_delivery) 
            / stats.std_dev
          ) > 2 
        THEN 1 
      END
    ) / COUNT(*), 
  3) AS anomaly_rate
FROM orders s
JOIN stats 
ON s.`Ship Mode` = stats.`Ship Mode`
GROUP BY s.`Ship Mode`;