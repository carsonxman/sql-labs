-- ====================================================================
-- ЛАБОРАТОРНАЯ РАБОТА №3
-- Тема: Многотабличные запросы и аналитические представления
-- ====================================================================

-- ====================================================================
-- РАЗДЕЛ 1. ВНУТРЕННЕЕ СОЕДИНЕНИЕ НЕ МЕНЕЕ ТРЕХ ТАБЛИЦ (INNER JOIN)
-- Задание 1: Запрос соединяет таблицы: товары (products), категории 
-- (categories), магазины-продавцы (sellers) и пользователей (users).
-- Назначение: подробный каталог активных товаров с указанием названия, 
-- категории, магазина продавца, его email и стоимости.
-- ====================================================================

SELECT 
    p.id           AS product_id,
    p.title        AS product_title,
    c.name         AS category_name,
    s.store_name   AS seller_store,
    u.email        AS seller_email,
    p.price,
    p.is_active
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
JOIN sellers    AS s ON s.id = p.seller_id
JOIN users      AS u ON u.id = s.user_id
WHERE p.is_active = TRUE
ORDER BY p.price DESC
LIMIT 10;


-- ====================================================================
-- РАЗДЕЛ 2. ЛЕВОЕ ВНЕШНЕЕ СОЕДИНЕНИЕ (LEFT JOIN) И ПОИСК НЕСООТВЕТСТВИЙ
-- Задание 2: Запрос с LEFT JOIN, показывающий строки без соответствий 
-- в связанной таблице (Anti-Join шаблон: LEFT JOIN ... WHERE right_table.id IS NULL).
-- Назначение: выборка активных товаров, на которые покупатели еще не оставили 
-- ни одного отзыва (для отдела маркетинга и запуска акций со сбором отзывов).
-- ====================================================================

SELECT 
    p.id           AS product_id,
    p.title        AS product_title,
    c.name         AS category_name,
    p.price,
    r.id           AS review_id
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
LEFT JOIN reviews AS r ON r.product_id = p.id
WHERE r.id IS NULL
ORDER BY p.id ASC
LIMIT 10;


-- ====================================================================
-- РАЗДЕЛ 3. ГРУППИРОВКА И АГРЕГАЦИЯ (GROUP BY)
-- Задание 3: Запрос с группировкой и агрегацией по каждой категории:
-- подсчет количества товаров, средней, минимальной и максимальной цены.
-- Назначение: комплексный срез товарной матрицы маркетплейса по категориям.
-- ====================================================================

SELECT 
    c.id                                 AS category_id,
    c.name                               AS category_name,
    COUNT(p.id)                          AS products_count,
    ROUND(COALESCE(AVG(p.price), 0), 2)  AS avg_price,
    COALESCE(MIN(p.price), 0)            AS min_price,
    COALESCE(MAX(p.price), 0)            AS max_price
FROM categories AS c
LEFT JOIN products AS p ON p.category_id = c.id AND p.is_active = TRUE
GROUP BY c.id, c.name
ORDER BY products_count DESC, c.name ASC;


-- ====================================================================
-- РАЗДЕЛ 4. ФИЛЬТРАЦИЯ ГРУПП С ПОМОЩЬЮ СЕКЦИИ HAVING
-- Задание 4: Применение секции HAVING для фильтрации результатов агрегации.
-- Назначение: отбор ведущих магазинов, суммарная выручка которых 
-- по успешным заказам (без отмененных) превышает 3 000 000 рублей.
-- ====================================================================

SELECT 
    s.id                                          AS seller_id,
    s.store_name,
    COUNT(DISTINCT o.id)                          AS orders_count,
    SUM(oi.quantity)                              AS total_items_sold,
    ROUND(SUM(oi.quantity * oi.unit_price), 2)    AS total_revenue
FROM sellers AS s
JOIN products AS p     ON p.seller_id = s.id
JOIN order_items AS oi ON oi.product_id = p.id
JOIN orders AS o       ON o.id = oi.order_id
WHERE o.status != 'cancelled'
GROUP BY s.id, s.store_name
HAVING SUM(oi.quantity * oi.unit_price) > 3000000.00
ORDER BY total_revenue DESC;


-- ====================================================================
-- РАЗДЕЛ 5. ПОДЗАПРОСЫ (СКАЛЯРНЫЙ, С IN, С EXISTS)
-- Задание 5: Написать по одному запросу каждого вида подзапросов.
-- ====================================================================

-- 5.1. Скалярный подзапрос
-- Назначение: отбор премиальных товаров, цена которых превышает 
-- среднюю цену активных товаров всего маркетплейса, с расчетом отклонения от средней.
SELECT 
    p.id                                                               AS product_id,
    p.title                                                            AS product_title,
    p.price,
    ROUND((SELECT AVG(price) FROM products WHERE is_active = TRUE), 2) AS market_avg_price,
    ROUND(p.price - (SELECT AVG(price) FROM products WHERE is_active = TRUE), 2) AS diff_from_avg
FROM products AS p
WHERE p.is_active = TRUE
  AND p.price > (SELECT AVG(price) FROM products WHERE is_active = TRUE)
ORDER BY p.price DESC
LIMIT 10;

-- 5.2. Подзапрос с предикатом IN
-- Назначение: определение покупателей (users), оформлявших заказы на 
-- дорогостоящую электронику («Смартфоны», «Ноутбуки»).
SELECT 
    u.id        AS user_id,
    u.full_name,
    u.email,
    u.phone
FROM users AS u
WHERE u.id IN (
    SELECT o.user_id
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.id
    JOIN products AS p     ON p.id = oi.product_id
    WHERE p.category_id IN (
        SELECT c.id 
        FROM categories AS c 
        WHERE c.name IN ('Смартфоны', 'Ноутбуки')
    )
)
ORDER BY u.id ASC;

-- 5.3. Подзапрос с предикатом EXISTS (коррелированный)
-- Назначение: поиск магазинов-продавцов, у которых есть хотя бы один 
-- товар с нулевым складским остатком (требуется срочная допоставка).
SELECT 
    s.id         AS seller_id,
    s.store_name,
    s.description
FROM sellers AS s
WHERE EXISTS (
    SELECT 1
    FROM products AS p
    JOIN stock AS st ON st.product_id = p.id
    WHERE p.seller_id = s.id
      AND st.quantity = 0
);


-- ====================================================================
-- РАЗДЕЛ 6. ОБЩИЕ ТАБЛИЧНЫЕ ВЫРАЖЕНИЯ (CTE)
-- Задание 6: CTE для пошаговой аналитики и рекурсивный CTE для обхода дерева.
-- ====================================================================

-- 6.1. Обычный многоэтапный CTE
-- Назначение: расчет финансовых показателей каждого продавца и вычисление 
-- их процентной рыночной доли (market share %) в суммарном товарообороте площадки.
WITH seller_revenue AS (
    SELECT 
        s.id                                          AS seller_id,
        s.store_name,
        COUNT(DISTINCT o.id)                          AS orders_count,
        COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS revenue
    FROM sellers AS s
    JOIN products AS p     ON p.seller_id = s.id
    JOIN order_items AS oi ON oi.product_id = p.id
    JOIN orders AS o       ON o.id = oi.order_id
    WHERE o.status != 'cancelled'
    GROUP BY s.id, s.store_name
),
total_market AS (
    SELECT SUM(revenue) AS total_revenue 
    FROM seller_revenue
)
SELECT 
    sr.seller_id,
    sr.store_name,
    sr.orders_count,
    ROUND(sr.revenue, 2) AS revenue,
    ROUND((sr.revenue / NULLIF(tm.total_revenue, 0)) * 100, 2) AS market_share_pct
FROM seller_revenue AS sr
CROSS JOIN total_market AS tm
ORDER BY sr.revenue DESC;

-- 6.2. Рекурсивный CTE для обхода иерархического каталога категорий
-- Назначение: рекурсивный обход дерева категорий сверху вниз:
-- расчет глубины вложенности (level) и формирование полного пути (full_path).
WITH RECURSIVE category_hierarchy AS (
    -- Базовая (анкерная) часть: корневые категории каталога
    SELECT 
        c.id,
        c.parent_id,
        c.name,
        1 AS level,
        c.name::TEXT AS full_path
    FROM categories AS c
    WHERE c.parent_id IS NULL

    UNION ALL

    -- Рекурсивная часть: дочерние подкатегории
    SELECT 
        c.id,
        c.parent_id,
        c.name,
        ch.level + 1 AS level,
        (ch.full_path || ' -> ' || c.name)::TEXT AS full_path
    FROM categories AS c
    JOIN category_hierarchy AS ch ON ch.id = c.parent_id
)
SELECT 
    id AS category_id,
    REPEAT('   ', level - 1) || '• ' || name AS visual_tree,
    level,
    full_path
FROM category_hierarchy
ORDER BY full_path;


-- ====================================================================
-- РАЗДЕЛ 7. ПРЕДСТАВЛЕНИЯ (VIEW)
-- Задание 7: Создание не менее двух аналитических представлений 
-- и демонстрация обращения к ним с фильтрацией и сортировкой.
-- ====================================================================

-- 7.1. Представление 1: Сводная витрина товарного каталога
CREATE OR REPLACE VIEW v_product_catalog_details AS
SELECT 
    p.id                                   AS product_id,
    p.title                                AS product_name,
    c.name                                 AS category_name,
    s.store_name                           AS seller_name,
    p.price,
    p.is_active,
    COALESCE(st.quantity, 0)               AS stock_quantity,
    COUNT(r.id)                            AS reviews_count,
    ROUND(COALESCE(AVG(r.score), 0), 1)    AS avg_rating
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
JOIN sellers AS s    ON s.id = p.seller_id
LEFT JOIN stock AS st ON st.product_id = p.id
LEFT JOIN reviews AS r ON r.product_id = p.id
GROUP BY p.id, p.title, c.name, s.store_name, p.price, p.is_active, st.quantity;

-- Демонстрация обращения к представлению 1:
-- Топ-10 активных товаров в наличии с сортировкой по рейтингу и цене
SELECT 
    product_id, 
    product_name, 
    category_name, 
    seller_name, 
    price, 
    stock_quantity, 
    avg_rating
FROM v_product_catalog_details
WHERE is_active = TRUE 
  AND stock_quantity > 0
ORDER BY avg_rating DESC, price DESC
LIMIT 10;


-- 7.2. Представление 2: Сводная витрина эффективности продавцов (KPI)
CREATE OR REPLACE VIEW v_seller_performance_summary AS
SELECT 
    s.id                                                               AS seller_id,
    s.store_name,
    COUNT(DISTINCT p.id)                                               AS total_products,
    COUNT(DISTINCT o.id)                                               AS completed_orders_count,
    COALESCE(SUM(oi.quantity), 0)                                      AS total_units_sold,
    ROUND(COALESCE(SUM(oi.quantity * oi.unit_price), 0), 2)           AS total_revenue,
    ROUND(COALESCE(SUM(oi.quantity * oi.unit_price) / NULLIF(COUNT(DISTINCT o.id), 0), 0), 2) AS avg_order_value
FROM sellers AS s
LEFT JOIN products AS p     ON p.seller_id = s.id
LEFT JOIN order_items AS oi ON oi.product_id = p.id
LEFT JOIN orders AS o       ON o.id = oi.order_id AND o.status IN ('paid', 'shipped', 'delivered')
GROUP BY s.id, s.store_name;

-- Демонстрация обращения к представлению 2:
-- Управленческий рейтинг магазинов маркетплейса по совокупной выручке
SELECT 
    seller_id,
    store_name,
    total_products,
    completed_orders_count,
    total_units_sold,
    total_revenue,
    avg_order_value
FROM v_seller_performance_summary
ORDER BY total_revenue DESC;
