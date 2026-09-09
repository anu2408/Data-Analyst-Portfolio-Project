-- =====================================================================
-- RedFlag — Fraud Detection Submission
-- Student: Parvathy M  |  Batch: DA-1
-- =====================================================================

Use redflag;

-- =====================================================================
-- PATTERN 1 · VELOCITY FRAUD
-- What I'm looking for: users with 30+ transactions in a single day
-- Expected suspects: ~50
-- ===================================================================== 

SELECT user_id, DATE(txn_time) AS attack_date, COUNT(*) AS daily_txn_count
FROM transactions
GROUP BY user_id, DATE(txn_time)
HAVING COUNT(*) >= 30
ORDER BY daily_txn_count DESC;

-- My findings: 50 suspect user-days flagged.
-- Top 3 fraudsters by transaction count: user 14569 (60 txns on 2024-04-03), user 14556 (60 txns on 2024-05-28), user 14564 (59 txns on 2024-02-15).
-- =====================================================================


-- =====================================================================
-- PATTERN 2 · ROUND-AMOUNT CLUSTERING
-- What I'm looking for: A single user_id with 15+ transactions where the amount is exactly one of: 100, 500, 1000, 5000, 10000.
-- Expected suspects: Exactly 25 (all seeded).
-- =====================================================================

SELECT user_id, COUNT(*) AS round_txn_count
FROM transactions
WHERE amount IN (100, 500, 1000, 5000, 10000)
GROUP BY user_id
HAVING COUNT(*) >= 15
ORDER BY round_txn_count DESC;

-- My findings: Exactly 21 suspect users flagged.
-- Top 3 fraudsters by round transaction count: user 14531 (23 txns), user 14541 (23 txns), user 14544 (22 txns).
-- =====================================================================


-- =====================================================================
-- PATTERN 3 · CARD TESTING
-- What I'm looking for: A single user_id with 30+ transactions under ₹10 in a single day.
-- Expected suspects: Exactly 20 (all seeded).
-- =====================================================================

SELECT user_id, DATE(txn_time) AS test_date, COUNT(*) AS test_count
FROM transactions
WHERE amount < 10
GROUP BY user_id, DATE(txn_time)
HAVING COUNT(*) >= 30
ORDER BY test_count DESC;

-- My findings: Exactly 20 suspect user-days flagged.
-- Top 3 fraudsters: user 14569 (60 txns on 2024-04-03), user 14556 (60 txns on 2024-05-28), user 14564 (59 txns on 2024-02-15).
-- =====================================================================


-- =====================================================================
-- PATTERN 4 · FAILED-THEN-SUCCEEDED (Advanced version)
-- What I'm looking for: A user_id with 20+ pairs where a FAILED transaction is followed within 2 minutes by a SUCCESS transaction of the same amount.
-- Expected suspects: Exactly 25 (all seeded).
-- =====================================================================

SELECT t1.user_id, COUNT(*) AS pair_count
FROM transactions t1
JOIN transactions t2
ON t1.user_id = t2.user_id
AND t1.amount = t2.amount
AND t1.status = 'FAILED'
AND t2.status = 'SUCCESS'
AND t2.txn_time > t1.txn_time
AND TIMESTAMPDIFF(SECOND, t1.txn_time, t2.txn_time) <= 120
GROUP BY t1.user_id
HAVING COUNT(*) >= 20
ORDER BY pair_count DESC;

-- My findings: Exactly 25 suspect users flagged.
-- Top 3 fraudsters by pair count: user 14595 (35 pairs), user 14593 (34 pairs), user 14576 (33 pairs).
-- =====================================================================


-- =====================================================================
-- PATTERN 5 · ODD-HOUR CONCENTRATION
-- What I'm looking for: A user_id where 80% or more of their transactions occur between 2 AM and 5 AM, with at least 30 total transactions.
-- Expected suspects: Exactly 20 (all seeded).
-- =====================================================================

SELECT user_id,
SUM(CASE WHEN HOUR(txn_time) BETWEEN 2 AND 4 THEN 1 ELSE 0 END) AS odd_hour_count,
COUNT(*) AS total_count,
SUM(CASE WHEN HOUR(txn_time) BETWEEN 2 AND 4 THEN 1 ELSE 0 END) / COUNT(*) AS odd_ratio
FROM transactions
GROUP BY user_id
HAVING COUNT(*) >= 30
AND SUM(CASE WHEN HOUR(txn_time) BETWEEN 2 AND 4 THEN 1 ELSE 0 END) / COUNT(*) >= 0.8
ORDER BY odd_ratio DESC, total_count DESC;

-- My findings: Exactly 20 suspect users flagged.
-- Top 3 fraudsters: user 14606 (49/52 odd-hour txns, 94.23% concentration), user 14609 (45/48 odd-hour txns, 93.75% concentration), user 14608 (58/63 odd-hour txns, 92.06% concentration).
-- =====================================================================


-- =====================================================================
-- PATTERN 6 · MULE ACCOUNTS
-- What I'm looking for: A user with 5+ instances where a CREDIT is followed within 30 minutes by a DEBIT of at least 70% of the credit amount.
-- Expected suspects: Exactly 30 (all seeded).
-- =====================================================================

SELECT t1.user_id, COUNT(*) AS mule_instances
FROM transactions t1
WHERE t1.txn_type = 'CREDIT'
AND EXISTS(
SELECT 1 FROM transactions t2
WHERE t2.user_id = t1.user_id
AND t2.txn_type = 'DEBIT'
AND t2.txn_time > t1.txn_time
AND TIMESTAMPDIFF(MINUTE, t1.txn_time, t2.txn_time) <= 30
AND t2.amount >= 0.70 * t1.amount
)
GROUP BY t1.user_id
HAVING COUNT(*) >= 5
ORDER BY mule_instances DESC;

-- My findings: Exactly 30 suspect users flagged.
-- Top 3 fraudsters by mule instance count: user 14637 (15 instances), user 14640 (15 instances), user 14645 (15 instances).
-- =====================================================================


-- =====================================================================
-- PATTERN 7 · REFUND ABUSE
-- What I'm looking for: A user with 20+ total transactions AND a refund ratio (REFUNDS / TOTAL) greater than 40%.
-- Expected suspects: 24-25 (all seeded).
-- =====================================================================

SELECT user_id,
SUM(CASE WHEN txn_type = 'REFUND' THEN 1 ELSE 0 END) AS refund_count,
COUNT(*) AS total_count,
SUM(CASE WHEN txn_type = 'REFUND' THEN 1 ELSE 0 END) / COUNT(*) AS refund_ratio
FROM transactions
GROUP BY user_id
HAVING COUNT(*) >= 20
AND SUM(CASE WHEN txn_type = 'REFUND' THEN 1 ELSE 0 END) / COUNT(*) > 0.4
ORDER BY refund_ratio DESC, total_count DESC;

-- My findings: Exactly 24 suspect users flagged.
-- Top 3 fraudsters: user 14662 (25 refunds out of 39 txns, 64.10% ratio), user 14670 (32 refunds out of 50 txns, 64.00% ratio), user 14665 (23 refunds out of 36 txns, 63.89% ratio).
-- =====================================================================


-- =====================================================================
-- PATTERN 8 · MERCHANT COLLUSION
-- What I'm looking for: A merchant where the top 5 users by volume account for more than 60% of the merchant's total transaction value.
-- Expected suspects: Exactly 15 merchants (merchant IDs 1-15 are the seeded colluding merchants).
-- =====================================================================

WITH UserMerchantVolume AS(
SELECT merchant_id, user_id, SUM(amount) AS user_volume
FROM transactions
GROUP BY merchant_id, user_id
),
RankedVolume AS(
SELECT merchant_id, user_id, user_volume,
ROW_NUMBER() OVER (PARTITION BY merchant_id ORDER BY user_volume DESC) AS rnk
FROM UserMerchantVolume
),
MerchantTotal AS(
SELECT merchant_id, SUM(amount) AS total_volume
FROM transactions
GROUP BY merchant_id
),
Top5Volume AS(
SELECT merchant_id, SUM(user_volume) AS top5_volume
FROM RankedVolume
WHERE rnk <= 5
GROUP BY merchant_id
)
SELECT t.merchant_id, t.top5_volume, m.total_volume,
(t.top5_volume / m.total_volume) AS concentration_ratio
FROM Top5Volume t
JOIN MerchantTotal m
ON t.merchant_id = m.merchant_id
WHERE (t.top5_volume / m.total_volume) > 0.60
ORDER BY concentration_ratio DESC;

-- My findings: Exactly 15 suspect merchants flagged (Merchants 1-15).
-- Top 3 colluding merchants: merchant 12 (99.91% concentration), merchant 8 (99.87% concentration), merchant 13 (99.85% concentration).
-- =====================================================================


-- =====================================================================
-- PATTERN 9 · JUST-UNDER-THRESHOLD (STRUCTURING)
-- What I'm looking for: A user with 10 or more transactions at exactly ₹9,999.00.
-- Expected suspects: Exactly 20 (all seeded).
-- =====================================================================

SELECT user_id, COUNT(*) AS count_9999
FROM transactions
WHERE amount = 9999.00
GROUP BY user_id
HAVING COUNT(*) >= 10
ORDER BY count_9999 DESC;

-- My findings: Exactly 20 suspect users flagged.
-- Top 3 fraudsters: user 14680 (25 txns of 9999.00), user 14690 (25 txns of 9999.00), user 14693 (22 txns of 9999.00).
-- =====================================================================


-- =====================================================================
-- PATTERN 10 · DORMANT-THEN-ACTIVE
-- What I'm looking for: A user who has a gap of 90+ days between two consecutive transactions, followed by 15+ transactions after the gap.
-- Expected suspects: 25-27 (25 seeded + occasional noise).
-- =====================================================================

WITH TxnWithLag AS(
SELECT user_id, txn_time,
LAG(txn_time) OVER (PARTITION BY user_id ORDER BY txn_time) AS
prev_txn_time
FROM transactions
),
GapStarts AS(
SELECT user_id, txn_time AS gap_end_time
FROM TxnWithLag
WHERE prev_txn_time IS NOT NULL
AND TIMESTAMPDIFF(DAY, prev_txn_time, txn_time) >= 90
)
SELECT g.user_id, MIN(g.gap_end_time) AS gap_end_time, COUNT(t.txn_id) AS
post_gap_txns
FROM GapStarts g
JOIN transactions t
ON g.user_id = t.user_id
AND t.txn_time >= g.gap_end_time
GROUP BY g.user_id
HAVING post_gap_txns >= 15
ORDER BY post_gap_txns DESC;

-- My findings: 26 suspect users flagged.
-- Top 3 fraudsters: user 14526 (55 post-gap txns, gap ended 2024-05-20 09:29:14), user 14701 (28 post-gap txns, gap ended 2024-06-05 08:51:00), user 14708 (28 post-gap txns, gap ended 2024-06-24 00:25:00).
-- =====================================================================


-- =====================================================================
-- PATTERN 11 · VELOCITY SPIKE
-- What I'm looking for: A user whose peak monthly transaction count is at least 5x their average monthly transaction count (and peak is at least 20 transactions).
-- Expected suspects: 35-45. 20 seeded users MUST appear in results.
-- =====================================================================

WITH MonthlyCounts AS(
SELECT user_id,
DATE_FORMAT(txn_time, '%Y-%m') AS txn_month,
COUNT(*) AS monthly_count
FROM transactions
GROUP BY user_id, DATE_FORMAT(txn_time, '%Y-%m')
),
UserStats AS(
SELECT user_id,
MAX(monthly_count) AS peak_monthly_count,
SUM(monthly_count) / 6.0 AS avg_monthly_count
FROM MonthlyCounts
GROUP BY user_id
)
SELECT user_id, peak_monthly_count, avg_monthly_count,
(peak_monthly_count / avg_monthly_count) AS spike_ratio
FROM UserStats
WHERE peak_monthly_count >= 20
AND (peak_monthly_count / avg_monthly_count) >= 5
ORDER BY spike_ratio DESC;

-- My findings: 66 suspect users flagged (including all 20 seeded users 14501-14520, plus other concentrated fraudsters from other patterns whose activity concentrated in a single month).
-- Top 3 fraudsters: user 14572 (peak: 52, avg: 8.67, ratio: 6.000), user 14571 (peak: 55, avg: 9.17, ratio: 6.000), user 14570 (peak: 36, avg: 6.00, ratio: 6.000).
-- =====================================================================


-- =====================================================================
-- PATTERN 12 · GEOGRAPHIC IMPOSSIBILITY
-- What I'm looking for: A user_id where at least one pair of consecutive transactions 
-- occurs in different cities within 60 minutes of each other.
-- Expected suspects: Exactly 15 (all seeded).
-- =====================================================================

WITH TaxWithLag AS(
SELECT user_id, city, txn_time,
LAG(city) OVER (PARTITION BY user_id ORDER BY txn_time) AS prev_city,
LAG(txn_time) OVER (PARTITION BY user_id ORDER BY txn_time) AS prev_time
FROM transactions
),
GeoImpossibility AS(
SELECT user_id, city, txn_time, prev_city, prev_time,
TIMESTAMPDIFF(MINUTE, prev_time, txn_time) AS time_diff_minutes
FROM TaxWithLag
WHERE prev_city IS NOT NULL
AND prev_time IS NOT NULL
AND city <> prev_city
AND TIMESTAMPDIFF(MINUTE, prev_time, txn_time) <= 60
)
SELECT user_id, COUNT(*) AS instances
FROM GeoImpossibility
GROUP BY user_id
ORDER BY instances DESC;

-- My findings: Exactly 15 suspect users flagged.
-- Top 3 fraudsters: user 14755 (8 instances), user 14743 (7 instances), user 14746 (7 instances).
-- =====================================================================
