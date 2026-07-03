---
layout: post
title: "builder pattern in java"
date: 2024-10-03 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, design-pattern, vietnamese]
---

Trong lập trình hướng đối tượng, việc khởi tạo đối tượng với nhiều tham số có thể dẫn đến mã nguồn khó đọc, dễ sai sót và khó bảo trì.

`Builder Pattern` là một giải pháp thiết kế hữu ích để giải quyết vấn đề này, mang lại sự linh hoạt, rõ ràng và dễ bảo trì hơn trong việc tạo đối tượng phức tạp.

### # khái niệm

`Builder Pattern` là một trong những mẫu thiết kế thuộc nhóm `Creational Design Patterns` trong `Gang of Four (GoF)`. Pattern này cung cấp một cách tiếp cận để xây dựng các đối tượng phức tạp mà không cần phải truyền nhiều tham số vào constructor hoặc tạo ra các cấu trúc phức tạp bên trong mã nguồn.

Thay vì khởi tạo trực tiếp một đối tượng, `Builder Pattern` sử dụng một lớp `Builder` để xây dựng từng phần của đối tượng một cách tuần tự. Sau đó, khi hoàn thành, đối tượng cuối cùng sẽ được `"build"` từ những phần đã định nghĩa.

### # ưu điểm

- **_Rõ ràng hơn trong việc xây dựng đối tượng_**: Với `Builder Pattern`, việc thiết lập các thuộc tính của đối tượng trở nên dễ đọc và tuần tự hơn.

- **_Hỗ trợ đối tượng phức tạp_**: Đối với các đối tượng có nhiều thuộc tính (bao gồm cả thuộc tính tùy chọn), `Builder Pattern` giúp giảm thiểu việc sử dụng quá nhiều constructor hoặc các phương thức thiết lập.

- **_Tính linh hoạt cao_**: `Builder Pattern` cho phép xây dựng đối tượng theo các cách khác nhau bằng cách sử dụng các phương thức khác nhau trong lớp `Builder`.

- **_Dễ dàng mở rộng_**: Khi cần thêm thuộc tính mới cho đối tượng, chỉ cần thêm phương thức tương ứng trong lớp `Builder` mà không ảnh hưởng đến mã nguồn hiện tại.

### # nhược điểm

- **_Mã nguồn phức tạp hơn_**: Builder Pattern yêu cầu tạo thêm các lớp và phương thức hỗ trợ, điều này có thể làm tăng độ phức tạp của mã nguồn đối với các dự án nhỏ.

- **_Tốn thời gian khởi tạo_**: Việc sử dụng Builder Pattern có thể làm tăng thời gian phát triển ban đầu do phải viết thêm mã cho lớp Builder.

### # khi nào sử dụng

Builder Pattern thường được sử dụng trong các trường hợp sau:

- Đối tượng có nhiều tham số (đặc biệt là khi các tham số này có thể là tùy chọn hoặc có giá trị mặc định).

- Đối tượng phức tạp cần được khởi tạo theo từng bước.

- Cần tránh sử dụng constructor quá tải hoặc sử dụng quá nhiều setter để thiết lập giá trị.

- Muốn cải thiện tính đọc hiểu và bảo trì của mã nguồn.

5. Ví dụ
   Giả sử chúng ta cần thiết kế một lớp `Car` với nhiều thuộc tính như `make, model, color, year, engine, và features`. Một số thuộc tính là bắt buộc, một số khác là tùy chọn.

- **_Lớp Car_**:

```java
public class Car {
    private final String make;       // Bắt buộc
    private final String model;      // Bắt buộc
    private final String color;      // Tùy chọn
    private final int year;          // Tùy chọn
    private final String engine;     // Tùy chọn
    private final String features;   // Tùy chọn

    // Constructor private, chỉ cho phép khởi tạo thông qua Builder
    private Car(CarBuilder builder) {
        this.make = builder.make;
        this.model = builder.model;
        this.color = builder.color;
        this.year = builder.year;
        this.engine = builder.engine;
        this.features = builder.features;
    }

    // Getters
    public String getMake() { return make; }
    public String getModel() { return model; }
    public String getColor() { return color; }
    public int getYear() { return year; }
    public String getEngine() { return engine; }
    public String getFeatures() { return features; }

    @Override
    public String toString() {
        return "Car{" +
                "make='" + make + '\'' +
                ", model='" + model + '\'' +
                ", color='" + color + '\'' +
                ", year=" + year +
                ", engine='" + engine + '\'' +
                ", features='" + features + '\'' +
                '}';
    }

    // Lớp Builder
    public static class CarBuilder {
        private final String make;    // Bắt buộc
        private final String model;   // Bắt buộc
        private String color;         // Tùy chọn
        private int year;             // Tùy chọn
        private String engine;        // Tùy chọn
        private String features;      // Tùy chọn

        // Constructor với tham số bắt buộc
        public CarBuilder(String make, String model) {
            this.make = make;
            this.model = model;
        }

        // Các phương thức thiết lập tùy chọn
        public CarBuilder setColor(String color) {
            this.color = color;
            return this;
        }

        public CarBuilder setYear(int year) {
            this.year = year;
            return this;
        }

        public CarBuilder setEngine(String engine) {
            this.engine = engine;
            return this;
        }

        public CarBuilder setFeatures(String features) {
            this.features = features;
            return this;
        }

        // Phương thức build
        public Car build() {
            return new Car(this);
        }
    }
}
```

- **_Sử dụng Builder Pattern_**:

```java
public class Main {
    public static void main(String[] args) {
        // Tạo một đối tượng Car bằng Builder Pattern
        Car car = new Car.CarBuilder("Toyota", "Camry")
                .setColor("Red")
                .setYear(2023)
                .setEngine("V6")
                .setFeatures("Sunroof, Leather seats")
                .build();

        System.out.println(car);

        // Tạo một đối tượng Car khác với ít thuộc tính hơn
        Car basicCar = new Car.CarBuilder("Honda", "Civic").build();
        System.out.println(basicCar);
    }
}
```

- **_Kết quả đầu ra_**:

```terminal
Car{make='Toyota', model='Camry', color='Red', year=2023, engine='V6', features='Sunroof, Leather seats'}
Car{make='Honda', model='Civic', color='null', year=0, engine='null', features='null'}
```

### # lời kết

`Builder Pattern` là một giải pháp mạnh mẽ và linh hoạt khi làm việc với các đối tượng phức tạp. Nó giúp mã nguồn dễ đọc, dễ bảo trì hơn và tránh được việc sử dụng quá nhiều `constructor` hoặc `setter`. Tuy nhiên, bạn nên cân nhắc sử dụng nó khi cần thiết, đặc biệt đối với các dự án có quy mô nhỏ, vì có thể gây dư thừa mã nguồn.

Nếu bạn thường xuyên làm việc với các ứng dụng Java lớn, nơi mà cấu trúc đối tượng phức tạp là phổ biến, `Builder Pattern` chắc chắn là một công cụ đáng để thêm vào `"hộp công cụ"` của bạn.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
