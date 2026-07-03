---
layout: post
title: "api gateway"
date: 2025-09-04 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, api-gateway, vietnamese]
---

Chào mừng các bạn đến với bài blog về một trong những nhân vật hot nhất trong làng `kiến trúc microservices`: `API Gateway`. Nếu bạn từng nghe qua nó mà không hiểu tại sao người ta lại lắm lời về cái _`"cổng"`_ này, thì đừng lo, hôm nay chúng ta sẽ _"khai sáng"_ nó một cách dễ hiểu nhất có thể. Chuẩn bị tinh thần đi nhé, vì API Gateway không chỉ là một cổng bình thường mà nó là _"cánh cổng huyền thoại"_ bảo vệ, tổ chức, và điều phối cả một hệ sinh thái `microservices`! 😎

### # API Gateway là gì?

`API Gateway` - hay dịch nôm na là **_"Cổng API"_**, là một thành phần quan trọng trong hệ thống kiến trúc `microservices`. Nếu coi các `microservices` như những căn nhà trong một khu phố nhỏ, thì `API Gateway` chính là anh bảo vệ đứng ở cổng, người quyết định ai được vào và ai phải... đứng ngoài. Nó là điểm tiếp xúc duy nhất giữa client (người dùng) và hệ thống backend (hệ thống phía sau).

Nói cách khác, khi bạn gửi một yêu cầu (request) từ client lên server, thay vì yêu cầu này được gửi trực tiếp đến từng `microservice`, nó sẽ được chuyển qua _"anh bảo vệ"_ API Gateway. Ở đây, `API Gateway` sẽ:

1. Xác thực yêu cầu xem bạn có phải là người xấu không.
2. Xử lý yêu cầu, bao gồm routing, load balancing, caching...
3. Rồi mới chuyển yêu cầu đến đúng microservice tương ứng.
   Và đương nhiên, sau khi `microservice` trả về kết quả, `API Gateway` cũng sẽ đứng ra làm trung gian để đưa kết quả lại cho client.

### # tại sao lại cần?

Giả sử bạn có một ứng dụng web `micoservice` với hàng tá service, mỗi service xử lý một phần riêng biệt: cái lo phần thanh toán, cái lo phần hiển thị, cái lo phần giỏ hàng, v.v. Bạn có tưởng tượng được không nếu mỗi lần người dùng truy cập, ứng dụng phải tự liên hệ với từng `service`? Đầu tiên là sẽ rất lằng nhằng, tiếp theo là khó quản lý, cuối cùng là nguy cơ hệ thống bị đứt gánh giữa đường rất cao!

`API Gateway` giúp giải quyết các vấn đề trên bằng cách trở thành `"single point of entry" (điểm vào duy nhất)` cho tất cả các yêu cầu từ phía client. Điều này giúp giảm thiểu sự phức tạp và tăng hiệu quả trong việc quản lý và phân phối các yêu cầu.

Một số vấn đề mà API Gateway giải quyết:

- `Routing`: Điều hướng yêu cầu đến đúng service. `Client` không cần phải biết `service` nào đang chạy ở đâu, API Gateway lo hết.
- `Authentication & Authorization`: Xác thực và phân quyền. Bạn không cần lo lắng về việc mỗi `microservice` phải tự kiểm tra xem người dùng có đủ quyền hay không.
- `Rate Limiting:` Giới hạn số lượng yêu cầu để tránh tình trạng `DDOS` hoặc `overload`.
- `Load Balancing`: Cân bằng tải, đảm bảo hệ thống không bị quá tải.
- `Caching`: Lưu trữ tạm thời để tăng tốc độ xử lý yêu cầu.
- `Logging & Monitoring`: Theo dõi và ghi lại các yêu cầu để phân tích sau này.

### # cơ chế hoạt động

Hãy tưởng tượng `API Gateway` như một nhân viên lễ tân siêu giỏi, làm việc tại một công ty khổng lồ. Khi khách hàng (client) đến, họ không cần phải biết rõ phòng nào chịu trách nhiệm về yêu cầu của họ. Nhân viên lễ tân (API Gateway) sẽ:

- Nhận yêu cầu từ khách hàng.
- Kiểm tra xem yêu cầu đó có hợp lệ không (kiểm tra vé, xác thực danh tính...).
- Điều hướng yêu cầu đến đúng phòng ban (microservice).
- Khi phòng ban xử lý xong, nhân viên lễ tân chuyển kết quả cho khách hàng.

Trong kiến trúc `microservices`, `API Gateway` đóng vai trò là nhân viên lễ tân thông minh này. Nó giúp client `"giấu đi"` sự phức tạp của hệ thống `microservices`, giúp việc giao tiếp dễ dàng và nhanh chóng hơn.

### # các lợi ích

Khi bạn sử dụng `API Gateway`, bạn sẽ nhận được một loạt lợi ích như sau:

1. Đơn giản hóa giao tiếp: Client chỉ cần tương tác với API Gateway thay vì phải tự mình gọi từng microservice. API Gateway sẽ xử lý việc điều hướng yêu cầu.

2. Tăng hiệu suất: API Gateway có thể cache những yêu cầu phổ biến, giúp giảm tải cho các microservice và cải thiện thời gian phản hồi.

3. Bảo mật tốt hơn: Vì tất cả yêu cầu đều phải qua API Gateway, bạn có thể áp dụng các biện pháp bảo mật như xác thực, phân quyền, kiểm soát truy cập một cách tập trung.

4. Dễ dàng mở rộng (scaling): API Gateway hỗ trợ cân bằng tải, giúp hệ thống hoạt động mượt mà ngay cả khi số lượng yêu cầu tăng cao đột ngột.

5. Tăng tính ổn định: Nếu một microservice gặp vấn đề, API Gateway có thể cung cấp các cơ chế dự phòng, giảm thiểu ảnh hưởng đến client.

6. Giám sát và theo dõi: Bạn có thể dễ dàng theo dõi các yêu cầu đi qua API Gateway, từ đó phát hiện và xử lý sự cố nhanh hơn.

### # demo với Spring Cloud Gateway

Giờ thì nói suông có vẻ dễ, nhưng để thực sự hiểu rõ, chúng ta hãy thử `"cầm tay chỉ việc"` với một ví dụ cụ thể. Ở đây, chúng ta sẽ sử dụng `Spring Cloud Gatewa`y, một trong những công cụ API Gateway phổ biến trong hệ sinh thái Spring.

**_Cấu hình cơ bản:_**
Đầu tiên, bạn cần tạo một project Spring Boot với dependency `spring-cloud-starter-gateway`. Bạn có thể dùng Spring Initializr để tạo project hoặc thêm dependency vào file pom.xml như sau:

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-gateway</artifactId>
</dependency>
```

**_Cấu hình routing trong `application.yml`:_**
Trong file application.yml, bạn sẽ định nghĩa các rule để điều hướng (route) các yêu cầu đến đúng service. Ví dụ:

```yml
spring:
  cloud:
    gateway:
      routes:
        - id: customer-service
          uri: http://localhost:8081/
          predicates:
            - Path=/customers/**
        - id: order-service
          uri: http://localhost:8082/
          predicates:
            - Path=/orders/**
```

Ở đây, chúng ta có 2 service: `customer-service` chạy trên port `8081` và `order-service` chạy trên port `8082`. Khi API Gateway nhận được yêu cầu với đường dẫn `/customers/**`, nó sẽ chuyển yêu cầu đó đến `customer-service`. Tương tự cho `/orders/**` và `order-service`.

**_Xử lý filter:_**\
API Gateway cho phép chúng ta thêm các bộ lọc (filter) để xử lý các yêu cầu trước hoặc sau khi nó đi qua các service. Ví dụ, bạn có thể thêm filter để log lại tất cả các yêu cầu đi qua gateway:

```yml
spring:
  cloud:
    gateway:
      default-filters:
        - name: AddRequestHeader
          args:
            Name: Request-Id
            Value: 'TungDaDev'
```

Trong ví dụ này, tất cả các yêu cầu đi qua Gateway sẽ được thêm một header `Request-Id` với giá trị `"TungDaDev"`.

### lời kết

`API Gateway` không phải là một khái niệm quá khó hiểu, nhưng khi ứng dụng đúng cách, nó sẽ là một vũ khí đắc lực giúp bạn xây dựng và quản lý hệ thống `microservices` hiệu quả hơn. Nó không chỉ giúp đơn giản hóa giao tiếp, tăng tính bảo mật, mà còn cải thiện hiệu suất và khả năng mở rộng của hệ thống. Và điều tuyệt vời nhất là, với những công cụ như `Spring Cloud Gateway`, việc triển khai một `API Gateway` chưa bao giờ dễ dàng hơn!

Nếu bạn chưa thử dùng `API Gateway` trong hệ thống của mình, hãy thử ngay! Bạn sẽ thấy cuộc sống của mình nhẹ nhàng hơn rất nhiều. 😎

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
