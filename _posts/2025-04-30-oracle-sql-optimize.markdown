---
layout: post
title: "một vài cách tối ưu sql query trong oracle"
date: 2025-04-30 19:29:39 +0700
categories: [Software Development]
tags: [software-development, sql, oracle, optimization, vietnamese]
---

Trong lĩnh vực phát triển phần mềm, có thể rất nhiều lần chính bạn hoặc đồng nghiệp của bạn thốt lên rằng: _WTF code đã tối ưu thế này mà sao thời gian phản hồi api vẫn chậm?_ Đó là một vấn đề nhứt nhói, cần phải bắt tay vào tối ưu ngay lặp tức - SQL.

Ở các dự án lớn, quy mô lớn thường có cả một đội DBA chuyên nghiệp làm công tác tối ưu SQL, nhưng đôi khi dự án cần release gấp với lượng người dùng ban đầu hạn chế thì chính dev cũng làm luôn công việc của DBA. Nếu bạn đã từng bị stress vì những câu truy vấn chậm chạp như rùa, thì đây chính là bài viết dành cho bạn.

Hãy chuẩn bị sẵn sàng vì bạn sẽ không chỉ học được cách tối ưu mà còn được ... được cái gì nữa thì mình cũng hong biết nữa!

### # tại sao phải tối ưu?

Trước khi bước vào những mẹo tuyệt vời, hãy cùng nhau đặt ra câu hỏi: **Tại sao chúng ta cần tối ưu SQL Query?**

Câu trả lời đơn giản: **Thời gian là vàng!** Nếu bạn không tối ưu, những câu truy vấn của bạn có thể sẽ khiến bạn mất rất nhiều thời gian (và có thể cả khách hàng) trong khi chờ đợi kết quả.

> Hãy tưởng tượng bạn đi ăn tối với người yêu, nhưng câu truy vấn (các món đang order) của bạn lại lên chậm như rùa. Thật tệ đúng không? Vì vậy, chúng ta hãy cùng nhau đi tìm giải pháp.

### # hiểu rõ về dữ liệu

Trước khi làm bất cứ điều gì với SQL, bạn cần phải hiểu rõ về dữ liệu của mình.

> Hãy tưởng tượng bạn là một thám tử và dữ liệu của bạn chính là vụ án cần được giải quyết. Bạn cần nắm rõ về các tình tiết và đối tượng liên quan.

Có một vài điều về dữ liệu mà bạn có thể chú ý:

- **Schema**: Biết cấu trúc dữ liệu của bạn như lòng bàn tay. Thay vì hỏi _"Tôi có cái gì ở đây?"_, hãy tự hỏi _"Tôi muốn tìm cái gì ở đây?"_.
- **Phân phối dữ liệu**: Nếu bạn có một bảng lớn với hàng triệu bản ghi, hãy chắc chắn rằng bạn biết dữ liệu trong đó được phân phối như thế nào. Hãy tìm ra những bản ghi **_“hot hòn họt”_** và những bản ghi **_“lạnh băng giá”_** để biết nên tập trung vào đâu.

Giả sử bạn có một bảng `customers` với hàng chục triệu bản ghi. Và bạn chỉ cần tìm kiếm khách hàng ở một thành phố cụ thể, hãy chắc chắn rằng bạn biết cách nhóm và chỉ định các bản ghi này.

```sql
SELECT * FROM customers WHERE city = 'HCM';
```

Nếu câu truy vấn này chạy chậm, thì phải làm sao?

... Đọc tiếp đi chứ làm sao :)))

### # một số cách tối ưu

#### # sử dụng index

Nói đến chỉ mục `(index)`, đây là một trong những cách tốt nhất để tăng tốc độ truy vấn của bạn. Chỉ mục giống như một bảng chỉ mục trong cuốn sách dày cộp mà bạn đang đọc. Nó giúp bạn tìm kiếm thông tin nhanh hơn nhiều.

Khi nào nên sử dụng Index?

- Khi bạn thường xuyên tìm kiếm trên một cột nào đó.
- Khi bạn có nhiều bản ghi trong bảng.
- Khi bạn có các truy vấn `JOIN` phức tạp.

Giả sử bạn có bảng `orders` và bạn thường xuyên tìm kiếm theo `customer_id`. Hãy thêm `index` như sau:

```sql
CREATE INDEX idx_customer_id ON orders(customer_id);
```

Và xem tốc độ truy vấn của bạn tăng vọt như một chiếc tên lửa của Elon Musk :)))

> Nhưng không phải lúc nào thêm index cũng là giải pháp tốt nhất. Việc đánh index cũng làm ảnh hưởng hiệu suất ở một số lệnh SQL khác nên hãy cân nhắc sử dụng khi thực sự hiểu rõ bản chất và yêu cầu nghiệp vụ. Còn tại sao thì mình hẹn ở một bài viết khác.

#### # tránh sử dụng SELECT \*

Đừng bao giờ sử dụng `SELECT *` một cách tuỳ tiện và vô tư.

> Giống như việc bạn gọi hết menu món ăn mà không biết mình đang muốn ăn gì. Hãy chỉ chọn những cột mà bạn thực sự cần, không chỉ giúp tăng tốc độ truy vấn mà còn tiết kiệm tài nguyên.

Thay vì cứ `SELECT *` lấy hết cột lên rồi muốn dùng trường nào thì dùng:

```sql
SELECT * FROM orders;
```

Hãy chỉ chọn các cột cần thiết:

```sql
SELECT order_id, order_date FROM orders;
```

> Nó giống như việc bạn chỉ gọi món mà mình thích, thay vì ăn tất cả những món có trên thực đơn.

#### # sử dụng JOIN hợp lý

Khi bạn cần kết hợp nhiều bảng, hãy sử dụng `JOIN` một cách thông minh. Sử dụng `INNER JOIN` khi bạn chỉ cần các bản ghi khớp ở cả hai bảng và `LEFT JOIN` khi bạn muốn giữ lại tất cả các bản ghi từ bảng bên trái.

```sql
SELECT c.customer_id, o.order_id
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id;
```

Hãy đảm bảo rằng bạn không sử dụng quá nhiều `JOIN` trong một truy vấn. Nếu không thì không khác gì việc bạn mời quá nhiều bạn bè đến bữa tiệc – thật hỗn độn!

#### # sử dụng EXPLAIN PLAN

Trước khi chạy một truy vấn lớn, hãy sử dụng `EXPLAIN PLAN` để hiểu cách Oracle xử lý truy vấn, nó sẽ giúp bạn xác định xem có bất kỳ nút thắt cổ chai nào trong truy vấn hay không.

```sql
EXPLAIN PLAN FOR
SELECT * FROM orders WHERE customer_id = 1;
```

Bạn có thể xem kế hoạch thực thi bằng cách sử dụng:

```sql
SELECT * FROM table(DBMS_XPLAN.DISPLAY());
```

> Tưởng tượng như việc bạn xem xét kế hoạch du lịch trước khi đi. Bạn cần biết mình sẽ đi đâu và làm gì để không bị lạc đường!

#### # tránh sử dụng các hàm trong WHERE clause

Khi bạn sử dụng hàm trong câu lệnh `WHERE`, có thể khiến Oracle không sử dụng chỉ mục một cách hiệu quả. Hãy tránh điều này nếu có thể.

Thay vì:

```sql
SELECT * FROM orders WHERE YEAR(order_date) = 2024;
```

Hãy viết lại như sau:

```sql
SELECT * FROM orders WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01';
```

Nó sẽ giúp bạn tiết kiệm thời gian như việc không cần đợi đến khi người khác quyết định chọn món ăn!

#### # tối ưu hóa các câu truy vấn con

Câu truy vấn con `(subquery)` đôi khi có thể làm chậm hiệu suất. Hãy xem xét việc sử dụng `JOIN` hoặc `CTE` (Common Table Expressions) thay vì sử dụng `subquery`.

Thay vì:

```sql
SELECT customer_id, (SELECT COUNT(*) FROM orders WHERE customer_id = c.customer_id) AS order_count
FROM customers c;
```

Hãy viết lại như sau:

```sql
WITH order_counts AS (
    SELECT customer_id, COUNT(*) AS order_count
    FROM orders
    GROUP BY customer_id
)
SELECT c.customer_id, oc.order_count
FROM customers c
LEFT JOIN order_counts oc ON c.customer_id = oc.customer_id;
```

Viết lại như vậy sẽ giúp bạn tối ưu hóa hiệu suất như việc bạn chuyển từ ăn bún phở sang sushi – ăn ít nhưng vẫn no!

#### # sử dụng partitioning

Nếu bạn có bảng lớn, hãy xem xét việc phân vùng bảng `(table partitioning)`. Nó sẽ giúp Oracle chỉ quét qua những phần cần thiết của bảng thay vì toàn bộ bảng.

Giả sử bạn có bảng `sales` với hàng triệu bản ghi. Bạn có thể phân vùng theo năm:

```sql
CREATE TABLE sales (
    sale_id NUMBER,
    sale_date DATE,
    amount NUMBER
)
PARTITION BY RANGE (sale_date) (
    PARTITION p2023 VALUES LESS THAN (TO_DATE('01-JAN-2024', 'DD-MON-YYYY')),
    PARTITION p2024 VALUES LESS THAN (TO_DATE('01-JAN-2025', 'DD-MON-YYYY'))
);
```

Điều này sẽ giúp bạn truy vấn nhanh hơn như việc bạn chọn món ăn ngay khi nhìn thấy thực đơn!

#### # kiểm tra hiệu suất thường xuyên

Cuối cùng, hãy luôn kiểm tra hiệu suất truy vấn của bạn. Sử dụng các công cụ như **AWR** `(Automatic Workload Repository)` và **ASH** `(Active Session History)` để theo dõi hiệu suất. Hãy như một huấn luyện viên thể hình, luôn kiểm tra và tối ưu hóa hiệu suất của bạn.

### # lời kết

Tối ưu SQL Query trong Oracle không phải là một nhiệm vụ dễ dàng, nhưng với những mẹo trên, bạn sẽ có thể tối ưu hóa truy vấn của mình một cách hiệu quả.

Hãy nhớ rằng, một truy vấn tốt không chỉ giúp bạn tiết kiệm thời gian mà còn giúp cuộc sống của bạn dễ dàng hơn (và có thể giúp bạn giữ lại người yêu của mình trong bữa tối).

Hãy chia sẻ những mẹo của bạn và đừng ngần ngại thử nghiệm. Chúc bạn thành công trong việc tối ưu hóa SQL Query và có những bữa tối không còn bị gián đoạn bởi những câu truy vấn chậm chạp!

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
