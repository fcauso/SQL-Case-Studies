use dannys_diner;
/* --------------------
   Case Study Questions
   --------------------*/
use dannys_diner;
CREATE TABLE sales 
(  
customer_id VARCHAR(1),  
order_date DATE,  
product_id INTEGER);   
INSERT INTO sales  
(customer_id, order_date, product_id)
VALUES  
('A', '2021-01-01', '1'),  
('A', '2021-01-01', '2'),  
('A', '2021-01-07', '2'),  
('A', '2021-01-10', '3'),  
('A', '2021-01-11', '3'),  
('A', '2021-01-11', '3'),  
('B', '2021-01-01', '2'),  
('B', '2021-01-02', '2'),  
('B', '2021-01-04', '1'),  
('B', '2021-01-11', '1'),  
('B', '2021-01-16', '3'),  
('B', '2021-02-01', '3'),  
('C', '2021-01-01', '3'),  
('C', '2021-01-01', '3'),  
('C', '2021-01-07', '3');  
CREATE TABLE menu 
(
product_id INTEGER,  
product_name VARCHAR(5),  
price INTEGER); 
INSERT INTO menu  
(product_id, product_name, price)
VALUES  
('1', 'sushi', '10'),  
('2', 'curry', '15'),  
('3', 'ramen', '12');   
CREATE TABLE members 
(
customer_id VARCHAR(1),  
join_date DATE); 
INSERT INTO members  
(customer_id, join_date)
VALUES  
('A', '2021-01-07'),  
('B', '2021-01-09');
-- 1. What is the total amount each customer spent at the restaurant?
select s.customer_id, sum(m.price)
from sales s
join menu m on m.product_id = s.product_id
group by s.customer_id;
-- 2. How many days has each customer visited the restaurant?
select count(distinct(date_format(order_date,'%m-%d%-Y'))) as num_days, customer_id
from sales
group by customer_id;
-- 3. What was the first item from the menu purchased by each customer?
select customer_id, order_date, s1.product_id, s3.product_name
from sales s1
join menu s3 on s3.product_id = s1.product_id
where order_date in (select min(order_date) from sales s2 where s1.customer_id = s2.customer_id)
group by customer_id;
--
with newd as (SELECT Row_number() OVER(partition by customer_id ORDER BY order_date) as cc, customer_id, product_name, order_date
FROM sales
join menu
on sales.product_id=menu.product_id
order by customer_id)
select customer_id, product_name, order_date
from newd
where cc =1;
--
select distinct(customer_id), order_date, s1.product_id, s3.product_name
from sales s1
join menu s3 on s3.product_id = s1.product_id
where s1.order_date in (select min(order_date) from sales s2 group by customer_id)
;
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
select count(customer_id), m.product_name
from sales s
join menu m on s.product_id = m.product_id
where s.product_id = (select s.product_id
from sales s
group by s.product_id
order by count(s.product_id) desc
limit 1);

-- 5. Which item was the most popular for each customer?
select customer_id, product_id, (select max(cnt) from sales s1 on s1.customer_id = a.customer_id) as max
from (select customer_id, product_id, count(product_id) as cnt
	from sales
	group by customer_id, product_id) a
;

select customer_id, product_id, count(product_id) as cnt
from sales
group by customer_id, product_id;
-- answer:
select * from (
		select customer_id, product_id, (rank() over (partition by customer_id order by count(product_id) desc)) as rank_count
        from sales
        group by customer_id, product_id
        ) a
join menu m on a.product_id = m.product_id
where rank_count = 1;

-- another way:
select order_r.customer_id, order_r.product_id, menu.product_name, order_r.r
from (
	select customer_id, product_id, rank() over (partition by customer_id order by cnt desc) r
		from (
			select customer_id, product_id, count(product_id) as cnt
			from sales
			group by customer_id, product_id
			) order_counts 
	) order_r
join menu on order_r.product_id = menu.product_id
where r = 1
order by customer_id;

-- 6. Which item was purchased first by the customer after they became a member?
select customer_id, product_id, join_date, order_date, rank_date, me.product_name
FROM (
	select customer_id, product_id, join_date, order_date, rank() over (partition by customer_id order by order_date) as rank_date
		from (
			select s.customer_id, product_id, m.join_date, s.order_date
			from sales s
			join members m using (customer_id)
			where s.order_date >= m.join_date
			) order_a
		) rank_a
join menu me using (product_id)
where rank_date = 1
group by customer_id
order by customer_id;

select customer_id, product_id, join_date, order_date, dense_rank() over (partition by customer_id order by order_date) as rank_date
		from (
			select s.customer_id, product_id, m.join_date, s.order_date
			from sales s
			join members m using (customer_id)
			where s.order_date >= m.join_date
			) order_a;
-- 7. Which item was purchased just before the customer became a member?
select customer_id, product_id, join_date, order_date, rank_date, me.product_name
FROM (
	select customer_id, product_id, join_date, order_date, rank() over (partition by customer_id order by order_date) as rank_date
		from (
			select s.customer_id, product_id, m.join_date, s.order_date
			from sales s
			join members m using (customer_id)
			where s.order_date < m.join_date
			) order_a
		) rank_a
join menu me using (product_id)
where rank_date = 1
group by customer_id
order by customer_id;
-- 8. What is the total items and amount spent for each member before they became a member?
select customer_id, count(distinct(product_id)), sum(price)
FROM (
select *,
	case
	when join_date is null then price
	when order_date < join_date then price
	else null
	end as price_adj
		from (
			select *
			from sales s
			join menu me using (product_id)
			left join members mem using (customer_id)
			) all_data
    ) a_a
where price_adj is not null
group by customer_id;
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
select customer_id, sum(price_adj) as total_points
from (
	select *,
	case when product_name = 'sushi' then 20*price
	else 10*price end as price_adj
	from sales 
	join menu using (product_id)
	) aa
group by customer_id;
-- other way
select customer_id, sum(case when (product_name='sushi') then tot_price*2*10 else tot_price*10 end) 
from (
select customer_id, product_name, sum(price) as tot_price
from sales
join menu using (product_id)
group by customer_id, product_name
) newd
group by customer_id
order by customer_id;
-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?