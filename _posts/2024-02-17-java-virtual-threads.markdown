---
layout: post
title: "java virtual threads"
date: 2024-02-17 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, virtual-threads, java21, vietnamese]
---

`Concurrency` (tính đồng thời) từ lâu đã là một trong những vấn đề phức tạp và quan trọng trong phát triển phần mềm, đặc biệt là khi làm việc với các hệ thống cần xử lý nhiều tác vụ cùng lúc, chẳng hạn như _server, ứng dụng web, hay các hệ thống phân tán_.

Các phương pháp truyền thống như sử dụng `threads` trong Java đã tồn tại từ rất lâu nhưng gặp phải một số hạn chế lớn, đặc biệt là khi số lượng `threads` tăng lên. Điều này dẫn đến việc sử dụng tài nguyên không hiệu quả và gặp phải những vấn đề như **overhead** lớn trong quản lý `threads`.

Java 21 giới thiệu `Virtual Threads`, một tính năng mới mà theo các chuyên gia sẽ cách mạng hóa cách thức quản lý và thực thi `concurrency` trong Java. Tính năng này không chỉ giúp giảm bớt sự phức tạp mà còn nâng cao hiệu suất, đặc biệt là đối với các ứng dụng cần xử lý một lượng lớn tác vụ đồng thời.

### # concurrency trong Java: những thách thức truyền thống

Trước khi Java 21 giới thiệu `Virtual Threads`, Java đã sử dụng các `threads` (**_real threads_**) để thực hiện các tác vụ đồng thời. `Threads` được quản lý trực tiếp bởi hệ điều hành, với mỗi `thread` có không gian bộ nhớ riêng và được yêu cầu tạo lập bởi **JVM**.

Mặc dù cách này hoạt động tốt cho các ứng dụng có lượng `threads` tương đối nhỏ, nhưng khi số lượng `threads` tăng lên, bạn sẽ gặp phải những vấn đề nghiêm trọng:

- _Overhead tài nguyên_: Mỗi thread cần một lượng tài nguyên nhất định (chẳng hạn như bộ nhớ cho stack) và khi số lượng `threads` tăng lên, `overhead` này có thể trở thành một vấn đề nghiêm trọng.
- _Quản lý threads phức tạp_: Khi ứng dụng yêu cầu hàng nghìn hoặc thậm chí hàng triệu `threads`, việc quản lý và tối ưu hóa `threads` trở nên rất khó khăn. Việc này có thể dẫn đến hiệu suất kém và làm tăng độ phức tạp của hệ thống.
- _Block I/O_: Trong các ứng dụng web hoặc hệ thống mạng, nhiều `threads` sẽ bị block khi thực hiện các tác vụ I/O, ví dụ như đọc/ghi file hoặc chờ phản hồi từ API. Từ đó có thể làm giảm hiệu suất nếu không được xử lý đúng cách.

### # virtual threads: giải pháp từ java 21

`Virtual Threads` trong Java 21 là một tính năng giúp giải quyết các vấn đề trên bằng cách cung cấp một mô hình thread mới nhẹ nhàng và hiệu quả hơn.

`Virtual Threads` là một dạng thread giả lập, được quản lý bởi **JVM** thay vì hệ điều hành. Chúng có chi phí thấp hơn rất nhiều so với `threads` truyền thống, cho phép bạn tạo hàng triệu `threads` mà không gặp phải vấn đề overhead lớn.

#### # cách hoạt động

Virtual Threads được tạo ra và quản lý bởi **JVM** thông qua một cơ chế được gọi là **Fiber Scheduling**. Mỗi Virtual Thread không yêu cầu một không gian bộ nhớ riêng biệt lớn như thread, mà thay vào đó chúng chia sẻ các `resources` của JVM, giúp tiết kiệm tài nguyên hệ thống với các tính chất sau:

- _Lightweight_: Virtual Threads sử dụng một lượng tài nguyên rất nhỏ, giúp tiết kiệm bộ nhớ và giảm chi phí tạo lập.
- _Non-blocking I/O_: Các Virtual Threads được thiết kế để hỗ trợ I/O không đồng bộ (**_non-blocking I/O_**). Khi một Virtual Thread thực hiện I/O (chẳng hạn như đọc từ file hoặc chờ API), nó không bị block, thay vào đó, JVM có thể chuyển sang thực thi các threads khác mà không làm gián đoạn hệ thống.
- _Scalable_: Bạn có thể tạo ra hàng triệu Virtual Threads mà không gặp phải các vấn đề về hiệu suất hoặc tài nguyên, giúp các ứng dụng có khả năng mở rộng dễ dàng hơn.

#### # lợi ích

Sự ra đời của Virtual Threads như một cuộc cách tân dành cho những tín đồ Java trong việc quản lý luồng và đa tác vụ. Những lợi ích mà Virtual Threads mang lại thật sự rất khó từ chối hay bàn cải, điển hình như:

**_Hiệu suất cao hơn_**: Nhờ vào việc giảm overhead tài nguyên và quản lý threads hiệu quả hơn, Virtual Threads giúp cải thiện hiệu suất của các ứng dụng đồng thời.

**_Quản lý đơn giản hơn_**: Các Virtual Threads không yêu cầu lập trình viên phải quản lý từng thread một cách thủ công. Với Virtual Threads, JVM sẽ lo liệu tất cả công việc này, giúp giảm thiểu sự phức tạp trong việc quản lý concurrency.

**_Khả năng mở rộng_**: Virtual Threads giúp các ứng dụng mở rộng dễ dàng hơn khi cần xử lý hàng triệu yêu cầu đồng thời mà không gặp phải các vấn đề liên quan đến tài nguyên hệ thống.

**_Cải thiện độ phản hồi_**: Nhờ vào khả năng sử dụng **_non-blocking I/O_**, Virtual Threads giúp cải thiện thời gian phản hồi của ứng dụng, đặc biệt là trong các hệ thống web hoặc mạng.

### # sử dụng virtual threads trong java 21

Để sử dụng Virtual Threads trong Java 21, ta cần thay đổi cách tạo và quản lý threads trong ứng dụng của mình. Cách tạo Virtual Thread đơn giản hơn rất nhiều so với threads truyền thống.

**Tạo Virtual Thread**

Để tạo một Virtual Thread trong Java 21, ta có thể sử dụng `Thread.ofVirtual().start()`:

```java
Thread virtualThread = Thread.ofVirtual().start(() -> {
    System.out.println("Virtual thread is running!");
});
```

Trong ví dụ trên, một Virtual Thread mới được tạo ra và bắt đầu thực thi ngay lập tức, nó có thể thay thế cho các cách tạo thread truyền thống như:

```java
Thread thread = new Thread(() -> {
    System.out.println("Real thread is running!");
});
thread.start();
```

Điều quan trọng cần lưu ý là Virtual Threads không cần phải lo lắng về việc sử dụng các `ExecutorService` hay `ThreadPoolExecutor` như với các `thread`. Java 21 hỗ trợ tích hợp Virtual Threads trong các API hiện tại của Java, giúp việc chuyển đổi sang sử dụng Virtual Threads dễ dàng hơn.

**Sử dụng Virtual Threads với ExecutorService**

Java 21 cho phép sử dụng Virtual Threads với `ExecutorService`. Để tạo một `ExecutorService` sử dụng Virtual Threads, ta có thể làm như sau:

```java
ExecutorService executorService = Executors.newVirtualThreadPerTaskExecutor();
executorService.submit(() -> {
    System.out.println("Virtual thread in ExecutorService is running!");
});
```

Khi sử dụng `Executors.newVirtualThreadPerTaskExecutor()`, mỗi **task** được gửi đến **executorService** sẽ được thực thi trong một Virtual Thread mới, giúp đơn giản hóa việc quản lý concurrency trong ứng dụng.

### # ví dụ thực tế về virtual threads

Để hiểu rõ hơn cách sử dụng Virtual Threads, hãy xem xét một ví dụ thực tế.

Giả sử bạn đang phát triển một ứng dụng server có hàng nghìn kết nối đồng thời. Thay vì tạo ra một `thread` cho mỗi kết nối, bạn có thể sử dụng `Virtual Threads` để xử lý chúng một cách hiệu quả.

```java
import java.util.concurrent.*;

public class VirtualThreadExample {
    public static void main(String[] args) {
        ExecutorService executorService = Executors.newVirtualThreadPerTaskExecutor();

        for (int i = 0; i < 1000; i++) {
            final int connectionId = i;
            executorService.submit(() -> {
                // Xử lý kết nối
                System.out.println("Handling connection " + connectionId + " in Virtual Thread");
            });
        }

        executorService.shutdown();
    }
}
```

Trong ví dụ trên, ứng dụng tạo ra **1000** Virtual Threads để xử lý các kết nối đồng thời. Với Virtual Threads, việc này không làm giảm hiệu suất, bởi vì chúng không tiêu tốn quá nhiều tài nguyên như threads .

### # lưu ý khi sử dụng virtual threads

Mặc dù Virtual Threads mang lại nhiều lợi ích, nhưng vẫn có một số điều cần lưu ý khi sử dụng chúng:

- **_Không thích hợp cho mọi trường hợp_**: Virtual Threads là lý tưởng cho các ứng dụng cần xử lý nhiều tác vụ đồng thời mà không yêu cầu sử dụng quá nhiều tài nguyên. Tuy nhiên, đối với các tác vụ tính toán nặng (CPU-bound), Virtual Threads có thể không phải là lựa chọn tối ưu.
- **_Đồng bộ hóa_**: Vì Virtual Threads chạy đồng thời, việc đồng bộ hóa giữa các thread vẫn là điều cần phải chú ý. Ta vẫn phải đảm bảo việc sử dụng các cơ chế đồng bộ như `synchronized`, `ReentrantLock` nếu có sự chia sẻ tài nguyên giữa các `threads`.

### # lời kết

**Virtual Threads** trong Java 21 là một cải tiến lớn đối với việc quản lý **concurrency** trong Java. Chúng giúp tiết kiệm tài nguyên, cải thiện hiệu suất và làm giảm độ phức tạp trong việc quản lý hàng triệu tác vụ đồng thời. Với tính năng này, Java có thể dễ dàng đáp ứng nhu cầu của các _ứng dụng web, hệ thống mạng, hoặc bất kỳ hệ thống nào yêu cầu xử lý đồng thời_.

Bằng cách sử dụng **Virtual Threads**, lập trình viên có thể tận dụng sức mạnh của **concurrency** mà không gặp phải các vấn đề về **overhead** tài nguyên và quản lý threads phức tạp.

Java 21 đã đưa **concurrency** trong Java lên một tầm cao mới, giúp các ứng dụng Java trở nên mạnh mẽ và hiệu quả hơn bao giờ hết.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
