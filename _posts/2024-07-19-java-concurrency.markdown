---
layout: post
title: "Java Concurrency"
date: 2024-07-19 19:29:39 +0700
categories: [Software Development]
tags: [Java]
---

`Concurrency (tính đồng thời)` trong Java là một trong những chủ đề quan trọng, đặc biệt khi làm việc với các ứng dụng phức tạp yêu cầu _xử lý song song, hiệu suất cao và khả năng mở rộng tốt_.

Việc hiểu rõ cách thức hoạt động và cách tận dụng các tính năng `concurrency` trong Java sẽ giúp chúng ta xây dựng các ứng dụng tối ưu và bền vững. Trong bài viết này, chúng ta sẽ phân tích chi tiết về `Java Concurrency`, với các ví dụ cụ thể và hi vọng là có ích cho các bạn.

Đọc bài thôi :)))

### 1. Concurrency là gì?
`Concurrency` đề cập đến khả năng của một hệ thống xử lý nhiều tác vụ trong cùng một khoảng thời gian, mặc dù không nhất thiết phải thực hiện đồng thời `(parallelism)`.

Đối với Java, điều này có nghĩa là hệ thống có thể xử lý nhiều luồng `(threads)` cùng một lúc, nhưng không phải mọi luồng đều cần chạy song song trên các lõi CPU khác nhau.

Trong Java, sự hỗ trợ `concurrency` chủ yếu được cung cấp qua:

- **_Threads_**: Một đơn vị cơ bản trong xử lý đồng thời.
- **_Executor_**: Cung cấp cách tiếp cận quản lý luồng cao cấp hơn.
- **_Locks và Synchronization_**: Để đồng bộ hóa và bảo vệ tài nguyên chia sẻ.

### 2. Làm việc với Threads trong Java
Java cung cấp nhiều cách để làm việc với `threads`, bao gồm việc kế thừa lớp `Thread` và triển khai `interface Runnable`.

Tuy nhiên, phương pháp hiện đại hơn là sử dụng `Executor Framework`.

#### 2.1. Tạo Thread với Thread và Runnable
Cách cơ bản nhất để tạo một `thread` trong Java là kế thừa lớp `Thread` hoặc triển khai `interface Runnable`.

Ví dụ với `Runnable`:
```java
public class MyRunnable implements Runnable {
    @Override
    public void run() {
        System.out.println("Thread đang chạy: " + Thread.currentThread().getName());
    }

    public static void main(String[] args) {
        MyRunnable runnable = new MyRunnable();
        Thread thread = new Thread(runnable);
        thread.start();  // Bắt đầu thread
    }
}
```

Kết quả khi chạy chương trình:
```terminal
Thread đang chạy: Thread-0
```

Tuy nhiên, với việc tạo và quản lý `threads` bằng tay, việc quản lý tài nguyên sẽ trở nên phức tạp khi số lượng `thread` lớn. Đó là lý do cho sự ra đời và tồn tại của `Executor Framework` :))).


#### 2.2. Executor Framework
`Executor` giúp chúng ta quản lý các `thread` trong ứng dụng một cách dễ dàng hơn. Cụ thể, sử dụng `ExecutorService` để tạo một `pool` chứa các thread và quản lý việc thực thi các tác vụ.
```java
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class ExecutorExample {
    public static void main(String[] args) {
        ExecutorService executorService = Executors.newFixedThreadPool(2);

        for (int i = 0; i < 5; i++) {
            executorService.submit(new Runnable() {
                @Override
                public void run() {
                    System.out.println("Task đang chạy: " + Thread.currentThread().getName());
                }
            });
        }

        executorService.shutdown();
    }
}
```

Kết quả khi chạy chương trình:
```terminal
Task đang chạy: pool-1-thread-1
Task đang chạy: pool-1-thread-2
Task đang chạy: pool-1-thread-1
Task đang chạy: pool-1-thread-2
Task đang chạy: pool-1-thread-1
```

Với `ExecutorService`, mọi thứ đã được xử lý tự động dựa trên các config nếu có, hoặc không thì Java lấy các giá trị mặc định.

### 3. Synchronization và đảm bảo tính an toàn khi chia sẻ tài nguyên
Khi làm việc với nhiều `thread`, việc chia sẻ tài nguyên giữa các `thread` là một vấn đề nan giải. Java cung cấp cơ chế `synchronized` để bảo vệ các tài nguyên chia sẻ, đảm bảo rằng chỉ một `thread` có thể truy cập vào tài nguyên tại một thời điểm.

#### 3.1. Đồng bộ hóa với synchronized
```java
public class Counter {
    private int count = 0;

    public synchronized void increment() {
        count++;
    }

    public synchronized int getCount() {
        return count;
    }

    public static void main(String[] args) {
        Counter counter = new Counter();
        Runnable task = () -> {
            for (int i = 0; i < 1000; i++) {
                counter.increment();
            }
        };

        Thread thread1 = new Thread(task);
        Thread thread2 = new Thread(task);
        thread1.start();
        thread2.start();
    }
}
```
Trong ví dụ trên, phương thức `increment` được đồng bộ hóa bằng từ khóa `synchronized`, đảm bảo rằng mỗi lần chỉ có một `thread` có thể thay đổi giá trị của biến `count`.

#### 3.2. Lock và ReentrantLock
Một cách khác để kiểm soát đồng bộ hóa là sử dụng `Lock` từ package `java.util.concurrent.locks`. Cung cấp nhiều tính năng linh hoạt hơn `synchronized`.
```java
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

public class CounterWithLock {
    private int count = 0;
    private final Lock lock = new ReentrantLock();

    public void increment() {
        lock.lock();
        try {
            count++;
        } finally {
            lock.unlock();
        }
    }

    public int getCount() {
        return count;
    }

    public static void main(String[] args) {
        CounterWithLock counter = new CounterWithLock();
        Runnable task = () -> {
            for (int i = 0; i < 1000; i++) {
                counter.increment();
            }
        };

        Thread thread1 = new Thread(task);
        Thread thread2 = new Thread(task);
        thread1.start();
        thread2.start();
    }
}
```
`ReentrantLock` mang lại khả năng khóa linh hoạt hơn, bao gồm khả năng kiểm tra `locks` và hủy bỏ các thao tác khi cần thiết.

### 4. ExecutorService và Future
Một trong những tính năng mạnh mẽ của `ExecutorService` là khả năng làm việc với `Future`, cho phép theo dõi trạng thái và kết quả của các tác vụ đang thực hiện.

Ví dụ sử dụng `Future` để nhận kết quả trả về từ các tác vụ xử lý:
```java
import java.util.concurrent.*;

public class ExecutorWithFuture {
    public static void main(String[] args) throws InterruptedException, ExecutionException {
        ExecutorService executor = Executors.newCachedThreadPool();

        Callable<Integer> task = () -> {
            Thread.sleep(2000); // Giả lập công việc tốn thời gian
            return 123;
        };

        Future<Integer> future = executor.submit(task);
        System.out.println("Kết quả của task: " + future.get()); // Chờ kết quả

        executor.shutdown();
    }
}
```
Trong ví dụ trên, `Future.get()` sẽ chặn cho đến khi tác vụ hoàn tất và trả về kết quả.

Dù việc sử dụng `concurrency` giúp ứng dụng của bạn chạy nhanh hơn, nhưng cần chú ý đến các vấn đề hiệu suất:

- **_Quản lý số lượng thread hợp lý_**: quá nhiều `thread` có thể làm giảm hiệu suất do chi phí quản lý và chuyển đổi giữa các luồng.
- **_Tránh deadlock_**: khi nhiều `thread` chờ tài nguyên của nhau, có thể dẫn đến tình trạng `deadlock`, làm cho ứng dụng không thể tiếp tục thực thi.


### 5. Các cơ chế Concurrency nâng cao
Java cung cấp nhiều tính năng tiên tiến giúp chúng ta xử lý `concurrency` hiệu quả hơn trong các trường hợp phức tạp, chẳng hạn như:

#### 5.1 CompletableFuture
Là một phần của `java.util.concurrent` và cung cấp các khả năng xử lý bất đồng bộ rất mạnh mẽ. Nó hỗ trợ việc thực thi các tác vụ bất đồng bộ và có thể kết hợp nhiều tác vụ lại với nhau thông qua các API như `thenApply, thenAccept, thenCompose, và thenCombine`. Ngoài ra, `CompletableFuture` cũng hỗ trợ _hẹn giờ_ và xử lý các kết quả trả về từ các tác vụ song song.
```java
import java.util.concurrent.*;

public class CompletableFutureExample {
    public static void main(String[] args) throws InterruptedException, ExecutionException {
        ExecutorService executorService = Executors.newFixedThreadPool(2);

        // Tạo một CompletableFuture để thực thi một tác vụ bất đồng bộ
        CompletableFuture<Integer> future1 = CompletableFuture.supplyAsync(() -> {
            try {
                Thread.sleep(1000); // Giả lập công việc tốn thời gian
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            return 20;
        }, executorService);

        // Tiếp tục với một tác vụ khác khi tác vụ trước hoàn thành
        CompletableFuture<Integer> future2 = future1.thenApplyAsync(result -> {
            return result * 2;
        }, executorService);

        // Tiếp tục với một tác vụ khác và kết hợp kết quả của các future
        CompletableFuture<Integer> future3 = future2.thenCombineAsync(future1, (result1, result2) -> {
            return result1 + result2;
        });

        // Chờ đợi và nhận kết quả cuối cùng
        System.out.println("Kết quả là: " + future3.get()); // In ra kết quả cuối cùng
        executorService.shutdown();
    }
}
```
Trong đó:
- _CompletableFuture.supplyAsync_: bắt đầu một tác vụ bất đồng bộ.
- _thenApplyAsync_: áp dụng một phép toán bất đồng bộ sau khi tác vụ đầu tiên hoàn thành.
- _thenCombineAsync_: kết hợp kết quả từ hai tác vụ bất đồng bộ.

Kết quả có thể sẽ là 40, vì tác vụ đầu tiên trả về 20, và tác vụ thứ hai sẽ nhân nó với 2, rồi cuối cùng cộng với kết quả của tác vụ đầu tiên.


#### 5.2 ForkJoinPool
`ForkJoinPool` được thiết kế để xử lý các tác vụ tính toán đệ quy, có thể chia nhỏ thành nhiều tác vụ con và thực thi song song. `ForkJoinPool` là một loại thread pool đặc biệt hỗ trợ các tác vụ chia nhỏ `(fork)` và kết hợp lại `(join)`. Đây là một công cụ rất hữu ích khi bạn làm việc với các phép toán tính toán nặng hoặc cần phân chia một tác vụ thành nhiều phần nhỏ.
```java
import java.util.concurrent.*;

public class ForkJoinPoolExample {
    public static void main(String[] args) throws InterruptedException, ExecutionException {
        ForkJoinPool forkJoinPool = new ForkJoinPool();

        // Tạo một tác vụ đệ quy tính tổng các số từ 1 đến N
        RecursiveTask<Integer> task = new RecursiveTask<Integer>() {
            @Override
            protected Integer compute() {
                int n = 10;  // Ví dụ, tính tổng từ 1 đến 10
                if (n <= 1) {
                    return 1;
                } else {
                    // Chia nhỏ tác vụ thành 2 phần
                    RecursiveTask<Integer> subtask1 = new RecursiveTask<Integer>() {
                        @Override
                        protected Integer compute() {
                            return 1 + 2 + 3 + 4 + 5; // Tính tổng một phần nhỏ
                        }
                    };
                    subtask1.fork();  // Chạy task con song song

                    // Tính phần còn lại
                    RecursiveTask<Integer> subtask2 = new RecursiveTask<Integer>() {
                        @Override
                        protected Integer compute() {
                            return 6 + 7 + 8 + 9 + 10; // Tính tổng phần còn lại
                        }
                    };
                    subtask2.fork(); // Chạy task con song song

                    // Kết hợp kết quả của các task con
                    return subtask1.join() + subtask2.join();
                }
            }
        };

        // Thực thi tác vụ
        System.out.println("Kết quả: " + forkJoinPool.invoke(task)); // Kết quả: 55
        forkJoinPool.shutdown();
    }
}
```
Trong đó:
- _RecursiveTask_: là một lớp trừu tượng đại diện cho các tác vụ có thể chia nhỏ. Mỗi tác vụ có thể chia thành các tác vụ con.
- _fork()_: bắt đầu thực thi một tác vụ con.
- _join()_: kết hợp kết quả của các tác vụ con lại.

`ForkJoinPool` rất hiệu quả trong các tác vụ tính toán lớn hoặc đệ quy, vì nó có thể chia nhỏ các công việc và thực thi song song.

#### 5.3 Streams API và Parallel Streams
Java 8 giới thiệu `Streams API` để xử lý dữ liệu một cách linh hoạt và khai thác tốt các tính năng của `concurrency`. `Parallel Streams` là một tính năng mạnh mẽ cho phép xử lý các dữ liệu song song mà không cần phải quản lý `thread` trực tiếp.
```java
import java.util.Arrays;
import java.util.List;

public class ParallelStreamExample {
    public static void main(String[] args) {
        List<Integer> numbers = Arrays.asList(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);

        // Sử dụng Parallel Stream để xử lý song song
        int sum = numbers.parallelStream()
                         .mapToInt(Integer::intValue)
                         .sum();  // Tính tổng tất cả các phần tử

        System.out.println("Tổng là: " + sum);  // Kết quả: 55
    }
}
```
Trong đó:
- _parallelStream()_: biến Stream thành một stream song song.
Các phần tử của list sẽ được xử lý song song trên các thread khác nhau, giúp tăng tốc độ khi làm việc với tập hợp dữ liệu lớn.
Dùng parallelStream() rất dễ dàng và có thể tăng hiệu suất khi xử lý các tập dữ liệu lớn mà không cần phải tốn công quản lý các thread thủ công.


### Lời kết

Java cung cấp một loạt công cụ và kỹ thuật để làm việc với `concurrency`, từ `Thread` cơ bản đến các cơ chế phức tạp như `ExecutorService, Locks, Future, và CompletableFuture`.

Tuy nhiên, việc sử dụng các kỹ thuật này đòi hỏi phải hiểu rõ về cách thức hoạt động của chúng và những vấn đề có thể phát sinh, như `deadlock, race conditions, và tối ưu hóa tài nguyên hệ thống`.

Bằng cách nắm vững các công cụ này và áp dụng chúng một cách khéo léo, chúng ta có thể xây dựng các ứng dụng Java hiệu quả, đáp ứng nhu cầu xử lý đồng thời phức tạp trong môi trường thực tiễn đòi hỏi cao ngày càng cao.

> P/S: Nếu bạn thấy bài viết này hữu ích, đừng quên chia sẻ với bạn bè và đồng nghiệp của mình nhé!

Happy coding! 😎 👍🏻 🚀 🔥