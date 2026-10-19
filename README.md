\# E-commerce Data Analysis with SQL and DuckDB



\## Project Overview

This project analyzes e-commerce data using SQL and DuckDB to evaluate sales performance, gross profitability, payment outcomes, product returns, and customer purchasing behavior.



\## Business Question

How can an online retailer use sales, product, payment, return, and customer data to understand business performance and identify opportunities to improve profitability and customer retention?



\## Tools

\- SQL

\- DuckDB

\- DBeaver



\## Dataset Overview

The project uses seven related tables:

\- Orders

\- Order items

\- Customers

\- Products

\- Categories

\- Payments

\- Returns



\## Analysis Areas

1\. \*\*Data Quality Checks\*\* — table sizes, key uniqueness, and referential integrity.

2\. \*\*Sales and Profitability\*\* — delivered-order sales, cost of goods sold, gross profit, and category performance.

3\. \*\*Payments Analysis\*\* — captured and failed payment attempts.

4\. \*\*Returns Analysis\*\* — return reasons and refund amounts.

5\. \*\*Customer Analytics\*\* — purchase frequency, spending patterns, and customer segments.

6\. \*\*Customer Retention\*\* — cohort-based analysis of repeat purchasing behavior.



\## Key Findings

\- Analyzed 90,000 orders covering January 2023 through December 2025.

\- Delivered orders generated approximately 6.51 million in sales after discounts and 2.58 million in gross profit, with a gross margin of approximately 39.67%.

\- Payment attempts had a failure rate of approximately 5.53%.

\- The most frequently recorded return reason was `changed\_mind`, followed by `damaged`.

\- Purchase frequency and retention varied across customer groups and cohorts.

\- Product categories differed in total gross profit and gross margin.



\## Limitations

\- Gross profit is calculated before returns/refunds and operating expenses; it is not net profit.

\- Payment amounts across all order statuses should not be interpreted as realized sales.

\- Cohort retention differences require further investigation before drawing conclusions about their causes.

\- Raw data files and the local DuckDB database are not included in this repository.



\## Project Structure

```text

ecommerce-analytics/

├── README.md

├── .gitignore

└── sql/

&#x20;   └── ecommerce\_analysis.sql

```



\## Project Objective

Demonstrate practical SQL skills in data quality validation, analytical querying, business performance analysis, and customer retention analysis.

