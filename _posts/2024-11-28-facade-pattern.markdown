---
layout: post
title: "facade pattern in java"
date: 2024-11-28 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, design-pattern, vietnamese]
---

`Facade Pattern` là một mẫu thiết kế thuộc nhóm Structural Design Patterns (mẫu thiết kế cấu trúc). Mục đích chính của nó là cung cấp một giao diện đơn giản (Facade) để che giấu sự phức tạp của các hệ thống con (Subsystem). Pattern này giúp giảm sự phụ thuộc và tăng tính dễ sử dụng của hệ thống.

Trong thực tế, chúng ta thường gặp những hệ thống phức tạp có nhiều thành phần khác nhau. Việc tương tác trực tiếp với các thành phần này có thể gây khó khăn và làm tăng độ phức tạp cho người dùng. `Facade Pattern` chính là giải pháp giúp đơn giản hóa việc sử dụng và quản lý các hệ thống này.

Khi bạn sử dụng một chiếc smartphone, bạn chỉ cần nhấn một nút để chụp ảnh. Tuy nhiên, phía sau đó, có rất nhiều hệ thống đang hoạt động, như cảm biến hình ảnh, thuật toán xử lý ảnh, lưu trữ, v.v. `Facade Pattern` giúp bạn "ẩn" đi những chi tiết phức tạp đó.

`Facade Pattern` thường gồm các thành phần chính:

- **_Facade_**: Cung cấp một giao diện đơn giản để tương tác với các hệ thống con.
- **_Subsystems_**: Các hệ thống con cung cấp chức năng phức tạp, nhưng không tương tác trực tiếp với client.
- **_Client_**: Sử dụng Facade để tương tác với hệ thống mà không cần biết về chi tiết bên trong.

### # ưu điểm

- **_Đơn giản hóa giao diện_**: Facade cung cấp một giao diện dễ sử dụng, giúp client tương tác với hệ thống mà không cần hiểu chi tiết.
- **_Tăng tính bảo trì_**: Giảm sự phụ thuộc trực tiếp giữa client và các hệ thống con. Khi hệ thống con thay đổi, chỉ cần cập nhật Facade mà không ảnh hưởng đến client.
- **_Tăng tính linh hoạt_**: Hỗ trợ việc thay đổi và mở rộng các hệ thống con mà không ảnh hưởng đến client.

### # nhược điểm

- **_Tiềm ẩn việc che giấu lỗi_**: Vì Facade "ẩn" đi chi tiết bên trong, việc xử lý lỗi từ các hệ thống con có thể không rõ ràng.
- **_Tăng thêm lớp trung gian_**: Nếu không được thiết kế cẩn thận, Facade có thể trở thành điểm nghẽn hiệu năng do việc thêm một lớp trung gian.

### # khi nào nên sử dụng

- Khi hệ thống phức tạp với nhiều thành phần và bạn muốn cung cấp một giao diện đơn giản cho người dùng.
- Khi bạn muốn giảm sự phụ thuộc giữa client và các hệ thống con để tăng tính bảo trì và mở rộng.
- Khi bạn cần đảm bảo rằng client chỉ truy cập vào hệ thống thông qua một điểm duy nhất.

### # triển khai trong Java

Giả sử chúng ta cần Xây dựng một hệ thống quản lý giải trí tại nhà gồm 3 hệ thống con:

- Hệ thống loa (Speaker System)
- Máy chiếu (Projector)
- Đầu phát Blu-ray (Blu-ray Player)

Người dùng chỉ cần nhấn một nút để bắt đầu buổi xem phim. Vậy triển khai hệ thống trên với Facade Pattern như thế nào?

Hãy cùng theo dõi tiếp nhé.

Khai báo các class mô tả cho hệ thông con:

```java
// Subsystem 1: Speaker System
class SpeakerSystem {
    public void turnOn() {
        System.out.println("Speaker system is turned on.");
    }

    public void setVolume(int level) {
        System.out.println("Speaker volume set to " + level);
    }
}

// Subsystem 2: Projector
class Projector {
    public void turnOn() {
        System.out.println("Projector is turned on.");
    }

    public void setInput(String input) {
        System.out.println("Projector input set to " + input);
    }
}

// Subsystem 3: Blu-ray Player
class BluRayPlayer {
    public void turnOn() {
        System.out.println("Blu-ray player is turned on.");
    }

    public void playMovie(String movie) {
        System.out.println("Playing movie: " + movie);
    }
}
```

Triển khai class đại diện cho Facade:

```java
// Facade
class HomeTheaterFacade {
    private SpeakerSystem speakerSystem;
    private Projector projector;
    private BluRayPlayer bluRayPlayer;

    public HomeTheaterFacade(SpeakerSystem speakerSystem, Projector projector, BluRayPlayer bluRayPlayer) {
        this.speakerSystem = speakerSystem;
        this.projector = projector;
        this.bluRayPlayer = bluRayPlayer;
    }

    public void startMovie(String movie) {
        System.out.println("Starting movie theater setup...");
        speakerSystem.turnOn();
        speakerSystem.setVolume(10);
        projector.turnOn();
        projector.setInput("HDMI");
        bluRayPlayer.turnOn();
        bluRayPlayer.playMovie(movie);
        System.out.println("Movie is now playing. Enjoy!");
    }
}
```

Vậy còn client thì sao?

```java
// Client
public class FacadePatternDemo {
    public static void main(String[] args) {
        SpeakerSystem speaker = new SpeakerSystem();
        Projector projector = new Projector();
        BluRayPlayer bluRay = new BluRayPlayer();

        HomeTheaterFacade homeTheater = new HomeTheaterFacade(speaker, projector, bluRay);
        homeTheater.startMovie("Inception");
    }
}
```

Bạn có thể thấy rằng:

- Hệ thống con: `SpeakerSystem, Projector, và BluRayPlayer` đại diện cho các thành phần phức tạp.
- Facade: Lớp `HomeTheaterFacade` cung cấp một giao diện đơn giản cho client để khởi chạy toàn bộ hệ thống chỉ bằng một lệnh startMovie().
- Client: Lớp `FacadePatternDemo` chỉ tương tác với `HomeTheaterFacade` mà không cần biết chi tiết về các hệ thống con.

### # lời kết

`Facade Pattern` là một giải pháp mạnh mẽ để giảm bớt sự phức tạp của hệ thống và cải thiện trải nghiệm người dùng. Khi áp dụng đúng cách, mẫu này giúp cải thiện khả năng bảo trì, tăng tính linh hoạt và giảm rủi ro khi mở rộng hệ thống. Tuy nhiên, cần cân nhắc việc che giấu chi tiết một cách hợp lý để không ảnh hưởng đến hiệu năng và khả năng phát hiện lỗi.

Hãy áp dụng `Facade Pattern` vào các dự án của bạn để tạo ra các hệ thống dễ sử dụng và dễ bảo trì hơn!

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
