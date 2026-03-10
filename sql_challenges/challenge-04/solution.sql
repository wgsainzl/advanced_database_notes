-- Analytic Functions: Databases for Developers Lesson

-- task 1
select b.*,
       count(*) over (
         partition by shape
       ) bricks_per_shape,
       median ( weight ) over (
         partition by shape
       ) median_weight_per_shape
from   bricks b
order  by shape, weight, brick_id;

-- task 2
select b.brick_id, b.weight,
       round ( avg ( weight ) over (
         order by brick_id
       ), 2 ) running_average_weight
from   bricks b
order  by brick_id;

-- task 3
select b.*,
       min ( colour ) over (
         order by brick_id
         rows between 2 preceding and 1 preceding
       ) first_colour_two_prev,
       count (*) over (
         order by weight
         range between 1 preceding and 1 following
       ) count_values_this_and_next
from   bricks b
order  by weight;

-- task 4
with totals as (
  select b.*,
         sum(weight) over (
           partition by shape
         ) weight_per_shape,
         sum(weight) over (
           order by brick_id
         ) running_weight_by_id
  from   bricks b
)
select *
from   totals
where  weight_per_shape > 4
and    running_weight_by_id > 4
order  by brick_id;

-- Top Three Salaries: DataLemur
with ranked as (
  SELECT 
    d.department_name,
    e.name,
    e.salary,
    dense_rank() over (
      partition by e.department_id
      order by e.salary DESC
    ) AS ranking
  FROM employee e 
  JOIN department d
    ON e.department_id = d.department_id
)

SELECT department_name, name, salary FROM ranked
WHERE ranking <=3
ORDER BY 
  department_name ASC,
  salary DESC,
  name ASC;