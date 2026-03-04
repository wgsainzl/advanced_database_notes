-- LESSON 6
-- Exercise 1
SELECT domestic_sales, international_sales 
FROM movies
INNER JOIN boxoffice
ON movies.id=boxoffice.movie_id
;
-- Exercise 2
SELECT *
FROM movies
INNER JOIN boxoffice
ON movies.id=boxoffice.movie_id
WHERE boxoffice.international_sales > boxoffice.domestic_sales
;
-- Exercise 3
SELECT *
FROM movies
INNER JOIN boxoffice
ON movies.id=boxoffice.movie_id
ORDER BY boxoffice.rating DESC
;

-- LESSON 7
-- Exercise 1
SELECT DISTINCT building
FROM employees
LEFT JOIN buildings
ON employees.building=buildings.building_name
;
-- Exercise 2
SELECT building_name, capacity
FROM buildings
;
-- Exercise 3
SELECT DISTINCT b.building_name, e.role
FROM buildings as b
LEFT JOIN employees as e
ON b.building_name=e.building
;