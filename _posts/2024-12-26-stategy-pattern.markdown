---
layout: post
title: "strategy pattern in java"
date: 2024-12-26 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, design-pattern, vietnamese]
---

`Strategy Pattern` (Mẫu thiết kế chiến lược) là một **Behavioral Design Pattern** (mẫu thiết kế hành vi), cho phép chúng ta định nghĩa một tập hợp các thuật toán, đặt chúng vào các class riêng biệt và làm cho chúng có thể thay thế được trong quá trình runtime.

`Strategy Pattern` giúp tách biệt các thuật toán ra khỏi class chính, đảm bảo nguyên lý **Open-Closed Principle trong SOLID** (mở rộng dễ dàng nhưng hạn chế chỉnh sửa code cũ).

Ví dụ thực tế:

- Khi bạn cần thay đổi các thuật toán xử lý thanh toán như PayPal, Visa, hoặc Momo mà không làm ảnh hưởng đến code của ứng dụng chính.
- Khi xây dựng một chương trình có thể thay đổi sort algorithm (bubble sort, quicksort, mergesort) trong runtime.

Strategy Pattern bao gồm 3 thành phần chính:

- Context: Lớp chứa tham chiếu đến một đối tượng Strategy. Nó tương tác với Strategy để thực thi thuật toán.
- Strategy (interface): Định nghĩa một giao diện chung cho các thuật toán.
- Concrete Strategy: Hiện thực cụ thể của Strategy.

![strategy-uml](/assets/img/blog/strategy-uml.png)

Sơ đồ UML:

```
               +-----------------+
               |    Context      |
               |-----------------|
               | strategy: IStrategy |
               +-----------------+
                          |
                          v
            +-------------------+
            |    IStrategy      | (Interface)
            +-------------------+
                          ^
         +----------------+---------------+
         |                                |
+-----------------+             +-----------------+
| StrategyA       |             | StrategyB       |
|-----------------|             |-----------------|
| execute():void  |             | execute():void  |
+-----------------+             +-----------------+
```

### # khi nào nên sử dụng

- Khi bạn có nhiều thuật toán hoặc logic tương tự nhau và cần thay đổi dễ dàng trong runtime.
- Khi cần tránh việc sử dụng if-else hoặc switch-case dài dòng.
- Khi các thuật toán có thể thay đổi độc lập mà không ảnh hưởng đến phần còn lại của hệ thống.

### # ưu điểm

- Tăng tính linh hoạt: Cho phép thay đổi thuật toán một cách dễ dàng trong runtime.
- Tuân thủ Open-Closed Principle: Có thể mở rộng thêm thuật toán mới mà không chỉnh sửa code hiện tại.
- Dễ bảo trì: Mỗi thuật toán được đặt trong class riêng biệt.

### # nhược điểm

- Tăng số lượng class: Mỗi thuật toán sẽ cần một class riêng.
- Phức tạp khi thuật toán đơn giản: Nếu hệ thống chỉ có một thuật toán, việc tách ra thành Strategy sẽ gây dư thừa.

### # ví dụ

Xây dựng một chương trình tính toán chi phí vận chuyển dựa trên các phương thức: đường bộ, đường thủy và đường hàng không.

Bước 1: Tạo interface Strategy:

```java
public interface ShippingStrategy {
    double calculateCost(double weight, double distance);
}
```

Bước 2: Tạo các Concrete Strategy

Phương thức vận chuyển đường bộ:

```java
public class RoadShipping implements ShippingStrategy {
    @Override
    public double calculateCost(double weight, double distance) {
        return weight * 1.5 + distance * 0.5;
    }
}
```

Phương thức vận chuyển đường thủy:

```java
public class SeaShipping implements ShippingStrategy {
    @Override
    public double calculateCost(double weight, double distance) {
        return weight * 1.0 + distance * 0.2;
    }
}
```

Phương thức vận chuyển đường hàng không:

```java
public class AirShipping implements ShippingStrategy {
    @Override
    public double calculateCost(double weight, double distance) {
        return weight * 2.5 + distance * 1.0;
    }
}
```

Bước 3: Tạo lớp Context

```java
public class ShippingContext {
    private ShippingStrategy strategy;

    public ShippingContext(ShippingStrategy strategy) {
        this.strategy = strategy;
    }

    public void setStrategy(ShippingStrategy strategy) {
        this.strategy = strategy;
    }

    public double calculateShippingCost(double weight, double distance) {
        return strategy.calculateCost(weight, distance);
    }
}
```

Bước 4: Sử dụng Strategy Pattern

```java
public class StrategyPatternDemo {
    public static void main(String[] args) {
        double weight = 10.0; // trọng lượng hàng hóa
        double distance = 100.0; // khoảng cách vận chuyển

        // Vận chuyển bằng đường bộ
        ShippingContext context = new ShippingContext(new RoadShipping());
        System.out.println("Chi phí vận chuyển đường bộ: " + context.calculateShippingCost(weight, distance));

        // Thay đổi chiến lược sang vận chuyển đường thủy
        context.setStrategy(new SeaShipping());
        System.out.println("Chi phí vận chuyển đường thủy: " + context.calculateShippingCost(weight, distance));

        // Thay đổi chiến lược sang vận chuyển hàng không
        context.setStrategy(new AirShipping());
        System.out.println("Chi phí vận chuyển hàng không: " + context.calculateShippingCost(weight, distance));
    }
}
```

Kết quả Output:

```
Chi phí vận chuyển đường bộ: 65.0
Chi phí vận chuyển đường thủy: 30.0
Chi phí vận chuyển hàng không: 125.0
```

Trong ví dụ trên:

- Tính mở rộng: Nếu có thêm phương thức vận chuyển như "đường sắt", chỉ cần tạo một class mới RailShipping implement interface ShippingStrategy mà không cần sửa code cũ.
- Tính linh hoạt: Dễ dàng thay đổi thuật toán vận chuyển trong runtime bằng cách gọi setStrategy().

### # lời kết

`Strategy Pattern` là một công cụ mạnh mẽ trong lập trình hướng đối tượng, giúp tách biệt logic thuật toán và dễ dàng mở rộng. Đây là mẫu thiết kế phù hợp trong những trường hợp cần thay đổi thuật toán một cách linh hoạt và tránh các cấu trúc if-else lồng nhau.

Áp dụng `Strategy Pattern` không chỉ giúp hệ thống trở nên linh hoạt, dễ bảo trì mà còn tuân thủ các nguyên tắc thiết kế **SOLID**, đặc biệt là **_Open-Closed Principle_**.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
