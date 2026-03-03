-- lesson 08

-- task 1
SELECT MAX(Years_employed) AS longest_time
FROM Employees;

-- task 2
SELECT Role, AVG(years_employed) AS avg_years_role 
FROM Employees
GROUP BY role;

-- task 3
SELECT Building, SUM(years_employed) AS sum_years_building
FROM Employees
GROUP BY building;




-- lesson 09

-- task 1
SELECT role, COUNT(role) as number_artists
FROM Employees
WHERE role = "Artist"

-- task 2
SELECT role, COUNT(role) as number_artists
FROM Employees
GROUP BY role

-- task 3
SELECT role, SUM(years_employed) as years_employed_engineers
FROM Employees
WHERE role = "Engineer"
GROUP BY role




-- aggregating rows tutorial

-- try it 1
select count ( distinct shape ) number_of_shapes,
       stddev ( distinct weight ) distinct_weight_stddev
from   bricks;

-- try it 2
select shape, SUM ( weight ) shape_weight
from   bricks
GROUP BY shape;

-- try it 3
select shape, sum ( weight )
from   bricks
having sum( weight ) < 4
group  by shape;
