---
layout: post
title: "visitor pattern trong java"
date: 2025-02-06 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, design-pattern, vietnamese]
---

`Visitor Pattern` là một mẫu thiết kế hành vi **(Behavioral Design Pattern)** cho phép tách rời các thao tác trên một đối tượng khỏi cấu trúc của đối tượng đó. Nó giúp bạn có thể thêm các hành vi mới vào một lớp mà không cần thay đổi chính lớp đó.

Visitor Pattern rất hữu ích khi:

- Bạn muốn thực hiện các hoạt động khác nhau trên các đối tượng của một cấu trúc phức tạp.
- Bạn cần mở rộng các thao tác mà không làm thay đổi cấu trúc lớp ban đầu (tuân thủ Open/Closed Principle trong SOLID).

Visitor Pattern gồm các thành phần chính:

- Visitor Interface: Định nghĩa các phương thức xử lý cho từng loại đối tượng cụ thể.
- Concrete Visitor: Hiện thực các phương thức của Visitor interface.
- Element Interface: Định nghĩa phương thức accept() để cho phép Visitor truy cập.
- Concrete Elements: Hiện thực phương thức accept() và gọi lại phương thức của Visitor.
- Client: Gửi yêu cầu tới các phần tử và visitor.

### # ưu Điểm

- Dễ dàng mở rộng hành vi mới: Bạn có thể thêm các Visitor mới mà không cần thay đổi các lớp hiện tại.
- Tách biệt logic xử lý: Các thao tác logic được tách ra khỏi cấu trúc đối tượng, giúp code dễ bảo trì và mở rộng.

### # nhược Điểm

- Phức tạp khi thêm loại phần tử mới: Nếu cần thêm lớp mới vào hệ thống, bạn phải chỉnh sửa tất cả các lớp Visitor.
- Không phù hợp với hệ thống nhỏ: Với các hệ thống đơn giản, việc triển khai Visitor có thể quá mức cần thiết.

### # khi nào nên sử dụng

- Khi hệ thống có cấu trúc phức tạp và nhiều đối tượng khác nhau cần áp dụng các hành vi giống nhau.
- Khi bạn cần thêm hành vi mới mà không muốn làm thay đổi mã nguồn hiện có.

### # ví dụ

Hãy cùng thực hiện một ví dụ cụ thể về Visitor Pattern để tính thuế cho các sản phẩm khác nhau: sách, thuốc và các mặt hàng tạp hóa.

Bước 1: Tạo Interface Visitor

```java
interface Visitor {
    void visit(Book book);
    void visit(Medicine medicine);
    void visit(Grocery grocery);
}
```

Bước 2: Tạo Interface Element

```java
interface Element {
    void accept(Visitor visitor);
}
```

Bước 3: Tạo Các Concrete Element

```java
class Book implements Element {
    private double price;
    private String title;

    public Book(double price, String title) {
        this.price = price;
        this.title = title;
    }

    public double getPrice() {
        return price;
    }

    public String getTitle() {
        return title;
    }

    @Override
    public void accept(Visitor visitor) {
        visitor.visit(this);
    }
}

class Medicine implements Element {
    private double price;
    private String name;

    public Medicine(double price, String name) {
        this.price = price;
        this.name = name;
    }

    public double getPrice() {
        return price;
    }

    public String getName() {
        return name;
    }

    @Override
    public void accept(Visitor visitor) {
        visitor.visit(this);
    }
}

class Grocery implements Element {
    private double price;
    private String item;

    public Grocery(double price, String item) {
        this.price = price;
        this.item = item;
    }

    public double getPrice() {
        return price;
    }

    public String getItem() {
        return item;
    }

    @Override
    public void accept(Visitor visitor) {
        visitor.visit(this);
    }
}
```

Bước 4: Tạo Concrete Visitor

```java
class TaxVisitor implements Visitor {

    @Override
    public void visit(Book book) {
        double tax = book.getPrice() * 0.1;
        System.out.println("Book: " + book.getTitle() + ", Tax: " + tax);
    }

    @Override
    public void visit(Medicine medicine) {
        double tax = medicine.getPrice() * 0.05;
        System.out.println("Medicine: " + medicine.getName() + ", Tax: " + tax);
    }

    @Override
    public void visit(Grocery grocery) {
        double tax = grocery.getPrice() * 0.0;
        System.out.println("Grocery: " + grocery.getItem() + ", Tax: " + tax);
    }
}
```

Bước 5: Tạo Client

```java
public class VisitorPatternDemo {
    public static void main(String[] args) {
        Element book = new Book(100, "Clean Code");
        Element medicine = new Medicine(200, "Paracetamol");
        Element grocery = new Grocery(50, "Rice");

        Visitor taxVisitor = new TaxVisitor();

        book.accept(taxVisitor);
        medicine.accept(taxVisitor);
        grocery.accept(taxVisitor);
    }
}
```

Ví dụ trên cho ta thấy rằng:

- Tách biệt logic tính thuế khỏi các lớp Book, Medicine, và Grocery.
- Dễ mở rộng: Nếu muốn thêm loại thuế mới (ví dụ thuế môi trường), chỉ cần tạo một Visitor mới mà không thay đổi các lớp Element.
- Mở rộng Visitor: Dễ dàng thêm các chức năng mới như in báo cáo, tính phí bảo hiểm, v.v.

### # lời kết

`Visitor Pattern` là một công cụ mạnh mẽ trong thiết kế phần mềm, giúp tách rời logic xử lý khỏi cấu trúc đối tượng. Mặc dù việc thêm phần tử mới có thể phức tạp, nhưng lợi ích trong việc mở rộng hành vi và bảo trì mã nguồn rất đáng giá.

Khi làm việc với các hệ thống lớn, đặc biệt trong các ứng dụng tài chính, thương mại điện tử, `Visitor Pattern` sẽ phát huy tối đa sức mạnh của nó.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
