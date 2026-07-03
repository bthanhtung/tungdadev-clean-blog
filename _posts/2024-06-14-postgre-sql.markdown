---
layout: post
title: "postgre-sql"
date: 2024-06-14 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, postgresql, best-practices, vietnamese]
---

Trong thế giới của những hệ thống Backend tải cao, việc chọn một database tốt chỉ là bước khởi đầu; thấu hiểu tầng sâu của nó mới là chìa khóa để kiến tạo một nền tảng vững chắc. Đặc biệt khi bạn áp dụng các triết lý như Clean Architecture hay thiết kế hệ thống theo pattern CQRS, nơi PostgreSQL thường được tin tưởng giao trọng trách làm "trái tim" cho Command-side (Write model), thì việc nắm rõ cách hệ quản trị này "thở" là điều bắt buộc.

Bài viết này không chỉ liệt kê cú pháp. Chúng ta sẽ cùng mổ xẻ cấu trúc vật lý, cơ chế đồng thời, và những thủ thuật tối ưu mà một kỹ sư thực thụ cần trang bị.

## # bản chất

PostgreSQL là một hệ quản trị cơ sở dữ liệu quan hệ khách thể (Object-Relational Database), tuân thủ nghiêm ngặt tiêu chuẩn ACID. Khác với MySQL sử dụng mô hình thread-per-connection (mỗi luồng cho một kết nối), PostgreSQL trung thành với kiến trúc Process-per-connection.

Nghĩa là: Mỗi khi một client chạm vào database, hệ điều hành (OS) sẽ fork ra một process độc lập. Điều này mang lại sự cô lập bộ nhớ tuyệt vời, nhưng đánh đổi lại là chi phí khởi tạo và tài nguyên RAM lớn hơn.

![postgre-connection](/assets/img/blog/postgre/postgre-connection.png)

### # mvcc (multi-version concurrency control)

Nhiều lập trình viên ngạc nhiên khi biết PostgreSQL không khóa (lock) row khi đọc. Phép màu đằng sau đó chính là MVCC — Quản lý đồng thời nhiều phiên bản.

Thay vì ghi đè trực tiếp lên dữ liệu cũ, mỗi thao tác sinh ra một phiên bản mới của dòng dữ liệu (row version):

```sql
UPDATE users SET name = 'Bob' WHERE id = 1;
```

Trạng thái trước: Row(id=1, name='Alice', xmin=100, xmax=∞) (Chỉ hiển thị cho các transaction > 100).

Trạng thái sau: \* Row(id=1, name='Alice', xmin=100, xmax=200) trở thành dead tuple (tàng hình với các transaction > 200).

- Row(id=1, name='Bob', xmin=200, xmax=∞) là phiên bản mới.

Định lý sống còn: Trong PostgreSQL, Readers không bao giờ block Writers, và Writers không bao giờ block Readers. UPDATE thực chất là một thao tác INSERT (phiên bản mới) + Đánh dấu xóa (phiên bản cũ).

Hệ quả tất yếu của triết lý này là rác — những dead tuples dần tích tụ, làm phình to (bloat) database. Đó là lúc chúng ta cần đến "người lao công" mẫn cán: VACUUM.

### # vacuum

VACUUM là tiến trình quét qua các data pages để thu hồi không gian từ các dead tuples, trả lại chỗ trống cho các bản ghi mới trong tương lai.

```sql
-- Dọn rác cơ bản
VACUUM VERBOSE users;

-- Dọn rác và dồn mảnh (Trả lại dung lượng đĩa thực tế nhưng sẽ LOCK TABLE toàn bộ!)
VACUUM FULL users;

-- Cập nhật lại thống kê dữ liệu cho Query Planner
VACUUM ANALYZE users;
```

Trong môi trường production, chúng ta hiếm khi gọi thủ công mà dựa vào Autovacuum:

```sql
-- Cấu hình tinh chỉnh ngưỡng kích hoạt Autovacuum
ALTER TABLE users SET (
   autovacuum_vacuum_threshold = 50,           -- Số dead tuples tối thiểu để kích hoạt
   autovacuum_vacuum_scale_factor = 0.1,       -- Kích hoạt khi 10% table biến thành rác
   autovacuum_analyze_threshold = 50,
   autovacuum_analyze_scale_factor = 0.05
);
```

**Khi nào autovacuum chạy:** `dead_tuples > threshold + scale_factor * table_size`

**Table bloat:** Nếu vacuum không kịp → table phình to (dead tuples chiếm space). Fix: `VACUUM FULL` (nhưng locks table) hoặc `pg_repack` (online). Nếu bảng có tần suất Write/Update cực lớn, hãy hạ scale_factor xuống để Autovacuum chạy thường xuyên hơn, ngăn chặn hiện tượng Table Bloat tồi tệ đến mức phải dùng đến pg_repack.

### # wal (write-ahead log)

Mọi thay đổi dữ liệu không được ghi thẳng vào Data Files (Heap). Chúng đi qua một chốt chặn an toàn gọi là WAL.

![transaction-commit](/assets/img/blog/postgre/transaction-commit.png)

WAL đảm bảo durability (D trong ACID). Nếu crash giữa chừng, replay WAL = recover.

### # indexes

Index là một thanh gươm hai lưỡi. Hiểu rõ cấu trúc dữ liệu của từng loại Index giúp bạn vung kiếm chính xác:

#### # b-tree (default, phổ biến nhất)

```sql
CREATE INDEX idx_users_email ON users(email);
-- Tốt cho: =, <, >, <=, >=, BETWEEN, IN, LIKE 'prefix%'
-- Không tốt cho: LIKE '%suffix', full-text search
```

#### # hash

```sql
CREATE INDEX idx_users_email_hash ON users USING hash(email);
-- Chỉ tốt cho: = (equality)
-- Nhỏ hơn B-Tree, nhanh hơn cho equality lookups
```

#### # gin (generalized inverted index)

```sql
CREATE INDEX idx_users_tags ON users USING gin(tags);
-- Tốt cho: arrays, JSONB, full-text search
-- @>, ?, ?|, ?&, @@
```

#### # gist (generalized search tree)

```sql
CREATE INDEX idx_locations_point ON locations USING gist(coordinates);
-- Tốt cho: geometric, range types, full-text search -> dữ liệu không gian, hình học
-- <<, >>, &&, @>
```

#### # partial index

Chỉ index những dữ liệu có ý nghĩa, tiết kiệm RAM và dung lượng cực lớn.

```sql
-- Chỉ index rows thỏa condition → nhỏ hơn, nhanh hơn
CREATE INDEX idx_orders_pending ON orders(created_at)
   WHERE status = 'PENDING';
```

#### # composite index

```sql
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
-- Tốt cho: WHERE user_id = ? AND status = ?
-- Cũng tốt cho: WHERE user_id = ? (leftmost prefix)
-- KHÔNG tốt cho: WHERE status = ? (không dùng được index)
```

#### # covering index (include)

Covering Index (INCLUDE): Đạt cảnh giới tối cao Index-Only Scan, lấy thẳng dữ liệu từ cây Index mà không cần chạm vào Heap table.

```sql
CREATE INDEX idx_orders_user ON orders(user_id) INCLUDE (status, total);
-- Index-only scan: không cần đọc heap table
```

### # query optimization

#### # explain analyze

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM orders WHERE user_id = 'abc' AND status = 'PENDING';

-- Output:
-- Index Scan using idx_orders_user_status on orders (cost=0.43..8.45 rows=1 width=200)
--   (actual time=0.023..0.025 rows=1 loops=1)
--   Index Cond: (user_id = 'abc' AND status = 'PENDING')
--   Buffers: shared hit=4
-- Planning Time: 0.150 ms
-- Execution Time: 0.050 ms
```

#### # scan types (tốt → xấu)

| Scan              | Ý nghĩa                         | Performance         |
| ----------------- | ------------------------------- | ------------------- |
| Index Only Scan   | Đọc từ index, không cần heap    | Tốt nhất            |
| Index Scan        | Dùng index, đọc heap cho data   | Tốt                 |
| Bitmap Index Scan | Dùng index tạo bitmap, đọc heap | OK cho nhiều rows   |
| Seq Scan          | Full table scan                 | Tệ cho large tables |

#### # common optimization patterns

```sql
-- 1. Avoid SELECT *
SELECT id, name, email FROM users WHERE ...;

-- 2. Use EXISTS instead of IN for subqueries
SELECT * FROM orders o WHERE EXISTS (
   SELECT 1 FROM users u WHERE u.id = o.user_id AND u.active = true
);

-- 3. Pagination with keyset (không dùng OFFSET cho large datasets)
SELECT * FROM orders WHERE id > :last_id ORDER BY id LIMIT 20;
-- Thay vì: SELECT * FROM orders ORDER BY id LIMIT 20 OFFSET 10000; (slow!)

-- 4. Batch operations
INSERT INTO orders (id, user_id, total) VALUES
   ('1', 'u1', 100), ('2', 'u2', 200), ('3', 'u3', 300);

-- 5. Use COPY for bulk load
COPY orders FROM '/tmp/orders.csv' WITH (FORMAT csv, HEADER true);
```

### # transactions & isolation levels

| Level                    | Dirty Read | Non-Repeatable Read | Phantom Read | Serialization Anomaly |
| ------------------------ | ---------- | ------------------- | ------------ | --------------------- |
| Read Uncommitted\*       | No         | Yes                 | Yes          | Yes                   |
| Read Committed (default) | No         | No                  | Yes          | Yes                   |
| Repeatable Read          | No         | No                  | No           | Yes                   |
| Serializable             | No         | No                  | No           | No                    |

\*PostgreSQL treats Read Uncommitted as Read Committed.

```sql
-- Set per transaction
BEGIN ISOLATION LEVEL REPEATABLE READ;
-- ... operations
COMMIT;
```

### # partitioning

```sql
-- Range partitioning (by date)
CREATE TABLE orders (
   id UUID PRIMARY KEY,
   created_at TIMESTAMP NOT NULL,
   user_id UUID,
   total DECIMAL
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_2024_01 PARTITION OF orders
   FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE orders_2024_02 PARTITION OF orders
   FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Query tự động chỉ scan partition cần thiết (partition pruning)
SELECT * FROM orders WHERE created_at >= '2024-01-15';
-- → chỉ scan orders_2024_01
```

### # connection pooling

Như đã đề cập ở phần Kiến trúc, vì PostgreSQL dùng Process-per-connection, việc mở hàng ngàn kết nối trực tiếp là tự sát. Bắt buộc phải dùng Connection Pooler (như PgBouncer) hoặc tối thiểu là tối ưu ở tầng Application (HikariCP trong Spring Boot).

```yaml
# HikariCP (Spring Boot default)
spring:
  datasource:
    hikari:
      maximum-pool-size: 20 # max connections
      minimum-idle: 5 # min idle connections
      connection-timeout: 30000 # wait for connection (ms)
      idle-timeout: 600000 # close idle connection after 10min
      max-lifetime: 1800000 # max connection age 30min
      leak-detection-threshold: 60000
```

Rule of thumb: `pool_size = (core_count * 2) + effective_spindle_count`
Thường: 10-20 connections cho hầu hết workloads.

### # useful queries

```sql
-- Active connections
SELECT pid, usename, application_name, state, query_start, query
FROM pg_stat_activity WHERE state = 'active';

-- Table sizes
SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC;

-- Index usage
SELECT indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes ORDER BY idx_scan DESC;

-- Unused indexes (candidates for removal)
SELECT indexrelname, idx_scan FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND indexrelname NOT LIKE '%pkey%';

-- Long running queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, query
FROM pg_stat_activity WHERE state != 'idle'
ORDER BY duration DESC LIMIT 10;

-- Dead tuples (need vacuum)
SELECT relname, n_dead_tup, last_vacuum, last_autovacuum
FROM pg_stat_user_tables WHERE n_dead_tup > 1000 ORDER BY n_dead_tup DESC;

-- Lock conflicts
SELECT blocked.pid, blocked.query, blocking.pid, blocking.query
FROM pg_stat_activity blocked
JOIN pg_locks bl ON bl.pid = blocked.pid
JOIN pg_locks bk ON bk.relation = bl.relation AND bk.pid != bl.pid
JOIN pg_stat_activity blocking ON blocking.pid = bk.pid
WHERE NOT bl.granted;
```

### # spring data jpa tips (với postgresql)

#### # stringtype=unspecified issue

Khi dùng Native Query, PostgreSQL driver thường nhầm lẫn tham số String là kiểu bytea, gây ra lỗi không map được function lower()

```java
// JDBC URL: jdbc:postgresql://host:5432/db?stringtype=unspecified
// → driver gửi params dạng bytea thay vì varchar

// JPQL FAILS:
@Query("SELECT u FROM User u WHERE LOWER(u.email) = LOWER(:email)")
// Error: function lower(bytea) does not exist

// FIX: Native query với CAST
@Query(value = "SELECT * FROM users WHERE LOWER(CAST(:email AS text)) = LOWER(email)", nativeQuery = true)
List<User> findByEmail(@Param("email") String email);

// Nullable params FIX:
@Query(value = "SELECT * FROM orders WHERE (CAST(:status AS text) IS NULL OR status = CAST(:status AS text))", nativeQuery = true)
List<Order> findByStatus(@Param("status") String status);
```

#### # enum handling

```java
// Enum phải convert sang String trước khi pass vào native query
String statusStr = status != null ? status.name() : null;
repository.findByStatus(statusStr);
```

### # production checklist

Để ngủ ngon vào ban đêm, hãy đảm bảo bạn đã tích đủ các ô sau:

- [ ] Đã cấu hình Connection Pooling (HikariCP / PgBouncer).
- [ ] Tinh chỉnh Autovacuum cho các bảng có tần suất Write cao.
- [ ] Soi kỹ EXPLAIN cho các query cốt lõi, đảm bảo đang dùng Index Scan.
- [ ] Xóa bỏ các Index thừa thãi (dùng view pg_stat_user_indexes).
- [ ] Lên kế hoạch Partitioning cho các bảng lớn hơn 10 triệu dòng.
- [ ] Bật pg_stat_statements để liên tục track performance của Query thực tế.
- [ ] Cài đặt statement_timeout ở mức Database để chống treo hệ thống vì một query lỡ tay.
- [ ] Bật Slow Query Log (log_min_duration_statement).

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
