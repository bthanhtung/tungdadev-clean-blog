---
layout: post
title: "decorator pattern in java"
date: 2024-11-14 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, design-pattern, vietnamese]
---

`Decorator Pattern` là một trong những **Structural Design Patterns** được giới thiệu trong cuốn sách _Design Patterns: Elements of Reusable Object-Oriented Software (GoF)_. Mẫu thiết kế này cho phép thêm các hành vi mới vào một đối tượng hiện có mà không làm thay đổi cấu trúc của nó. Đây là một giải pháp thay thế linh hoạt hơn so với việc sử dụng kế thừa.

Thay vì tạo ra một số lượng lớn lớp con để bổ sung các hành vi, `Decorator Pattern` cho phép chúng ta "gói" các hành vi này vào đối tượng tại runtime. Đồng thời, tuân thủ nguyên tắc OCP (Open/Closed Principle) - lớp chính không bị thay đổi khi thêm các tính năng mới.

### # cách hoạt động & cấu trúc

`Decorator Pattern` sử dụng các lớp Decorator để bọc (wrap) đối tượng gốc (component). Các decorator này triển khai cùng interface hoặc kế thừa cùng abstract class như đối tượng gốc, giúp mở rộng các chức năng của đối tượng mà không làm thay đổi mã nguồn của nó.

Decorator Pattern bao gồm các thành phần chính:

- **_Component (thành phần gốc)_**: Đây là interface hoặc abstract class mà các lớp Decorator và đối tượng gốc sẽ tuân theo.
  ConcreteComponent (thành phần cụ thể): Là lớp cơ bản triển khai interface hoặc abstract class Component.
- **_Decorator_**: Là lớp abstract hoặc interface bao bọc thành phần gốc. Nó triển khai Component và có tham chiếu đến một đối tượng Component.
- **_ConcreteDecorator (Decorator cụ thể)_**: Là lớp cụ thể kế thừa Decorator, thêm các hành vi mới.

### # ưu điểm

- **_Tăng tính linh hoạt:_** Bạn có thể thêm hành vi mới vào từng đối tượng riêng lẻ mà không ảnh hưởng đến các đối tượng khác.
- ***Không thay đổi mã gố***c: Decorator Pattern giúp mở rộng chức năng mà không sửa đổi mã nguồn gốc, tuân thủ nguyên tắc SOLID.
- **_Giảm số lượng lớp con_**: Giảm thiểu sự phức tạp do phải tạo nhiều lớp con cho từng trường hợp cụ thể.

### # nhược điểm

- **_Phức tạp hơn kế thừa_**: Khi có nhiều decorator lồng nhau, code sẽ trở nên khó đọc và khó hiểu.
- **_Khó debug_**: Việc debug các lớp decorator lồng nhau có thể gây khó khăn khi bạn cần xác định luồng thực thi.

### # khi nào nên sử dụng

- Khi cần thêm hành vi động cho một đối tượng mà không làm thay đổi cấu trúc của nó.
- Khi không thể sử dụng kế thừa do các hạn chế về runtime hoặc vấn đề thiết kế.
- Khi muốn giữ lớp gốc nhỏ gọn và tránh sự phình to do phải thêm quá nhiều tính năng.

### # ví dụ cụ thể trong Java

Giả sử chúng ta xây dựng một hệ thống cho phép tùy biến thức uống (coffee). Các thức uống cơ bản có thể được thêm topping như sữa, đường, caramel, v.v. mà không cần tạo quá nhiều lớp con.

Đầu tiên, chúng ta tạo cấu trúc cơ bản như sau:

```java
// Component
public interface Beverage {
    String getDescription();
    double getCost();
}

// ConcreteComponent
public class Espresso implements Beverage {
    @Override
    public String getDescription() {
        return "Espresso";
    }

    @Override
    public double getCost() {
        return 50.0;
    }
}
```

Tiếp đến, bắt đầu xây dựng lớp Decorator:

```java
// Decorator
public abstract class BeverageDecorator implements Beverage {
    protected Beverage beverage; // Tham chiếu tới đối tượng gốc

    public BeverageDecorator(Beverage beverage) {
        this.beverage = beverage;
    }

    @Override
    public String getDescription() {
        return beverage.getDescription();
    }

    @Override
    public double getCost() {
        return beverage.getCost();
    }
}
```

Thêm các ConcreteDecorator:

```java
// ConcreteDecorator: Thêm sữa
public class MilkDecorator extends BeverageDecorator {
    public MilkDecorator(Beverage beverage) {
        super(beverage);
    }

    @Override
    public String getDescription() {
        return beverage.getDescription() + ", Milk";
    }

    @Override
    public double getCost() {
        return beverage.getCost() + 10.0; // Thêm giá tiền cho sữa
    }
}

// ConcreteDecorator: Thêm đường
public class SugarDecorator extends BeverageDecorator {
    public SugarDecorator(Beverage beverage) {
        super(beverage);
    }

    @Override
    public String getDescription() {
        return beverage.getDescription() + ", Sugar";
    }

    @Override
    public double getCost() {
        return beverage.getCost() + 5.0; // Thêm giá tiền cho đường
    }
}
```

Cuối cùng, ráp các thành phần trên lại với nhau là xong:

```java
public class DecoratorPatternDemo {
    public static void main(String[] args) {
        // Tạo thức uống cơ bản
        Beverage espresso = new Espresso();
        System.out.println(espresso.getDescription() + " => Cost: " + espresso.getCost());

        // Thêm sữa
        Beverage espressoWithMilk = new MilkDecorator(espresso);
        System.out.println(espressoWithMilk.getDescription() + " => Cost: " + espressoWithMilk.getCost());

        // Thêm sữa và đường
        Beverage espressoWithMilkAndSugar = new SugarDecorator(espressoWithMilk);
        System.out.println(espressoWithMilkAndSugar.getDescription() + " => Cost: " + espressoWithMilkAndSugar.getCost());
    }
}
```

### # lời kết

`Decorator Pattern` là một mẫu thiết kế mạnh mẽ giúp mở rộng chức năng của đối tượng một cách linh hoạt và hiệu quả.

Khi sử dụng `Decorator Pattern`, hãy luôn chú ý đến sự phức tạp tiềm ẩn và cân nhắc liệu đây có phải là giải pháp tốt nhất cho bài toán của bạn. Đơn giản là chìa khóa để duy trì và mở rộng hệ thống lâu dài.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
