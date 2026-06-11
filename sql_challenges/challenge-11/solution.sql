-- ============================================================
-- Lesson 03: SQLAlchemy ORM + Alembic Migrations
-- File: 01_setup_schema.sql
-- Purpose: V1 Schema — teams, users, tasks.
--
-- Run this in your FreeSQL worksheet to create the base tables.
-- ============================================================

-- Drop tables if they exist (clean start)
DROP TABLE IF EXISTS tasks;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS teams;

-- ============================================================
-- TEAMS
-- ============================================================
CREATE TABLE teams (
    id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR2(50)  NOT NULL UNIQUE,
    description VARCHAR2(200),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- USERS
-- ============================================================
CREATE TABLE users (
    id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username    VARCHAR2(50)  NOT NULL UNIQUE,
    email       VARCHAR2(100) NOT NULL,
    full_name   VARCHAR2(100),
    team_id     NUMBER,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_users_team
        FOREIGN KEY (team_id) REFERENCES teams(id)
);

-- ============================================================
-- TASKS
-- ============================================================
CREATE TABLE tasks (
    id           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title        VARCHAR2(200) NOT NULL,
    description  VARCHAR2(1000),
    status       VARCHAR2(20)  DEFAULT 'open',
    assigned_to  NUMBER,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP,
    CONSTRAINT fk_tasks_user
        FOREIGN KEY (assigned_to) REFERENCES users(id)
);

-- ============================================================
-- SEED DATA
-- ============================================================

-- Teams
INSERT INTO teams (name, description) VALUES ('Engineering', 'Software development team');
INSERT INTO teams (name, description) VALUES ('Product', 'Product management team');

-- Users
INSERT INTO users (username, email, full_name, team_id)
    VALUES ('alice_dev', 'alice@example.com', 'Alice Smith', 1);
INSERT INTO users (username, email, full_name, team_id)
    VALUES ('bob_dev', 'bob@example.com', 'Bob Jones', 1);
INSERT INTO users (username, email, full_name, team_id)
    VALUES ('carol_pm', 'carol@example.com', 'Carol White', 2);

-- Tasks
INSERT INTO tasks (title, description, status, assigned_to)
    VALUES ('Fix login bug', 'Users cannot log in with SSO', 'open', 1);
INSERT INTO tasks (title, description, status, assigned_to)
    VALUES ('Design new dashboard', 'Create mockups for analytics page', 'in_progress', 3);
INSERT INTO tasks (title, description, status, assigned_to)
    VALUES ('Update dependencies', 'Upgrade numpy and pandas', 'open', 2);

COMMIT;

-- ============================================================
-- VERIFY
-- ============================================================
SELECT 'Teams:' AS section, name FROM teams
UNION ALL
SELECT 'Users:' AS section, username FROM users
UNION ALL
SELECT 'Tasks:' AS section, title FROM tasks;

 

-----

 

 

---

--# Lesson Exercises

---

--# Exercise 1 — Model Design (10 min)

--## Scenario

--Your task system needs a `comments` table.

--Each comment belongs to:
-- - one task
-- - one user

---

--## Task

--Create a new Colab cell and write the `Comment` model.

--### Required Fields

-- - `id`
-- - `task_id`
-- - `user_id`
-- - `content`
-- - `created_at`

---

class Comment(Base):
    __tablename__ = "comments"

    id = Column(Integer, primary_key=True)
    task_id = Column(Integer, ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    content = Column(String(1000), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    task = relationship("Task", back_populates="comments")
    user = relationship("User", back_populates="comments")

# In Task model
comments = relationship(
    "Comment",
    back_populates="task",
    cascade="all, delete-orphan"
)

# In User model
comments = relationship(
    "Comment",
    back_populates="user"
)

--## Questions

--1. What relationships should `Comment` have? Comment debe tener relación con Task y con User.
--2. Should `Task` have a `comments` relationship? Sí, Task debe tener una relación comments, porque una tarea puede tener muchos comentarios.
--3. What should happen to comments when a task is deleted? Si una tarea se elimina, sus comentarios también deberían eliminarse. Por eso usamos cascade="all, delete-orphan" en SQLAlchemy y ondelete="CASCADE" en el foreign key hacia tasks.

---

-- # Exercise 2 — Migration Creation (10 min)

-- ## Scenario

-- You added the `Comment` model.

-- Now generate a migration programmatically.

---

-- ## Task

-- Run:

--```python
-- command.revision(
--    alembic_cfg,
--    autogenerate=True,
--    message="add comments table"
--)
--```

---

-- ## Then Inspect the Migration

-- ```python
-- import glob

-- migration_files = sorted(
--    glob.glob('/content/project/alembic/versions/*.py')
-- )

-- for f in migration_files:
--    print(f)
```

---

-- ## Open the Generated Migration

-- ```python
-- latest = migration_files[-1]

-- with open(latest) as f:
--     print(f.read())
-- ```

---

-- ## Questions

-- 1. What does upgrade() do?
-- upgrade() applies the migration. In this case, it creates the new comments table,
-- including its columns, primary key, foreign keys, and the CHECK constraint if it was added.

-- 2. What does downgrade() do?
-- downgrade() reverses the migration. In this case, it drops the comments table.

-- 3. What happens if you downgrade this migration?
-- If I downgrade this migration, the comments table is removed from the database.
-- Any data stored in the comments table would be lost because the table is dropped.

---

## Bonus

Add a CHECK constraint so `content != ''`

---

# Exercise 3 — CRUD Challenge (10 min)

## Scenario

Write a script that:

1. Creates a team called `"DevOps"`
2. Creates a user `"diana_ops"`
3. Creates 3 tasks with different priorities
4. Prints task count
5. Closes one task
6. Deletes the lowest priority task

---

## Requirements

- Use ORM only
- Use relationships
- Print output clearly


from datetime import datetime

session = SessionLocal()

# 1. Creates a team called "DevOps"
devops_team = Team(
    name="DevOps",
    description="Operations and infrastructure team"
)

session.add(devops_team)
session.commit()

# 2. Creates a user "diana_ops"
diana = User(
    username="diana_ops",
    email="diana@example.com",
    full_name="Diana Operations",
    team=devops_team
)

session.add(diana)
session.commit()

# 3. Creates 3 tasks with different priorities
task1 = Task(
    title="Set up monitoring",
    description="Configure application monitoring tools",
    status="open",
    priority="high",
    assigned_user=diana
)

task2 = Task(
    title="Clean old logs",
    description="Remove old server log files",
    status="open",
    priority="low",
    assigned_user=diana
)

task3 = Task(
    title="Update deployment script",
    description="Improve the deployment automation script",
    status="open",
    priority="medium",
    assigned_user=diana
)

session.add_all([task1, task2, task3])
session.commit()

# 4. Prints task count
task_count = session.query(Task).count()
print("Task count:", task_count)

# 5. Closes one task
task1.status = "closed"
task1.updated_at = datetime.utcnow()
session.commit()

print("Closed task:", task1.title)

# 6. Deletes the lowest priority task
lowest_priority_task = session.query(Task).filter_by(priority="low").first()

if lowest_priority_task:
    print("Deleting lowest priority task:", lowest_priority_task.title)
    session.delete(lowest_priority_task)
    session.commit()

# Print final tasks clearly
print("\nFinal tasks:")
for task in session.query(Task).all():
    print(f"- {task.title} | status={task.status} | priority={task.priority} | assigned_to={task.assigned_user.username}")

session.close()
---

# Exercise 4 — Migration Rollback (5 min)

## Scenario

You added a bad column:
`estimated_hours`

The migration has already been applied.

---

## Task

Rollback the migration programmatically.

### Example

```python
command.downgrade(alembic_cfg, "-1")
```

command.downgrade(alembic_cfg, "-1")
---

## Questions

# 1. What happens to the column?
# The estimated_hours column is removed from the table because the downgrade reverses
# the migration that added the bad column.

# 2. What happens to the data?
# Any data stored in the estimated_hours column is lost when the column is dropped.
# The rest of the table and its other columns remain unchanged.

---

# Exercise 5 — Concept Check (5 min)

Answer briefly:

# 1. Why use ORM instead of raw SQL?
# ORM lets us work with database tables as Python classes and objects.
# It makes code easier to read, reuse, and maintain, especially when working with relationships.

# 2. Why use migrations?
# Migrations track database schema changes over time.
# They make it possible to upgrade or downgrade the database safely and consistently.

# 3. When would you rollback?
# I would rollback when a migration has a mistake, breaks the application,
# adds the wrong column, or needs to be reversed before applying a corrected migration.

# 4. Difference between add() and commit()?
# add() stages an object in the current session.
# commit() actually saves the staged changes permanently to the database.

# 5. Why are relationships useful?
# Relationships make it easier to navigate between connected tables using Python objects.
# For example, I can access a user's tasks or a task's comments without manually writing joins every time.

---