---
layout: post
title: "command pattern in java"
date: 2025-01-09 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, design-pattern, vietnamese]
---

`Command Pattern` là một mẫu thiết kế thuộc nhóm **Behavioral Patterns** trong Design Patterns. Mẫu này giúp đóng gói các yêu cầu hoặc lệnh (command) thành các đối tượng độc lập, cho phép hệ thống tách biệt người gọi lệnh và người thực thi lệnh.

Command Pattern thường được sử dụng trong các tình huống như:

- Undo/Redo trong các ứng dụng.
- Macro để nhóm nhiều lệnh thành một lệnh.
- Menu, nút bấm trong GUI hoặc hệ thống yêu cầu nhiều thao tác lệnh.

Command Pattern bao gồm các thành phần chính:

- Command (Giao diện hoặc lớp trừu tượng): Định nghĩa phương thức execute() và undo() để thực thi và hoàn tác lệnh.
- Concrete Command (Lớp triển khai Command): Triển khai giao diện Command và thực thi các thao tác cụ thể.
- Receiver (Người nhận lệnh): Lớp thực thi các yêu cầu cụ thể.
- Invoker (Người gọi lệnh): Lưu trữ lệnh và gọi phương thức execute() để thực thi lệnh.
- Client: Tạo đối tượng lệnh và gán lệnh cho Invoker.

![command-uml]({{ site.baseurl }}/assets/img/blog/command-uml.png)

Sơ đồ UML:

```
+------------------+        +------------------+
|   Command        |        |   Invoker        |
|------------------|        |------------------|
| + execute()      |        | + setCommand()   |
| + undo()         |        | + executeCommand()|
+------------------+        +------------------+
            |                         |
            v                         |
+------------------+                  |
|   ConcreteCommand|                  |
|------------------|                  v
| + execute()      |        +------------------+
| + undo()         |        |   Receiver       |
+------------------+        |------------------|
                            | + action()       |
                            +------------------+
```

### # ưu điểm

- Tách biệt giữa người gọi lệnh và người thực thi lệnh: Command Pattern giúp giảm sự phụ thuộc giữa các lớp.
- Dễ dàng mở rộng và bảo trì: Có thể thêm lệnh mới mà không làm thay đổi mã nguồn hiện tại.
- Hỗ trợ tính năng Undo/Redo: Việc đóng gói lệnh thành các đối tượng cho phép dễ dàng lưu lại và hoàn tác các lệnh.
- Linh hoạt trong xử lý yêu cầu: Có thể xếp hàng (queue), log, hoặc thực thi lệnh trễ (delayed execution).

### # nhược điểm

- Phức tạp hóa hệ thống: Với những dự án nhỏ, Command Pattern có thể tạo ra quá nhiều lớp.
- Tốn tài nguyên bộ nhớ: Mỗi lệnh được lưu thành một đối tượng riêng biệt, có thể gây tiêu tốn bộ nhớ nếu có nhiều lệnh.

### # khi nào sử dụng

- Khi bạn muốn tách biệt giữa người gọi lệnh và người thực thi lệnh.
- Khi bạn cần hỗ trợ Undo/Redo hoặc lưu trữ lịch sử thao tác.
- Khi bạn muốn xếp hàng (queue) hoặc thực thi lệnh sau một khoảng thời gian.
- Khi hệ thống của bạn yêu cầu các macro command – tức là thực thi nhiều lệnh một lúc.

### ví dụ

Chúng ta sẽ triển khai Command Pattern mô phỏng một hệ thống điều khiển từ xa đơn giản.

Tạo Command Interface:

```java
public interface Command {
    void execute();
    void undo();
}

```

Tạo Receiver:

```java
public class Light {
    public void turnOn() {
        System.out.println("Đèn đã bật");
    }

    public void turnOff() {
        System.out.println("Đèn đã tắt");
    }
}
```

Tạo Concrete Command:

```java
public class LightOnCommand implements Command {
    private Light light;

    public LightOnCommand(Light light) {
        this.light = light;
    }

    @Override
    public void execute() {
        light.turnOn();
    }

    @Override
    public void undo() {
        light.turnOff();
    }
}

public class LightOffCommand implements Command {
    private Light light;

    public LightOffCommand(Light light) {
        this.light = light;
    }

    @Override
    public void execute() {
        light.turnOff();
    }

    @Override
    public void undo() {
        light.turnOn();
    }
}
```

Tạo Invoker:

```java
public class RemoteControl {
    private Command command;

    public void setCommand(Command command) {
        this.command = command;
    }

    public void pressButton() {
        command.execute();
    }

    public void pressUndo() {
        command.undo();
    }
}
```

Tạo Client:

```java
public class CommandPatternExample {
    public static void main(String[] args) {
        Light livingRoomLight = new Light();

        Command lightOnCommand = new LightOnCommand(livingRoomLight);
        Command lightOffCommand = new LightOffCommand(livingRoomLight);

        RemoteControl remote = new RemoteControl();

        // Bật đèn
        remote.setCommand(lightOnCommand);
        remote.pressButton(); // Output: Đèn đã bật

        // Tắt đèn
        remote.setCommand(lightOffCommand);
        remote.pressButton(); // Output: Đèn đã tắt

        // Undo hành động cuối
        remote.pressUndo(); // Output: Đèn đã bật
    }
}
```

Output:

```
Đèn đã bật
Đèn đã tắt
Đèn đã bật
```

### # lời kết

`Command Pattern` là một trong những mẫu thiết kế linh hoạt giúp đóng gói các yêu cầu thành các đối tượng riêng biệt. Trong Java, nó thường được sử dụng trong các hệ thống lớn cần xử lý Undo/Redo, lập lịch hoặc điều khiển các thao tác người dùng.

Ví dụ trên minh họa cách chúng ta triển khai Command Pattern trong một hệ thống điều khiển từ xa đơn giản. Với ưu điểm mở rộng và bảo trì dễ dàng, `Command Pattern` là một lựa chọn lý tưởng cho nhiều bài toán trong lập trình Java.

Nếu bạn đang phát triển các ứng dụng phức tạp, như ứng dụng desktop GUI, hệ thống giao dịch hoặc các ứng dụng cần lưu trữ lịch sử thao tác, `Command Pattern`là một giải pháp không thể bỏ qua.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
