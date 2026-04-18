-- ============================================================================
-- CULTFIT STORE E-COMMERCE DATABASE — PRODUCTION SCHEMA
-- DBMS Course Project | MySQL 8.0+
-- Designed for premium gym-focused platform with deep taxation features
-- ============================================================================

CREATE DATABASE IF NOT EXISTS ecommerce_db;
USE ecommerce_db;

-- Drop tables in reverse-dependency order for clean re-runs
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS admin_logs;
DROP TABLE IF EXISTS order_feedback;
DROP TABLE IF EXISTS order_tracking;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS wishlist;
DROP TABLE IF EXISTS cart;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS addresses;
DROP TABLE IF EXISTS product_images;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS coupons;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- TABLE 1: users
-- ============================================================================
CREATE TABLE users (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    full_name       VARCHAR(100)    NOT NULL,
    email           VARCHAR(150)    NOT NULL UNIQUE,
    phone           VARCHAR(15),
    password_hash   VARCHAR(255)    NOT NULL,
    role            ENUM('customer', 'admin') DEFAULT 'customer',
    is_active       BOOLEAN         DEFAULT TRUE,
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_users_email (email),
    INDEX idx_users_phone (phone),
    INDEX idx_users_role  (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE 2: categories
-- ============================================================================
CREATE TABLE categories (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL UNIQUE,
    slug            VARCHAR(120)    NOT NULL UNIQUE,
    description     TEXT,
    image_url       VARCHAR(500),
    parent_id       INT             DEFAULT NULL,
    is_active       BOOLEAN         DEFAULT TRUE,
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL,
    INDEX idx_cat_slug   (slug),
    INDEX idx_cat_parent (parent_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE 3: products
-- Enhanced with Gym-specific traits: product_brand, product_type, tax features
-- ============================================================================
CREATE TABLE products (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    title           VARCHAR(255)    NOT NULL,
    description     TEXT,
    price           DECIMAL(10,2)   NOT NULL,
    discount_price  DECIMAL(10,2)   DEFAULT NULL,
    stock           INT             DEFAULT 0,
    category_id     INT             NOT NULL,
    product_brand   VARCHAR(100),
    product_type    ENUM('supplement', 'equipment') NOT NULL,
    tax_percentage  DECIMAL(5,2)    DEFAULT 18.00,
    gst_applied     BOOLEAN         DEFAULT TRUE,
    sku             VARCHAR(50)     UNIQUE,
    weight_grams    INT,
    is_active       BOOLEAN         DEFAULT TRUE,
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE RESTRICT,
    INDEX idx_prod_category (category_id),
    INDEX idx_prod_price    (price),
    INDEX idx_prod_brand    (product_brand),
    INDEX idx_prod_type     (product_type),
    INDEX idx_prod_active   (is_active),
    FULLTEXT INDEX ft_prod_search (title, description)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================================
-- TABLE 4: product_images
-- ============================================================================
CREATE TABLE product_images (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    product_id      INT             NOT NULL,
    image_url       VARCHAR(500)    NOT NULL,
    alt_text        VARCHAR(255),
    is_primary      BOOLEAN         DEFAULT FALSE,
    sort_order      INT             DEFAULT 0,

    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    INDEX idx_pimg_product (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE 5: addresses
-- ============================================================================
CREATE TABLE addresses (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT             NOT NULL,
    label           VARCHAR(50)     DEFAULT 'Home',
    recipient_name  VARCHAR(100)    NOT NULL,
    phone           VARCHAR(15)     NOT NULL,
    address_line1   VARCHAR(255)    NOT NULL,
    address_line2   VARCHAR(255),
    landmark        VARCHAR(150),
    city            VARCHAR(100)    NOT NULL,
    state           VARCHAR(100)    NOT NULL,
    pin_code        CHAR(6)         NOT NULL,
    is_default      BOOLEAN         DEFAULT FALSE,
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_addr_user    (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE 6: coupons
-- ============================================================================
CREATE TABLE coupons (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    code            VARCHAR(50),
    discount_type   VARCHAR(20),
    value           INT,
    expiry_date     DATE,
    usage_limit     INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================================
-- TABLE 7: cart
-- Cart is updated dynamically using APIs, but we store tax calculations later in Views
-- ============================================================================
CREATE TABLE cart (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT             NOT NULL,
    product_id      INT             NOT NULL,
    quantity        INT             NOT NULL DEFAULT 1 CHECK (quantity >= 1),
    added_at        TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    UNIQUE KEY uk_cart_user_product (user_id, product_id),
    INDEX idx_cart_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================================
-- TABLE 8: wishlist
-- ============================================================================
CREATE TABLE wishlist (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT             NOT NULL,
    product_id      INT             NOT NULL,
    added_at        TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    UNIQUE KEY uk_wish_user_product (user_id, product_id),
    INDEX idx_wish_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================================
-- TABLE 9: orders
-- Orders table enhanced to explicitly store tax paid
-- ============================================================================
CREATE TABLE orders (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT             NOT NULL,
    address_id      INT             NOT NULL,
    coupon_id       INT             DEFAULT NULL,
    subtotal        DECIMAL(10,2)   NOT NULL,
    tax_amount      DECIMAL(10,2)   DEFAULT 0.00,
    discount_amount DECIMAL(10,2)   DEFAULT 0.00,
    shipping_fee    DECIMAL(10,2)   DEFAULT 0.00,
    total_price     DECIMAL(10,2)   NOT NULL,
    status          ENUM('Pending', 'Confirmed', 'Processing', 'Shipped',
                         'Out for Delivery', 'Delivered', 'Cancelled', 'Returned')
                    DEFAULT 'Pending',
    notes           TEXT,
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id)   REFERENCES users(id)     ON DELETE CASCADE,
    FOREIGN KEY (address_id) REFERENCES addresses(id) ON DELETE RESTRICT,
    FOREIGN KEY (coupon_id) REFERENCES coupons(id)    ON DELETE SET NULL,
    INDEX idx_order_user   (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================================
-- TABLE 10: order_items
-- Includes individual tax amount calculation
-- ============================================================================
CREATE TABLE order_items (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    order_id        INT             NOT NULL,
    product_id      INT             NOT NULL,
    quantity        INT             NOT NULL CHECK (quantity >= 1),
    unit_price      DECIMAL(10,2)   NOT NULL,
    tax_percentage  DECIMAL(5,2)    DEFAULT 0.00,
    tax_amount      DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    total_price     DECIMAL(10,2)   GENERATED ALWAYS AS (quantity * unit_price + tax_amount) STORED,

    FOREIGN KEY (order_id)   REFERENCES orders(id)   ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id)  ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE 11: payments
-- ============================================================================
CREATE TABLE payments (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    order_id        INT             NOT NULL,
    payment_method  ENUM('COD', 'UPI', 'Credit Card', 'Debit Card', 'Net Banking', 'Wallet')
                    NOT NULL DEFAULT 'COD',
    transaction_id  VARCHAR(100),
    upi_id          VARCHAR(100),
    amount          DECIMAL(10,2)   NOT NULL,
    status          ENUM('Pending', 'Success', 'Failed', 'Refunded') DEFAULT 'Pending',
    paid_at         DATETIME        DEFAULT NULL,
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE 12: order_tracking
-- ============================================================================
CREATE TABLE order_tracking (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    order_id        INT             NOT NULL,
    status          VARCHAR(100)    NOT NULL,
    location        VARCHAR(200),
    description     TEXT,
    tracked_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE 13: order_feedback
-- ============================================================================
CREATE TABLE order_feedback (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    order_id        INT             NOT NULL UNIQUE,
    user_id         INT             NOT NULL,
    rating          TINYINT         NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment         TEXT,
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id)  REFERENCES users(id)  ON DELETE CASCADE,
    INDEX idx_feedback_order (order_id),
    INDEX idx_feedback_user  (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE 14: reviews
-- ============================================================================
CREATE TABLE reviews (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    product_id      INT             NOT NULL,
    user_id         INT             NOT NULL,
    rating          TINYINT         NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title           VARCHAR(200),
    comment         TEXT,
    is_verified     BOOLEAN         DEFAULT FALSE,
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id)    REFERENCES users(id)     ON DELETE CASCADE,
    UNIQUE KEY uk_review_user_product (user_id, product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================================
-- TABLE 15: admin_logs
-- ============================================================================
CREATE TABLE admin_logs (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    admin_id        INT             NOT NULL,
    action          VARCHAR(100)    NOT NULL,
    entity_type     VARCHAR(50),
    entity_id       INT,
    details         TEXT,
    ip_address      VARCHAR(45),
    performed_at    TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================================
-- ========================  CULTFIT SAMPLE DATA ==============================
-- ============================================================================

-- ----- USERS -----
INSERT INTO users (full_name, email, phone, password_hash, role) VALUES
('Pratham Gym Bro',  'pratham@gym.com',       '+919876543210', '$2b$10$xJQkR5Vz0GNdW2HpYqTmF.hashedpassword1', 'admin'),
('Rahul Fitness',    'rahul.fit@gym.com',     '+919123456789', '$2b$10$xJQkR5Vz0GNdW2HpYqTmF.hashedpassword2', 'customer');

-- ----- COUPONS -----
INSERT INTO coupons (code, discount_type, value, expiry_date, usage_limit) VALUES
('SAVE10', 'percentage', 10, DATE_ADD(NOW(), INTERVAL 30 DAY), 100),
('FIRST50', 'flat', 50, DATE_ADD(NOW(), INTERVAL 30 DAY), 100),
('FREESHIP', 'freeship', 100, DATE_ADD(NOW(), INTERVAL 30 DAY), 100);

-- ----- CATEGORIES -----
INSERT INTO categories (id, name, slug, description, image_url) VALUES
(1, 'Protein Powder',     'protein-powder',    'Whey, Casein & Blends',               'https://images.unsplash.com/photo-1579722820308-d74e571900a9?w=600'),
(2, 'Mass Gainer',        'mass-gainer',       'High calorie mass gainers',           'https://images.unsplash.com/photo-1593095948071-474c5cc2989d?w=600'),
(3, 'Creatine',           'creatine',          'Pure Creatine Monohydrate',           'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=600'),
(4, 'Pre-workout',        'pre-workout',       'Energy boost for heavy lifting',      'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=600'),
(5, 'Vegan Supplements',  'vegan-supplements', 'Plant based nutrition',             'https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?w=600'),
(6, 'Fitness Equipment',  'fitness-equipment', 'Dumbbells, Weights, Accessories',   'https://images.unsplash.com/photo-1584735935682-2f2b69dff9d2?w=600');

-- ----- PRODUCTS (15 REAL GYM PRODUCTS) -----
INSERT INTO products (title, description, price, discount_price, category_id, product_brand, product_type, tax_percentage, stock) VALUES
-- Protein
('MuscleBlaze Biozyme Whey Protein', 'India’s first clinically tested Whey Protein for 50% higher protein absorption.', 3199.00, 2899.00, 1, 'MuscleBlaze', 'supplement', 18.00, 50),
('Optimum Nutrition (ON) Gold Standard 100% Whey', 'World’s Best-Selling Whey Protein Powder.', 3699.00, 3299.00, 1, 'Optimum Nutrition', 'supplement', 18.00, 30),
('BigMuscles Nutrition Premium Gold Whey', '25g protein per serving with whey isolate and concentrate blend.', 1999.00, 1699.00, 1, 'BigMuscles', 'supplement', 18.00, 100),
('Asitis Nutrition Atom Whey Protein', 'Affordable and pure unflavored whey protein.', 1899.00, 1599.00, 1, 'Asitis', 'supplement', 18.00, 45),

-- Mass Gainer
('MuscleBlaze Super Gainer XXL', 'High calorie mass gainer with complex carbs and protein.', 1399.00, 1199.00, 2, 'MuscleBlaze', 'supplement', 18.00, 20),
('Labrada Muscle Mass Gainer', '1200+ calories per serving for serious mass gains.', 2699.00, 2399.00, 2, 'Labrada', 'supplement', 18.00, 15),

-- Creatine
('MuscleBlaze Creatine Monohydrate', '100% Pure Creatine for strength and endurance.', 999.00, 799.00, 3, 'MuscleBlaze', 'supplement', 18.00, 80),
('ON Micronized Creatine Powder', '5g pure creatine monohydrate per serving.', 1499.00, 1299.00, 3, 'Optimum Nutrition', 'supplement', 18.00, 40),

-- Pre-workout
('Cellucor C4 Original Pre Workout', 'Explosive energy and performance pre-workout powder.', 2499.00, 1999.00, 4, 'Cellucor', 'supplement', 18.00, 25),
('MuscleBlaze PRE Workout 300', 'Advanced formula with 300mg caffeine.', 1199.00, 899.00, 4, 'MuscleBlaze', 'supplement', 18.00, 60),

-- Vegan
('Plix Plant Protein', 'Vegan protein blend with pea and brown rice.', 1699.00, 1499.00, 5, 'Plix', 'supplement', 18.00, 35),
('Fast&Up Plant Protein Isolate', 'Premium plant-based complete amino acid profile.', 2199.00, 1899.00, 5, 'Fast&Up', 'supplement', 18.00, 20),

-- Equipment
('Cult.fit Adjustable Dumbbells 20kg', 'Premium adjustable dumbbells set for home gym.', 4999.00, 3999.00, 6, 'Cult.fit', 'equipment', 12.00, 10),
('Boldfit Resistance Bands Set', '11-piece resistance tube set with handles.', 1299.00, 899.00, 6, 'Boldfit', 'equipment', 12.00, 100),
('Kore PVC Weights Home Gym Set', 'Combi set including barbell, dumbbells, weights, and gloves.', 2499.00, 1499.00, 6, 'Kore', 'equipment', 12.00, 15);

-- ----- PRODUCT IMAGES -----
INSERT INTO product_images (product_id, image_url, is_primary) VALUES
(1, 'https://cdn.nutrabay.com/wp-content/uploads/2020/09/NB-MBZ-1087-01-01.jpg', TRUE),
(2, 'https://img.lazcdn.com/g/p/cbd13baa5c381c2e4e1417396811ad6c.jpg_720x720q80.jpg', TRUE),
(3, 'https://247nutrition.in/wp-content/uploads/2023/04/bm-whey-gold-2kg-bc-p3-1024x1024.jpg', TRUE),
(4, 'https://totalnutritions.in/wp-content/uploads/2023/08/muscleblaze-whey-gold-protein-2kg-11.jpg', TRUE),
(5, 'https://img4.hkrtcdn.com/38824/prd_3882323-MuscleBlaze-Super-Gainer-XXL-6.6-lb-Matcha_o.jpg', TRUE),
(6, 'https://img3.hkrtcdn.com/19806/prd_1980592-Labrada-Muscle-Mass-Gainer-11-lb-Chocolate_o.jpg', TRUE),
(7, 'https://www.beastnutrition.store/wp-content/uploads/2020/10/6-31.jpg', TRUE),
(8, 'https://eropharma.com/images/detailed/37/creatine-plus-3d.jpg', TRUE),
(9, 'https://www.netnutri.com/media/catalog/product/cache/17/image/650x/d9c70597da8a9cb2926ef4bca3f81833/u/n/untitled-1-recovered-recovered9.jpg', TRUE),
(10, 'https://cdn.nutrabay.com/wp-content/uploads/2018/05/NB-MBZ-1009-01-05.jpg', TRUE),
(11, 'https://cdn.nutrabay.com/wp-content/uploads/2020/10/NB-PLX-1000-01-03.jpg', TRUE),
(12, 'https://assets.hyugalife.com/catalog/product/1/-/1-1775-4_kxbwlqdpspb5kjsj.jpg', TRUE),
(13, 'https://images-na.ssl-images-amazon.com/images/I/41-NZZo1V8L.jpg', TRUE),
(14, 'https://5.imimg.com/data5/SELLER/Default/2025/12/570844038/XB/II/HG/122171514/boldfit-resistance-bands-mini-loop-set-1000x1000.jpg', TRUE),
(15, 'https://images.price.tools/images/kore-pvc-10-40-kg-home-l-iAeXeWLc3.jpg', TRUE);

-- ----- REVIEWS -----
INSERT INTO reviews (product_id, user_id, rating, title, comment) VALUES
(1, 2, 5, 'Great Mixability', 'Tastes awesome in cold water. Gains are visible.'),
(7, 2, 5, 'Pure strength', 'My lifts went up by 10kgs in 2 weeks.'),
(13, 2, 4, 'Solid build', 'Good dumbbells but plates slip slightly.');

-- ============================================================================
-- ==========================  DBMS ADVANCED VIEWS  ===========================
-- ============================================================================

-- VIEW 1: vw_product_summary (Aggregates + Joins for Products)
CREATE OR REPLACE VIEW vw_product_summary AS
SELECT 
    p.id, p.title, p.product_brand, c.name AS category_name,
    p.price,
    p.discount_price,
    IFNULL(p.discount_price, p.price) AS active_price,
    p.tax_percentage,
    ROUND(IFNULL(p.discount_price, p.price) + (IFNULL(p.discount_price, p.price) * p.tax_percentage / 100), 2) AS price_with_gst,
    COALESCE(ROUND(AVG(r.rating), 1), 0) AS avg_rating,
    COUNT(r.id) AS total_reviews
FROM products p
JOIN categories c ON p.category_id = c.id
LEFT JOIN reviews r ON r.product_id = p.id
GROUP BY p.id, p.title, p.product_brand, c.name, p.price, p.discount_price, p.tax_percentage;


-- VIEW 2: vw_cart_summary_with_tax (Computing GST on the fly using SQL Views)
CREATE OR REPLACE VIEW vw_cart_summary_with_tax AS
SELECT 
    c.user_id,
    SUM(c.quantity * IFNULL(p.discount_price, p.price)) AS cart_subtotal,
    SUM(c.quantity * IFNULL(p.discount_price, p.price) * (p.tax_percentage / 100)) AS total_gst,
    SUM(c.quantity * IFNULL(p.discount_price, p.price) + c.quantity * IFNULL(p.discount_price, p.price) * (p.tax_percentage / 100)) AS cart_grand_total
FROM cart c
JOIN products p ON c.product_id = p.id
GROUP BY c.user_id;


-- ============================================================================
-- ==================== ADVANCED DBMS SQL QUERIES =============================
-- ============================================================================

-- QUERY A: Products having higher price than the average price in their category (Subquery)
/*
SELECT title, product_brand, active_price, category_name
FROM vw_product_summary
WHERE active_price > (
    SELECT AVG(active_price) 
    FROM vw_product_summary AS v2 
    WHERE v2.category_name = vw_product_summary.category_name
);
*/

-- QUERY B: Total reviews and Average Rating per Brand (GROUP BY, Joins, Aggregation)
/*
SELECT 
    p.product_brand,
    COUNT(r.id) AS total_reviews,
    ROUND(AVG(r.rating), 1) AS average_brand_rating
FROM products p
JOIN reviews r ON p.id = r.product_id
GROUP BY p.product_brand
HAVING average_brand_rating >= 4;
*/
