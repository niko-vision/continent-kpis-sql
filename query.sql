
WITH 
-- Sessions per continent
sessions_data AS (
 SELECT sp.continent,
        sp.ga_session_id
  FROM `DA.session_params` sp
  ),

-- Aggregate sessions (1 row per continent)
sessions_by_continent AS (
 SELECT continent,
        COUNT(DISTINCT ga_session_id) session_cnt
  FROM sessions_data
  GROUP BY continent
  ),

-- Accounts with continent + verification flag
accounts_data AS (
 SELECT sp.continent, ac.id, ac.is_verified
   FROM `DA.account` ac
   JOIN `DA.account_session` acs
       ON ac.id = acs.account_id
   JOIN `DA.session_params` sp
       ON sp.ga_session_id = acs.ga_session_id
  ),

-- Accounts per continent + verified accounts count
accounts_by_continent AS (
 SELECT continent, 
        COUNT(DISTINCT id) AS account_count,
        COUNT(DISTINCT 
         CASE 
            WHEN is_verified = 1 
            THEN id 
         END
        ) AS verified_account
   FROM accounts_data
   GROUP BY continent
  ),

-- Revenue rows with continent and device
revenue_data AS (
  SELECT sp.continent,
         p.price,
         sp.device
   FROM `DA.order` o
   JOIN `DA.product` p
       ON o.item_id = p.item_id
   JOIN `DA.session_params` sp
       ON o.ga_session_id = sp.ga_session_id
  ),
-- Revenue per continent with split by device
revenue_by_continent AS (
 SELECT continent, 
        SUM(price) AS total_revenue,
        SUM(CASE WHEN device = 'mobile' THEN price ELSE 0 END) AS revenue_mobile,
        SUM(CASE WHEN device = 'desktop' THEN price ELSE 0 END) AS revenue_desktop
   FROM revenue_data
   GROUP BY continent
  ),

-- Add total revenue across all continents (for % share)
total_revenue_t AS (
  SELECT continent,
         total_revenue,
         revenue_mobile,
         revenue_desktop,
         SUM(total_revenue) OVER() AS total_revenue_all
   FROM revenue_by_continent)


SELECT sbc.continent AS continent,
       ROUND(total_revenue, 2) AS revenue,
       ROUND(revenue_mobile,2) AS revenue_from_mobile,
       ROUND(revenue_desktop,2) AS revenue_from_desktop,
       ROUND(CASE
                WHEN total_revenue_all = 0 THEN 0
                ELSE total_revenue / total_revenue_all * 100
             END
       ,2) AS revenue_from_total,
       account_count,
       verified_account,
       session_cnt AS session_count
 FROM sessions_by_continent sbc
 LEFT JOIN total_revenue_t trt
     ON sbc.continent = trt.continent
 LEFT JOIN accounts_by_continent abc
     ON  sbc.continent = abc.continent
 ORDER BY revenue DESC
