/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Сабурова Кристина
 * Дата: 12.11.2024
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT (id) AS total_players, -- Общее количество зарегистрированных игроков
       SUM(CASE WHEN payer = '1' THEN 1 ELSE 0 END) AS paying_players, -- Количество платящих игроков
       ROUND(SUM(CASE WHEN payer = '1' THEN 1 ELSE 0 END)::decimal / COUNT (id), 2) AS ratio -- Доля платящих игроков
FROM fantasy.users

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT 
    r.race, 
    COUNT(u.id) AS total_players, -- Общее количество игроков данной расы
    SUM(CASE WHEN u.payer = '1' THEN 1 ELSE 0 END) AS paying_players, -- Количество платящих игроков
    ROUND(AVG(CASE WHEN u.payer = '1' THEN 1.0 ELSE 0 END), 4) AS ratio -- Доля платящих игроков
FROM fantasy.users u
JOIN fantasy.race r ON u.race_id = r.race_id
WHERE u.payer IN ('0', '1')
GROUP BY r.race
ORDER BY paying_players DESC 

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(amount) AS total_amount,
       SUM(amount) AS sum_amount,
       MIN(amount) AS min_amount,
       MAX(amount) AS max_amount,
       AVG(amount) AS avg_amount,
       PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY amount) AS median_amount,
       STDDEV(amount) AS stdev_amount
FROM fantasy.events

-- 2.2: Аномальные нулевые покупки:
SELECT 
    COUNT(*) AS total_transactions, -- Общее количество покупок
    COUNT(*) FILTER (WHERE amount = 0) AS zero_transactions, -- Количество покупок за 0 у.е.
    ROUND(COUNT(*) FILTER (WHERE amount = 0) * 100.0 / COUNT(*), 2) AS zero_percentage -- Доля нулевых покупок
FROM fantasy.events

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
WITH player_purchases AS (
    SELECT 
        e.id,
        u.payer,
        COUNT(*) AS total_purchases, -- Общее количество покупок (исключая нулевые)
        SUM(e.amount) AS total_amount -- Суммарная стоимость покупок (исключая нулевые)
    FROM fantasy.events AS e
    JOIN fantasy.users AS u ON e.id = u.id
    WHERE e.amount > 0 -- Исключаем покупки с нулевой стоимостью
    GROUP BY e.id, u.payer
)
SELECT 
    payer, -- Платящие 1, неплатящие 0
    COUNT(id) AS player_count, -- Количество игроков в каждой группе
    AVG(total_purchases) AS avg_purchases_per_player, -- Среднее количество покупок на игрока
    AVG(total_amount) AS avg_total_amount_per_player -- Средняя суммарная стоимость покупок на игрока
FROM player_purchases
GROUP BY payer

-- 2.4: Популярные эпические предметы:
WITH item_sales AS (
    SELECT game_items AS item_name,
           COUNT(transaction_id) AS total_sales, 
           COUNT(DISTINCT id) AS unique_buyers
    FROM fantasy.events
    JOIN fantasy.items USING(item_code)
    GROUP BY game_items),
total_sales AS (
    SELECT SUM(total_sales) AS total_all_sales --общее количество покупок
    FROM item_sales),
player_count AS (
    SELECT COUNT(DISTINCT id) AS total_players 
    FROM fantasy.users)
SELECT 
    item_sales.item_name,
    item_sales.total_sales,
    ROUND(item_sales.total_sales * 100.0 / total_sales.total_all_sales, 2) AS sales_percentage, --Относительное значение: доля продаж каждого предмета от всех продаж
    ROUND(item_sales.unique_buyers * 100.0 / player_count.total_players, 2) AS player_percentage -- Доля игроков хотя бы раз покупали предмет
FROM item_sales, total_sales, player_count
ORDER BY item_sales.unique_buyers DESC

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- 1. Считаем общее количество зарегистрированных игроков для каждой расы
WITH race_players AS (
    SELECT race AS race_name,
           COUNT(DISTINCT id) AS total_players -- Общее количество зарегистрированных игроков данной расы
    FROM fantasy.users
    JOIN fantasy.race USING (race_id)
    GROUP BY race),
-- 2. Количество игроков, совершивших покупку, и долю платящих игроков среди них
purchase AS (
    SELECT r.race AS race_name,
           COUNT(DISTINCT e.id) AS purchasing_players, -- Количество игроков, совершивших хотя бы одну покупку
           COUNT(DISTINCT CASE WHEN u.payer = 1 THEN e.id END) AS paying_players -- Количество платящих игроков
    FROM fantasy.events AS e
    JOIN fantasy.users AS u ON e.id = u.id
    JOIN fantasy.race AS r ON u.race_id = r.race_id
    WHERE e.amount > 0
    GROUP BY r.race),
-- 3. Считаем информацию об активности игроков (покупки и выручка)
stats_active AS (
    SELECT r.race AS race_name,
           COUNT(e.transaction_id) AS total_purchases, -- Общее количество покупок
           SUM(e.amount) AS total_revenue -- Общая сумма покупок
    FROM fantasy.events AS e
    JOIN fantasy.users AS u ON e.id = u.id
    JOIN fantasy.race AS r ON u.race_id = r.race_id
    WHERE e.amount > 0
    GROUP BY r.race)
-- Итоговый запрос
SELECT 
    tp.race_name,
    tp.total_players, -- Общее количество зарегистрированных игроков
    pp.purchasing_players AS purchasing_players, -- Количество игроков, совершивших покупку
    ROUND(pp.purchasing_players * 100.0 / tp.total_players, 2) AS purchasing_rate, -- Доля игроков, совершающих покупки
    pp.paying_players AS paying_players, -- Количество платящих игроков
    ROUND(pp.paying_players * 100.0 / pp.purchasing_players, 2) AS paying_rate, -- Доля платящих среди тех, кто совершил покупку
    ROUND(act.total_purchases * 1.0 / pp.purchasing_players, 2) AS avg_purchases_per_player, -- Среднее количество покупок на одного игрока
    act.total_revenue * 1.0 / act.total_purchases::NUMERIC AS avg_purchase_cost, -- Средняя стоимость одной покупки на одного игрока
    act.total_revenue * 1.0 / pp.purchasing_players::numeric AS avg_total_revenue_per_player -- Средняя суммарная стоимость всех покупок на одного игрока
FROM race_players AS tp
LEFT JOIN purchase AS pp ON tp.race_name = pp.race_name
LEFT JOIN stats_active AS act ON tp.race_name = act.race_name
ORDER BY tp.race_name

