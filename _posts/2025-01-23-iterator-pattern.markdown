---
layout: post
title: "iterator pattern in java"
date: 2025-01-23 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, design-pattern, vietnamese]
---

`Iterator Pattern` (Mẫu thiết kế Duyệt phần tử) là một trong những **Behavioral Patterns** thuộc nhóm các mẫu thiết kế hành vi trong Design Patterns. Mục tiêu của `Iterator Pattern` là cung cấp một cách để duyệt qua các phần tử của một tập hợp (collection) mà không cần tiết lộ cấu trúc bên trong của tập hợp đó.

Iterator Pattern bao gồm 2 thành phần quan trọng:

- Iterator Interface: Xác định các phương thức cơ bản để duyệt qua tập hợp.
  - hasNext(): Kiểm tra xem còn phần tử nào trong tập hợp không.
  - next(): Trả về phần tử tiếp theo.
- Concrete Iterator: Cài đặt cụ thể của Iterator Interface.
- Aggregate Interface: Tạo một phương thức để trả về Iterator.
- Concrete Aggregate: Cài đặt cụ thể của Aggregate Interface và cung cấp một Iterator tương ứng.

Sơ đồ UML đơn giản của Iterator Pattern:

```
+----------------+      +------------------+
|   Aggregate    |<---->| ConcreteAggregate|
+----------------+      +------------------+
| createIterator()|      | createIterator() |
+----------------+      +------------------+
        ^                            ^
        |                            |
+----------------+       +-----------------+
|   Iterator     |       | ConcreteIterator|
+----------------+       +-----------------+
| hasNext()      |       | hasNext()       |
| next()         |       | next()          |
+----------------+       +-----------------+
```

### # khi nào nên sử dụng

- Khi bạn cần truy cập các phần tử của một tập hợp (list, map, set, v.v.) mà không cần biết cấu trúc chi tiết.
- Khi bạn muốn duyệt qua các phần tử theo nhiều cách khác nhau.
- Khi tập hợp của bạn cần ẩn thông tin triển khai nhưng vẫn cung cấp cách thức truy cập.

### # ví dụ

Giả sử bạn cần thiết kế một lớp để duyệt qua danh sách các tên sinh viên.
Tạo Iterator Interface:

```java
public interface Iterator {
    boolean hasNext();
    Object next();
}
```

Tạo Aggregate Interface:

```java
public interface Container {
    Iterator getIterator();
}
```

Tạo lớp cụ thể ConcreteIterator:

```java
public class NameIterator implements Iterator {
    private String[] names;
    private int index;

    public NameIterator(String[] names) {
        this.names = names;
        this.index = 0;
    }

    @Override
    public boolean hasNext() {
        return index < names.length;
    }

    @Override
    public Object next() {
        if (this.hasNext()) {
            return names[index++];
        }
        return null;
    }
}
```

Tạo lớp ConcreteAggregate:

```java
public class NameRepository implements Container {
    private String[] names = {"Tung", "Miu", "Boo"};

    @Override
    public Iterator getIterator() {
        return new NameIterator(names);
    }
}
```

Sử dụng Iterator Pattern trong Main:

```java
public class Main {
    public static void main(String[] args) {
        NameRepository nameRepository = new NameRepository();

        System.out.println("Danh sách sinh viên:");
        Iterator iterator = nameRepository.getIterator();

        while (iterator.hasNext()) {
            System.out.println(iterator.next());
        }
    }
}
```

Output:

```
Danh sách sinh viên:
Tung
Miu
Boo
```

### # uu điểm

- Ẩn chi tiết triển khai: Người dùng chỉ cần biết cách sử dụng Iterator mà không cần quan tâm đến cấu trúc của tập hợp.
- Duyệt phần tử một cách linh hoạt: Có thể thêm nhiều kiểu duyệt khác nhau bằng cách tạo các Concrete Iterator khác nhau.
- Tăng tính tái sử dụng: Iterator và Aggregate được tách biệt, giúp dễ dàng mở rộng và tái sử dụng mã nguồn.

### # nhược điểm

- Tăng chi phí bộ nhớ: Việc tạo các đối tượng Iterator sẽ tiêu tốn thêm bộ nhớ.
- Phức tạp hóa hệ thống: Với các hệ thống đơn giản, việc sử dụng Iterator Pattern có thể làm mã nguồn trở nên phức tạp không cần thiết.

### # ứng dụng trong Java Collections Framework

Trong Java Collections Framework, Iterator Pattern được sử dụng rộng rãi. Một số ví dụ bao gồm:

#### # Iterator Interface:

Các collection như List, Set, Queue đều cung cấp iterator() để duyệt phần tử.
Phương thức phổ biến: hasNext(), next(), remove().

```java
import java.util.ArrayList;
import java.util.Iterator;

public class CollectionExample {
    public static void main(String[] args) {
        ArrayList<String> names = new ArrayList<>();
        names.add("Tung");
        names.add("Miu");
        names.add("Boo");

        Iterator<String> iterator = names.iterator();

        while (iterator.hasNext()) {
            System.out.println(iterator.next());
        }
    }
}
```

Output:

```java
Tung
Miu
Boo
```

#### # for-each loop:

Java cung cấp cú pháp for-each như một cách ngắn gọn để duyệt các phần tử.
Thực tế, for-each sử dụng Iterator ở cấp độ nền tảng.

```java
for (String name : names) {
    System.out.println(name);
}
```

So sánh Iterator với các phương pháp khác:

| **Tiêu chí**       | **Iterator**                | **For-Each Loop**       |
| ------------------ | --------------------------- | ----------------------- |
| **Tính linh hoạt** | Cao, có thể kiểm soát luồng | Thấp, chỉ dùng để duyệt |
| **Xóa phần tử**    | Dùng `iterator.remove()`    | Không hỗ trợ            |
| **Cú pháp**        | Phức tạp hơn đôi chút       | Đơn giản, ngắn gọn      |
| **Tính mở rộng**   | Có thể tạo nhiều kiểu       |

### # lời kết

`Iterator Pattern` là một mẫu thiết kế quan trọng giúp bạn duyệt qua các phần tử trong tập hợp mà không cần quan tâm đến cấu trúc nội bộ của tập hợp đó. Nó mang lại sự linh hoạt và dễ mở rộng, đặc biệt khi làm việc với các tập hợp lớn hoặc phức tạp.

Trong Java, `Iterator Pattern` được tích hợp sẵn thông qua Iterator Interface và for-each loop, giúp lập trình viên thao tác với dữ liệu một cách dễ dàng và hiệu quả.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
