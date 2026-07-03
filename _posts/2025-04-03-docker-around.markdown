---
layout: post
title: "một chút với docker"
date: 2025-04-03 19:29:39 +0700
categories: [Software Development]
tags: [software-development, docker, vietnamese]
---

`Docker` là một nền tảng mã nguồn mở cho phép đóng gói, phân phối và chạy ứng dụng trong các container nhẹ, độc lập. Container giống như một hộp chứa, đảm bảo ứng dụng chạy đồng nhất trên mọi môi trường, từ máy tính cá nhân đến server production.

Chắc các bạn cũng đã từng ... như mình. Build source và run trên máy cá nhân thì OK nhưng khi push lên git và teammate kéo về, run lại thì FAILED. :))) What's up? Để khắc phục tình trạng đó, thì `Docker` là công cụ tuyệt vời!!!

### # các thành phần chính

**_Dockerfile_** là một file dạng text không có phần đuôi mở rộng, chứa các đặc tả về một trường thực thi phần mềm, cấu trúc cho Docker image. Từ những câu lệnh đó, Docker sẽ build ra Docker image (thường có dung lượng nhỏ từ vài MB đến lớn vài GB).

**_Docker Images_** là các bản thiết kế (blueprints) cho container. Một image định nghĩa tất cả những gì một ứng dụng cần để chạy. Sau khi một image được tạo ra, nó không thể thay đổi (immutable). Bạn có thể chạy các instance của image này, được gọi là các container.

**_Docker Containers_** là các instance đang chạy của Docker images. Container đóng gói một ứng dụng và tất cả các thành phần phụ thuộc của nó. Containers cô lập phần mềm khỏi sự ảnh hưởng của môi trường và đảm bảo rằng nó vẫn hoạt động bất kể sự khác biệt (staging vs production).

**_docker-compose.yml_** gần giống ý nghĩa với `Dockerfile`, là một file text, viết với định dạng YAML (Ain’t Markup Language, đọc nhanh định dạng Định dạng YML) là cấu hình để từ đó sinh ra và quản lý các service (container), các network, các ổ đĩa ... cho một ứng dụng hoàn chỉnh.

**_Docker Hub_** là một registry service phổ biến nhất cung cấp bởi Docker. Đây là nơi bạn có thể tải lên (push) các Docker images của mình, chia sẻ chúng với cộng đồng hoặc đồng nghiệp, và tải xuống (pull) các images từ cộng đồng hoặc từ các nguồn đáng tin cậy khác.

### # ưu điểm

- **_Tính nhất quán_**: Docker đảm bảo ứng dụng chạy giống nhau trên mọi môi trường.
- **_Nhẹ và nhanh_**: Container tiêu tốn ít tài nguyên hơn so với máy ảo.
- **_Triển khai linh hoạt_**: Dễ dàng scale hệ thống lên nhiều container.
- **_Quản lý phụ thuộc hiệu quả_**: Đóng gói toàn bộ ứng dụng và các thư viện cần thiết.
- **_Cộng đồng lớn_**: Hỗ trợ mạnh mẽ từ các tài nguyên như Docker Hub.

### # nhược điểm

- **_Độ phức tạp ban đầu_**: Cần thời gian để làm quen.
- **_Giới hạn hiệu năng_**: Không phù hợp với ứng dụng cần hiệu năng phần cứng cao.
- **_Bảo mật_**: Cần cấu hình đúng để tránh rủi ro bảo mật.

### # khi nào nên sử dụng

- **_Triển khai Microservices_**: Mỗi dịch vụ chạy trong một container riêng.
- **_Môi trường phát triển_**: Dễ dàng tái tạo môi trường production.
- **_Tự động hóa CI/CD_**: Docker giúp tích hợp và triển khai liên tục dễ dàng hơn.
- **_Chạy ứng dụng đa nền tảng_**: Đảm bảo đồng nhất trên Windows, macOS và Linux.

### # các câu lệnh cơ bản

Kiểm tra phiên bản docker đang cài:

```terminal
docker --version
```

Liệt kê các container:

```terminal
#Liệt kê các container đang chạy
docker ps

#Liệt kê các container đã tắt
docker ps -a
```

Tắt tất cả các container đang chạy:

```terminal
docker kill $(docker ps -q)
```

Liệt kê các images hiện có:

```terminal
docker images
```

Xóa một hoặc nhiều image:

```terminal
docker rmi <image_id1/name1 image_id2/name2 ....>
```

Xóa một hoặc nhiều container:

```terminal
docker rm <container_id1/name1 container_id1/name2 container_id3/name3 ...>
```

Pull một image từ Docker Hub:

```terminal
docker pull <image_name>
```

Xem lịch sử các commit trên image:

```terminal
docker history <image_name>
```

Build image từ DockerFile: với `my-app` là tên container mà bạn muốn đặt.

```terminal
docker build -t my-app .
```

Run container:

```terminal
docker run -d -p 8080:8080 my-app
```

Stop container:

```terminal
docker stop <container_id>
```

- Sử dụng Docker Compose:

```terminal
docker-compose up
```

### # ứng dụng với Spring Boot, MySQL, MongoDB

Giả sử chúng ta có dự án SpringBoot, toàn bộ source-code giả định được hàon thiện bên trong thư mục `src/`, với cấu trúc như sau:

```
project/
├── src/
├── Dockerfile
├── docker-compose.yml
├── application.properties
```

Viết Dockerfile cho ứng dụng:

```dockerfile
FROM openjdk:17-jdk-slim
COPY target/my-app.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

Tạo docker-compose.yml:

```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - '8080:8080'
    environment:
      SPRING_DATASOURCE_URL: jdbc:mysql://db:3306/mydb
      SPRING_DATA_MONGODB_URI: mongodb://mongo:27017/mydb
    depends_on:
      - db
      - mongo

  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: mydb
    ports:
      - '3306:3306'

  mongo:
    image: mongo:6.0
    ports:
      - '27017:27017'
```

Cấu hình application.properties:

```yaml
spring.datasource.url=${SPRING_DATASOURCE_URL}
spring.datasource.username=root
spring.datasource.password=root

spring.data.mongodb.uri=${SPRING_DATA_MONGODB_URI}
```

Run ứng dụng:

```terminal
mvn clean package
docker-compose up
```

Truy cập ứng dụng Spring Boot tại `http://localhost:8080`.

Dữ liệu sẽ được lưu trong MySQL và MongoDB.

### # chạy Docker từ Docker Hub

`Docker Hub` như khái niệm đã nêu ở mục 1, nhưng chúng ta có thể làm gì với cá hub lạ hoắc lạ quơ đó nhỉ?. Ví dụ, bạn có thể sử dụng các image của MySQL, MongoDB và Spring Boot từ Docker Hub như ví dụ trên đã làm.

**_Tìm kiếm image_**: thường người ta sẽ lên trang chủ `https://hub.docker.com/` để tìm rồi copy lệnh pull về rồi dùng. Nhưng nếu muốn trông _cool ngầu_ hơn, bạn có thể dùng lệnh để search.

```terminal
docker search <tên_image>
```

Ví dụ, để tìm kiếm image `mysql`, khó ha, bạn phải nhớ tên `image`:

```terminal
docker search mysql
```

**_Dowload image_**: tương tự như search, trên trang chủ đã có sẵn.

```terminal
docker pull <tên_image>:<tag>
```

Ví dụ:

```terminal
docker pull mysql:8.0
```

**_Run container_**: cú pháp và ví dụ như bên dưới:

```terminal
docker run -d --name mysql-container -e MYSQL_ROOT_PASSWORD=root -p 3306:3306 mysql:8.0
```

Trong đó:

- -d: Chạy container ở chế độ nền.
- -name: Tên container.
- -e: Thiết lập biến môi trường.
- -p: Mở cổng (3306).

### # lời kết

`Docker` là công cụ mạnh mẽ để triển khai và quản lý ứng dụng. Việc tận dụng tối đa sức mạnh và lợi ích của `Docker` sẽ giúp giảm thiểu các vấn đề phát sinh về sự tương thích về môi trường và cài đặt giữa các developer và hệ điều hành.

Hãy khám phá thêm các tính năng của `Docker` để tối ưu hóa quy trình phát triển và triển khai!

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
