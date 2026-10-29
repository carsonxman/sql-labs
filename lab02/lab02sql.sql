-- ЛАБОРАТОРНАЯ РАБОТА №2
-- Базовые SQL-запросы и фильтрация данных
-- База данных: marketplace (PostgreSQL)

-- РАЗДЕЛ 1. НАПОЛНЕНИЕ ТАБЛИЦ ТЕСТОВЫМИ ДАННЫМИ

-- 1.1. Пользователи 
INSERT INTO users (full_name, email, phone, role) VALUES
('Иван Петров',     'ivan@mail.ru',      '+79001112233', 'customer'),
('Мария Сидорова',  'maria@mail.ru',     '+79004445566', 'customer'),
('ООО ТехноМир',    'sales@technomir.ru','+78002003040', 'seller'),
('ООО Книголюб',    'info@knigolub.ru',  '+78005006070', 'seller'),
('Алексей Смирнов', 'alex@mail.ru',      '+79007778899', 'customer'),
('ООО СпортЛайн',   'sport@shop.ru',     '+78009001020', 'seller'),
('Елена Кузнецова', 'elena@mail.ru',     NULL,           'customer'),
('Дмитрий Волков',  'dmitry@mail.ru',    '+79003334455', 'customer');

--1.2. Продавцы 
INSERT INTO sellers (user_id, store_name, description) VALUES
(3, 'ТехноМир',   'Электроника и гаджеты'),
(4, 'Книголюб',   'Книги и канцелярия'),
(6, 'СпортЛайн',  'Спортивные товары');

-- 1.3. Категории (иерархия)
INSERT INTO categories (parent_id, name) VALUES
(NULL, 'Электроника'),
(NULL, 'Книги'),
(NULL, 'Спорт'),
(1,    'Смартфоны'),
(1,    'Ноутбуки'),
(1,    'Наушники'),
(2,    'Художественная литература'),
(2,    'Учебники'),
(3,    'Фитнес'),
(3,    'Велоспорт');

--1.4. Товары (стартовые) 
INSERT INTO products (seller_id, category_id, title, description, price, is_active) VALUES
(1, 4, 'Смартфон Galaxy A54',      '6.4", 128 ГБ',           34990.00, TRUE),
(1, 4, 'Смартфон iPhone 15',       '6.1", 128 ГБ',           79990.00, TRUE),
(1, 5, 'Ноутбук Lenovo IdeaPad',   '15.6", 16 ГБ RAM',       54990.00, TRUE),
(1, 6, 'Наушники Sony WH-1000XM5', 'Беспроводные, ANC',      29990.00, TRUE),
(2, 7, 'Роман «Мастер и Маргарита»','Булгаков М.А.',           890.00, TRUE),
(2, 8, 'Учебник «Базы данных»',    'Дейт К.',                2500.00, TRUE),
(3, 9, 'Гантели разборные 2×10 кг','Металл, обрезиненные',     4500.00, TRUE),
(3, 10,'Велосипед горный Stels',   '21 скорость, 26"',       18900.00, TRUE),
(1, 6, 'Наушники AirPods Pro 2',   'TWS, шумоподавление',     24990.00, FALSE),
(1, 4, 'Смартфон Xiaomi 13T',      '6.67", 256 ГБ',          42990.00, TRUE);

-- 1.5. Складские остатки
INSERT INTO stock (product_id, quantity) VALUES
(1, 50), (2, 20), (3, 15), (4, 30), (5, 100),
(6, 40), (7, 25), (8, 10), (9, 0),  (10, 35);

-- 1.6. Корзины 
INSERT INTO carts (user_id) VALUES (1), (2), (5), (7), (8);

-- 1.7. Позиции корзин
INSERT INTO cart_items (cart_id, product_id, quantity) VALUES
(1, 1, 1), (1, 4, 2),
(2, 5, 3),
(3, 2, 1),
(4, 7, 1), (4, 8, 1),
(5, 3, 1);

--1.8. Массовое заполнение товаров (1000+)
INSERT INTO products (seller_id, category_id, title, price, is_active)
SELECT
    (random() * 2 + 1)::int,
    (random() * 9 + 1)::int,
    'Товар №' || g,
    (random() * 9000 + 1000)::numeric(12,2),
    (random() < 0.8)
FROM generate_series(11, 1100) AS g;

-- 1.9. Массовое заполнение заказов (1000)
INSERT INTO orders (user_id, status, total_amount, created_at)
SELECT
    (random() * 7 + 1)::int,
    (ARRAY['created','paid','shipped','delivered','cancelled'])[(random()*4+1)::int],
    0,
    now() - (random() * interval '180 days')
FROM generate_series(1, 1000);

-- 1.10. Позиции заказов (без дубликатов) 
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT
    o.id                                AS order_id,
    p.id                                AS product_id,
    (random() * 3 + 1)::int             AS quantity,
    (random() * 9000 + 1000)::numeric(12,2) AS unit_price
FROM orders o
JOIN LATERAL (
    SELECT id FROM products ORDER BY random() LIMIT 2
) p ON TRUE
WHERE o.id <= 500;

-- 1.11. Пересчёт итоговых сумм заказов
UPDATE orders o
SET total_amount = COALESCE((
    SELECT SUM(oi.quantity * oi.unit_price)
    FROM order_items oi
    WHERE oi.order_id = o.id
), 0);

--  1.12. Контрольная сводка по количеству строк
SELECT 'users'        AS table_name, COUNT(*) AS rows_count FROM users
UNION ALL SELECT 'sellers',     COUNT(*) FROM sellers
UNION ALL SELECT 'categories',  COUNT(*) FROM categories
UNION ALL SELECT 'products',    COUNT(*) FROM products
UNION ALL SELECT 'stock',       COUNT(*) FROM stock
UNION ALL SELECT 'carts',       COUNT(*) FROM carts
UNION ALL SELECT 'cart_items',  COUNT(*) FROM cart_items
UNION ALL SELECT 'orders',      COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;


-- РАЗДЕЛ 2. ЗАПРОСЫ НА ВЫБОРКУ И ФИЛЬТРАЦИЮ

--  ЗАПРОС 1. DISTINCT с псевдонимами 
-- Назначение: уникальные категории, к которым привязаны активные товары
SELECT DISTINCT
    c.id              AS category_id,
    c.name            AS category_name
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
WHERE p.is_active = TRUE
ORDER BY category_name;

-- ЗАПРОС 2. AND / OR со скобками 
-- Назначение: активные товары категорий «Смартфоны» и «Ноутбуки» в диапазоне цен
SELECT
    p.title,
    p.price,
    c.name AS category
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
WHERE p.is_active = TRUE
  AND (c.name = 'Смартфоны' OR c.name = 'Ноутбуки')
  AND p.price BETWEEN 20000 AND 60000
ORDER BY p.price DESC;

--  ЗАПРОС 3. BETWEEN 
-- Назначение: товары средней ценовой категории (5000–30000)
SELECT title, price
FROM products
WHERE price BETWEEN 5000 AND 30000
ORDER BY price;

--  ЗАПРОС 4. IN 
-- Назначение: товары из конкретных категорий (Смартфоны, Ноутбуки, Наушники)
SELECT title, category_id, price
FROM products
WHERE category_id IN (4, 5, 6)
ORDER BY category_id, price;

-- ЗАПРОС 5. LIKE и ILIKE 
-- Назначение: поиск по названию без учёта регистра
SELECT title, price
FROM products
WHERE title ILIKE '%смартфон%';

-- Назначение: поиск по названию с учётом регистра
SELECT title
FROM products
WHERE title LIKE 'Наушники%';

-- ---------- ЗАПРОС 6. IS NULL и COALESCE ----------
-- Назначение: товары без описания
SELECT title, COALESCE(description, 'нет описания') AS descr
FROM products
WHERE description IS NULL;

-- Назначение: пользователи без телефона
SELECT full_name, email, COALESCE(phone, 'не указан') AS phone
FROM users
WHERE phone IS NULL;

-- ЗАПРОС 7. ORDER BY по двум столбцам 
-- Назначение: активные товары — по цене убыв., при равенстве — по названию возр.
SELECT title, price, is_active
FROM products
WHERE is_active = TRUE
ORDER BY price DESC, title ASC
LIMIT 15;

-- ЗАПРОС 8. LIMIT и OFFSET (постраничный вывод) 
-- Страница 1
SELECT title, price
FROM products
WHERE is_active = TRUE
ORDER BY id
LIMIT 10 OFFSET 0;

-- Страница 2
SELECT title, price
FROM products
WHERE is_active = TRUE
ORDER BY id
LIMIT 10 OFFSET 10;

-- Страница 3
SELECT title, price
FROM products
WHERE is_active = TRUE
ORDER BY id
LIMIT 10 OFFSET 20;

--  ЗАПРОС 9 (дополнительный). Топ-5 самых дорогих 
SELECT title, price
FROM products
WHERE is_active = TRUE
ORDER BY price DESC
LIMIT 5;

-- ЗАПРОС 10 (дополнительный). Товары с нулевым остатком 
SELECT p.title, s.quantity
FROM products p
JOIN stock s ON s.product_id = p.id
WHERE s.quantity = 0;


-- РАЗДЕЛ 3. СЛУЖЕБНОЕ: ОЧИСТКА (использовать только при перезапуске)
-- TRUNCATE users, sellers, categories, products, stock,
--          carts, cart_items, orders, order_items, payments,
--          reviews, addresses, deliveries
-- RESTART IDENTITY CASCADE;