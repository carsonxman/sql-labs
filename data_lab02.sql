-- СБРОС ДАННЫХ
TRUNCATE users, sellers, categories, products, stock,
         carts, cart_items, orders, order_items, payments,
         reviews, addresses, deliveries
RESTART IDENTITY CASCADE;

-- НАПОЛНЕНИЕ ДАННЫМИ (ЛР №2)

-- 1. Пользователи
INSERT INTO users (full_name, email, phone, role) VALUES
('Иван Петров',     'ivan@mail.ru',      '+79001112233', 'customer'),
('Мария Сидорова',  'maria@mail.ru',     '+79004445566', 'customer'),
('ООО ТехноМир',    'sales@technomir.ru','+78002003040', 'seller'),
('ООО Книголюб',    'info@knigolub.ru',  '+78005006070', 'seller'),
('Алексей Смирнов', 'alex@mail.ru',      '+79007778899', 'customer'),
('ООО СпортЛайн',   'sport@shop.ru',     '+78009001020', 'seller'),
('Елена Кузнецова', 'elena@mail.ru',     NULL,           'customer'),
('Дмитрий Волков',  'dmitry@mail.ru',    '+79003334455', 'customer');

-- 2. Продавцы
INSERT INTO sellers (user_id, store_name, description) VALUES
(3, 'ТехноМир',   'Электроника и гаджеты'),
(4, 'Книголюб',   'Книги и канцелярия'),
(6, 'СпортЛайн',  'Спортивные товары');

-- 3. Категории
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

-- 4. Товары (стартовые)
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

-- 5. Складские остатки
INSERT INTO stock (product_id, quantity) VALUES
(1, 50), (2, 20), (3, 15), (4, 30), (5, 100),
(6, 40), (7, 25), (8, 10), (9, 0),  (10, 35);

-- 6. Корзины и позиции
INSERT INTO carts (user_id) VALUES (1), (2), (5), (7), (8);

INSERT INTO cart_items (cart_id, product_id, quantity) VALUES
(1, 1, 1), (1, 4, 2),
(2, 5, 3),
(3, 2, 1),
(4, 7, 1), (4, 8, 1),
(5, 3, 1);

-- 7. Массово 1000+ товаров
INSERT INTO products (seller_id, category_id, title, price, is_active)
SELECT
    (random() * 2 + 1)::int,
    (random() * 9 + 1)::int,
    'Товар №' || g,
    (random() * 9000 + 1000)::numeric(12,2),
    (random() < 0.8)
FROM generate_series(11, 1100) AS g;

-- 8. Массово 1000 заказов
INSERT INTO orders (user_id, status, total_amount, created_at)
SELECT
    (random() * 7 + 1)::int,
    (ARRAY['created','paid','shipped','delivered','cancelled'])[(random()*4+1)::int],
    0,
    now() - (random() * interval '180 days')
FROM generate_series(1, 1000);

-- 9. Позиции заказов (без дубликатов)
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

-- 10. Обновление сумм заказов
UPDATE orders o
SET total_amount = COALESCE((
    SELECT SUM(oi.quantity * oi.unit_price)
    FROM order_items oi
    WHERE oi.order_id = o.id
), 0);

-- 11. Контроль количества строк
SELECT 'users'        AS table_name, COUNT(*) AS rows_count FROM users
UNION ALL SELECT 'sellers',     COUNT(*) FROM sellers
UNION ALL SELECT 'categories',  COUNT(*) FROM categories
UNION ALL SELECT 'products',    COUNT(*) FROM products
UNION ALL SELECT 'stock',       COUNT(*) FROM stock
UNION ALL SELECT 'carts',       COUNT(*) FROM carts
UNION ALL SELECT 'cart_items',  COUNT(*) FROM cart_items
UNION ALL SELECT 'orders',      COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;