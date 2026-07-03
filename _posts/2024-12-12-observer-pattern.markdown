---
layout: post
title: "observer pattern trong java"
date: 2024-12-12 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, design-pattern, vietnamese]
---

Trong lập trình hướng đối tượng, `Observer Pattern` là một trong những mẫu thiết kế hành vi (**Behavioral Design Patterns)** quan trọng. Nó được sử dụng khi có sự phụ thuộc một-nhiều giữa các đối tượng, trong đó một đối tượng thay đổi trạng thái và thông báo đến tất cả các đối tượng liên quan.

`Observer Pattern` cho phép một đối tượng (Subject) thông báo cho các đối tượng khác (Observers) về sự thay đổi trạng thái của nó mà không cần biết cụ thể các đối tượng đó là gì.

- Subject: Đối tượng chứa trạng thái và danh sách các Observer.
- Observer: Đối tượng cần được thông báo khi Subject thay đổi.
- Notification: Cơ chế truyền thông báo từ Subject đến Observer.

Trong Java, Observer Pattern thường được triển khai bằng cách sử dụng interface hoặc abstract class.

Các Thành Phần Chính của Observer Pattern

- Subject (Observable):
  - Chứa trạng thái.
  - Duy trì danh sách các Observer.
  - Cung cấp phương thức để thêm/xóa Observer.
  - Thông báo cho tất cả các Observer khi trạng thái thay đổi.

- Observer:
  - Đăng ký (subscribe) để nhận thông báo từ Subject.
  - Thực hiện các hành động cần thiết khi nhận thông báo.

- ConcreteSubject và ConcreteObserver:
  - Lớp triển khai cụ thể của Subject và Observer.

### # ưu điểm

- Giảm sự kết nối chặt chẽ: Subject không cần biết chi tiết các Observer.
- Dễ mở rộng: Có thể thêm Observer mới mà không cần thay đổi mã nguồn của Subject.
- Tái sử dụng code: Observer có thể được sử dụng lại cho các Subject khác nhau.

### # nhược điểm

- Chi phí quản lý Observer: Subject cần quản lý danh sách Observer và đảm bảo thông báo đúng.
- Vấn đề hiệu suất: Nếu có quá nhiều Observer, việc thông báo đến tất cả có thể gây tốn tài nguyên.
- Khó theo dõi luồng xử lý: Khi có nhiều Observer, việc debug có thể phức tạp.

### # ứng dụng thực tế

- Giao diện người dùng (GUI): Khi người dùng nhấn nút, hệ thống thông báo sự kiện cho các Listener.
- Hệ thống thông báo: Gửi thông báo khi có thay đổi trạng thái hệ thống.
- Mô hình pub-sub: Triển khai trong các hệ thống lớn như Kafka, RabbitMQ.

### # ví dụ

Giả sử chúng ta có một hệ thống thời tiết. Khi thời tiết thay đổi, tất cả các màn hình hiển thị sẽ được cập nhật.

Step 1: Tạo Interface Observer:

```java
public interface Observer {
    void update(float temperature, float humidity, float pressure);
}
```

Tạo Interface Subject:

```java
public interface Subject {
    void registerObserver(Observer o);
    void removeObserver(Observer o);
    void notifyObservers();
}
```

Tạo ConcreteSubject:

```java
import java.util.ArrayList;
import java.util.List;

public class WeatherData implements Subject {
    private List<Observer> observers;
    private float temperature;
    private float humidity;
    private float pressure;

    public WeatherData() {
        observers = new ArrayList<>();
    }

    @Override
    public void registerObserver(Observer o) {
        observers.add(o);
    }

    @Override
    public void removeObserver(Observer o) {
        observers.remove(o);
    }

    @Override
    public void notifyObservers() {
        for (Observer observer : observers) {
            observer.update(temperature, humidity, pressure);
        }
    }

    public void setMeasurements(float temperature, float humidity, float pressure) {
        this.temperature = temperature;
        this.humidity = humidity;
        this.pressure = pressure;
        notifyObservers();
    }
}
```

Tạo ConcreteObserver:

```java
public class CurrentConditionsDisplay implements Observer {
    private float temperature;
    private float humidity;

    @Override
    public void update(float temperature, float humidity, float pressure) {
        this.temperature = temperature;
        this.humidity = humidity;
        display();
    }

    public void display() {
        System.out.println("Current conditions: " + temperature + "C degrees and " + humidity + "% humidity.");
    }
}
```

Tạo Client:

```java
public class WeatherStation {
    public static void main(String[] args) {
        WeatherData weatherData = new WeatherData();

        CurrentConditionsDisplay currentDisplay = new CurrentConditionsDisplay();

        weatherData.registerObserver(currentDisplay);

        weatherData.setMeasurements(30, 65, 1013);
        weatherData.setMeasurements(32, 70, 1012);
    }
}
```

Output:

```
Current conditions: 30.0C degrees and 65.0% humidity.
Current conditions: 32.0C degrees and 70.0% humidity.
```

Trong đó:

- WeatherData (Subject):
  - Duy trì danh sách Observer.
  - Khi dữ liệu thay đổi, nó gọi notifyObservers() để thông báo.
- CurrentConditionsDisplay (Observer):
  - Nhận thông báo qua phương thức update.
  - Cập nhật và hiển thị dữ liệu mới.
- WeatherStation (Client):
  - Tạo Subject và Observer.
  - Thêm Observer vào Subject và cập nhật dữ liệu.

Java cung cấp các lớp sẵn có như `java.util.Observer` và `java.util.Observable` để triển khai `Observer Pattern`. Tuy nhiên, kể từ Java 9, các lớp này đã bị đánh dấu là deprecated vì hạn chế về tính linh hoạt.

### # lời kết

`Observer Pattern` là một công cụ mạnh mẽ trong lập trình hướng đối tượng, giúp giảm sự kết nối chặt chẽ giữa các thành phần trong hệ thống. Bằng cách áp dụng `Observer Pattern`, chúng ta có thể xây dựng các ứng dụng linh hoạt và dễ mở rộng hơn.

Trong Java, bạn có thể dễ dàng triển khai `Observer Pattern` bằng cách sử dụng các interface hoặc các lớp trừu tượng. Hy vọng qua bài viết này, bạn đã hiểu rõ hơn về cách hoạt động của `Observer Pattern` và cách áp dụng nó trong các dự án thực tế.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
