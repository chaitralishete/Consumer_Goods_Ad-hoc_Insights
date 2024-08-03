---Codebasics SQL Project

/*Q1:Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.*/

    select distinct market 
    from dim_customer 
    where customer = 'Atliq Exclusive' and region = 'APAC'; 

/*Q2: What is the percentage of unique product increase in 2021 vs. 2020? 
The final output contains these fields,unique_products_2020 unique_products_2021 percentage_chg*/

---Method 1: Using CTE 

    with cte1 as (select fiscal_year, count(distinct product_code) As unique_products 
    			from fact_sales_monthly
    			group by fiscal_year),
     cte2 as (select 
                    (select unique_products from cte1 where fiscal_year = 2020) as P_2020,
                    (select unique_products from cte1 where fiscal_year = 2021) as P_2021
    		)
    select P_2020 as unique_products_2020, P_2021 as unique_products_2021, ROUND((P_2021 - P_2020)*100/P_2020,2) as pct_change
    from cte2;

---Method 2: Using Subquery 
    select X.p_2020, Y.p_2021, ROUND((p_2021 - p_2020)*100/p_2020,2) as pct_change
    from(
    (select count(distinct product_code) as p_2020 from fact_sales_monthly where fiscal_year = 2020) AS X,
    (select count(distinct product_code) as p_2021 from fact_sales_monthly where fiscal_year = 2021) AS Y );

/*Q3: Provide a report with all the unique product counts for each segment and
sort them in descending order of product counts. The final output contains
2 fields,segment, product_count*/
    
    select segment, count(distinct product_code) as product_count
    from dim_product
    group by segment 
    order by product_count DESC;

/* Q4: Follow-up: Which segment had the most increase in unique products in
2021 vs 2020? The final output contains these fields,
segment
product_count_2020
product_count_2021
difference */

    with cte1 as (select count(distinct s.product_code) as product_count, p.segment as segment, s.fiscal_year 
    from fact_sales_monthly s
    Left join dim_product p
    on s.product_code = p.product_code
    group by p.segment, s.fiscal_year),
    cte2 as (select segment, 
    				sum(case when fiscal_year = 2020 then product_count else 0 end) as p_2020,
                    sum(case when fiscal_year = 2021 then product_count else 0 end) as p_2021
    		from cte1 
            group by segment) 
    select segment, p_2020 as product_count_2020, p_2021 as product_count_2021, (p_2021- p_2020) as difference
    from cte2 
    order by difference DESC; 

/* Q5: 5. Get the products that have the highest and lowest manufacturing costs.
The final output should contain these fields: product_code, product, manufacturing_cost */ 

---method1 : using Window function : 

    select product_code, product, manufacturing_cost
    from (select m.product_code as product_code, p.product as product, m.manufacturing_cost as manufacturing_cost,
           rank() over(order by manufacturing_cost DESC) as rnk_desc,
           rank() over(order by manufacturing_cost ASC) as rnk_asc
    from dim_product p 
    right join fact_manufacturing_cost m 
    on p.product_code = m.product_code) X
    where rnk_desc = 1 or rnk_asc = 1
    order by manufacturing_cost desc;


---Method 2: Using union 
    
    select m.product_code as product_code, p.product as product, m.manufacturing_cost as manufacturing_cost
    from dim_product p 
    right join fact_manufacturing_cost m 
    on p.product_code = m.product_code
    where manufacturing_cost IN ( 
    							  (select max(manufacturing_cost) from fact_manufacturing_cost) 
                                  UNION 
                                  (select min(manufacturing_cost) from fact_manufacturing_cost)
                                  );


/*Q6: Generate a report which contains the top 5 customers who received an
average high pre_invoice_discount_pct for the fiscal year 2021 and in the
Indian market. The final output contains these fields: customer_code, customer, average_discount_percentage */ 

    select c.customer_code, c.customer, 
    	   ROUND(avg(i.pre_invoice_discount_pct),4) as average_discount_percentage
    from fact_pre_invoice_deductions i 
    left join dim_customer c
    on c.customer_code = i.customer_code 
    where fiscal_year = 2021 and market = 'India' 
    group by  c.customer_code, c.customer
    ORDER BY average_discount_percentage DESC
    LIMIT 5;

/* Q7: Get the complete report of the Gross sales amount for the customer “Atliq
Exclusive” for each month. This analysis helps to get an idea of low and
high-performing months and take strategic decisions.
The final report contains these columns: Month, Year, Gross sales Amount */

    select concat(monthname(date), '-' , year(date)) as month, s.fiscal_year as fiscal_year ,
    	  Sum((sold_quantity*gross_price))as gross_sales 
    from fact_sales_monthly s 
    join dim_customer c on c.customer_code = s.customer_code 
    join fact_gross_price g on s.product_code = g.product_code  
    where customer  = 'Atliq Exclusive'
    group by month, fiscal_year
    order by fiscal_year;

/*Q8: In which quarter of 2020, got the maximum total_sold_quantity? The final
output contains these fields sorted by the total_sold_quantity: Quarter, total_sold_quantity */

    select 
    	  case  when date between '2019-09-01' and '2019-11-30' then 1
    			when date between '2019-12-01' and '2020-02-29' then 2 
                when date between '2020-03-01' and '2020-05-31' then 3
                when date between '2020-06-01' and '2020-08-31' then 4 
                end as quarter,
    			sum(sold_quantity) as total_sold_quantity
    from fact_sales_monthly
    where fiscal_year = 2020 
    group by quarter 
    order by total_sold_quantity desc;

/*Q9: Which channel helped to bring more gross sales in the fiscal year 2021
and the percentage of contribution? The final output contains these fields: channel,gross_sales_mln,percentage*/

    with cte1 as (select c.channel as channel, 
    		ROUND(sum(s.sold_quantity*g.gross_price)/1000000,2) as gross_sales_mln
    from fact_sales_monthly s
    join dim_customer c on c.customer_code = s.customer_code 
    join fact_gross_price g on g.product_code = s.product_code 
    where s.fiscal_year = 2021 
    group by c.channel)
    select channel, 
           gross_sales_mln,
           Concat(ROUND((gross_sales_mln/(select sum(gross_sales_mln) as total_gross_sales from cte1))*100,2), '%') as percentage_contribution 
    from cte1
    order by percentage_contribution desc;

/*Q10: Get the Top 3 products in each division that have a high
total_sold_quantity in the fiscal_year 2021? The final output contains these
fields: division,product_code,product,total_sold_quantity,rank_order*/

    with cte1 as(
    select p.division, p.product_code, p.product, 
           sum(s.sold_quantity) as total_sold_quantity, 
           rank() over(partition by p.division order by sum(s.sold_quantity) desc) as rnk 
    from fact_sales_monthly s
    join dim_product p on p.product_code = s.product_code 
    where fiscal_year = 2021
    group by p.division, p.product_code, p.product)
    select *
    from cte1 
    where rnk <= 3;





