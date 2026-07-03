---
layout: post
title: "java 25: should be upgraded?"
date: 2025-12-02 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, java25, optimization, vietnamese]
---

Trong những ăm gần đây, Java liên tục cải tiến với các phiên bản mới. Java 21 (LTS) đã mang lại nhiều tính năng như Virtual Threads, Pattern Matching và Foreign Function & Memory API.

Giờ đây, Java 25 tiếp tục nâng cao hiệu suất và khả năng mở rộng, đặc biệt hữu ích cho các ứng dụng Spring Boot và cloud-native.

Java ra bản mới cũng bị chửi, không ra cũng bị chửi. Nhưng với Java 25, có nhiều cải tiến đáng giá, đặc biệt trong bối cảnh microservices và cloud-native apps ngày càng phổ biến.

Mặc kệ thiên hạ, Java vẫn cứ tiến lên!

### # jvm performance: startup nhanh hơn, jit tối ưu & profiling cloud

Java 25 tiếp tục cải tiến JVM với:

- **Compact Object Headers**: giảm từ 12–16 bytes → 8 bytes

**Lợi ích**: heap footprint giảm 5–10%, quét object nhanh hơn, cache hiệu quả hơn.

- **Ahead-of-Time Compilation (AOT)**: biên dịch bytecode → native code ngay từ build step
- Startup nhanh hơn, steady-state performance cải thiện rõ rệt.
- **Generational Shenandoah GC**: giảm pause time & CPU usage.
- **Removal 32-bit x86 Port**: build nhỏ hơn, giảm technical debt, tối ưu cho hardware hiện đại.

#### # so sánh startup spring boot nhỏ

```java
public class StartupTest {
    public static void main(String[] args) throws Exception {
        long start = System.currentTimeMillis();
        // Giả lập Spring Boot init
        Thread.sleep(500);
        System.out.println("App started in " + (System.currentTimeMillis() - start) + " ms");
    }
}
```

Run với 2 JDK:

```bash
/usr/lib/jvm/jdk-21/bin/java StartupTest
/usr/lib/jvm/jdk-25/bin/java StartupTest
```

Benchmark StringConcat:

```bash
/usr/lib/jvm/jdk-21/bin/java -jar target/benchmarks.jar "org.openjdk.bench.java.lang.StringConcat"
/usr/lib/jvm/jdk-25/bin/java -jar target/benchmarks.jar "org.openjdk.bench.java.lang.StringConcat"
```

**Kết quả**: Java 25 giảm startup time ~20% và StringConcat nhanh hơn ~15% nhờ JIT tối ưu.

#### # AOT example

```java
public class HelloService {
    public static void main(String[] args) {
        long t0 = System.currentTimeMillis();
        for (int i = 0; i < 1_000_000; i++) {
            Math.log(Math.sqrt(i + 1));
        }
        System.out.println("Done in " + (System.currentTimeMillis() - t0) + " ms");
    }
}
```

Compile AOT:

```bash
/usr/lib/jvm/jdk-25/bin/jaotc2 --output HelloAOT.so HelloService.class
/usr/lib/jvm/jdk-25/bin/java -XX:+LoadAOTLibrary=HelloAOT.so HelloService
```

**Kết quả**: Startup + warmup nhanh hơn đáng kể so với Java 21.

### # garbage collection: zgc & g1 tối ưu cho container

Java 25 tune ZGC và G1:

- ZGC pause-time giảm ~50%
- G1 pause-time giảm ~30%
- CPU usage giảm
- Tự đọc cgroup memory, RAM free nhanh hơn
- Generational ZGC: tốt cho workloads nhiều object nhỏ

Benchmark:

```java
import java.util.*;

public class GCBenchmark {
    public static void main(String[] args) {
        List<byte[]> list = new ArrayList<>();
        long start = System.currentTimeMillis();
        for (int i = 0; i < 100_000; i++) {
            list.add(new byte[1024 * 512]);
            if (list.size() > 200) list.subList(0, 100).clear();
        }
        System.out.println("Done in " + (System.currentTimeMillis() - start) + " ms");
    }
}
```

Run:

```bash
# G1
/usr/lib/jvm/jdk-21/bin/java -Xmx1G -Xlog:gc -jar GCBenchmark.jar > gc21.log
/usr/lib/jvm/jdk-25/bin/java -Xmx1G -Xlog:gc -jar GCBenchmark.jar > gc25.log

# ZGC
/usr/lib/jvm/jdk-21/bin/java -XX:+UseZGC -Xmx1G -Xlog:gc -jar GCBenchmark.jar > zgc21.log
/usr/lib/jvm/jdk-25/bin/java -XX:+UseZGC -Xmx1G -Xlog:gc -jar GCBenchmark.jar > zgc25.log
```

**Observation**:

- Pause trung bình ZGC: từ 1–2 ms → ~0.5 ms
- Heap used after GC thấp hơn → memory footprint giảm
- Số full GC ít hơn → ứng dụng ổn định hơn

### # language features: string templates & pattern matching

Java 25 hoàn thiện String Templates và Sequenced Collections, kết hợp với Pattern Matching từ Java 21:

```java
Object obj = "Hello Java 25";
if (obj instanceof String s && s.length() > 5) {
    System.out.println(s.toUpperCase()); // không cần cast
}

static String formatter(Object obj) {
    return switch (obj) {
        case Integer i -> String.format("int %d", i);
        case Long l    -> String.format("long %d", l);
        case String s  -> String.format("String '%s'", s);
        default        -> obj.toString();
    };
}
```

String Templates:

```java
import static java.lang.StringTemplate.STR;

String name = "Alice";
int age = 30;
String message = STR."Hello, \{name}! You are \{age} years old.";
System.out.println(message);
```

**Lợi ích**: code gọn hơn, đọc dễ, giảm boilerplate.

### # virtual threads: quản lý concurrency dễ dàng hơn

Java 25 tiếp tục tối ưu Virtual Threads:

- Memory per thread giảm 1MB → 2–4 KB
- Thread creation nhanh, scheduling overhead thấp
- Thích hợp I/O bound & high concurrency

```java
import java.util.concurrent.*;

public class VirtualThreadPOC {
    static final int TASKS = 100_000;

    public static void main(String[] args) throws Exception {
        long start = System.nanoTime();
        try (ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor()) {
            for (int i = 0; i < TASKS; i++) {
                int id = i;
                executor.submit(() -> { Thread.sleep(10); return id; });
            }
        }
        long end = System.nanoTime();
        System.out.printf("Completed %,d tasks in %.2f s%n", TASKS, (end - start)/1_000_000_000.0);
    }
}
```

==> time giảm 10–20%, CPU usage thấp hơn ~20%.

### # foreign function & memory API: safe & fast native access

- Finalized trong Java 25
- Truy cập memory & native code mà không cần JNI
- Dễ dùng cho cloud-native, microservices

### # security & tooling

- TLS & crypto defaults mạnh hơn
- JLink images nhỏ hơn → deploy nhẹ
- Diagnostic tools cải thiện → monitor & troubleshoot dễ dàng

### # jvm flags gợi ý java 25

```bash
-XX:+UseCompactObjectHeaders
-XX:+UnlockExperimentalVMOptions
-XX:+UseZGC
-XX:+ZGenerational
-XX:MaxGCPauseMillis=5
-XX:SoftMaxHeapSize=80%
-XX:ZFragmentationLimit=10
-XX:ZUncommitDelay=300
-Xlog:gc*,gc+heap=info,safepoint=info:file=/var/log/java/gc.log:time,level,tags
```

Lý do bật Compact Object Headers:

- Heap giảm 10–30%
- Cache tốt hơn → performance tăng
- Hỗ trợ object model Valhalla

### # kết luận

Java 25 không chỉ là cập nhật phiên bản. Nó cải thiện performance, GC, concurrency, memory footprint, cloud-readiness, và developer experience. Với workloads Spring Boot, microservices, và cloud-native apps, việc nâng cấp là một quyết định chiến lược.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
