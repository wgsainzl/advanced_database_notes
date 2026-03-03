# Session – 2026-02-17

## Topics covered
- joins
- aggregation

## What I understood
-  tables -> Structure Data
- Primary key -> Column that will identify a row in a table
- Foreign key -> Column that gives refence to the match with another table
- We split in different tables, because if we have all info in only one table, if we want to update something, we would have dupplicated data.
- In the joins we have 2+ tables that we want to connect
TYPES OF JOINS
- INNER JOIN: Data present in both tables
SELECT t1."t1 column", t2."t1 column"
FROM table1 as t1
INNER JOIN table2 as t2
ON t1.course_id = t2.id
- LEFT JOIN
- RIGHT JOIN
- FULL JOIN
- CROSS JOIN: returns cartesian product
- SELF JOIN

## What is still confusing
- 

## Questions
- 

## Related concepts
- [Concept name](../concepts/concept-name.md)

## Resources used
- See `resources/`
