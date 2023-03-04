--                 ____________________________
--                | AD-Hoc Analysis SQL Script | 
--                |______BY SHOVAN BISWAS______| 
			
-- 1. List of the [market] in which customer Atlique Exclusive operates its business:

select distinct market
from   dim_customer
where  customer = 'Atliq Exclusive'
	   and dim_customer.region = 'APAC';

-- ______________________________________________________________________________________
               
-- 2. Percentage Increse of Unique Product in 2020 vs 2021:
--    [unique_product_2020, unique_product_2021, percentage_chg]

with table1 (unique_product_2020) as 
		(select count(distinct fs.product_code)
		from fact_sales_monthly as fs
		where fs.fiscal_year =2020),
        
	table2 (unique_product_2021) as
		(select count(distinct fs.product_code)
		from fact_sales_monthly as fs
		where fs.fiscal_year=2021)
select 
	table1.unique_product_2020, table2.unique_product_2021,
	round((table2.unique_product_2021 - table1.unique_product_2020)*100
	/table1.unique_product_2020,2) as percentage_chg
from table1
join table2;

-- __________________________________________________________________________________________
                   
-- 3. Provide a report with all the unique product counts for each segment :
--     [segment, product_count]

 select  p.segment,
	     COUNT(distinct product_code) as product_count
   from  dim_product as p
group by p.segment
order by product_count desc;

-- ___________________________________________________________________________________________
                    
-- 4. Which segment has most increase in unique product in 2020 vs 2021:
--     [Segment, Product_Count_2020, Product_Count_2021, Difference]

with 
	table1 (Segment,Product_Count_2020) as 
		(select p.Segment,
			    count(distinct fs.product_code) as Product_Count_2020
		from fact_sales_monthly as fs
		left join dim_product as p
			on fs.product_code = p.product_code
        where fs.fiscal_year = 2020
        group by p.Segment),
        
    table2 (segment,Product_Count_2021) as
		(select  p.Segment,
			     count(distinct fs.product_code) as Product_Count_2021
		from  fact_sales_monthly as fs
		left join dim_product as p
			 on p.product_code = fs.product_code
		where fs.fiscal_year = 2021
		group by p.Segment)
        
select table1.Segment,Product_Count_2020,table2.Product_Count_2021,
	   table2.Product_Count_2021-table1.Product_Count_2020 as Difference
from table1
join table2
  on table1.Segment = table2.Segment
order by Difference Desc;

--  _______________________________________________________________________________________________
                   
-- 5. Get the products that have the highest and lowest manufacturing costs:
--         [product_code, product, manufacturing_cost]                                                                          

select
	p.product_code,  p.product,
    round((mc.manufacturing_cost),2) as Manufacturing_cost
from
	fact_manufacturing_cost as mc
join dim_product as P
  on p.product_code = mc.product_code
where 
	  manufacturing_cost= (select max(mc.manufacturing_cost)from fact_manufacturing_cost as mc) or
	  manufacturing_cost= (select min(mc.manufacturing_cost)from fact_manufacturing_cost as mc);
      
-- ________________________________________________________________________________________________________________
                  
-- 6. top 5 customers who received an average high pre_invoice_discount_pct
--    for the fiscal year 2021 and in the Indian market:
--    [customer_code, customer, average_discount_percentage]
            
select c.customer_code, c.customer, 
	  round(avg(id.pre_invoice_discount_pct),4) as average_discount_percentage
from   dim_customer as c
join   fact_pre_invoice_deductions as id
  on   c.customer_code=id.customer_code
where  id.fiscal_year =2021 and c.market ='India'
group by c.customer,id.customer_code
order by avg(id.pre_invoice_discount_pct) desc
limit 5;

-- ___________________________________________________________________________________________________________________________
                            
-- 7. Get the complete report of the Gross sales amount for the customer "Atliq Exclusive” for each month.
--         [month, year, gross_sales_price]

select  monthname(sm.date) as month,
		year(sm.date) as year,
		round(sum(gp.gross_price*sm.sold_quantity),2) as gross_sales_price
from  fact_sales_monthly as sm
join  dim_customer as c on c.customer_code = sm.customer_code
join  fact_gross_price as gp on sm.product_code = gp.product_code
where  c.customer = "Atliq Exclusive"
    and sm.fiscal_year = gp.fiscal_year
group by year,month
order by year,month;

-- ________________________________________________________________________________________________________________

-- 8. In which quarter of 2020, got the maximum total_sold_quantity?
			-- [quarter, Total_Sold_Quantity]
            
select 
	case when month(sm.date) in (9,10,11) then "Q1"
		when month(sm.date) in (12,1,2) then "Q2"
        when month(sm.date) in (3,4,5) then "Q3"
        when month(sm.date) in (6,7,8) then "Q4"
        end as Quarter,
	sum(sm.sold_quantity)as Total_Sold_Quantity
from  fact_sales_monthly as sm
where  fiscal_year = 2020
group by Quarter
order by Quarter;

-- ___________________________________________________________________________________________________________________________________

-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?
--            [channel, gross_sales_Mn, percentage]
with 
	table1 (channel, gross_sales) as
		(select c.channel,
				sum(fgp.gross_price*fsm.sold_quantity) as gross_sales
		from fact_sales_monthly as fsm
		join dim_customer as c on c.customer_code = fsm.customer_code
		join fact_gross_price as fgp 
		  on fsm.product_code = fgp.product_code and fgp.fiscal_year = fsm.fiscal_year
		group by c.channel),
        
	table2 (Total_gross_sales) as
		(select sum(gross_sales) from table1)

select table1.channel,
	   round(table1.gross_sales/1000000,2) as gross_sales_Mn,
	   round(table1.gross_sales*100/table2.Total_gross_sales,2) as percentage
from table1
join table2 
order by gross_sales_Mn desc;                                                                  
                                                                                                                                                          -- ________________________________________________________________________________________________________________________________    
-- ____________________________________________________________________________________________________________

-- 10. Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021:
-- 		[division, product_code, product, total_sold_quantity, rank_order]
																																						
with rank_table as (
		with product_table as (select p.product_code,
									division,
                                    concat(product,' ',variant) as products,
									SUM(sm.sold_quantity) as total_sold_quantity
								from dim_product as p
                                join fact_sales_monthly as sm
                                 on p.product_code=sm.product_code
                                 where sm.fiscal_year=2021
                                 group by division, product_code, products
                                 order by total_sold_quantity desc)                                 
			select    *,    
				      rank()  over ( partition by division 
                      order by total_sold_quantity desc) as ranks
			from product_table)
	select * 
	from rank_table 
	where ranks in (1,2,3);
   


/*	       			         __________________________________________________________
					|  THANKS TO CODEBASICS -- FOR GIVING ME THIS OPPORTUNITY  |
					|__________________________________________________________|
*/


















    
    


