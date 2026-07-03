---
layout: post
title: "singleton pattern in java"
date: 2024-08-22 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, design-pattern, vietnamese]
---

`Singleton Pattern` là một trong những Design Patterns nổi bật trong nhóm `Creational Pattern`, giúp quản lý việc tạo đối tượng trong một ứng dụng.

Được sử dụng để đảm bảo rằng một lớp chỉ có duy nhất một `instance (thể hiện)` và cung cấp một điểm truy cập toàn cục đến `instance` đó, `Singleton` được áp dụng phổ biến trong các ứng dụng khi cần chia sẻ tài nguyên hoặc quản lý trạng thái chung.

### # ưu điểm

- _**Tiết kiệm tài nguyên**_: `Singleton` giúp hạn chế việc tạo nhiều đối tượng không cần thiết, từ đó tiết kiệm tài nguyên hệ thống.
- **_Quản lý nhất quán_**: Với một `instance` duy nhất, trạng thái chung được quản lý dễ dàng và nhất quán.
- **_Dễ triển khai và sử dụng_**: Cách triển khai đơn giản và rõ ràng giúp lập trình viên dễ dàng tiếp cận và tích hợp.

### # nhược điểm

- **_Khó khăn trong việc mở rộng_**: Việc mở rộng lớp `Singleton` có thể gặp khó khăn do ràng buộc instance duy nhất.
- **_Khả năng gây ra vấn đề trong môi trường đa luồng_**: `Singleton` không được triển khai đúng cách có thể dẫn đến race condition và các lỗi liên quan đến `concurrency`.
- **_Phụ thuộc vào trạng thái toàn cục_**: Nếu không được quản lý cẩn thận, `Singleton` có thể dẫn đến việc chia sẻ trạng thái không mong muốn, gây khó khăn trong việc debug và bảo trì.

### # implementation

`Singleton Pattern` thường được áp dụng trong các tình huống như:

- **_Quản lý kết nối cơ sở dữ liệu_**: Đảm bảo rằng chỉ có một kết nối duy nhất đến cơ sở dữ liệu tại một thời điểm.
- _**Cấu hình ứng dụng**_: Lưu trữ các thông tin cấu hình chung mà nhiều thành phần khác nhau của ứng dụng cần truy cập.
- **_Logging_**: Duy trì một logger duy nhất để ghi lại các thông tin log trong ứng dụng.
- **_Cơ chế cache_**: Quản lý cache tập trung để tối ưu hóa việc truy xuất dữ liệu.

Có nhiều cách để triển khai `Singleton Pattern` trong Java, từ cách đơn giản nhất đến những cách tối ưu hóa cao cấp hơn để hỗ trợ môi trường đa luồng.

Nhưng dù cho việc implement bằng cách nào đi nữa cũng dựa vào nguyên tắc dưới đây cơ bản dưới đây:

- **_private constructor_** để hạn chế truy cập từ class bên ngoài.
- Đặt **_private static final variable_** đảm bảo biến chỉ được khởi tạo trong class.
- Có một method **_public static_** để **_return instance_** được khởi tạo ở trên.

Dưới đây là một số cách triển khai phổ biến.

#### # singleton cơ bản

```java
public class BasicSingleton {
    private static BasicSingleton instance;

    private BasicSingleton() {
        // Ngăn không cho khởi tạo từ bên ngoài
    }

    public static BasicSingleton getInstance() {
        if (instance == null) {
            instance = new BasicSingleton();
        }
        return instance;
    }
}
```

Cách triển khai này đơn giản, dễ hiểu nhưng không an toàn trong môi trường đa luồng.

Nếu hai luồng gọi `getInstance()` cùng lúc, có thể dẫn đến việc tạo ra hai `instance`.

#### # singleton với synchronized

```java
public class ThreadSafeSingleton {
    private static ThreadSafeSingleton instance;

    private ThreadSafeSingleton() {}

    public static synchronized ThreadSafeSingleton getInstance() {
        if (instance == null) {
            instance = new ThreadSafeSingleton();
        }
        return instance;
    }
}
```

Tuy cách này đảm bảo an toàn trong môi trường đa luồng. Tuy nhiên sử dụng từ khóa `synchronized` khiến hiệu suất giảm trong trường hợp `getInstance()` được gọi thường xuyên.

#### # double-checked locking

```java
public class DCLSingleton {
    private static volatile DCLSingleton instance;

    private DCLSingleton() {}

    public static DCLSingleton getInstance() {
        if (instance == null) {
            synchronized (DCLSingleton.class) {
                if (instance == null) {
                    instance = new DCLSingleton();
                }
            }
        }
        return instance;
    }
}
```

Nhận xét đây là cách triển khai tối ưu, tránh được việc đồng bộ hóa liên tục, nâng cao hiệu suất. Nhược điểm duy nhất là pức tạp hơn so với các cách khác.

#### # singleton sử dụng Enum

```java
public enum EnumSingleton {
    INSTANCE;

    public void showMessage() {
        System.out.println("Hello from Singleton!");
    }
}
```

Cách tiếp cận này là an toàn nhất, đảm bảo chống lại việc phá vỡ Singleton trong Java nhờ đặc tính của Enum. Nhưng không linh hoạt nếu cần khởi tạo Singleton với tham số.

### # ví dụ bonus

Giả sử bạn cần một Logger duy nhất trong toàn bộ ứng dụng:

```java
public class Logger {
    private static Logger instance;

    private Logger() {}

    public static Logger getInstance() {
        if (instance == null) {
            synchronized (Logger.class) {
                if (instance == null) {
                    instance = new Logger();
                }
            }
        }
        return instance;
    }

    public void log(String message) {
        System.out.println("[LOG] " + message);
    }
}

// Cách sử dụng
public class MainApp {
    public static void main(String[] args) {
        Logger logger = Logger.getInstance();
        logger.log("Application started");
    }
}
```

### # lời kết

`Singleton Pattern` là một trong những pattern đơn giản nhưng hiệu quả, thường xuyên xuất hiện trong các dự án thực tế.

Khi triển khai `Singleton`, cần cân nhắc đến môi trường đa luồng và hiệu suất của ứng dụng để chọn phương pháp phù hợp nhất.

Nhờ vào việc quản lý tài nguyên tốt và cung cấp tính nhất quán, `Singleton` vẫn luôn là một lựa chọn đáng cân nhắc trong các tình huống sử dụng cụ thể.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
