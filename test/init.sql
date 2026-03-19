-- ============================================================
-- Seed data for experimenting with indexes, vacuum, bloat, etc.
-- ============================================================

-- 1. A large-ish orders table (100k rows) -- good for index experiments
CREATE TABLE customers (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    email       TEXT NOT NULL,
    region      TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE products (
    id      SERIAL PRIMARY KEY,
    name    TEXT NOT NULL,
    category TEXT NOT NULL,
    price   NUMERIC(10,2) NOT NULL
);

CREATE TABLE orders (
    id           SERIAL PRIMARY KEY,
    customer_id  INT NOT NULL REFERENCES customers(id),
    product_id   INT NOT NULL REFERENCES products(id),
    quantity     INT NOT NULL,
    total        NUMERIC(10,2) NOT NULL,
    status       TEXT NOT NULL,       -- 'pending','shipped','delivered','cancelled'
    ordered_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. A table specifically for bloat/vacuum experiments
CREATE TABLE events (
    id         BIGSERIAL PRIMARY KEY,
    event_type TEXT NOT NULL,
    payload    JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- Populate with generate_series + random data
-- ============================================================

-- 10k customers
INSERT INTO customers (name, email, region)
SELECT
    'customer_' || i,
    'customer_' || i || '@example.com',
    (ARRAY['us-east','us-west','eu-west','eu-central','apac'])[1 + (i % 5)]
FROM generate_series(1, 10000) AS s(i);

-- 500 products across 10 categories
INSERT INTO products (name, category, price)
SELECT
    'product_' || i,
    'cat_' || (i % 10),
    round((random() * 500 + 1)::numeric, 2)
FROM generate_series(1, 500) AS s(i);

-- 100k orders with skewed status distribution (most delivered, few cancelled)
INSERT INTO orders (customer_id, product_id, quantity, total, status, ordered_at)
SELECT
    1 + (random() * 9999)::int,
    1 + (random() * 499)::int,
    1 + (random() * 10)::int,
    round((random() * 2000 + 5)::numeric, 2),
    (ARRAY['delivered','delivered','delivered','shipped','shipped','pending','cancelled'])[1 + (i % 7)],
    now() - (random() * interval '730 days')
FROM generate_series(1, 100000) AS s(i);

-- 50k events (for vacuum/bloat testing -- you'll update/delete these)
INSERT INTO events (event_type, payload, created_at)
SELECT
    (ARRAY['page_view','click','signup','purchase','logout'])[1 + (i % 5)],
    jsonb_build_object(
        'session_id', md5(i::text),
        'value', (random() * 100)::int
    ),
    now() - (random() * interval '365 days')
FROM generate_series(1, 50000) AS s(i);

-- ============================================================
-- A couple of indexes to start with (add/drop your own to compare)
-- ============================================================
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_status      ON orders(status);
CREATE INDEX idx_orders_ordered_at  ON orders(ordered_at);
CREATE INDEX idx_events_type        ON events(event_type);

-- ============================================================
-- Analyze so the planner has stats from the start
-- ============================================================
ANALYZE;
