-- Lesson 04: Setup
-- Create a simple accounts table for the transfer demo

DROP TABLE accounts PURGE;

CREATE TABLE accounts (
    account_id   NUMBER PRIMARY KEY,
    owner_name   VARCHAR2(50) NOT NULL,
    balance      NUMBER(10,2) NOT NULL CHECK (balance >= 0)
);

INSERT INTO accounts VALUES (1, 'Alice',  1000.00);
INSERT INTO accounts VALUES (2, 'Bob',     500.00);
INSERT INTO accounts VALUES (3, 'Charlie', 250.00);
COMMIT;

-- Verify starting state
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;
-- Expected: Alice=1000, Bob=500, Charlie=250

-- Lesson 04: Class Exercises
-- Students: work through these in order. Don't skip the verify steps.

-- ============================================================
-- EXERCISE 1: Manual transaction (warm-up)
-- ============================================================
-- Transfer $50 from Charlie (3) to Alice (1) using BEGIN / COMMIT manually.
-- Before: verify balances. After COMMIT: verify again.

-- Your SQL here:

CREATE OR REPLACE PROCEDURE transfer_funds(
    p_from_account  IN  NUMBER,
    p_to_account    IN  NUMBER,
    p_amount        IN  NUMBER
) AS
    v_from_balance  NUMBER;
BEGIN
    -- Check sufficient funds before doing anything
    SELECT balance INTO v_from_balance
    FROM accounts
    WHERE account_id = p_from_account;

    IF v_from_balance < p_amount THEN
        RAISE_APPLICATION_ERROR(-20001, 'Insufficient funds in account ' || p_from_account);
    END IF;

    -- Perform the transfer
    UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from_account;
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_to_account;

    -- Commit only if both succeed
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Transfer complete: $' || p_amount ||
                         ' from account ' || p_from_account ||
                         ' to account ' || p_to_account);
EXCEPTION
    WHEN OTHERS THEN
        -- Something went wrong — undo everything
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Transfer failed. All changes rolled back.');
        RAISE;  -- re-raise the error so the caller knows it failed
END;

-- Check starting state
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;

-- Transfer $100 from Alice (1) to Bob (2)
SET SERVEROUTPUT ON;
EXEC transfer_funds(1, 2, 100);

-- Verify
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;

-- ============================================================
-- EXERCISE 2: Catch yourself with ROLLBACK
-- ============================================================
-- Start a transfer of $10,000 from Bob (2) to Charlie (3).
-- Before committing, check the balances. Does Bob have enough?
-- Use ROLLBACK to undo. Verify balances restored.

-- Your SQL here:

EXEC transfer_funds(2, 3, 10000);
-- Freesql uses automatic commit, no need to use rollback
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;
-- There is no change

-- ============================================================
-- EXERCISE 3: SAVEPOINT checkpoint
-- ============================================================
-- You need to:
-- 1. Add $25 to Alice's balance
-- 2. Set a savepoint
-- 3. Deduct $25 from Charlie's balance (wrong account — you meant Bob)
-- 4. Rollback to savepoint
-- 5. Deduct $25 from Bob's balance instead
-- 6. Commit

-- Your SQL here:

-- 1. Add $25 to Alice's balance
UPDATE accounts 
SET balance = balance + 25 
WHERE account_id = 1;

-- 2. Set a savepoint
SAVEPOINT sp_after_alice;

-- 3. Deduct $25 from Charlie's balance
UPDATE ACCOUNTS
SET balance = balance - 50
WHERE account_id = 3

-- 4. Rollback to savepoint
ROLLBACK TO SAVEPOINT sp_after_alice;
-- Rollback is not permitted, following steps were not done, but should be as following:

-- 5. Deduct $25 from Bob's balance instead
UPDATE accounts 
SET balance = balance - 25 
WHERE account_id = 2;

-- 6. Commit (Hacemos permanentes los cambios: +25 Alice, -25 Bob)
COMMIT;

-- Verificación final
SELECT * FROM accounts ORDER BY account_id;

-- ============================================================
-- EXERCISE 4: Write your own stored procedure
-- ============================================================
-- Create a procedure called deposit_funds(p_account_id, p_amount)
-- It should:
-- 1. Validate that p_amount > 0 (raise error if not)
-- 2. Add p_amount to the account balance
-- 3. COMMIT on success
-- 4. ROLLBACK + re-raise on any error
-- Test it with: EXEC deposit_funds(3, 75);

-- Your SQL here:

CREATE OR REPLACE PROCEDURE deposit_funds(
    p_account_id IN NUMBER,
    p_amount     IN NUMBER
) AS
BEGIN
    -- 1. Validate that p_amount > 0 (raise error if not)
    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'El monto del depósito debe ser mayor a cero.');
    END IF;

    -- 2. Add p_amount to the account balance
    UPDATE accounts 
    SET balance = balance + p_amount 
    WHERE account_id = p_account_id;

    -- Si el UPDATE no afectó a ninguna fila (el ID no existe)
    IF SQL%NOTFOUND THEN
        RAISE_APPLICATION_ERROR(-20003, 'La cuenta ' || p_account_id || ' no existe.');
    END IF;

    -- 3. COMMIT on success
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Depósito exitoso: $' || p_amount || ' abonados a la cuenta ' || p_account_id);

EXCEPTION
    -- 4. ROLLBACK + re-raise on any error
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en el depósito. Transacción cancelada.');
        RAISE; 
END;
/

-- Test procedure
SET SERVEROUTPUT ON;
EXEC deposit_funds(3, 75);

-- Verify result
SELECT * FROM accounts WHERE account_id = 3;

 

-- ============================================================
-- EXERCISE 5: Discussion
-- ============================================================
-- Answer these in words (no SQL needed):

-- Q1: You're building a patient appointment booking system.
-- A booking requires:
--   a) Reserve the time slot
--   b) Create the appointment record
--   c) Send a confirmation notification
-- Which of these should be inside the transaction? Which should be outside? Why?
-- Inside should be the time slot reservation and the appointment record creation, both should be dependent of each other.
-- Outside should be the confirmation notification, it depends of an external agent.

-- Q2: Your stored procedure calls COMMIT at the end.
-- A developer calls your procedure from inside their own larger transaction.
-- What problem does this create?
-- The problem is if something was wrong in their own transaction, as my procedure is committing, it won't be able to rollback.

-- Q3: You have a function called calculate_copay() and a procedure called post_payment().
-- A colleague wants to use calculate_copay() inside a SELECT statement.
-- Can they? Can they do the same with post_payment()? Why or why not?
-- Functions can be used, as they return values and do not change the database.
-- Procedures can't be used, as they do change the database.