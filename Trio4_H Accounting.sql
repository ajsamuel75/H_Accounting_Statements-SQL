USE H_Accounting;

/*******************************************************************************
** Produce Profit & Loss Statements 
** Print P&L as clear as possible on the Result Grids
** Show the % change vs. the previous year for every major line item on the P&L
********************************************************************************/

-- -----------------------------------------------------------------------------------------------
#1. LEFT JOIN is needed; ex. 1 journal_entry_id has multiple line entries
#   Check which columns to join all tables
# 	journal_entry_id, account_id, profit_loss_section_id(=statement_section_id) are relation keys
-- -----------------------------------------------------------------------------------------------
Select count(*)
From journal_entry_line_item jeli
LEFT JOIN journal_entry je
 ON je.journal_entry_id = jeli.journal_entry_id -- 5155
LEFT JOIN account a
 ON a.account_id = jeli.account_id
LEFT JOIN statement_section ss
 ON ss.statement_section_id = a.profit_loss_section_id
Where YEAR(je.entry_date) = 2016
;

-- -----------------------------------------------------------------------------------------------
#2. Profit&Loss statement setting
#	Check je table; debit_credit_balanced(0) = cancelled(1) + user_id(0) = null values for all
#	closing type should be 0; Exclude FY Closing to avoid bringing accout balance to zero
-- -----------------------------------------------------------------------------------------------
Select ss.statement_section, ss.debit_is_positive, count(*),
	   SUM(jeli.debit) AS DEBIT, SUM(jeli.credit) AS CREDIT
From journal_entry_line_item jeli
LEFT JOIN journal_entry je
 ON je.journal_entry_id = jeli.journal_entry_id 
LEFT JOIN account a
 ON a.account_id = jeli.account_id
LEFT JOIN statement_section ss
 ON ss.statement_section_id = a.profit_loss_section_id
Where YEAR(je.entry_date) = 2016 -- FY2016
  AND je.debit_credit_balanced = 1 AND je.user_id != 0
  AND je.closing_type = 0
  AND ss.statement_section_id != 0 -- Both local and H_server working
Group by ss.statement_section, ss.debit_is_positive
;
-- -----------------------------------------------------------------------------------------------
#3. SUM credit&debit to figure out whether it is profit or loss
# 	Show 1 column as year(debt+credit)
#	Debt shows as double type..so use case~when to take debit calc. in opposite way
-- -----------------------------------------------------------------------------------------------

-- Group by year; 2016 is the best reference to check both 2016 & 2015 + '% change'
Select ss.statement_section, YEAR(je.entry_date) as entry_year,
        ROUND(SUM(CASE WHEN ss.debit_is_positive = 1 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)*-1
					   WHEN ss.debit_is_positive = 0 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0) 
					END),2) AS SUM
		From journal_entry_line_item jeli
        LEFT JOIN journal_entry je
			ON je.journal_entry_id = jeli.journal_entry_id 
        LEFT JOIN `account` a
			ON a.account_id = jeli.account_id
		LEFT JOIN statement_section ss
			ON ss.statement_section_id = a.profit_loss_section_id
Where 	ss.statement_section != '' 
  AND je.debit_credit_balanced = 1 AND je.user_id != 0 AND cancelled = 0
  AND je.closing_type = 0
Group by entry_year, statement_section; -- Check all year

-- 2016 to check, try to shape as P&L report
Select ss.statement_section, 
	   Round(SUM(CASE WHEN ss.debit_is_positive = 1 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)*-1
					  WHEN ss.debit_is_positive = 0 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)
	   END),2) AS year_2016
From journal_entry_line_item jeli
LEFT JOIN journal_entry je
 ON je.journal_entry_id = jeli.journal_entry_id 
LEFT JOIN account a
 ON a.account_id = jeli.account_id
LEFT JOIN statement_section ss
 ON ss.statement_section_id = a.profit_loss_section_id
Where YEAR(je.entry_date) = 2016 -- FY2016
  AND je.debit_credit_balanced = 1 AND je.user_id != 0 AND cancelled = 0
  AND je.closing_type = 0
  AND ss.statement_section_id != 0 -- Both local and H_server working
Group by ss.statement_section, ss.statement_section_id
Order by ss.statement_section_id
; -- Check target_year

-- -----------------------------------------------------------------------------------------------
#4. Add columns to show % change by year
# 	Show 1 column as year(debt+credit)
#	Debt shows as double type..so use case~when to take debit calc. in opposite way
-- -----------------------------------------------------------------------------------------------

-- Considering 2016 is an input variable 
Select ss.statement_section, 
	   Round(SUM(CASE WHEN ss.debit_is_positive = 1 AND YEAR(je.entry_date) = 2016 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)*-1
					  WHEN ss.debit_is_positive = 0 AND YEAR(je.entry_date) = 2016 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)
	   END),2) AS Query_year
       ,
	   Round(SUM(CASE WHEN ss.debit_is_positive = 1 AND YEAR(je.entry_date) = 2016-1 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)*-1
					  WHEN ss.debit_is_positive = 0 AND YEAR(je.entry_date) = 2016-1 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)
	   END),2) AS Previous_year
       ,Round((Round(SUM(CASE WHEN ss.debit_is_positive = 1 AND YEAR(je.entry_date) = 2016 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)*-1
					  WHEN ss.debit_is_positive = 0 AND YEAR(je.entry_date) = 2016 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)
	   END),2) - Round(SUM(CASE WHEN ss.debit_is_positive = 1 AND YEAR(je.entry_date) = 2016-1 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)*-1
					  WHEN ss.debit_is_positive = 0 AND YEAR(je.entry_date) = 2016-1 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)
	   END),2)) / Round(SUM(CASE WHEN ss.debit_is_positive = 1 AND YEAR(je.entry_date) = 2016 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)*-1
					  WHEN ss.debit_is_positive = 0 AND YEAR(je.entry_date) = 2016 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)
	   END),2)*100,2) AS `YoY Growth(%)`
From journal_entry_line_item jeli
LEFT JOIN journal_entry je
 ON je.journal_entry_id = jeli.journal_entry_id 
LEFT JOIN account a
 ON a.account_id = jeli.account_id
LEFT JOIN statement_section ss
 ON ss.statement_section_id = a.profit_loss_section_id
Where je.debit_credit_balanced = 1 AND je.user_id != 0 AND cancelled = 0
  AND je.closing_type = 0
--  AND ss.statement_section != ' ' -- Include after balancing btw Debit and Credit
  AND ss.statement_section_id != 0 -- Both local and H_server working
Group by ss.statement_section, ss.statement_section_id
Order by ss.statement_section_id
; -- Check target_year


/*******************************************************************************
** Produce Blance Sheet Statements 
** Print B/S as clear as possible on the Result Grids
** Show the % change vs. the previous year for every major line item on the B/S
********************************************************************************/

-- -----------------------------------------------------------------------------------------------
#1. Using LEFT JOIN to build own master-table
#   Check debit, credit
# 	
-- -----------------------------------------------------------------------------------------------

-- P&L, B/S check
SELECT	pl.statement_section AS PL, bs.statement_section AS BS, COUNT(*)
FROM	journal_entry_line_item AS jeli
LEFT JOIN	journal_entry AS je
	ON	jeli.journal_entry_id = je.journal_entry_id
LEFT JOIN	`account` AS a
	ON	jeli.account_id = a.account_id
LEFT JOIN	statement_section AS pl
	ON	a.profit_loss_section_id = pl.statement_section_id
LEFT JOIN	statement_section AS bs
	ON	a.balance_sheet_section_id = bs.statement_section_id
WHERE	je.debit_credit_balanced = 1 AND je.user_id != 0 AND je.cancelled = 0
	AND je.closing_type = 0
	AND YEAR(je.entry_date) = '2016' 
	AND (bs.statement_section_id != 0 or pl.statement_section_id != 0)-- Both local and H_server working
GROUP BY	pl.statement_section, bs.statement_section
;

-- Aligning statement_section
SELECT CASE WHEN pl.statement_section != '' THEN pl.statement_section
		    ELSE bs.statement_section 
		    END AS statement_section,
		a.account, a.account_id, a.account_code, jeli.line_item, a.postable,
		je.journal_entry, je.journal_entry_code, bs.statement_section_id, bs.is_balance_sheet_section, 
        jeli.debit, jeli.credit
FROM journal_entry_line_item AS jeli
LEFT JOIN	journal_entry AS je
	ON	jeli.journal_entry_id = je.journal_entry_id
LEFT JOIN	`account` AS a
	ON	jeli.account_id = a.account_id
LEFT JOIN	statement_section AS pl
	ON	a.profit_loss_section_id = pl.statement_section_id
LEFT JOIN	statement_section AS bs
	ON	a.balance_sheet_section_id = bs.statement_section_id
WHERE	je.debit_credit_balanced = 1 AND je.user_id != 0 AND je.cancelled = 0
	AND je.closing_type = 0
	AND YEAR(je.entry_date) = '2016' 	  
	AND (bs.statement_section_id != 0 or pl.statement_section_id != 0)-- Both local and H_server working
;

-- -----------------------------------------------------------------------------------------------
#2. Result Grids setting
#	Add Assets, Liabilities, Equity column  
# 	Use master-table as sub_query
-- -----------------------------------------------------------------------------------------------

Select distinct statement_section from statement_section;

-- Build master table
SELECT  postable, `name`, `account`, journal_entry_code, journal_entry, line_item,
		ROUND(CASE 
					WHEN `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND credit IS NULL THEN IFNULL(debit, 0)
					WHEN `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND debit  IS NULL THEN IFNULL(credit, 0) * -1
					ELSE 0 -- Avoid NULL values
					END, 2) AS ASSETS,
		ROUND(CASE 
					WHEN `name` IN ('CURRENT LIABILITIES') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN `name` IN ('CURRENT LIABILITIES') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0
					END, 2) AS LIABILITIES,
		ROUND(CASE 
					WHEN `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0
					END, 2) AS EQUITY
FROM 
	(SELECT CASE WHEN pl.statement_section != '' THEN pl.statement_section
		    ELSE bs.statement_section 
		    END AS `name`,
		a.account, a.account_id, a.account_code, jeli.line_item, a.postable,
		je.journal_entry, je.journal_entry_code, je.entry_date, bs.statement_section_id, bs.is_balance_sheet_section,
        jeli.debit, jeli.credit
	FROM journal_entry_line_item AS jeli
	LEFT JOIN	journal_entry AS je
		ON	jeli.journal_entry_id = je.journal_entry_id
	LEFT JOIN	`account` AS a
		ON	jeli.account_id = a.account_id
	LEFT JOIN	statement_section AS pl
		ON	a.profit_loss_section_id = pl.statement_section_id
	LEFT JOIN	statement_section AS bs
		ON	a.balance_sheet_section_id = bs.statement_section_id
	WHERE	je.debit_credit_balanced = 1 AND je.user_id != 0 AND je.cancelled = 0
		AND je.closing_type = 0
		AND YEAR(je.entry_date) = '2016' 
		AND (bs.statement_section_id != 0 or pl.statement_section_id != 0)-- Both local and H_server working
	) AS `all` -- master table alias
ORDER BY is_balance_sheet_section DESC, statement_section_id, journal_entry_code ASC
;

-- Setting A = L+E from master table
SELECT  account_code, `name`,
		ROUND(SUM(CASE 
					WHEN `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND credit IS NULL THEN IFNULL(debit, 0)
					WHEN `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND debit  IS NULL THEN IFNULL(credit, 0) * -1
					ELSE 0 -- Avoid NULL values
					END), 2) AS ASSETS,
		ROUND(SUM(CASE 
					WHEN `name` IN ('CURRENT LIABILITIES') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN `name` IN ('CURRENT LIABILITIES') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0
					END), 2) AS LIABILITIES,
		ROUND(SUM(CASE 
					WHEN `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0
					END), 2) AS EQUITY
FROM 
	(SELECT CASE WHEN pl.statement_section != '' THEN pl.statement_section
		    ELSE bs.statement_section 
		    END AS `name`,
		a.account, a.account_id, a.account_code, jeli.line_item, a.postable,
		je.journal_entry, je.journal_entry_code, je.entry_date, bs.statement_section_id, bs.is_balance_sheet_section,
        jeli.description, jeli.debit, jeli.credit
	FROM journal_entry_line_item AS jeli
	LEFT JOIN	journal_entry AS je
		ON	jeli.journal_entry_id = je.journal_entry_id
	LEFT JOIN	`account` AS a
		ON	jeli.account_id = a.account_id
	LEFT JOIN	statement_section AS pl
		ON	a.profit_loss_section_id = pl.statement_section_id
	LEFT JOIN	statement_section AS bs
		ON	a.balance_sheet_section_id = bs.statement_section_id
	WHERE	je.debit_credit_balanced = 1 AND je.user_id != 0 AND je.cancelled = 0
		AND je.closing_type = 0
		AND YEAR(je.entry_date) = '2016' 
	) AS `all` -- master table alias 
Where is_balance_sheet_section = 1 -- Exclude P&L components
GROUP BY `name`, account_code -- , journal_entry_code, statement_section_id, is_balance_sheet_section
;

-- -----------------------------------------------------------------------------------------------
#3. Demonstrate A = L + E
#	Add manual column to see the result clear
# 	
-- -----------------------------------------------------------------------------------------------
SELECT  
		ROUND(SUM(CASE 
					WHEN `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND credit IS NULL THEN IFNULL(debit, 0)
					WHEN `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND debit  IS NULL THEN IFNULL(credit, 0) * -1
					ELSE 0 -- Avoid NULL values
					END), 2) AS ASSETS,
		'=', -- add manual column
		ROUND(SUM(CASE 
					WHEN `name` IN ('CURRENT LIABILITIES') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN `name` IN ('CURRENT LIABILITIES') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0
					END), 2) AS LIABILITIES,
		'+',
		ROUND(SUM(CASE 
					WHEN `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0
					END), 2) AS EQUITY
FROM 
	(SELECT CASE WHEN pl.statement_section != '' THEN pl.statement_section
		    ELSE bs.statement_section 
		    END AS `name`,
		a.account, a.account_id, a.account_code, jeli.line_item, a.postable,
		je.journal_entry, je.journal_entry_code, je.entry_date, bs.statement_section_id, bs.is_balance_sheet_section,
        jeli.debit, jeli.credit
	FROM journal_entry_line_item AS jeli
	LEFT JOIN	journal_entry AS je
		ON	jeli.journal_entry_id = je.journal_entry_id
	LEFT JOIN	`account` AS a
		ON	jeli.account_id = a.account_id
	LEFT JOIN	statement_section AS pl
		ON	a.profit_loss_section_id = pl.statement_section_id
	LEFT JOIN	statement_section AS bs
		ON	a.balance_sheet_section_id = bs.statement_section_id
	WHERE	je.debit_credit_balanced = 1 AND je.user_id != 0 AND je.cancelled = 0
		AND je.closing_type = 0
		AND YEAR(je.entry_date) = '2016' 
	) AS `all` -- master table alias 
;

-- -----------------------------------------------------------------------------------------------
#4. Add columns to show % change by year
#	Use SUM with CASE~WHEN function
# 	Use same master-table as sub_query
-- -----------------------------------------------------------------------------------------------

-- Considering 2016 is an input variable 
-- Setting A = L+E from master table
SELECT  `name`,
		ROUND(SUM(CASE 
					WHEN  YEAR(entry_date) = 2016  AND `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND credit IS NULL THEN IFNULL(debit, 0)
					WHEN  YEAR(entry_date) = 2016  AND `name` IN ('CURRENT LIABILITIES') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = 2016  AND `name` IN ('CURRENT LIABILITIES') AND debit  IS NULL THEN IFNULL(credit, 0)
					WHEN  YEAR(entry_date) = 2016  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = 2016  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0 -- Avoid NULL values
					END), 2) AS Query_year
		,
        ROUND(SUM(CASE 
					WHEN  YEAR(entry_date) = 2016-1  AND `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND credit IS NULL THEN IFNULL(debit, 0)
					WHEN  YEAR(entry_date) = 2016-1  AND `name` IN ('CURRENT LIABILITIES') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = 2016-1  AND `name` IN ('CURRENT LIABILITIES') AND debit  IS NULL THEN IFNULL(credit, 0)
					WHEN  YEAR(entry_date) = 2016-1  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = 2016-1  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0 -- Avoid NULL values
					END), 2) AS Previous_year
		,
        ROUND((ROUND(SUM(CASE 
					WHEN  YEAR(entry_date) = 2016  AND `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND credit IS NULL THEN IFNULL(debit, 0)
					WHEN  YEAR(entry_date) = 2016  AND `name` IN ('CURRENT LIABILITIES') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = 2016  AND `name` IN ('CURRENT LIABILITIES') AND debit  IS NULL THEN IFNULL(credit, 0)
					WHEN  YEAR(entry_date) = 2016  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = 2016  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0 -- Avoid NULL values
					END), 2)
		- ROUND(SUM(CASE 
					WHEN  YEAR(entry_date) = 2016-1  AND `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND credit IS NULL THEN IFNULL(debit, 0)
					WHEN  YEAR(entry_date) = 2016-1  AND `name` IN ('CURRENT LIABILITIES') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = 2016-1  AND `name` IN ('CURRENT LIABILITIES') AND debit  IS NULL THEN IFNULL(credit, 0)
					WHEN  YEAR(entry_date) = 2016-1  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = 2016-1  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0 -- Avoid NULL values
					END), 2))/ROUND(SUM(CASE 
					WHEN  YEAR(entry_date) = 2016  AND `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND credit IS NULL THEN IFNULL(debit, 0)
					WHEN  YEAR(entry_date) = 2016  AND `name` IN ('CURRENT LIABILITIES') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = 2016  AND `name` IN ('CURRENT LIABILITIES') AND debit  IS NULL THEN IFNULL(credit, 0)
					WHEN  YEAR(entry_date) = 2016  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = 2016  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0 -- Avoid NULL values
					END), 2)*100,2) AS `YoY Growth(%)`
FROM 
	(SELECT CASE WHEN pl.statement_section != '' THEN pl.statement_section
		    ELSE bs.statement_section 
		    END AS `name`,
		a.account, a.account_id, a.account_code, jeli.line_item, a.postable,
		je.journal_entry, je.journal_entry_code, je.entry_date, bs.statement_section_id, bs.is_balance_sheet_section,
        jeli.debit, jeli.credit
	FROM journal_entry_line_item AS jeli
	LEFT JOIN	journal_entry AS je
		ON	jeli.journal_entry_id = je.journal_entry_id
	LEFT JOIN	`account` AS a
		ON	jeli.account_id = a.account_id
	LEFT JOIN	statement_section AS pl
		ON	a.profit_loss_section_id = pl.statement_section_id
	LEFT JOIN	statement_section AS bs
		ON	a.balance_sheet_section_id = bs.statement_section_id
	WHERE	je.debit_credit_balanced = 1 AND je.user_id != 0 AND je.cancelled = 0
		AND je.closing_type = 0
-- 		AND YEAR(je.entry_date) = '2016' 
	) AS `all` -- master table alias 
Where is_balance_sheet_section = 1 -- Exclude P&L components
Group by `name`
Order by `name`
;

/*******************************************************************************
** Create Stored Procedure for P&L, B/S
** Be careful of running 'DELIMITER'
-- stored procedure template
DELIMITER $$

DROP PROCEDURE IF EXISTS database_name.stored_procedure_name; -- change this part!!

CREATE PROCEDURE database_name.stored_procedure_name()

	READS SQL DATA -- reading the data
    
BEGIN

<put your query here> -- change this part too
 
END$$
DELIMITER ;
********************************************************************************/

USE H_Accounting;


-- Building the stored procedure
DELIMITER $$ -- The tpycal delimiter for Stored procedures is a double dollar sign

-- DROP PROCEDURE IF EXISTS H_Accounting.Trio4_bkim;
CREATE PROCEDURE H_Accounting.Trio4_bkim(IN fy_year INT) -- IN: Input sign
    READS SQL DATA

BEGIN

-- (1) Build STORED PROCEDURE for P&L; Line 321
-- Considering 2016 is an input variable; Change 2016 to fy_year
Select ss.statement_section, 
	   Round(SUM(CASE WHEN ss.debit_is_positive = 1 AND YEAR(je.entry_date) = fy_year THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)*-1
					  WHEN ss.debit_is_positive = 0 AND YEAR(je.entry_date) = fy_year THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)
	   END),2) AS Query_year
       ,
	   Round(SUM(CASE WHEN ss.debit_is_positive = 1 AND YEAR(je.entry_date) = fy_year-1 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)*-1
					  WHEN ss.debit_is_positive = 0 AND YEAR(je.entry_date) = fy_year-1 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)
	   END),2) AS Previous_year
       ,Round((Round(SUM(CASE WHEN ss.debit_is_positive = 1 AND YEAR(je.entry_date) = fy_year THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)*-1
					  WHEN ss.debit_is_positive = 0 AND YEAR(je.entry_date) = fy_year THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)
	   END),2) - Round(SUM(CASE WHEN ss.debit_is_positive = 1 AND YEAR(je.entry_date) = fy_year-1 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)*-1
					  WHEN ss.debit_is_positive = 0 AND YEAR(je.entry_date) = fy_year-1 THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)
	   END),2)) / Round(SUM(CASE WHEN ss.debit_is_positive = 1 AND YEAR(je.entry_date) = fy_year THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)*-1
					  WHEN ss.debit_is_positive = 0 AND YEAR(je.entry_date) = fy_year THEN   IFNULL(jeli.credit,0) - IFNULL(jeli.debit,0)
	   END),2)*100,2) AS `YoY Growth(%)`
From journal_entry_line_item jeli
LEFT JOIN journal_entry je
 ON je.journal_entry_id = jeli.journal_entry_id 
LEFT JOIN account a
 ON a.account_id = jeli.account_id
LEFT JOIN statement_section ss
 ON ss.statement_section_id = a.profit_loss_section_id
Where je.debit_credit_balanced = 1 AND je.user_id != 0 AND cancelled = 0
  AND je.closing_type = 0
  AND ss.statement_section != ' ' -- Include after balancing btw Debit and Credit
Group by ss.statement_section, ss.statement_section_id
Order by ss.statement_section_id
;
-- (2) Build STORED PROCEDURE for B/S; Line 273
-- Considering 2016 is an input variable; Change 2016 to fy_year
SELECT  `name`,
		ROUND(SUM(CASE 
					WHEN  YEAR(entry_date) = fy_year  AND `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND credit IS NULL THEN IFNULL(debit, 0)
					WHEN  YEAR(entry_date) = fy_year  AND `name` IN ('CURRENT LIABILITIES') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = fy_year  AND `name` IN ('CURRENT LIABILITIES') AND debit  IS NULL THEN IFNULL(credit, 0)
					WHEN  YEAR(entry_date) = fy_year  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = fy_year  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0 -- Avoid NULL values
					END), 2) AS Query_year
		,
        ROUND(SUM(CASE 
					WHEN  YEAR(entry_date) = fy_year-1  AND `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND credit IS NULL THEN IFNULL(debit, 0)
					WHEN  YEAR(entry_date) = fy_year-1  AND `name` IN ('CURRENT LIABILITIES') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = fy_year-1  AND `name` IN ('CURRENT LIABILITIES') AND debit  IS NULL THEN IFNULL(credit, 0)
					WHEN  YEAR(entry_date) = fy_year-1  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = fy_year-1  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0 -- Avoid NULL values
					END), 2) AS Previous_year
		,
        ROUND((ROUND(SUM(CASE 
					WHEN  YEAR(entry_date) = fy_year  AND `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND credit IS NULL THEN IFNULL(debit, 0)
					WHEN  YEAR(entry_date) = fy_year  AND `name` IN ('CURRENT LIABILITIES') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = fy_year  AND `name` IN ('CURRENT LIABILITIES') AND debit  IS NULL THEN IFNULL(credit, 0)
					WHEN  YEAR(entry_date) = fy_year  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = fy_year  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0 -- Avoid NULL values
					END), 2)
		- ROUND(SUM(CASE 
					WHEN  YEAR(entry_date) = fy_year-1  AND `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND credit IS NULL THEN IFNULL(debit, 0)
					WHEN  YEAR(entry_date) = fy_year-1  AND `name` IN ('CURRENT LIABILITIES') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = fy_year-1  AND `name` IN ('CURRENT LIABILITIES') AND debit  IS NULL THEN IFNULL(credit, 0)
					WHEN  YEAR(entry_date) = fy_year-1  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = fy_year-1  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0 -- Avoid NULL values
					END), 2))/ROUND(SUM(CASE 
					WHEN  YEAR(entry_date) = fy_year  AND `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND credit IS NULL THEN IFNULL(debit, 0)
					WHEN  YEAR(entry_date) = fy_year  AND `name` IN ('CURRENT LIABILITIES') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = fy_year  AND `name` IN ('CURRENT LIABILITIES') AND debit  IS NULL THEN IFNULL(credit, 0)
					WHEN  YEAR(entry_date) = fy_year  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN  YEAR(entry_date) = fy_year  AND `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0 -- Avoid NULL values
					END), 2)*100,2) AS `YoY Growth(%)`
FROM 
	(SELECT CASE WHEN pl.statement_section != '' THEN pl.statement_section
		    ELSE bs.statement_section 
		    END AS `name`,
		a.account, a.account_id, a.account_code, jeli.line_item, a.postable,
		je.journal_entry, je.journal_entry_code, je.entry_date, bs.statement_section_id, bs.is_balance_sheet_section,
        jeli.debit, jeli.credit
	FROM journal_entry_line_item AS jeli
	LEFT JOIN	journal_entry AS je
		ON	jeli.journal_entry_id = je.journal_entry_id
	LEFT JOIN	`account` AS a
		ON	jeli.account_id = a.account_id
	LEFT JOIN	statement_section AS pl
		ON	a.profit_loss_section_id = pl.statement_section_id
	LEFT JOIN	statement_section AS bs
		ON	a.balance_sheet_section_id = bs.statement_section_id
	WHERE	je.debit_credit_balanced = 1 AND je.user_id != 0 AND je.cancelled = 0
		AND je.closing_type = 0
	) AS `all` -- master table alias 
Where is_balance_sheet_section = 1 -- Exclude P&L components
Group by `name`
Order by `name`
;

-- (3) Demostrate A = L + E; Line 273
SELECT  
		ROUND(SUM(CASE 
					WHEN `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND credit IS NULL THEN IFNULL(debit, 0)
					WHEN `name` IN ('CURRENT ASSETS', 'FIXED ASSETS') AND debit  IS NULL THEN IFNULL(credit, 0) * -1
					ELSE 0 -- Avoid NULL values
					END), 2) AS ASSETS,
		'=', -- add manual column
		ROUND(SUM(CASE 
					WHEN `name` IN ('CURRENT LIABILITIES') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN `name` IN ('CURRENT LIABILITIES') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0
					END), 2) AS LIABILITIES,
		'+',
		ROUND(SUM(CASE 
					WHEN `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND credit IS NULL THEN IFNULL(debit, 0) * -1
					WHEN `name` IN ('REVENUE', 'OTHER INCOME', 'COST OF GOODS AND SERVICES', 'OTHER EXPENSES', 'SELLING EXPENSES', 'INCOME TAX', 'EQUITY') AND debit  IS NULL THEN IFNULL(credit, 0)
					ELSE 0
					END), 2) AS EQUITY
FROM 
	(SELECT CASE WHEN pl.statement_section != '' THEN pl.statement_section
		    ELSE bs.statement_section 
		    END AS `name`,
		a.account, a.account_id, a.account_code, jeli.line_item, a.postable,
		je.journal_entry, je.journal_entry_code, je.entry_date, bs.statement_section_id, bs.is_balance_sheet_section,
        jeli.debit, jeli.credit
	FROM journal_entry_line_item AS jeli
	LEFT JOIN	journal_entry AS je
		ON	jeli.journal_entry_id = je.journal_entry_id
	LEFT JOIN	`account` AS a
		ON	jeli.account_id = a.account_id
	LEFT JOIN	statement_section AS pl
		ON	a.profit_loss_section_id = pl.statement_section_id
	LEFT JOIN	statement_section AS bs
		ON	a.balance_sheet_section_id = bs.statement_section_id
	WHERE	je.debit_credit_balanced = 1 AND je.user_id != 0 AND je.cancelled = 0
		AND je.closing_type = 0
		AND YEAR(je.entry_date) = fy_year -- Considering 2016 is an input variable; Change 2016 to fy_year
	) AS `all` -- master table alias 
;
	END$$

DELIMITER ; -- STOP RUN

-- Stored Procedure test; PUT Fiscal Year(2016) which has the most data also with previous year 
CALL H_Accounting.Trio4_bkim(2016); 
