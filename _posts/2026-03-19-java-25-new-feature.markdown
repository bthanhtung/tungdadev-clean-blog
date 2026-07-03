---
layout: post
title: "new features in java 25"
date: 2026-03-19 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, java25, english]
---

In September 2025, `Java 25` was released as a new `Long-Term Support (LTS)` version. As with every LTS release, it brings language updates, JVM improvements, and new tools for observability and performance tuning.

In this article, we’ll explore the most important features of Java 25, compare them to previous versions, and look at code examples.

### # compact object headers

Every Java object carries a header with metadata such as identity hash code, synchronization information and class pointer. In earlier JDKs, these headers typically consumed 12–16 bytes per object.

Java 25 introduces compact object headers, reducing the size to 8 bytes when class compression is enabled.

Let’s consider a simple class:

```java
class Point {
    int x;
    int y;
}
```

If we create 10 million Point objects:

```java
List<Point> points = new ArrayList<>();
for (int i = 0; i < 10_000_000; i++) {
    points.add(new Point());
}
```

- _**Before Java 25**_: Each object carries a 12-byte header. Total memory overhead **~120 MB**.

- _**With Java 25**_: Each object carries an 8-byte header. Total memory overhead **~80 MB**.

This results in **~33% memory savings** in this simple case, with improved CPU cache locality.

### # generational shenandoah GC

The Shenandoah GC was introduced to reduce pause times by performing concurrent compaction. However, without generations, it treated all objects equally, which caused inefficiencies for short-lived objects.

Java 25 finalizes Generational Shenandoah, splitting the heap into young and old generations:

- Young objects are collected more frequently.
- Long-lived objects are moved into the old generation and scanned less often.

This reduces CPU overhead and makes Shenandoah more competitive with **G1GC** while maintaining its low-pause characteristics.

### # ahead-of-time (AOT) method profiling

In large applications, the **JIT compiler** needs time to warm up before methods are fully optimized. This results in slower performance during startup or after scale-ups.

Java 25 introduces AOT method profiling, allowing us to record hot methods and apply optimizations earlier.

```bash
# Collect profiling data
java -XX:+UnlockExperimentalVMOptions -XX:+RecordAOTProfile -jar app.jar

# Use collected profile at startup
java -XX:+UseAOTProfile -jar app.jar
```

In practice, this can **reduce startup times by 30–70%** for microservices and serverless workloads.

### # java flight recorder (JFR) enhancements

Java flight recorder is one of the most powerful tools for observing the JVM in production. Java 25 improves it in several ways:

- CPU-time profiling: differentiates between CPU usage and wall-clock time.
- Method timing and tracing: finer-grained performance data.
- Cooperative sampling: reduces profiling overhead.

To start recording CPU-time profiling:

```bash
java -XX:StartFlightRecording:settings=profile,filename=recording.jfr \
     -XX:+UnlockCommercialFeatures -XX:+FlightRecorderCPUTime
```

This helps identify hotspots in real-world production workloads with minimal overhead.

### # structured concurrency

Concurrency in Java often requires careful coordination between multiple threads. Structured Concurrency simplifies this by treating multiple related tasks as a single unit of work.

```java
try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
    Future<String> user = scope.fork(() -> findUser());
    Future<Integer> order = scope.fork(() -> findOrders());

    scope.join();           // Wait for both
    scope.throwIfFailed();  // Propagate exceptions

    System.out.println(user.result() + " " + order.result());
}
```

Compared to traditional `ExecutorService`, error handling and cancellation are now more predictable.

### # language enhancements

#### # primitives in patterns and switch

In previous versions, pattern matching worked mainly with reference types. Java 25 expands this to primitive types:

```java
int number = 42;

switch (number) {
    case int n when n > 40 -> System.out.println("Large");
    case int n -> System.out.println("Small");
}
```

#### # compact source files

We can now write small programs in a single source file without wrapping everything in a class:

```java
void main() {
    System.out.println("Hello from Java 25!");
}
```

This is particularly useful for scripting and quick experiments.

#### # flexible constructor bodies

Constructors in Java traditionally required super() or this() to be the first statement. Java 25 allows pre-super logic:

```java
class Account {
    Account(String id) {
        log(id);      // Allowed before super()
        super();
    }
}
```

### # performance improvements

_**Memory**_:

- Compact headers save up to 25% heap usage for object-heavy applications.
- Generational Shenandoah reduces CPU usage and GC pause times for short-lived objects.

_**Startup**_:

- AOT profiling significantly reduces cold-start latency, especially in cloud-native applications.

_**Observability**_:

- New JFR features make profiling safer in production, reducing the need for custom monitoring hacks.

### # migration considerations

Compatibility: Compact headers support up to ~4M loaded classes. Applications with extreme dynamic class loading may need testing.

Preview features: Structured Concurrency and some language changes are still preview. Avoid in core production code until finalized.

Library support: Some libraries relying on low-level object header layouts may break. Run regression tests carefully.

### # conclusion

Java 25 builds on the foundations of Java 21 and 24 by delivering:

- More efficient memory use through compact headers.

- Better garbage collection with generational Shenandoah.

- Faster startup via AOT method profiling.

- Improved observability with enhanced JFR.

- Simpler concurrency and language ergonomics with structured concurrency and new syntax features.

For teams running large-scale microservices, latency-sensitive APIs, or memory-heavy workloads, these features bring measurable improvements in cost, performance, and maintainability.

As with any LTS release, Java 25 is a solid candidate for long-term adoption, and testing these new features early will help us prepare our codebases for the future.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.

**Reference**:

- [**OpenJDK JDK 25 Features – official list of JEPs and release notes**](https://openjdk.org/projects/jdk/25)
- [**InfoWorld – Game-changing features in JDK 25**](https://www.infoworld.com/article/4057212/the-three-game-changing-features-of-jdk-25.html)
- [**HappyCoders.eu – Java 25 Features**](https://www.happycoders.eu/java/java-25-features/?utm_source=chatgpt.com)
