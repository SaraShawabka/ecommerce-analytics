-- =====================================================
-- E-commerce Analytics Project
-- Purpose: Analyze sales, profitability, returns,
-- payments, and customer retention.
-- Database: DuckDB
-- =====================================================
-- Check the available source tables
SHOW TABLES;

-- =====================================================
-- 01. DATA QUALITY CHECKS
-- Purpose: Validate table sizes and primary-key uniqueness
-- =====================================================

-- Check the number of rows in each table
SELECT 'categories' AS table_name, COUNT(*) AS row_count FROM categories
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'returns', COUNT(*) FROM returns


-- Check primary-key uniqueness in each table
WITH id_checks AS (
    SELECT 'categories' AS table_name, COUNT(*) AS total_rows,
           COUNT(DISTINCT category_id) AS unique_ids
    FROM categories

    UNION ALL

    SELECT 'customers', COUNT(*), COUNT(DISTINCT customer_id)
    FROM customers

    UNION ALL

    SELECT 'orders', COUNT(*), COUNT(DISTINCT order_id)
    FROM orders

    UNION ALL

    SELECT 'order_items', COUNT(*), COUNT(DISTINCT order_item_id)
    FROM order_items

    UNION ALL

    SELECT 'products', COUNT(*), COUNT(DISTINCT product_id)
    FROM products

    UNION ALL

    SELECT 'payments', COUNT(*), COUNT(DISTINCT payment_id)
    FROM payments

    UNION ALL

    SELECT 'returns', COUNT(*), COUNT(DISTINCT return_id)
    FROM returns
)
SELECT *
FROM id_checks
ORDER BY table_name;


-- Check referential integrity between related tables
WITH relationship_checks AS (
    SELECT
        'orders -> customers' AS relationship,
        COUNT(*) AS unmatched_rows
    FROM orders o
    LEFT JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE c.customer_id IS NULL

    UNION ALL

    SELECT
        'order_items -> orders',
        COUNT(*)
    FROM order_items i
    LEFT JOIN orders o
        ON i.order_id = o.order_id
    WHERE o.order_id IS NULL

    UNION ALL

    SELECT
        'order_items -> products',
        COUNT(*)
    FROM order_items i
    LEFT JOIN products p
        ON i.product_id = p.product_id
    WHERE p.product_id IS NULL

    UNION ALL

    SELECT
        'products -> categories',
        COUNT(*)
    FROM products p
    LEFT JOIN categories c
        ON p.category_id = c.category_id
    WHERE c.category_id IS NULL

    UNION ALL

    SELECT
        'payments -> orders',
        COUNT(*)
    FROM payments p
    LEFT JOIN orders o
        ON p.order_id = o.order_id
    WHERE o.order_id IS NULL

    UNION ALL

    SELECT
        'returns -> order_items',
        COUNT(*)
    FROM returns r
    LEFT JOIN order_items i
        ON r.order_item_id = i.order_item_id
    WHERE i.order_item_id IS NULL
)
SELECT *
FROM relationship_checks
ORDER BY relationship;


-- Check missing values in key order and customer fields
SELECT
    'orders' AS table_name,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS missing_customer_id,
    COUNT(*) FILTER (WHERE ordered_at IS NULL) AS missing_ordered_at,
    COUNT(*) FILTER (WHERE status IS NULL) AS missing_status,
    COUNT(*) FILTER (WHERE channel IS NULL) AS missing_channel
FROM orders

UNION ALL

SELECT
    'customers',
    COUNT(*) FILTER (WHERE customer_id IS NULL),
    COUNT(*) FILTER (WHERE signup_date IS NULL),
    COUNT(*) FILTER (WHERE country IS NULL),
    COUNT(*) FILTER (WHERE loyalty_tier IS NULL)
FROM customers;


-- Check missing values in key product and order-item fields
SELECT
    'products' AS table_name,
    COUNT(*) FILTER (WHERE product_name IS NULL) AS missing_name,
    COUNT(*) FILTER (WHERE category_id IS NULL) AS missing_category,
    COUNT(*) FILTER (WHERE unit_price IS NULL) AS missing_unit_price,
    COUNT(*) FILTER (WHERE unit_cost IS NULL) AS missing_unit_cost
FROM products

UNION ALL

SELECT
    'order_items',
    COUNT(*) FILTER (WHERE order_id IS NULL),
    COUNT(*) FILTER (WHERE product_id IS NULL),
    COUNT(*) FILTER (WHERE quantity IS NULL),
    COUNT(*) FILTER (WHERE unit_price IS NULL)
FROM order_items;


-- Check invalid quantities, prices, costs, and discounts
SELECT
    COUNT(*) FILTER (WHERE quantity <= 0) AS invalid_quantities,
    COUNT(*) FILTER (WHERE unit_price <= 0) AS invalid_item_prices,
    COUNT(*) FILTER (WHERE discount_amount < 0) AS negative_discounts,
    COUNT(*) FILTER (
        WHERE discount_amount > quantity * unit_price
    ) AS discounts_above_line_value
FROM order_items;


-- Check invalid product prices and costs
SELECT
    COUNT(*) FILTER (WHERE unit_price <= 0) AS invalid_product_prices,
    COUNT(*) FILTER (WHERE unit_cost < 0) AS negative_unit_costs,
    COUNT(*) FILTER (WHERE unit_price < unit_cost) AS products_costing_more_than_price
FROM products;


-- =====================================================
-- 02. SALES AND PROFITABILITY
-- Purpose: Understand order status before measuring sales
-- =====================================================

-- Review the distribution of order statuses
SELECT
    status,
    COUNT(*) AS total_orders,
    ROUND(
        100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders),
        2
    ) AS order_pct
FROM orders
GROUP BY status
ORDER BY total_orders DESC;


-- Calculate sales and discounts for delivered orders
SELECT
    ROUND(SUM(i.quantity * i.unit_price), 2) AS gross_sales,
    ROUND(SUM(i.discount_amount), 2) AS total_discounts,
    ROUND(
        SUM(i.quantity * i.unit_price - i.discount_amount),
        2
    ) AS net_sales,
    ROUND(
        100.0 * SUM(i.discount_amount)
        / NULLIF(SUM(i.quantity * i.unit_price), 0),
        2
    ) AS discount_rate_pct
FROM orders AS o
JOIN order_items AS i
    ON o.order_id = i.order_id
WHERE o.status = 'delivered';


-- Calculate cost of goods sold and gross profit
-- for delivered orders
SELECT
    ROUND(
        SUM(i.quantity * p.unit_cost),
        2
    ) AS cost_of_goods_sold,
    ROUND(
        SUM(i.quantity * i.unit_price - i.discount_amount),
        2
    ) AS net_sales,
    ROUND(
        SUM(
            i.quantity * i.unit_price
            - i.discount_amount
            - i.quantity * p.unit_cost
        ),
        2
    ) AS gross_profit,
    ROUND(
        100.0 * SUM(
            i.quantity * i.unit_price
            - i.discount_amount
            - i.quantity * p.unit_cost
        )
        / NULLIF(
            SUM(i.quantity * i.unit_price - i.discount_amount),
            0
        ),
        2
    ) AS gross_margin_pct
FROM orders AS o
JOIN order_items AS i
    ON o.order_id = i.order_id
JOIN products AS p
    ON i.product_id = p.product_id
WHERE o.status = 'delivered';

-- Compare sales, cost, and gross profit by product category
-- using delivered orders only
SELECT
    c.category_name,
    ROUND(SUM(i.quantity * i.unit_price - i.discount_amount), 2) AS net_sales,
    ROUND(SUM(i.quantity * p.unit_cost), 2) AS cost_of_goods_sold,
    ROUND(
        SUM(i.quantity * i.unit_price - i.discount_amount - i.quantity * p.unit_cost),
        2
    ) AS gross_profit,
    ROUND(
        100.0 * SUM(i.quantity * i.unit_price - i.discount_amount - i.quantity * p.unit_cost)
        / NULLIF(SUM(i.quantity * i.unit_price - i.discount_amount), 0),
        2
    ) AS gross_margin_pct
FROM orders AS o
JOIN order_items AS i
    ON o.order_id = i.order_id
JOIN products AS p
    ON i.product_id = p.product_id
JOIN categories AS c
    ON p.category_id = c.category_id
WHERE o.status = 'delivered'
GROUP BY c.category_name
ORDER BY gross_profit DESC;

-- Compare delivered sales performance across sales channels
SELECT
    o.channel,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(
        SUM(i.quantity * i.unit_price - i.discount_amount), 2
    ) AS net_sales,
    ROUND(
        SUM(i.quantity * i.unit_price - i.discount_amount
            - i.quantity * p.unit_cost), 2
    ) AS gross_profit,
    ROUND(
        100.0 * SUM(i.quantity * i.unit_price - i.discount_amount
            - i.quantity * p.unit_cost)
        / NULLIF(
            SUM(i.quantity * i.unit_price - i.discount_amount), 0
        ), 2
    ) AS gross_margin_pct
FROM orders AS o
JOIN order_items AS i
    ON o.order_id = i.order_id
JOIN products AS p
    ON i.product_id = p.product_id
WHERE o.status = 'delivered'
GROUP BY o.channel
ORDER BY net_sales DESC;

-- Analyze monthly sales and gross profit trends
-- using delivered orders only
SELECT
    DATE_TRUNC('month', o.ordered_at) AS sales_month,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(
        SUM(i.quantity * i.unit_price - i.discount_amount), 2
    ) AS net_sales,
    ROUND(
        SUM(i.quantity * i.unit_price - i.discount_amount
            - i.quantity * p.unit_cost), 2
    ) AS gross_profit
FROM orders AS o
JOIN order_items AS i
    ON o.order_id = i.order_id
JOIN products AS p
    ON i.product_id = p.product_id
WHERE o.status = 'delivered'
GROUP BY DATE_TRUNC('month', o.ordered_at)
ORDER BY sales_month;
-- =====================================================
-- 03. PAYMENTS ANALYSIS
-- Purpose: Evaluate payment outcomes and failure patterns
-- =====================================================
-- Analyze payment outcomes and failure rates
SELECT
    status,
    COUNT(*) AS payment_count,
    ROUND(SUM(amount), 2) AS total_payment_amount,
    ROUND(
        100.0 * COUNT(*) / (SELECT COUNT(*) FROM payments),
        2
    ) AS payment_pct
FROM payments
GROUP BY status
ORDER BY payment_count DESC;

-- Identify the most common reasons for failed payments
SELECT
    failure_reason,
    COUNT(*) AS failed_payment_count,
    ROUND(
        100.0 * COUNT(*) /
        (SELECT COUNT(*) FROM payments WHERE status = 'failed'),
        2
    ) AS pct_of_failed_payments
FROM payments
WHERE status = 'failed'
GROUP BY failure_reason
ORDER BY failed_payment_count DESC;

-- Compare failed payment records across order statuses
SELECT
    o.status AS order_status,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT p.order_id) FILTER (
        WHERE p.status = 'failed'
    ) AS orders_with_failed_payments,
    ROUND(
        100.0 * COUNT(DISTINCT p.order_id) FILTER (
            WHERE p.status = 'failed'
        ) / NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS pct_orders_with_failed_payments
FROM orders AS o
LEFT JOIN payments AS p
    ON o.order_id = p.order_id
GROUP BY o.status
ORDER BY total_orders DESC;

-- Compare payment methods by volume and failure rate
SELECT
    method,
    COUNT(*) AS total_payment_attempts,
    COUNT(*) FILTER (
        WHERE status = 'captured'
    ) AS captured_payments,
    COUNT(*) FILTER (
        WHERE status = 'failed'
    ) AS failed_payments,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE status = 'failed'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS failure_rate_pct
FROM payments
GROUP BY method
ORDER BY total_payment_attempts DESC;

-- =====================================================
-- 04. RETURNS ANALYSIS
-- Purpose: Understand returns, refunds, and return patterns
-- =====================================================
-- Summarize return volume, refunds, and restocking
SELECT
    COUNT(*) AS total_returns,
    COUNT(DISTINCT order_item_id) AS unique_returned_items,
    ROUND(SUM(refund_amount), 2) AS total_refunds,
    ROUND(AVG(refund_amount), 2) AS avg_refund_amount,
    COUNT(*) FILTER (
        WHERE restocked = TRUE
    ) AS restocked_returns,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE restocked = TRUE
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS restocked_pct
FROM returns;

-- Identify the most common return reasons
SELECT
    reason,
    COUNT(*) AS return_count,
    ROUND(SUM(refund_amount), 2) AS total_refunds,
    ROUND(
        100.0 * COUNT(*) / (SELECT COUNT(*) FROM returns),
        2
    ) AS return_pct
FROM returns
GROUP BY reason
ORDER BY return_count DESC;

-- Compare return-line rates across product categories
-- using delivered and returned orders as the denominator
SELECT
    c.category_name,
    COUNT(DISTINCT i.order_item_id) AS total_order_lines,
    COUNT(DISTINCT r.order_item_id) AS returned_lines,
    ROUND(
        100.0 * COUNT(DISTINCT r.order_item_id)
        / NULLIF(COUNT(DISTINCT i.order_item_id), 0),
        2
    ) AS return_line_rate_pct,
    ROUND(SUM(r.refund_amount), 2) AS total_refunds
FROM orders AS o
JOIN order_items AS i
    ON o.order_id = i.order_id
JOIN products AS p
    ON i.product_id = p.product_id
JOIN categories AS c
    ON p.category_id = c.category_id
LEFT JOIN returns AS r
    ON i.order_item_id = r.order_item_id
WHERE o.status IN ('delivered', 'returned')
GROUP BY c.category_name
ORDER BY return_line_rate_pct DESC;

-- Break down return reasons by product category
SELECT
    c.category_name,
    r.reason,
    COUNT(*) AS return_count,
    ROUND(SUM(r.refund_amount), 2) AS total_refunds
FROM returns AS r
JOIN order_items AS i
    ON r.order_item_id = i.order_item_id
JOIN products AS p
    ON i.product_id = p.product_id
JOIN categories AS c
    ON p.category_id = c.category_id
GROUP BY
    c.category_name,
    r.reason
ORDER BY
    c.category_name,
    return_count DESC;

-- =====================================================
-- 05. CUSTOMER ANALYTICS
-- Purpose: Understand customer spending and purchase behavior
-- =====================================================
-- Compare customer spending and purchase frequency by loyalty tier
-- using delivered orders only
WITH customer_metrics AS (
    SELECT
        c.customer_id,
        c.loyalty_tier,
        COUNT(DISTINCT o.order_id) AS delivered_orders,
        SUM(i.quantity * i.unit_price - i.discount_amount) AS net_sales
    FROM customers AS c
    JOIN orders AS o
        ON c.customer_id = o.customer_id
    JOIN order_items AS i
        ON o.order_id = i.order_id
    WHERE o.status = 'delivered'
    GROUP BY
        c.customer_id,
        c.loyalty_tier
)
SELECT
    COALESCE(loyalty_tier, 'Not specified') AS loyalty_tier,
    COUNT(*) AS customers_with_delivered_orders,
    ROUND(AVG(net_sales), 2) AS avg_sales_per_customer,
    ROUND(AVG(delivered_orders), 2) AS avg_orders_per_customer,
    ROUND(
        SUM(net_sales) / NULLIF(SUM(delivered_orders), 0),
        2
    ) AS avg_sales_per_order
FROM customer_metrics
GROUP BY loyalty_tier
ORDER BY avg_sales_per_customer DESC;

-- Segment customers by the number of delivered orders
WITH customer_order_counts AS (
    SELECT
        c.customer_id,
        COUNT(DISTINCT o.order_id) AS delivered_orders
    FROM customers AS c
    JOIN orders AS o
        ON c.customer_id = o.customer_id
    WHERE o.status = 'delivered'
    GROUP BY c.customer_id
)
SELECT
    CASE
        WHEN delivered_orders = 1 THEN '1 order'
        WHEN delivered_orders BETWEEN 2 AND 5 THEN '2-5 orders'
        ELSE '6+ orders'
    END AS customer_segment,
    COUNT(*) AS customer_count,
    ROUND(
        100.0 * COUNT(*) /
        (SELECT COUNT(*) FROM customer_order_counts),
        2
    ) AS customer_pct
FROM customer_order_counts
GROUP BY customer_segment
ORDER BY
    CASE customer_segment
        WHEN '1 order' THEN 1
        WHEN '2-5 orders' THEN 2
        ELSE 3
    END;


-- =====================================================
-- 06. Customer Retention (Cohort Analysis)
-- =====================================================

-- Calculate monthly customer retention by first-purchase cohort
WITH first_purchase AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(ordered_at)) AS cohort_month
    FROM orders
    WHERE status = 'delivered'
    GROUP BY customer_id
),

customer_activity AS (
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC('month', ordered_at) AS activity_month
    FROM orders
    WHERE status = 'delivered'
),

cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(*) AS cohort_size
    FROM first_purchase
    GROUP BY cohort_month
),

cohort_activity AS (
    SELECT
        f.cohort_month,
        DATE_DIFF(
            'month',
            f.cohort_month,
            a.activity_month
        ) AS months_since_first_purchase,
        COUNT(DISTINCT a.customer_id) AS active_customers
    FROM first_purchase AS f
    JOIN customer_activity AS a
        ON f.customer_id = a.customer_id
    GROUP BY
        f.cohort_month,
        months_since_first_purchase
),

latest_month AS (
    SELECT
        DATE_TRUNC('month', MAX(ordered_at)) AS latest_month
    FROM orders
    WHERE status = 'delivered'
),

cohort_months AS (
    SELECT
        cs.cohort_month,
        cs.cohort_size,
        month_number AS months_since_first_purchase
    FROM cohort_sizes AS cs
    CROSS JOIN latest_month AS lm
    CROSS JOIN UNNEST(
        GENERATE_SERIES(
            0,
            DATE_DIFF('month', cs.cohort_month, lm.latest_month)
        )
    ) AS months(month_number)
),

retention AS (
    SELECT
        cm.cohort_month,
        cm.cohort_size,
        cm.months_since_first_purchase,
        COALESCE(ca.active_customers, 0) AS active_customers,
        ROUND(
            100.0 * COALESCE(ca.active_customers, 0)
            / cm.cohort_size,
            2
        ) AS retention_rate_pct
    FROM cohort_months AS cm
    LEFT JOIN cohort_activity AS ca
        ON cm.cohort_month = ca.cohort_month
        AND cm.months_since_first_purchase =
            ca.months_since_first_purchase
)

SELECT
    cohort_month,
    cohort_size,
    MAX(CASE WHEN months_since_first_purchase = 0 THEN retention_rate_pct END) AS month_0,
    MAX(CASE WHEN months_since_first_purchase = 1 THEN retention_rate_pct END) AS month_1,
    MAX(CASE WHEN months_since_first_purchase = 2 THEN retention_rate_pct END) AS month_2,
    MAX(CASE WHEN months_since_first_purchase = 3 THEN retention_rate_pct END) AS month_3,
    MAX(CASE WHEN months_since_first_purchase = 4 THEN retention_rate_pct END) AS month_4,
    MAX(CASE WHEN months_since_first_purchase = 5 THEN retention_rate_pct END) AS month_5,
    MAX(CASE WHEN months_since_first_purchase = 6 THEN retention_rate_pct END) AS month_6,
    MAX(CASE WHEN months_since_first_purchase = 7 THEN retention_rate_pct END) AS month_7,
    MAX(CASE WHEN months_since_first_purchase = 8 THEN retention_rate_pct END) AS month_8,
    MAX(CASE WHEN months_since_first_purchase = 9 THEN retention_rate_pct END) AS month_9,
    MAX(CASE WHEN months_since_first_purchase = 10 THEN retention_rate_pct END) AS month_10,
    MAX(CASE WHEN months_since_first_purchase = 11 THEN retention_rate_pct END) AS month_11,
    MAX(CASE WHEN months_since_first_purchase = 12 THEN retention_rate_pct END) AS month_12
FROM retention
GROUP BY
    cohort_month,
    cohort_size
ORDER BY cohort_month;








