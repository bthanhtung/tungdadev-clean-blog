---
layout: post
title: "factory pattern in java"
date: 2024-09-05 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, design-pattern, vietnamese]
---

`Factory Method Pattern` là một trong những mẫu thiết kế thuộc nhóm `Creational Design Patterns`, tập trung vào việc tạo đối tượng mà không tiết lộ logic khởi tạo cụ thể cho client. Thay vì sử dụng từ khóa `new` để tạo đối tượng, pattern này cung cấp một phương thức hoặc lớp chuyên phụ trách công việc này, cho phép mã nguồn linh hoạt và dễ bảo trì hơn.

`Factory Method` định nghĩa một `interface` để tạo đối tượng, nhưng cho phép các lớp con quyết định loại đối tượng nào sẽ được tạo. Điều này thúc đẩy tính đóng gói và phân quyền trong việc khởi tạo đối tượng.

### # ưu điểm

- **_Tăng tính mở rộng (Extensibility)_**: Khi cần thêm loại đối tượng mới, bạn chỉ cần mở rộng lớp và triển khai phương thức factory. Không cần thay đổi mã hiện có.

- **_Tách biệt logic khởi tạo_**: Logic tạo đối tượng được cô lập trong `Factory Method`, giúp mã nguồn rõ ràng và dễ kiểm soát hơn.

- **_Tuân theo nguyên tắc SOLID_**:
  - Đặc biệt là nguyên tắc `Open/Closed Principle` (mở để mở rộng, đóng để sửa đổi).
  - Đảm bảo rằng đối tượng ở client không bị ảnh hưởng bởi thay đổi trong logic khởi tạo.
- **_Hỗ trợ Dependency Injection_**: Factory Method giúp quản lý `dependency` dễ dàng hơn, đặc biệt trong các ứng dụng phức tạp.

### # nhược điểm

- **_Tăng độ phức tạp_**: Khi triển khai `Factory Method`, số lượng lớp và interface có thể tăng, khiến cấu trúc hệ thống trở nên phức tạp hơn.

- **_Có thể gây dư thừa_**: Trong các trường hợp đơn giản, việc sử dụng `Factory Method` có thể không cần thiết, dẫn đến dư thừa không đáng có. Giống như việc, dùng dao mổ trâu để giết gà vậy :v

- **_Hiệu năng thấp hơn_**: So với việc trực tiếp sử dụng từ khóa `new`, `Factory Method` có thể làm giảm hiệu năng (nhưng không đáng kể trong đa số trường hợp).

### # khi nào nên dùng

- Khi có nhiều lớp con với logic khởi tạo khác nhau: Ví dụ: Tạo các đối tượng khác nhau dựa trên loại sản phẩm (Product A, Product B, ...).
- Khi logic khởi tạo phức tạp: Factory Method tách riêng logic khởi tạo khỏi mã chính, giúp mã dễ hiểu và bảo trì.
- Khi cần mở rộng ứng dụng: Dễ dàng thêm loại đối tượng mới mà không cần thay đổi mã hiện tại.
- ...

### # ví dụ

Bài toán: Xây dựng Hệ thống thông báo (Notification System)

Một hệ thống có thể gửi nhiều loại thông báo khác nhau như **_Email, SMS, hoặc Push Notification_**. Thay vì để client chịu trách nhiệm khởi tạo từng loại thông báo, chúng ta sử dụng `Factory Method` để xử lý.

Định nghĩa Interface:

```java
// Notification.java
public interface Notification {
    void notifyUser();
}
```

Triển khai các lớp cụ thể:

```java
// EmailNotification.java
public class EmailNotification implements Notification {
    @Override
    public void notifyUser() {
        System.out.println("Sending an Email Notification");
    }
}

// SMSNotification.java
public class SMSNotification implements Notification {
    @Override
    public void notifyUser() {
        System.out.println("Sending an SMS Notification");
    }
}

// PushNotification.java
public class PushNotification implements Notification {
    @Override
    public void notifyUser() {
        System.out.println("Sending a Push Notification");
    }
}
```

Tạo Factory Method:

```java
// NotificationFactory.java
public class NotificationFactory {
    public Notification createNotification(String type) {
        if ("EMAIL".equalsIgnoreCase(type)) {
            return new EmailNotification();
        } else if ("SMS".equalsIgnoreCase(type)) {
            return new SMSNotification();
        } else if ("PUSH".equalsIgnoreCase(type)) {
            return new PushNotification();
        }
        return null;
    }
}
```

Sử dụng Factory Method:

Ở đây, ta giả sử hàm `main` là một `client` nào đó đang gọi và sử dụng các Factory Method đã định nghĩa bên trên:

```java
// Main.java
public class Main {
    public static void main(String[] args) {
        NotificationFactory factory = new NotificationFactory();

        Notification email = factory.createNotification("EMAIL");
        email.notifyUser();

        Notification sms = factory.createNotification("SMS");
        sms.notifyUser();

        Notification push = factory.createNotification("PUSH");
        push.notifyUser();
    }
}
```

Kết quả đầu ra:

```terminal
Sending an Email Notification
Sending an SMS Notification
Sending a Push Notification
```

Qua ví dụ trên ta có thể thấy, việc sử dụng Factory Method mang đến lợi ích rõ ràng:

- **_Tăng tính linh hoạt_**: Client không cần biết chi tiết lớp cụ thể nào được tạo ra.
- **_Dễ mở rộng_**: Nếu cần thêm loại thông báo mới (VD: SlackNotification), chỉ cần tạo lớp mới và sửa Factory Method.

### # lời kết

`Factory Method Pattern` mang lại nhiều lợi ích trong việc thiết kế phần mềm, đặc biệt là khi làm việc với các ứng dụng có nhiều lớp đối tượng khác nhau. Tuy nhiên, cần sử dụng mẫu thiết kế này đúng lúc, tránh việc lạm dụng làm tăng độ phức tạp không cần thiết.

Hãy cân nhắc sử dụng `Factory Method` khi:

- Bạn cần tách logic khởi tạo khỏi mã client.
- Ứng dụng của bạn dễ thay đổi hoặc mở rộng trong tương lai.

Hy vọng qua bài viết này, bạn đã có cái nhìn tổng quan và cụ thể về cách sử dụng F`actory Method Pattern` trong Java!

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
