select * from credit_card_transcations

-- firstly, we will just explore the data and figure out few details

-- There are 986 distinct cities in the dataset
select distinct city 
from credit_card_transcations

-- Card types
select distinct card_type
from credit_card_transcations
/* There are 4 types of cards
			1)Silver
			2)Signature
			3)Gold
			4)Platinum
*/

select distinct exp_type
from credit_card_transcations
/*  There are 6 distinct types of expenses
		1)Entertainment
		2)Food
		3)Bills
		4)Fuel
		5)Travel
		6)Grocery
*/

select min(transaction_date) as start_date, max(transaction_date) as end_date
from credit_card_transcations

-- The dataset contains transactions from 2013-10-04 to 2015-05-26 

select count(1)
from credit_card_transcations
-- The dataset contains 26,052 transactions

-- Now we have the basic information about our dataset. So we'll start solving the questions

/* Q1) write a query to print top 5 cities with highest spends and their 
		percentage contribution of total credit card spends */
	--we had to convert total_spend to bigint since its value was too big
	-- since we wanted to display total_spend in every row we had to use the over() clause


with city_total_cte as (
select city, sum(cast(amount as bigint)) as city_spend
from credit_card_transcations
group by city
),
city_and_overall_total_cte as (
select *, sum(city_spend) over() as total_spend
from city_total_cte
)
select top 5 city, city_spend, total_spend, 
Round(((Cast(city_spend AS FLOAT) / total_spend) * 100), 2) as percent_contribution
from city_and_overall_total_cte 
order by ((CAST(city_spend AS FLOAT) / total_spend) * 100) desc 


-- Q2) write a query to print highest spend month and amount spent in that month for each card type


with card_type_monthly_cte as (
select format(transaction_date, 'yyyy-MM') as month_year, card_type, sum(amount)as card_type_monthly 
from credit_card_transcations
group by format(transaction_date, 'yyyy-MM'), card_type 
)
select top 4 month_year, card_type, card_type_monthly,
sum(card_type_monthly) over(partition by month_year) as month_sum
from card_type_monthly_cte
order by sum(card_type_monthly) over(partition by month_year) desc


/*  Q3) Write a query to print the transaction details(all columns from the table) for each 
		card type when it reaches a cumulative of 1000000 total spends
		(We should have 4 rows in the o/p one for each card type)      */

with cumulative_card_type_cte as (
select *, sum(amount) over(partition by card_type order by amount) as cumulative_card_type
from credit_card_transcations
),
cumulative_with_rn_cte as (
select *,row_number() over(partition by card_type order by amount) as rn
from cumulative_card_type_cte
where cumulative_card_type >= 1000000 
)
select *
from cumulative_with_rn_cte
where rn = 1


-- Q4)  write a query to find city which had lowest percentage spend for gold card type

with gold_type_spend_cte as (
select city, sum(amount) as gold_spend
from credit_card_transcations
where card_type = 'Gold'
group by city
),
gold_and_total_cte as (
select *, sum(cast(gold_spend as bigint)) over() as total_gold_spend
from gold_type_spend_cte
)
select top 1 city,gold_spend, total_gold_spend, 
(cast(gold_spend as float)/total_gold_spend) * 100 as percentage_spend
from gold_and_total_cte
order by round((cast(gold_spend as float)/total_gold_spend) * 100, 4)

--   98,45,39,536 (gold type spend)
-- Dhamtari has the lowest spend for gold type at 0.000143% with amount 1416
-- 4,07,48,33,373 (total spend by all the credit cards)



/* Q5) write a query to print 3 columns:  city, highest_expense_type, 
	lowest_expense_type (example format : Delhi , bills, Fuel)   */

with exp_type_sum_cte as (
select city, exp_type, sum(amount) exp_type_sum
from credit_card_transcations
group by city, exp_type
),
sum_rn_cte as (
select city, exp_type, exp_type_sum,
rank() over(partition by city order by exp_type_sum desc) as rn,
rank() over(partition by city order by exp_type_sum) as drn
from exp_type_sum_cte
),
lowest_expense_cte as (
select city, exp_type as lowest_expense_type
from sum_rn_cte
where drn = 1
),
highest_expense_cte as (
select city, exp_type as highest_expense_type
from sum_rn_cte as s1
where rn = 1 
)
select h.*, l.lowest_expense_type
from highest_expense_cte h
inner join lowest_expense_cte l on h.city = l.city
order by h.city


-- Q6) write a query to find percentage contribution of spends by females for each expense type


with gender_wise_sum_cte as (
select exp_type, gender, sum(amount) as gender_wise_sum
from credit_card_transcations
group by exp_type, gender
), 
exp_type_sum_cte as (
select *, sum(gender_wise_sum) over(partition by exp_type) as exp_type_sum
from gender_wise_sum_cte 
)
select exp_type, gender, 
round((cast(gender_wise_sum as float) / exp_type_sum) * 100, 2) as percentage_contribution
from exp_type_sum_cte 
where gender = 'F'


-- Q7) which card and expense type combination saw highest month over month growth in Jan-2014

with monthly_exp_card_cte as (
select card_type, exp_type, format(transaction_date, 'yyyy-MM') as year_month,
sum(amount) as monthly_sum
from credit_card_transcations
group by card_type, exp_type, format(transaction_date, 'yyyy-MM') 
),
monthly_with_previous_cte as (
select *, 
lead(monthly_sum, 1) over(partition by card_type, exp_type order by year_month desc) as last_month_sum
from monthly_exp_card_cte
)
select top 1 *, 
round((cast((monthly_sum - last_month_sum) as float)/last_month_sum) * 100, 2) as mom_growth
from monthly_with_previous_cte
where year_month = '2014-01'
order by ((cast((monthly_sum - last_month_sum) as float)/last_month_sum) * 100) desc

-- Travel expense in gold type credit card saw the highest MOM growth in Jan-2014 of 87.92%

--Q8) during weekends which city has highest total spend to total no of transcations ratio

with weekend_spend_cte as (
select city, count(transaction_id) as transactions, sum(amount) as weekend_spend
from credit_card_transcations
where datepart(weekday, transaction_date) in (1, 7)
group by city 
)
select top 1 *, cast(weekend_spend as float) / transactions as spend_transactions_ratio
from weekend_spend_cte
order by cast(weekend_spend as float) / transactions desc 

-- Sonepur has the highest weekend spend to no of transations ratio of 299905

/* Q9) which city took least number of days to reach its 500th transaction 
		after the first transaction in that city   */

with city_trn_rn_cte as (
select city, transaction_date,
row_number() over(partition by city order by transaction_date) as rn
from credit_card_transcations
), 
first_trn_cte as (
select city, transaction_date, rn 
from city_trn_rn_cte
where rn = 1 
),
transc_500_cte as (
select city, transaction_date as transc_500, rn
from city_trn_rn_cte
where rn = 500
)
select top 1 f.city, datediff(day, f.transaction_date, t.transc_500) as duration_days
from first_trn_cte f
inner join transc_500_cte t on f.city = t.city 
order by datediff(day, f.transaction_date, t.transc_500)

-- Bengaluru completed its first 500 transactions in just 81 days which is the least of all cities
