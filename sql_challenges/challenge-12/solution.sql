-- ============================================================
-- Lesson 07: KPI Dashboards — Class Exercises ANSWERS
-- File: 06_exercises_answers.sql
-- Purpose: SQL answers for KPI Dashboard exercises
--
-- Run after:
-- 01_enrich_schema.sql
-- 02_seed_dashboard_data.sql
-- ============================================================


-- ============================================================
-- EXERCISE 1: Define "Team Velocity"
-- ============================================================
--
-- KPI CONTRACT:
-- Business question:
--   How fast does each team complete work?
--
-- Exact definition:
--   Team velocity = completed tasks per active team member per day.
--   We count only tasks with status = 'completed' and completed_at IS NOT NULL.
--   We join teams -> users -> tasks.
--   The number of days is calculated from the first completed_at date to the
--   last completed_at date in the dataset, inclusive.
--
-- Edge cases:
--   - Teams with zero users should not cause division by zero.
--   - Teams with zero completed tasks should appear with velocity 0.
--   - Cancelled tasks are excluded.
--   - Story points do not exist, so this is task-count velocity, not effort velocity.
--
-- Unit:
--   Completed tasks per user per day.
--
-- What could make this misleading:
--   Task complexity is not considered. A small UI task and a critical backend
--   fix both count as one task.
--
-- One-sentence explanation:
--   Team velocity shows how many completed tasks each team finishes per team
--   member per day.

WITH completed_window AS (
    SELECT GREATEST(
               MAX(TRUNC(CAST(completed_at AS DATE))) -
               MIN(TRUNC(CAST(completed_at AS DATE))) + 1,
               1
           ) AS active_days
    FROM tasks
    WHERE status = 'completed'
      AND completed_at IS NOT NULL
),
team_metrics AS (
    SELECT t.id AS team_id,
           t.name AS team_name,
           COUNT(DISTINCT u.id) AS team_members,
           COUNT(CASE WHEN ts.status = 'completed'
                       AND ts.completed_at IS NOT NULL
                      THEN ts.id END) AS completed_tasks,
           cw.active_days,
           ROUND(
               COUNT(CASE WHEN ts.status = 'completed'
                            AND ts.completed_at IS NOT NULL
                           THEN ts.id END)
               / NULLIF(COUNT(DISTINCT u.id), 0)
               / cw.active_days,
               3
           ) AS velocity_tasks_per_member_per_day
    FROM teams t
    LEFT JOIN users u
           ON u.team_id = t.id
    LEFT JOIN tasks ts
           ON ts.assigned_to = u.id
    CROSS JOIN completed_window cw
    GROUP BY t.id, t.name, cw.active_days
),
overall_avg AS (
    SELECT AVG(velocity_tasks_per_member_per_day) AS avg_velocity
    FROM team_metrics
)
SELECT tm.team_name,
       tm.team_members,
       tm.completed_tasks,
       tm.active_days,
       tm.velocity_tasks_per_member_per_day,
       ROUND(oa.avg_velocity, 3) AS overall_avg_velocity,
       CASE
           WHEN tm.velocity_tasks_per_member_per_day < oa.avg_velocity
           THEN 'Below Average'
           ELSE 'At or Above Average'
       END AS velocity_flag
FROM team_metrics tm
CROSS JOIN overall_avg oa
ORDER BY tm.velocity_tasks_per_member_per_day DESC;


-- ============================================================
-- EXERCISE 2: Define "On-Time Delivery Rate"
-- ============================================================
--
-- KPI CONTRACT:
-- Business question:
--   Do we complete tasks before their deadlines?
--
-- Exact definition:
--   On-time delivery rate = completed tasks finished before the end of their
--   due_date divided by completed tasks with a due_date.
--   A task due on 2026-05-03 is on time if completed before
--   2026-05-04 00:00:00.
--
-- Edge cases:
--   - Tasks without due_date are excluded because they have no deadline.
--   - Incomplete tasks are excluded from delivery rate because delivery has
--     not happened yet.
--   - Cancelled tasks are excluded.
--   - A task completed at 23:59 on the due date is on time.
--   - A task completed at 00:01 the next day is late.
--
-- Unit:
--   Percentage and hours.
--
-- What could make this misleading:
--   It ignores tasks still open and overdue, because this metric measures
--   delivery performance only after completion.
--
-- One-sentence explanation:
--   On-time delivery rate shows the percentage of completed tasks finished
--   before the end of their due date.

WITH completed_with_deadline AS (
    SELECT priority,
           id,
           due_date,
           completed_at,
           CASE
               WHEN completed_at < CAST(due_date + 1 AS TIMESTAMP)
               THEN 1
               ELSE 0
           END AS on_time_flag,
           CASE
               WHEN completed_at >= CAST(due_date + 1 AS TIMESTAMP)
               THEN ROUND(
                    (CAST(completed_at AS DATE) - (due_date + 1)) * 24,
                    2
               )
               ELSE NULL
           END AS lateness_hours
    FROM tasks
    WHERE status = 'completed'
      AND completed_at IS NOT NULL
      AND due_date IS NOT NULL
      AND priority IS NOT NULL
)
SELECT priority,
       COUNT(*) AS completed_tasks_with_due_date,
       SUM(on_time_flag) AS on_time_tasks,
       COUNT(*) - SUM(on_time_flag) AS late_tasks,
       ROUND(SUM(on_time_flag) * 100 / NULLIF(COUNT(*), 0), 1) AS on_time_delivery_rate_pct,
       ROUND(AVG(lateness_hours), 2) AS avg_lateness_hours_for_late_tasks
FROM completed_with_deadline
GROUP BY priority
ORDER BY CASE priority
             WHEN 'critical' THEN 1
             WHEN 'high' THEN 2
             WHEN 'medium' THEN 3
             WHEN 'low' THEN 4
             ELSE 5
         END;


-- ============================================================
-- EXERCISE 3: Improve "Tasks per Team"
-- ============================================================
--
-- KPI CONTRACT:
-- Business question:
--   Which teams have the most current workload, and are they overloaded?
--
-- Exact definition:
--   total_tasks = all tasks assigned to users in the team.
--   active_tasks = tasks with status open, in_progress, or blocked.
--   completion_rate = completed / total non-cancelled tasks.
--
-- Edge cases:
--   - Cancelled tasks are excluded from completion_rate denominator.
--   - Teams with zero tasks still appear because of LEFT JOIN.
--   - Division by zero is handled with NULLIF.
--
-- Unit:
--   Count and percentage.
--
-- What could make this misleading:
--   Active task count does not measure complexity or effort.

WITH team_task_counts AS (
    SELECT t.id AS team_id,
           t.name AS team_name,
           COUNT(ts.id) AS total_tasks,
           COUNT(CASE
                     WHEN ts.status IN ('open', 'in_progress', 'blocked')
                     THEN ts.id
                 END) AS active_tasks,
           COUNT(CASE
                     WHEN ts.status = 'completed'
                     THEN ts.id
                 END) AS completed_tasks,
           COUNT(CASE
                     WHEN ts.status <> 'cancelled'
                     THEN ts.id
                 END) AS non_cancelled_tasks
    FROM teams t
    LEFT JOIN users u
           ON u.team_id = t.id
    LEFT JOIN tasks ts
           ON ts.assigned_to = u.id
    GROUP BY t.id, t.name
)
SELECT team_name,
       total_tasks,
       active_tasks,
       ROUND(completed_tasks * 100 / NULLIF(non_cancelled_tasks, 0), 1) AS completion_rate_pct,
       CASE
           WHEN active_tasks > 10 THEN 'Overloaded'
           WHEN active_tasks BETWEEN 5 AND 10 THEN 'Healthy'
           ELSE 'Underutilized'
       END AS health_score
FROM team_task_counts
ORDER BY active_tasks DESC;


-- ============================================================
-- EXERCISE 4: Improve "Average Resolution Time"
-- ============================================================
--
-- KPI CONTRACT:
-- Business question:
--   How long does it take to complete tasks by priority?
--
-- Exact definition:
--   Resolution time = completed_at - created_at, measured in hours.
--   Only completed tasks with completed_at IS NOT NULL are included.
--   Results are grouped by priority.
--
-- Edge cases:
--   - Priorities with one completed task are shown, but marked as low sample size.
--   - Incomplete and cancelled tasks are excluded.
--   - NULL completed_at values are excluded.
--
-- Unit:
--   Hours.
--
-- What could make this misleading:
--   Averages hide outliers, so median, fastest, and slowest are also shown.

WITH completed_tasks AS (
    SELECT priority,
           ROUND((CAST(completed_at AS DATE) - CAST(created_at AS DATE)) * 24, 2) AS resolution_hours
    FROM tasks
    WHERE status = 'completed'
      AND completed_at IS NOT NULL
      AND created_at IS NOT NULL
),
priority_stats AS (
    SELECT priority,
           COUNT(*) AS completed_task_count,
           ROUND(AVG(resolution_hours), 1) AS avg_resolution_hours,
           ROUND(
               PERCENTILE_CONT(0.5)
               WITHIN GROUP (ORDER BY resolution_hours),
               1
           ) AS median_resolution_hours,
           ROUND(MIN(resolution_hours), 1) AS fastest_resolution_hours,
           ROUND(MAX(resolution_hours), 1) AS slowest_resolution_hours
    FROM completed_tasks
    GROUP BY priority
)
SELECT priority,
       completed_task_count,
       avg_resolution_hours,
       median_resolution_hours,
       fastest_resolution_hours,
       slowest_resolution_hours,
       CASE priority
           WHEN 'critical' THEN 24
           WHEN 'high' THEN 72
           WHEN 'medium' THEN 168
           WHEN 'low' THEN 336
       END AS target_sla_hours,
       CASE
           WHEN avg_resolution_hours <=
                CASE priority
                    WHEN 'critical' THEN 24
                    WHEN 'high' THEN 72
                    WHEN 'medium' THEN 168
                    WHEN 'low' THEN 336
                END
           THEN 'Target Met'
           ELSE 'Target Missed'
       END AS target_met,
       CASE
           WHEN completed_task_count < 3 THEN 'Low Sample Size'
           ELSE 'Sample OK'
       END AS sample_warning
FROM priority_stats
ORDER BY CASE priority
             WHEN 'critical' THEN 1
             WHEN 'high' THEN 2
             WHEN 'medium' THEN 3
             WHEN 'low' THEN 4
             ELSE 5
         END;


-- ============================================================
-- EXERCISE 5: Improve "Overdue Tasks"
-- ============================================================
--
-- KPI CONTRACT:
-- Business question:
--   Which overdue tasks need attention first?
--
-- Exact definition:
--   A task is overdue when due_date is before the report date and status is
--   not completed or cancelled.
--   This report uses DATE '2026-05-15' as a fixed report date to match the
--   seed dataset. Replace it with TRUNC(SYSDATE) for live production use.
--
-- Edge cases:
--   - Completed and cancelled tasks are excluded.
--   - Tasks with NULL due_date are excluded.
--   - Unassigned tasks would still appear because of LEFT JOIN.
--
-- Unit:
--   Days overdue.
--
-- What could make this misleading:
--   Severity is based only on priority and days overdue, not customer impact.

WITH overdue_base AS (
    SELECT ts.title,
           COALESCE(u.full_name, 'Unassigned') AS assignee,
           COALESCE(t.name, 'No Team') AS team_name,
           ts.priority,
           ts.due_date,
           DATE '2026-05-15' - ts.due_date AS days_overdue,
           CASE
               WHEN ts.priority = 'critical'
                    AND DATE '2026-05-15' - ts.due_date > 0
               THEN 'CRITICAL'
               WHEN ts.priority = 'high'
                    AND DATE '2026-05-15' - ts.due_date > 2
               THEN 'HIGH'
               WHEN ts.priority = 'medium'
                    AND DATE '2026-05-15' - ts.due_date > 5
               THEN 'MEDIUM'
               ELSE 'LOW'
           END AS severity
    FROM tasks ts
    LEFT JOIN users u
           ON u.id = ts.assigned_to
    LEFT JOIN teams t
           ON t.id = u.team_id
    WHERE ts.due_date IS NOT NULL
      AND ts.due_date < DATE '2026-05-15'
      AND ts.status NOT IN ('completed', 'cancelled')
),
detail_rows AS (
    SELECT 'DETAIL' AS row_type,
           title,
           assignee,
           team_name,
           priority,
           due_date,
           days_overdue,
           severity,
           CAST(NULL AS NUMBER) AS overdue_count,
           CAST(NULL AS NUMBER) AS avg_days_overdue
    FROM overdue_base
),
summary_rows AS (
    SELECT 'SUMMARY' AS row_type,
           'SUMMARY FOR ' || severity AS title,
           CAST(NULL AS VARCHAR2(100)) AS assignee,
           CAST(NULL AS VARCHAR2(100)) AS team_name,
           CAST(NULL AS VARCHAR2(10)) AS priority,
           CAST(NULL AS DATE) AS due_date,
           CAST(NULL AS NUMBER) AS days_overdue,
           severity,
           COUNT(*) AS overdue_count,
           ROUND(AVG(days_overdue), 1) AS avg_days_overdue
    FROM overdue_base
    GROUP BY severity
)
SELECT row_type,
       title,
       assignee,
       team_name,
       priority,
       due_date,
       days_overdue,
       severity,
       overdue_count,
       avg_days_overdue
FROM (
    SELECT * FROM detail_rows
    UNION ALL
    SELECT * FROM summary_rows
)
ORDER BY CASE severity
             WHEN 'CRITICAL' THEN 1
             WHEN 'HIGH' THEN 2
             WHEN 'MEDIUM' THEN 3
             WHEN 'LOW' THEN 4
             ELSE 5
         END,
         CASE row_type
             WHEN 'DETAIL' THEN 1
             WHEN 'SUMMARY' THEN 2
         END,
         days_overdue DESC NULLS LAST;


-- ============================================================
-- EXERCISE 6: Fix the "Productivity Score"
-- ============================================================
--
-- PROBLEM:
--   The bad query counts all assigned tasks and calls that productivity.
--   That is misleading because it does not distinguish completed work from
--   open work, cancelled work, or task difficulty. It also treats every
--   priority equally.
--
-- BETTER KPI:
--   Weighted completed tasks per active day.
--   Priority weights:
--     critical = 4
--     high     = 3
--     medium   = 2
--     low      = 1
--
-- Unit:
--   Weighted completed-task points per active day.

WITH user_completed AS (
    SELECT u.id AS user_id,
           u.full_name,
           COUNT(ts.id) AS completed_tasks,
           SUM(CASE ts.priority
                   WHEN 'critical' THEN 4
                   WHEN 'high' THEN 3
                   WHEN 'medium' THEN 2
                   WHEN 'low' THEN 1
                   ELSE 0
               END) AS weighted_completed_points,
           MIN(TRUNC(CAST(ts.completed_at AS DATE))) AS first_completion_date,
           MAX(TRUNC(CAST(ts.completed_at AS DATE))) AS last_completion_date
    FROM users u
    LEFT JOIN tasks ts
           ON ts.assigned_to = u.id
          AND ts.status = 'completed'
          AND ts.completed_at IS NOT NULL
    GROUP BY u.id, u.full_name
)
SELECT full_name,
       completed_tasks,
       weighted_completed_points,
       CASE
           WHEN completed_tasks = 0 THEN 0
           ELSE last_completion_date - first_completion_date + 1
       END AS active_completion_days,
       ROUND(
           weighted_completed_points /
           NULLIF(
               CASE
                   WHEN completed_tasks = 0 THEN 0
                   ELSE last_completion_date - first_completion_date + 1
               END,
               0
           ),
           2
       ) AS weighted_completed_points_per_day
FROM user_completed
ORDER BY weighted_completed_points_per_day DESC NULLS LAST;


-- ============================================================
-- EXERCISE 7: Fix the "Team Efficiency"
-- ============================================================
--
-- PROBLEM:
--   AVG(ts.id) is mathematically meaningless as a KPI.
--   A task ID is an identifier, not a measurement. Averaging IDs does not
--   describe efficiency, productivity, speed, or quality.
--
-- BETTER KPI:
--   Team efficiency = completed tasks / non-cancelled tasks per team.
--
-- Unit:
--   Percentage.

WITH team_efficiency AS (
    SELECT t.id AS team_id,
           t.name AS team_name,
           COUNT(CASE
                     WHEN ts.status <> 'cancelled'
                     THEN ts.id
                 END) AS non_cancelled_tasks,
           COUNT(CASE
                     WHEN ts.status = 'completed'
                     THEN ts.id
                 END) AS completed_tasks
    FROM teams t
    LEFT JOIN users u
           ON u.team_id = t.id
    LEFT JOIN tasks ts
           ON ts.assigned_to = u.id
    GROUP BY t.id, t.name
)
SELECT team_name,
       completed_tasks,
       non_cancelled_tasks,
       ROUND(completed_tasks * 100 / NULLIF(non_cancelled_tasks, 0), 1) AS team_efficiency_pct,
       CASE
           WHEN non_cancelled_tasks = 0 THEN 'No Data'
           WHEN completed_tasks * 100 / NULLIF(non_cancelled_tasks, 0) >= 70 THEN 'High Efficiency'
           WHEN completed_tasks * 100 / NULLIF(non_cancelled_tasks, 0) >= 40 THEN 'Medium Efficiency'
           ELSE 'Low Efficiency'
       END AS efficiency_band
FROM team_efficiency
ORDER BY team_efficiency_pct DESC NULLS LAST;


-- ============================================================
-- EXERCISE 8: Fix the "Urgency Index"
-- ============================================================
--
-- PROBLEM:
--   The bad query tries to multiply priority, which is a VARCHAR2, by 10.
--   It also tries to add a DATE to a number without defining a meaningful
--   business rule. The result is invalid or meaningless.
--
-- BETTER KPI:
--   Urgency score = priority weight * 100 + overdue pressure.
--   Priority weights:
--     critical = 4
--     high     = 3
--     medium   = 2
--     low      = 1
--
--   overdue pressure:
--     If overdue, add days overdue * 10.
--     If not overdue, add smaller pressure for tasks due soon.
--
-- Report date:
--   Uses DATE '2026-05-15' to match the seed dataset.
--   Replace with TRUNC(SYSDATE) for live production use.
--
-- Unit:
--   Score. Higher score means more urgent.

WITH task_urgency AS (
    SELECT id,
           title,
           status,
           priority,
           due_date,
           CASE priority
               WHEN 'critical' THEN 4
               WHEN 'high' THEN 3
               WHEN 'medium' THEN 2
               WHEN 'low' THEN 1
               ELSE 0
           END AS priority_weight,
           due_date - DATE '2026-05-15' AS days_until_due
    FROM tasks
    WHERE status NOT IN ('completed', 'cancelled')
)
SELECT title,
       status,
       priority,
       due_date,
       priority_weight,
       days_until_due,
       CASE
           WHEN due_date IS NULL THEN priority_weight * 100
           WHEN days_until_due < 0 THEN priority_weight * 100 + ABS(days_until_due) * 10
           ELSE priority_weight * 100 + GREATEST(30 - days_until_due, 0)
       END AS urgency_score,
       CASE
           WHEN due_date IS NULL THEN 'No Due Date'
           WHEN days_until_due < 0 THEN 'Overdue'
           WHEN days_until_due = 0 THEN 'Due Today'
           WHEN days_until_due <= 3 THEN 'Due Soon'
           ELSE 'Scheduled'
       END AS urgency_label
FROM task_urgency
ORDER BY urgency_score DESC, due_date ASC NULLS LAST;
