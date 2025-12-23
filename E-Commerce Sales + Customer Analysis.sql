CREATE DATABASE ecommerce;
USE ecommerce;

CREATE TABLE orders (
  order_id VARCHAR(50),
  customer_id VARCHAR(50),
  order_status VARCHAR(20),
  order_purchase_timestamp DATETIME,
  order_approved_at DATETIME,
  order_delivered_carrier_date DATETIME,
  order_delivered_customer_date DATETIME,
  order_estimated_delivery_date DATETIME
);

select count(*) from  orders ;

CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(50),
    customer_state VARCHAR(5)
);
select count(*)  from customers;
CREATE TABLE order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2)
);

select count(*) from order_items;

CREATE TABLE products (
    product_id VARCHAR(50),
    product_category_name VARCHAR(100),
    product_name_lenght INT,
    product_description_lenght INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

select count(*) from products;

CREATE TABLE sellers (
    seller_id VARCHAR(50),
    seller_zip_code_prefix INT,
    seller_city VARCHAR(100),
    seller_state VARCHAR(10)
);
select count(*) from sellers;

CREATE TABLE payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(50),
    payment_installments INT,
    payment_value DECIMAL(10,2)
);
select count(*) from Payments;

CREATE TABLE reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME
);

desc customers;
desc order_items;
desc orders;
desc payments;
desc products;
desc sellers ;

/*-----------------Check missing values -----------------------------------*/

SELECT 
  COUNT(*) AS total_rows,
  SUM(order_delivered_customer_date IS NULL) AS missing_delivery
FROM orders;

/* ------------------- Handle canceled & unavailable orders --------------------------------*/

SELECT order_status, COUNT(*)
FROM orders
GROUP BY order_status;

/*------- Fix date columns (if needed)
                   If dates are TEXT: ---------------------*/ 

ALTER TABLE orders
MODIFY order_purchase_timestamp DATETIME;

/******* START ANALYSIS   
 KPI 1 > Order Status Distribution */

SELECT 
  COUNT(*) AS total_rows,
  SUM(order_delivered_customer_date IS NULL) AS missing_delivery
FROM orders;

/*KPI 2 > TOTAL Revenue Analysis (REAL analysis) */
SELECT 
    ROUND(SUM(payment_value), 2) AS total_revenue
FROM payments;

/*--- AVERAGE ORDER VALUE (AOV) ----*/

SELECT 
    round(SUM(PAYMENT_VALUE) / COUNT(DISTINCT ORDER_ID),2) AS AVG_ORDER_VALUE
   FROM payments;  

/*------- KPI 3 > CANCELLED ORDERS IMPACT ---------------- */

SELECT 
      count(*) AS CANCELLED_ORDERS
FROM ORDERS 
where ORDER_STATUS = 'CANCELED' ;

/*--- POTENTIAL REVENUE LOSS ---*/

SELECT 
     round(SUM(P.PAYMENT_VALUE),2) AS CANCELLED_REVENUE 
FROM ORDERS O 
JOIN PAYMENTS P 
ON O.ORDER_ID = P.ORDER_ID
WHERE O.ORDER_STATUS = 'CANCELED' ; 

/*---KPI 4: DELIVERY PERFORMANCE (important for resume)---*/
SELECT 
      count(*) AS LATE_DELIVERIES 
	FROM ORDERS 
    WHERE ORDER_DELIVERED_CUSTOMER_DATE > ORDER_ESTIMATED_DELIVERY_DATE ; 
    
/*---LATE DELIVARY PERSENTAGE---*/
    
SELECT 
      ROUND(
           SUM(
               CASE 
                   WHEN ORDER_DELIVERED_CUSTOMER_DATE > ORDER_ESTIMATED_DELIVERY_DATE 
                   THEN 1 ELSE 0 
				END 
			) * 100.0 / COUNT(*),
            2) AS LATE_DELIVARY_PERCENTAGE 
	FROM ORDERS 
    WHERE ORDER_STATUS = 'DELIVERED';


/* KPI :- CUSTOMER ANALYSIS ----------------- 
---------Repeat vs One-time Customers ------------ */

SELECT 
     COUNT(DISTINCT CUSTOMER_UNIQUE_ID) AS TOTAL_CUSTOMERS ,
     SUM(CASE WHEN ORDER_COUNT  > 1 THEN 1 ELSE 0 END ) AS REPEAT_CUSTOMERS 
FROM ( 
      SELECT 
           C.CUSTOMER_UNIQUE_ID , 
           COUNT(O.ORDER_ID) AS ORDER_COUNT 
	FROM CUSTOMERS C 
    JOIN ORDERS O ON C.CUSTOMER_ID = O.CUSTOMER_ID 
    GROUP BY C.CUSTOMER_UNIQUE_ID 
) T ; 

/*-------- PHASE 2: CUSTOMER BEHAVIOR ANALYSIS --------------------*/ 
/*========== Customer Lifetime Value (CLV) ===============*/

SELECT 
    c.customer_unique_id,
    ROUND(SUM(p.payment_value), 2) AS lifetime_value,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN payments p ON o.order_id = p.order_id
GROUP BY c.customer_unique_id
ORDER BY lifetime_value DESC
LIMIT 10;

/*===Revenue by Customer Type (Repeat vs One-time)===*/
SELECT 
    customer_type,
    ROUND(SUM(payment_value), 2) AS revenue
FROM (
    SELECT 
        c.customer_unique_id,
        p.payment_value,
        CASE 
            WHEN COUNT(o.order_id) OVER (PARTITION BY c.customer_unique_id) > 1 
            THEN 'Repeat'
            ELSE 'One-time'
        END AS customer_type
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN payments p ON o.order_id = p.order_id
) t
GROUP BY customer_type;

/* === PHASE 3: PRODUCT & SELLER ANALYSIS (THIS MAKES YOU STAND OUT) ===*/ 
/*========== Top Revenue Categories ==========*/
SELECT 
    pr.product_category_name,
    ROUND(SUM(p.payment_value), 0) AS category_revenue
FROM order_items oi
JOIN products pr ON oi.product_id = pr.product_id
JOIN payments p ON oi.order_id = p.order_id
GROUP BY pr.product_category_name
ORDER BY category_revenue DESC
LIMIT 10;

/* ========== Top & Worst Sellers (Resume-level insight) ==========*/
SELECT 
    s.seller_id,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(p.payment_value), 2) AS seller_revenue
FROM sellers s
JOIN order_items oi ON s.seller_id = oi.seller_id
JOIN payments p ON oi.order_id = p.order_id
GROUP BY s.seller_id
ORDER BY seller_revenue DESC
LIMIT 10;

/* ===== PHASE 4: DELIVERY & LOGISTICS ANALYSIS (VERY STRONG FOR INTERVIEWS) */
/* =====  Average Delivery Time (Days) ======*/ 
SELECT 
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 2)
    AS avg_delivery_days
FROM orders
WHERE order_status = 'DELIVERED';

/* =========== Late Delivery by Category (BIG INSIGHT) ========*/ 
SELECT 
    pr.product_category_name,
    COUNT(*) AS late_orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products pr ON oi.product_id = pr.product_id
WHERE o.order_delivered_customer_date > o.order_estimated_delivery_date
GROUP BY pr.product_category_name
ORDER BY late_orders DESC;

/* ===== PHASE 5: TIME-BASED ANALYSIS ======*/
/* ====== Monthly Revenue Trend ======*/

select
      date_format(o.order_purchase_timestamp , '%Y-%M') AS month , 
      round(sum(p.payment_value), 2 ) as monthly_revenue 
from orders o 
join payments p on o.order_id = p.order_id 
group by month 
order by month ;  

/* === CREATE VIEWS
  1 :- ORDERS FACT TABLE ===== */
  CREATE VIEW fact_orders AS
SELECT 
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) AS delivery_days,
    CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
        THEN 1 ELSE 0 
    END AS is_late,
    p.payment_value
FROM orders o
JOIN payments p ON o.order_id = p.order_id;

/*=====  2 :- Customer Summary Table =====*/
  CREATE VIEW customer_summary AS
SELECT 
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(p.payment_value), 2) AS lifetime_value
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN payments p ON o.order_id = p.order_id
GROUP BY c.customer_unique_id;

 /* ======  3 :- : Product & Category Performance ====== */
CREATE VIEW product_category_performance AS
SELECT 
    pr.product_category_name,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(p.payment_value), 2) AS total_revenue
FROM order_items oi
JOIN products pr ON oi.product_id = pr.product_id
JOIN payments p ON oi.order_id = p.order_id
GROUP BY pr.product_category_name;


SELECT *  FROM PRODUCT_CATEGORY_PERFORMANCE ;

