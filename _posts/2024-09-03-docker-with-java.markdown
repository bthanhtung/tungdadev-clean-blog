---
layout: post
title: "Docker basic"
date: 2024-09-03 19:29:39 +0700
categories: [Information Technology, Software]
tags: [Docker]
---

`Docker` là một nền tảng mã nguồn mở cho phép đóng gói, phân phối và chạy ứng dụng trong các container nhẹ, độc lập. Container giống như một hộp chứa, đảm bảo ứng dụng chạy đồng nhất trên mọi môi trường, từ máy tính cá nhân đến server production.

Chắc các bạn cũng đã từng ... như mình. Build source và run trên máy cá nhân thì OK nhưng khi push lên git và temate kéo về, run lại thì FAILED. :))) What's up? Để khắc phục tình trạng đó, thì `Docker` là công cụ tuyệt vời!!!

### 1. Ưu điểm của Docker
- **_Tính nhất quán_**: Docker đảm bảo ứng dụng chạy giống nhau trên mọi môi trường.
- **_Nhẹ và nhanh_**: Container tiêu tốn ít tài nguyên hơn so với máy ảo.
- **_Triển khai linh hoạt_**: Dễ dàng scale hệ thống lên nhiều container.
- **_Quản lý phụ thuộc hiệu quả_**: Đóng gói toàn bộ ứng dụng và các thư viện cần thiết.
- **_Cộng đồng lớn_**: Hỗ trợ mạnh mẽ từ các tài nguyên như Docker Hub.

### 2. Nhược điểm của Docker
- **_Độ phức tạp ban đầu_**: Cần thời gian để làm quen.
- **_Giới hạn hiệu năng_**: Không phù hợp với ứng dụng cần hiệu năng phần cứng cao.
- **_Bảo mật_**: Cần cấu hình đúng để tránh rủi ro bảo mật.

### 3. Khi nào nên sử dụng Docker?
- **_Triển khai Microservices_**: Mỗi dịch vụ chạy trong một container riêng.
- **_Môi trường phát triển_**: Dễ dàng tái tạo môi trường production.
- **_Tự động hóa CI/CD_**: Docker giúp tích hợp và triển khai liên tục dễ dàng hơn.
- **_Chạy ứng dụng đa nền tảng_**: Đảm bảo đồng nhất trên Windows, macOS và Linux.

### 4. Các câu lệnh Docker cơ bản
- Build image:
```terminal
docker build -t my-app .
```

- Run container:
```terminal
docker run -d -p 8080:8080 my-app
```

- Liệt kê container:
```terminal
docker ps
```

- Stop container:
```terminal
docker stop <container_id>
```

- Xóa container:
```terminal
docker rm <container_id>
```

- Sử dụng Docker Compose:
```terminal
docker-compose up
```

### 5. Ứng dụng với Spring Boot, MySQL, MongoDB

Giả sử dự án chúng ta có cấu trúc như sau:
```plantext
project/
├── src/
├── Dockerfile
├── docker-compose.yml
├── application.properties
```

- Viết Dockerfile cho ứng dụng:
```dockerfile
FROM openjdk:17-jdk-slim
COPY target/my-app.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

- Tạo docker-compose.yml:
```yaml
version: "3.8"
services:
  app:
    build: .
    ports:
      - "8080:8080"
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
      - "3306:3306"

  mongo:
    image: mongo:6.0
    ports:
      - "27017:27017"
```

- Cấu hình application.properties:
```properties
spring.datasource.url=${SPRING_DATASOURCE_URL}
spring.datasource.username=root
spring.datasource.password=root

spring.data.mongodb.uri=${SPRING_DATA_MONGODB_URI}
```

- Run ứng dụng:
```terminal
mvn clean package
docker-compose up
```

Truy cập ứng dụng Spring Boot tại http://localhost:8080.

Dữ liệu sẽ được lưu trong MySQL và MongoDB.

### 6. Chạy Docker từ Docker Hub
`Docker Hub` là kho lưu trữ các image sẵn có để bạn có thể tải xuống và chạy ứng dụng nhanh chóng. Ví dụ, bạn có thể sử dụng các image của MySQL, MongoDB và Spring Boot từ Docker Hub.

- Tìm kiếm image:
```terminal
docker search <tên_image>
```

Ví dụ:
```terminal
docker search mysql
```

- Dowload image:
```terminal
docker pull <tên_image>:<tag>
```

Ví dụ:
```terminal
docker pull mysql:8.0
```

- Run container:
```terminal
docker run -d --name mysql-container -e MYSQL_ROOT_PASSWORD=root -p 3306:3306 mysql:8.0
```

Trong đó:
-d: Chạy container ở chế độ nền.
--name: Tên container.
-e: Thiết lập biến môi trường.
-p: Mở cổng (3306).


### Lời kết

`Docker` là công cụ mạnh mẽ để triển khai và quản lý ứng dụng. Việc tận dụng tối đa sức mạnh và lợi ích của `Docker` sẽ giúp giảm thiểu các vấn đề phát sinh về sự tương thích về môi trường và cài đặt giữa các developer và hệ điều hành.

Hãy khám phá thêm các tính năng của `Docker` để tối ưu hóa quy trình phát triển và triển khai!


> P/S: Nếu bạn thấy bài viết này hữu ích, đừng quên chia sẻ với bạn bè và đồng nghiệp của mình nhé!

Happy coding! 😎 👍🏻 🚀 🔥