---
layout: post
title: "adapter pattern in java"
date: 2024-10-31 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, design-pattern, vietnamese]
---

Trong thiết kế phần mềm, `Adapter Pattern` (hay còn gọi là Wrapper) là một mẫu thiết kế thuộc nhóm **Structural Design Patterns**. Mẫu này giúp chuyển đổi giao diện của một lớp thành một giao diện mà khách hàng mong đợi, cho phép các lớp có giao diện không tương thích làm việc cùng nhau.

Hãy tưởng tượng bạn có một cổng USB nhưng lại cần kết nối với thiết bị chỉ hỗ trợ cổng HDMI. Adapter chính là giải pháp trung gian để thực hiện kết nối này.

### # mục đích

- Khả năng tích hợp: Kết nối các hệ thống hoặc lớp với giao diện khác nhau mà không cần thay đổi mã nguồn ban đầu.
- **_Tăng khả năng tái sử dụng_**: Cho phép sử dụng lại các lớp cũ mà không cần chỉnh sửa.
- **_Đơn giản hóa mã nguồn_**: Tách biệt các logic chuyển đổi giao diện khỏi phần logic chính của ứng dụng.

### # khi nào nên dùng

- Khi bạn cần sử dụng một lớp đã có nhưng giao diện của nó không khớp với yêu cầu của hệ thống.
- Khi cần tích hợp hệ thống cũ với hệ thống mới.
- Khi cần áp dụng một tiêu chuẩn giao diện chung cho nhiều lớp khác nhau.

Một số trường hợp thực tế thường hay dùng Adapter:

- **_Tích hợp thư viện cũ_**: Adapter Pattern được sử dụng rộng rãi để tích hợp các hệ thống hoặc thư viện cũ với hệ thống mới.
- **_API Gateway_**: Trong microservices, Adapter Pattern thường được sử dụng để chuẩn hóa giao diện giữa các dịch vụ khác nhau.
- **_ Xử lý dữ liệu đa nguồn_**: Khi các nguồn dữ liệu khác nhau sử dụng định dạng khác nhau, Adapter giúp chuyển đổi dữ liệu về một định dạng chuẩn.

### # ưu điểm

- **_Tăng tính linh hoạt_**: Dễ dàng tích hợp các lớp hoặc module có giao diện khác nhau.
- **_Tái sử dụng_**: Có thể sử dụng lại các lớp hiện có mà không phải sửa đổi chúng.
- **_Đơn giản hóa bảo trì_**: Tách biệt logic chuyển đổi giao diện giúp dễ dàng bảo trì và nâng cấp hệ thống.

### # nhược điểm

- **_Phức tạp hóa thiết kế_**: Khi hệ thống có quá nhiều adapter, có thể gây khó khăn trong việc quản lý và bảo trì.
- **_Giới hạn hiệu năng_**: Sử dụng adapter có thể thêm overhead nhỏ do việc chuyển đổi giao diện.

### # cấu trúc

Adapter Pattern thường có hai cách triển khai chính trong Java:

- **_Class Adapter (Sử dụng kế thừa)_**: Adapter kế thừa từ lớp cần tích hợp và triển khai giao diện mục tiêu.
- **_Object Adapter (Sử dụng ủy quyền)_**: Adapter sử dụng một đối tượng của lớp cần tích hợp, thay vì kế thừa.

Class Adapter (Kế Thừa):

```java
// Giao diện mục tiêu
public interface Target {
    void request();
}

// Lớp hiện có (không tương thích)
public class Adaptee {
    public void specificRequest() {
        System.out.println("Specific request is being called.");
    }
}

// Adapter sử dụng kế thừa
public class ClassAdapter extends Adaptee implements Target {
    @Override
    public void request() {
        specificRequest(); // Chuyển đổi gọi phương thức
    }
}

// Sử dụng Adapter
public class Main {
    public static void main(String[] args) {
        Target target = new ClassAdapter();
        target.request();
    }
}
```

Object Adapter (Ủy Quyền):

```java
// Giao diện mục tiêu
public interface Target {
    void request();
}

// Lớp hiện có (không tương thích)
public class Adaptee {
    public void specificRequest() {
        System.out.println("Specific request is being called.");
    }
}

// Adapter sử dụng ủy quyền
public class ObjectAdapter implements Target {
    private Adaptee adaptee;

    public ObjectAdapter(Adaptee adaptee) {
        this.adaptee = adaptee;
    }

    @Override
    public void request() {
        adaptee.specificRequest(); // Chuyển đổi gọi phương thức
    }
}

// Sử dụng Adapter
public class Main {
    public static void main(String[] args) {
        Adaptee adaptee = new Adaptee();
        Target target = new ObjectAdapter(adaptee);
        target.request();
    }
}
```

So Sánh Class Adapter và Object Adapter:
| **Tiêu Chí** | **Class Adapter** | **Object Adapter** |
|-------------------|------------------------------------|-----------------------------------------|
| **Kế thừa** | Sử dụng kế thừa (_extends_) | Sử dụng ủy quyền (_composition_) |
| **Tính linh hoạt**| Ít linh hoạt (bị ràng buộc bởi lớp cơ sở) | Linh hoạt hơn (không bị giới hạn bởi kế thừa) |
| **Tái sử dụng** | Chỉ làm việc với một lớp cụ thể | Có thể làm việc với nhiều lớp khác nhau |

### # ví dụ

Hãy xem xét một ví dụ về việc tích hợp một thư viện thanh toán cũ vào hệ thống hiện đại.

```java
// Giao diện thanh toán mới
public interface PaymentGateway {
    void processPayment(String customerName, double amount);
}

// Thư viện thanh toán cũ
public class OldPaymentSystem {
    public void makePayment(String name, double money) {
        System.out.println("Payment of " + money + " made by " + name + " using old system.");
    }
}

// Adapter cho thư viện cũ
public class PaymentAdapter implements PaymentGateway {
    private OldPaymentSystem oldPaymentSystem;

    public PaymentAdapter(OldPaymentSystem oldPaymentSystem) {
        this.oldPaymentSystem = oldPaymentSystem;
    }

    @Override
    public void processPayment(String customerName, double amount) {
        oldPaymentSystem.makePayment(customerName, amount); // Chuyển đổi gọi phương thức
    }
}

// Sử dụng
public class Main {
    public static void main(String[] args) {
        OldPaymentSystem oldPaymentSystem = new OldPaymentSystem();
        PaymentGateway paymentGateway = new PaymentAdapter(oldPaymentSystem);

        paymentGateway.processPayment("John Doe", 250.75);
    }
}
```

Kết quả:

```
Payment of 250.75 made by John Doe using old system.
```

### # lời kết

`Adapter Pattern` là một giải pháp mạnh mẽ để xử lý các vấn đề không tương thích trong phần mềm, giúp tăng tính tái sử dụng và giảm thiểu sự phức tạp khi tích hợp các hệ thống hoặc thư viện khác nhau. Dù có một số nhược điểm nhỏ, nhưng lợi ích mà mẫu thiết kế này mang lại là không thể phủ nhận.

Khi ứng dụng `Adapter Pattern` trong Java, bạn nên cân nhắc cách triển khai phù hợp nhất (Class Adapter hoặc Object Adapter) để tối ưu hóa tính linh hoạt và khả năng bảo trì của hệ thống. Hãy nhớ rằng, mục tiêu cuối cùng của mẫu thiết kế này là làm cho các phần khác biệt trong hệ thống hoạt động hài hòa như một tổng thể.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
