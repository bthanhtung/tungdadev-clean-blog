---
layout: post
title: "rownum in SQL"
date: 2025-04-22 19:29:39 +0700
categories: [Software Development]
tags: [sql, software-development, oracle, database, vietnamese]
---

Trong thế giới SQL, việc kiểm soát và tối ưu hóa kết quả truy vấn là một kỹ năng quan trọng, đặc biệt khi làm việc với các tập dữ liệu lớn. **ROWNUM** là một trong những tính năng đặc biệt của Oracle SQL, cho phép gán số thứ tự cho từng dòng dữ liệu, từ đó hỗ trợ giới hạn kết quả, phân trang, và thậm chí là loại bỏ dữ liệu trùng lặp.

Dù có vẻ đơn giản, nhưng **ROWNUM** mở ra nhiều khả năng xử lý linh hoạt và mạnh mẽ khi kết hợp với các câu lệnh con và điều kiện phức tạp. Trong bài viết này, chúng ta sẽ khám phá các kịch bản thực tế, đi kèm với các ví dụ truy vấn cụ thể để giúp bạn nắm vững cách sử dụng **ROWNUM** trong các tình huống khác nhau.

### # rownum là gì?

**ROWNUM** là một cột giả (`pseudocolumn`) trong Oracle SQL, gán số duy nhất cho mỗi hàng được trả về bởi một truy vấn. Việc đánh số bắt đầu từ 1 và tăng dần 1 đơn vị cho mỗi hàng tiếp theo.

Đây là một tính năng hữu ích để giới hạn số lượng hàng được trả về hoặc thực hiện phân trang (`pagination`).

### # các trường hợp sử dụng

#### # giới hạn số hàng được trả về

Giả sử bạn có một bảng tên là **EMPLOYEES** và muốn truy xuất 5 nhân viên đầu tiên dựa trên ngày tuyển dụng (hiring date).

```sql
SELECT *
FROM EMPLOYEES
WHERE ROWNUM <= 5
ORDER BY HIRE_DATE;
```

- Truy vấn trên giới hạn kết quả ở 5 hàng đầu tiên.
- Tuy nhiên, lưu ý rằng **ORDER BY** được áp dụng sau khi bộ lọc **ROWNUM**.

Cách đảm bảo sắp xếp trước khi giới hạn:

```sql
SELECT *
FROM (SELECT *
      FROM EMPLOYEES
      ORDER BY HIRE_DATE)
WHERE ROWNUM <= 5;
```

#### # phân trang (pagination)

Phân trang rất phổ biến trong các ứng dụng web, nơi kết quả được hiển thị theo từng trang. Ví dụ, hiển thị 10 nhân viên mỗi trang.

Lấy từ hàng thứ 11 đến 20 (trang thứ hai):

```sql
SELECT *
FROM (SELECT E.*, ROWNUM RNUM
      FROM EMPLOYEES E
      WHERE ROWNUM <= 20)
WHERE RNUM > 10;
```

- Truy vấn bên trong gán **ROWNUM** cho mỗi hàng tới hàng thứ 20.
- Truy vấn bên ngoài lọc các hàng có `RNUM > 10`.

#### # chọn hàng với điều kiện cụ thể

Lấy nhân viên đầu tiên được tuyển dụng sau ngày 26/12/2024.

```sql
SELECT *
FROM EMPLOYEES
WHERE HIRE_DATE > TO_DATE('2024-12-26', 'YYYY-MM-DD')
AND ROWNUM = 1
ORDER BY HIRE_DATE;
```

`ROWNUM = 1` đảm bảo chỉ trả về hàng đầu tiên sau khi sắp xếp.

#### # xóa các hàng trùng lặp

Giả sử bạn muốn xóa các hàng trùng lặp dựa trên EMPLOYEE_ID, chỉ giữ lại bản ghi đầu tiên.

```sql
DELETE FROM EMPLOYEES E1
WHERE E1.ROWID > (SELECT MIN(E2.ROWID)
                  FROM EMPLOYEES E2
                  WHERE E1.EMPLOYEE_ID = E2.EMPLOYEE_ID);
```

- **ROWID** giúp xác định hàng duy nhất.
- Truy vấn con giữ lại bản ghi đầu tiên của mỗi **EMPLOYEE_ID**.

#### # xếp hạng theo điều kiện trong nhóm

Xếp hạng nhân viên theo lương trong mỗi phòng ban.

```sql
SELECT DEPARTMENT_ID, EMPLOYEE_ID, SALARY, ROWNUM AS RANK
FROM (SELECT DEPARTMENT_ID, EMPLOYEE_ID, SALARY
      FROM EMPLOYEES
      ORDER BY DEPARTMENT_ID, SALARY DESC);
```

#### # giới hạn kết quả trong các truy vấn phân tích

Lấy 3 nhân viên có lương cao nhất trong mỗi phòng ban.

```sql
SELECT DEPARTMENT_ID, EMPLOYEE_ID, SALARY
FROM (SELECT DEPARTMENT_ID, EMPLOYEE_ID, SALARY, ROWNUM AS RANK
      FROM (SELECT DEPARTMENT_ID, EMPLOYEE_ID, SALARY
            FROM EMPLOYEES
            ORDER BY DEPARTMENT_ID, SALARY DESC))
WHERE RANK <= 3;
```

#### # tìm giá trị cao thứ N

Tìm mức lương cao thứ 5:

```sql
SELECT SALARY
FROM (SELECT SALARY
      FROM EMPLOYEES
      ORDER BY SALARY DESC)
WHERE ROWNUM = 5;
```

#### # kết hợp JOIN và giới hạn kết quả

Giới hạn 3 nhân viên có lương cao nhất trong mỗi phòng ban khi JOIN với bảng **DEPARTMENTS**:

```sql
SELECT D.DEPARTMENT_NAME, E.EMPLOYEE_ID, E.SALARY
FROM DEPARTMENTS D
JOIN (SELECT DEPARTMENT_ID, EMPLOYEE_ID, SALARY
      FROM (SELECT DEPARTMENT_ID, EMPLOYEE_ID, SALARY, ROWNUM AS RANK
            FROM (SELECT DEPARTMENT_ID, EMPLOYEE_ID, SALARY
                  FROM EMPLOYEES
                  ORDER BY DEPARTMENT_ID, SALARY DESC))
      WHERE RANK <= 3) E
ON D.DEPARTMENT_ID = E.DEPARTMENT_ID;
```

#### # lọc phức tạp với nhiều điều kiện

Lấy 10 nhân viên đầu tiên được tuyển dụng sau năm 2020 và có lương trên 50.000:

```sql
SELECT *
FROM EMPLOYEES
WHERE HIRE_DATE > TO_DATE('2020-01-01', 'YYYY-MM-DD')
AND SALARY > 50000
AND ROWNUM <= 10
ORDER BY HIRE_DATE;
```

**Lưu ý quan trọng**:

- `ROWNUM` được gán trước khi sắp xếp `(ORDER BY)`. Nếu muốn giới hạn sau khi sắp xếp, cần sử dụng truy vấn con `(subquery)`.
- Một số hệ quản trị cơ sở dữ liệu (DBMS) không hỗ trợ `ROWNUM`. Thay vào đó, có thể dùng:
  - MySQL: LIMIT
  - SQL Server: TOP
  - PostgreSQL: ROW_NUMBER() (window function).

### # lời kết

`ROWNUM` là một công cụ mạnh mẽ và linh hoạt trong Oracle SQL, cho phép bạn giới hạn kết quả, thực hiện phân trang, xóa dữ liệu trùng lặp và thực hiện các truy vấn phức tạp một cách hiệu quả. Tuy nhiên, điều quan trọng là phải hiểu rõ cách `ROWNUM` hoạt động – đặc biệt là việc gán số thứ tự trước khi sắp xếp dữ liệu (ORDER BY).

Bằng cách sử dụng các truy vấn con (subquery), bạn có thể kiểm soát việc sắp xếp và áp dụng `ROWNUM` chính xác theo nhu cầu cụ thể. Mặc dù `ROWNUM` là đặc trưng của Oracle, nhưng các hệ quản trị cơ sở dữ liệu khác có các phương pháp tương đương như `LIMIT`, `TOP`, hoặc `ROW_NUMBER()`.

Việc thành thạo `ROWNUM` sẽ giúp bạn tối ưu hóa hiệu suất truy vấn, giải quyết các bài toán phân tích dữ liệu và xử lý các tình huống thực tế một cách dễ dàng. Hãy thử áp dụng các ví dụ trên vào công việc của bạn để hiểu sâu hơn về sức mạnh của SQL và khai thác tối đa lợi ích mà `ROWNUM` mang lại.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
