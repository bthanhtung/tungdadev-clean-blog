---
layout: post
title: "abstract factory in java"
date: 2024-11-19 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, design-pattern, vietnamese]
---

`Abstract Factory` là một trong các mẫu thiết kế thuộc nhóm `Creational Design Pattern`. Mục tiêu chính của nó là cung cấp một `interface` để tạo ra các họ đối tượng liên quan hoặc phụ thuộc mà không cần chỉ rõ lớp cụ thể của chúng.

**_Tại sao cần Abstract Factory?_**: \
Khi bạn làm việc với hệ thống có các nhóm đối tượng liên quan (như các sản phẩm trong UI: Button, Checkbox, Dropdown) và muốn quản lý chúng nhất quán, `Abstract Factory` giúp đảm bảo rằng tất cả các đối tượng trong một nhóm sẽ phù hợp với nhau.

**_Khác biệt với Factory Method Pattern_**: \
Nếu `Factory Method` tạo một đối tượng cụ thể thì `Abstract Factory` tập trung vào việc tạo một nhóm đối tượng.

### # ưu điểm

- **_Tách biệt mã nguồn và đối tượng cụ thể_**: Giảm sự phụ thuộc vào các lớp cụ thể, giúp mã dễ bảo trì và mở rộng.
- **_Tăng tính linh hoạt_**: Dễ dàng thay đổi hoặc bổ sung các họ sản phẩm mới mà không ảnh hưởng đến mã hiện có.
- **_Tính nhất quán_**: Đảm bảo các đối tượng trong cùng một nhóm luôn tương thích.

### # nhược điểm

- **_Độ phức tạp cao hơn_**: Thiết kế phức tạp hơn khi chỉ cần tạo một số lượng ít đối tượng.
- **_Khó khăn trong việc mở rộng_**: Thêm sản phẩm mới vào một họ sản phẩm có thể yêu cầu thay đổi trong các factory hiện tại.

### # khi nào nên dùng

- Khi hệ thống của bạn cần tạo các nhóm đối tượng liên quan, như UI themes (Light và Dark theme).
- Khi bạn muốn tách biệt logic tạo đối tượng ra khỏi logic kinh doanh, giúp dễ dàng mở rộng và bảo trì.
- Trong các ứng dụng đa nền tảng, nơi các đối tượng được tạo khác nhau tùy theo nền tảng (Windows, MacOS, Linux).

### # ví dụ

Xây dựng một ứng dụng cần hỗ trợ cả hai giao diện `Light` và `Dark`. Mỗi giao diện có các thành phần UI riêng như `Button` và `Checkbox`.

Cài đặt `Abstract Factory Pattern` trong Java:

- **_Định nghĩa các Interfaces:_**

```java
// Button Interface
public interface Button {
    void render();
}

// Checkbox Interface
public interface Checkbox {
    void render();
}
```

- **_Triển khai cho Light Theme:_**

```java
// Light Button Implementation
public class LightButton implements Button {
    @Override
    public void render() {
        System.out.println("Rendering Light Button");
    }
}

// Light Checkbox Implementation
public class LightCheckbox implements Checkbox {
    @Override
    public void render() {
        System.out.println("Rendering Light Checkbox");
    }
}
```

- **_Triển khai cho Dark Theme:_**

```java
// Dark Button Implementation
public class DarkButton implements Button {
    @Override
    public void render() {
        System.out.println("Rendering Dark Button");
    }
}

// Dark Checkbox Implementation
public class DarkCheckbox implements Checkbox {
    @Override
    public void render() {
        System.out.println("Rendering Dark Checkbox");
    }
}
```

- **_Định nghĩa Abstract Factory:_**

```java
public interface UIFactory {
    Button createButton();
    Checkbox createCheckbox();
}
```

- **_Triển khai các Factory cụ thể:_**

```java
// Factory for Light Theme
public class LightUIFactory implements UIFactory {
    @Override
    public Button createButton() {
        return new LightButton();
    }

    @Override
    public Checkbox createCheckbox() {
        return new LightCheckbox();
    }
}

// Factory for Dark Theme
public class DarkUIFactory implements UIFactory {
    @Override
    public Button createButton() {
        return new DarkButton();
    }

    @Override
    public Checkbox createCheckbox() {
        return new DarkCheckbox();
    }
}
```

- **_Sử dụng Abstract Factory:_**

```java
public class Application {
    private final Button button;
    private final Checkbox checkbox;

    public Application(UIFactory factory) {
        this.button = factory.createButton();
        this.checkbox = factory.createCheckbox();
    }

    public void renderUI() {
        button.render();
        checkbox.render();
    }

    public static void main(String[] args) {
        UIFactory lightFactory = new LightUIFactory();
        Application lightApp = new Application(lightFactory);
        lightApp.renderUI();

        UIFactory darkFactory = new DarkUIFactory();
        Application darkApp = new Application(darkFactory);
        darkApp.renderUI();
    }
}
```

- **_Kết quả khi chạy chương trình:_**

```terminal
Rendering Light Button
Rendering Light Checkbox
Rendering Dark Button
Rendering Dark Checkbox
```

### # lời kết

`Abstract Factory Pattern` là một giải pháp mạnh mẽ để tạo các họ đối tượng liên quan mà không cần chỉ rõ lớp cụ thể của chúng. Mặc dù có một số nhược điểm về mặt phức tạp, nhưng pattern này vẫn rất hữu ích trong các ứng dụng lớn hoặc yêu cầu mở rộng linh hoạt.

Bạn có thể áp dụng `Abstract Factory` trong các dự án Java để đảm bảo mã nguồn rõ ràng, dễ bảo trì và dễ mở rộng.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
