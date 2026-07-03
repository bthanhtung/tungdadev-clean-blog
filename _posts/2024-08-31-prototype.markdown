---
layout: post
title: "Prototype Pattern trong Java"
date: 2024-08-31 19:29:39 +0700
categories: [Software Development]
tags: [Java, Design Pattern]
---

`Prototype Pattern` là một trong các mẫu thiết kế thuộc nhóm `Creational Patterns`. Nó cho phép tạo ra các đối tượng mới bằng cách sao chép các đối tượng hiện có thay vì khởi tạo chúng từ đầu. Điều này giúp giảm chi phí khởi tạo, đặc biệt khi đối tượng có cấu trúc phức tạp hoặc việc tạo đối tượng mới tốn kém tài nguyên.

Trong Java, `Prototype Pattern` được hiện thực hóa thông qua việc triển khai `interface Cloneable` và sử dụng phương thức `clone()` của lớp Object.

Cách hoạt động của Prototype Pattern:
**_Prototype_**: Là đối tượng ban đầu, được dùng làm cơ sở để sao chép.
**_Client_**: Yêu cầu tạo các đối tượng bằng cách sao chép từ `prototype`.

### 1. Ưu điểm
- **_Hiệu suất tốt hơn_**: Tránh chi phí tạo mới từ đầu khi đối tượng có cấu trúc phức tạp.
- **_Linh hoạt_**: Có thể tạo nhiều bản sao độc lập và dễ dàng tùy chỉnh.
- **_Đơn giản hóa_**: Giảm sự phụ thuộc vào các lớp cụ thể trong quá trình khởi tạo.

### 2. Nhược điểm
- **_Khó bảo trì_**: Việc sao chép các đối tượng phức tạp có thể gặp lỗi nếu không quản lý đúng cách.
- **_Clone phức tạp_**: Sao chép các đối tượng có chứa tài nguyên hoặc con trỏ đòi hỏi phải xử lý deep clone thay vì shallow clone.
- **_Sử dụng Cloneable không trực quan_**: Interface Cloneable trong Java có thiết kế lỗi thời, dễ gây nhầm lẫn.

### 3. Trường hợp sử dụng
Khi chi phí tạo đối tượng mới quá lớn (ví dụ: đối tượng kết nối đến cơ sở dữ liệu, tài nguyên hệ thống).
Khi cần nhiều bản sao của một đối tượng với những tinh chỉnh nhỏ.
Khi các đối tượng cần giữ trạng thái độc lập.

### 4. Ví dụ
Bài toán: Một công ty cần tạo nhiều đối tượng hình học `(Circle, Rectangle)` với thông tin giống nhau nhưng có thể thay đổi chi tiết nhỏ.

Ta có thể triển khai Prototype Pattern như sau:

```java
// 1. Lớp Shape - Prototype
abstract class Shape implements Cloneable {
    private String id;
    protected String type;

    abstract void draw();

    public String getType() {
        return type;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    // Clone method
    @Override
    protected Object clone() {
        Object clone = null;
        try {
            clone = super.clone();
        } catch (CloneNotSupportedException e) {
            e.printStackTrace();
        }
        return clone;
    }
}

// 2. Circle class
class Circle extends Shape {
    public Circle() {
        type = "Circle";
    }

    @Override
    public void draw() {
        System.out.println("Drawing a Circle.");
    }
}

// 3. Rectangle class
class Rectangle extends Shape {
    public Rectangle() {
        type = "Rectangle";
    }

    @Override
    public void draw() {
        System.out.println("Drawing a Rectangle.");
    }
}

// 4. ShapeCache - lưu trữ prototype
class ShapeCache {
    private static Map<String, Shape> shapeMap = new HashMap<>();

    public static Shape getShape(String shapeId) {
        Shape cachedShape = shapeMap.get(shapeId);
        return (Shape) cachedShape.clone();
    }

    public static void loadCache() {
        Circle circle = new Circle();
        circle.setId("1");
        shapeMap.put(circle.getId(), circle);

        Rectangle rectangle = new Rectangle();
        rectangle.setId("2");
        shapeMap.put(rectangle.getId(), rectangle);
    }
}

// 5. Client
public class PrototypePatternDemo {
    public static void main(String[] args) {
        ShapeCache.loadCache();

        Shape clonedShape1 = ShapeCache.getShape("1");
        System.out.println("Shape: " + clonedShape1.getType());
        clonedShape1.draw();

        Shape clonedShape2 = ShapeCache.getShape("2");
        System.out.println("Shape: " + clonedShape2.getType());
        clonedShape2.draw();
    }
}
```

Kết quả:

```java
Shape: Circle
Drawing a Circle.
Shape: Rectangle
Drawing a Rectangle.
```

Trong đó:
- **_Prototype (Shape)_**: Đóng vai trò làm lớp cơ sở, hỗ trợ sao chép.
- **_Concrete Prototype (Circle, Rectangle)_**: Các lớp con triển khai cụ thể của Prototype.
- **_Prototype Registry (ShapeCache)_**: Lưu trữ các prototype ban đầu và cung cấp khả năng sao chép.
- **_Client_**: Yêu cầu các bản sao từ registry mà không cần khởi tạo trực tiếp.

_Lưu ý một số trường hợp không nên dùng Prototype Pattern:_

- Khi đối tượng cần sao chép chứa nhiều tài nguyên phức tạp mà không thể quản lý tốt.
- Khi việc quản lý danh sách prototype trở nên rắc rối, gây khó khăn cho bảo trì.


### Lời kết

`Prototype Design Patter`n giúp tối ưu hóa quá trình tạo đối tượng trong Java, đặc biệt khi cần xử lý các đối tượng phức tạp hoặc khởi tạo tốn kém.

Tuy nhiên, cần cẩn thận khi áp dụng, đặc biệt với các hệ thống phức tạp hoặc yêu cầu `deep copy`. Nếu triển khai đúng cách, `Prototype Pattern` có thể giúp hệ thống linh hoạt và hiệu quả hơn.

> P/S: Nếu bạn thấy bài viết này hữu ích, đừng quên chia sẻ với bạn bè và đồng nghiệp của mình nhé!

Happy coding! 😎 👍🏻 🚀 🔥