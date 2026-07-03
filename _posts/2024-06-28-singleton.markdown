---
layout: post
title: "Singleton Pattern trong Java"
date: 2024-06-28 19:29:39 +0700
categories: [Software Development]
tags: [Java, Design Pattern]
---

`Singleton Pattern` là một trong những Design Patterns nổi bật trong nhóm `Creational Pattern`, giúp quản lý việc tạo đối tượng trong một ứng dụng.

Được sử dụng để đảm bảo rằng một lớp chỉ có duy nhất một `instance (thể hiện)` và cung cấp một điểm truy cập toàn cục đến `instance` đó, `Singleton` được áp dụng phổ biến trong các ứng dụng khi cần chia sẻ tài nguyên hoặc quản lý trạng thái chung.

### 1. Ưu điểm
- _**Tiết kiệm tài nguyên**_: `Singleton` giúp hạn chế việc tạo nhiều đối tượng không cần thiết, từ đó tiết kiệm tài nguyên hệ thống.
- **_Quản lý nhất quán_**: Với một `instance` duy nhất, trạng thái chung được quản lý dễ dàng và nhất quán.
- **_Dễ triển khai và sử dụng_**: Cách triển khai đơn giản và rõ ràng giúp lập trình viên dễ dàng tiếp cận và tích hợp.

### 2. Nhược điểm
- **_Khó khăn trong việc mở rộng_**: Việc mở rộng lớp `Singleton` có thể gặp khó khăn do ràng buộc instance duy nhất.
- **_Khả năng gây ra vấn đề trong môi trường đa luồng_**: `Singleton` không được triển khai đúng cách có thể dẫn đến race condition và các lỗi liên quan đến `concurrency`.
- **_Phụ thuộc vào trạng thái toàn cục_**: Nếu không được quản lý cẩn thận, `Singleton` có thể dẫn đến việc chia sẻ trạng thái không mong muốn, gây khó khăn trong việc debug và bảo trì.

### 3. Implement
`Singleton Pattern` thường được áp dụng trong các tình huống như:
- **_Quản lý kết nối cơ sở dữ liệu_**: Đảm bảo rằng chỉ có một kết nối duy nhất đến cơ sở dữ liệu tại một thời điểm.
- *__Cấu hình ứng dụng__*: Lưu trữ các thông tin cấu hình chung mà nhiều thành phần khác nhau của ứng dụng cần truy cập.
- **_Logging_**: Duy trì một logger duy nhất để ghi lại các thông tin log trong ứng dụng.
- **_Cơ chế cache_**: Quản lý cache tập trung để tối ưu hóa việc truy xuất dữ liệu.

Có nhiều cách để triển khai `Singleton Pattern` trong Java, từ cách đơn giản nhất đến những cách tối ưu hóa cao cấp hơn để hỗ trợ môi trường đa luồng.

Dưới đây là một số cách triển khai phổ biến.

#### 3.1 Singleton cơ bản
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


#### 3.2 Singleton với từ khóa synchronized
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


#### 3.3 Double-checked locking
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


#### 3.4 Singleton sử dụng Enum
```java
public enum EnumSingleton {
    INSTANCE;

    public void showMessage() {
        System.out.println("Hello from Singleton!");
    }
}
```
Cách tiếp cận này là an toàn nhất, đảm bảo chống lại việc phá vỡ Singleton trong Java nhờ đặc tính của Enum. Nhưng không linh hoạt nếu cần khởi tạo Singleton với tham số.

### 4. Ví dụ bonus thêm
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

### Lời kết

`Singleton Pattern` là một trong những pattern đơn giản nhưng hiệu quả, thường xuyên xuất hiện trong các dự án thực tế.

Khi triển khai `Singleton`, cần cân nhắc đến môi trường đa luồng và hiệu suất của ứng dụng để chọn phương pháp phù hợp nhất.

Nhờ vào việc quản lý tài nguyên tốt và cung cấp tính nhất quán, `Singleton` vẫn luôn là một lựa chọn đáng cân nhắc trong các tình huống sử dụng cụ thể.

> P/S: Nếu bạn thấy bài viết này hữu ích, đừng quên chia sẻ với bạn bè và đồng nghiệp của mình nhé!

Happy coding! 😎 👍🏻 🚀 🔥