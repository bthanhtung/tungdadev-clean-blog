---
layout: post
title: "backpressure using semaphores"
date: 2022-10-06 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, virtual-thread, concurrency, english]
---

Performance isn't always about doing things faster. Sometimes, it's about doing things wisely — understanding where your bottlenecks really are and shaping your system around them rather than bulldozing through.

Recently, I ran into a situation that reminded me of this truth.
I was working on a service that had to send **hundreds of independent requests** to an external API — each request small, statelessand safe to run in parallel. The perfect candidate for concurrency, right?

So naturally, I thought:

```
"Hey, let's use Java's virtual threads. They're lightweight.
Let's fire them all and watch the magic happen!"
```

And for a moment, it was magical — until it wasn't.

### # limited capacity of concurrency

Virtual threads are a remarkable leap in concurrency design. They're cheap to create, require minimal memoryand make it possible to scale I/O-bound workloads to tens of thousands of threads without sweating.

But here's the catch: **your external dependencies don't scale the same way**.

When you suddenly spin up hundreds or thousands of concurrent HTTP calls, your machine might handle it just fine. The remote API, though, may not.
Soon enough, I saw this pattern:

- Random timeouts.
- Rate-limit errors (HTTP 429s).
- Throughput dropping, not rising.

It was a classic case of _**"too much of a good thing"**_.

Even though virtual threads freed me from the limitations of the JVM's thread model, they didn't free me from reality — network capacity, server throttlingand API rate limits.

So the challenge shifted:

```
"How do I keep the concurrency benefits, but prevent the system from overwhelming the external API?"
```

### # the elegant old-school fix: semaphore

Instead of introducing reactive streams or a full-blown rate limiter like `Resilience4j`, I wanted something simple — a piece of logic that could express:

```
"No more than N requests at once."
```

Enter the humble **Semaphore**.

Semaphores have been around for decades, dating back to Dijkstra's early work on concurrency control. They're often overlooked today in favor of modern abstractions like CompletableFutures or reactive pipelines, but they're still incredibly effective in the right scenario.

Here's the simplified idea I implemented:

```java
var semaphore = new Semaphore(20); // allow 20 concurrent requests

ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();

List<Callable<Void>> tasks = requests.stream()
    .<Callable<Void>>map(req -> () -> {
        semaphore.acquire();
        try {
            callExternalApi(req);
        } finally {
            semaphore.release();
        }
        return null;
    })
    .toList();

executor.invokeAll(tasks);
executor.shutdown();
```

And that's it.
The entire backpressure mechanism lives in just a few lines of code.

### # what's happening here

Let's unpack what's really going on under the hood:

- Virtual threads handle scalability. They allow the system to run thousands of lightweight tasks without blocking kernel threads.
- The Semaphore acts as a concurrency gate — only allowing 20 threads to proceed with the API call at any moment.
- When a thread finishes, it releases its permit, letting another waiting thread in line.
- This creates a natural flow control mechanism, keeping both our local machine and the remote API healthy.

It's like managing traffic at a one-lane bridge: everyone eventually crosses, but only a safe number of cars pass at a time.

### # why this works well

This approach works because it aligns throughput with capacity.
Virtual threads give us the ability to generate concurrency cheaply. The Semaphore ensures we consume concurrency responsibly.

Instead of letting thousands of requests hit the network layer simultaneously (and letting the remote server panic), we're saying:

```
"We'll go as fast as you can handle — no faster."
```

This keeps:

- The **CPU** free from excessive context switching.
- The **remote API** safe from overload.
- The **system latency** stable, even under heavy load.

In other words, we achieve **_controlled concurrency_** — not just concurrency for its own sake.

### # backpressure - systemic control loop

From a systems design standpoint, what we've done here is implement a primitive form of backpressure — a feedback mechanism that prevents producers (our threads) from overwhelming consumers (the external API).

In reactive systems (like Reactor, RxJava, or Akka Streams), backpressure is built into the pipeline. It automatically signals upstream producers to slow down when downstream consumers can't keep up.
But in our simple virtual-thread setup, there's no natural backpressure signal. The producer just keeps generating tasks.

By wrapping the external call in a Semaphore, we effectively simulate that signal:

- When all 20 permits are in use, new threads pause until capacity is freed.
- The queue of waiting threads becomes our implicit buffer.
- No extra libraries, brokers, or schedulers required.

It's simple. It's predictable. And it's enough.

### # tuning the limit

Here's where the engineer in me couldn't resist experimenting.
I ran several benchmarks to tune the number of concurrent permits (N in the Semaphore).

At first, I tried:

- **N = 10** → Safe but underutilized.
- **N = 50** → Occasional timeouts.
- **N = 20** → Sweet spot.

What I found interesting is that the optimal concurrency had nothing to do with CPU cores or memory — it was purely bound by the external system's tolerance.

This led to a useful realization:

```
"The optimal concurrency of your system is not how many tasks you can run, but how many tasks your dependencies can handle."
```

That's a principle worth remembering.

### # alternatives

Of course, Semaphores aren't the only game in town. Depending on your system's complexity, you could also use:

- **Rate limiters**: Libraries like` Resilience4j` or Guava's `RateLimiter` control request rate (per second), not concurrency. Good for strict APIs with rate caps.

- **Reactive streams**: Frameworks like Reactor or RxJava provide native backpressure via demand signals. Excellent for fully reactive pipelines — but heavier to introduce if you're not already reactive.

- **Message brokers (Kafka, RabbitMQ)**: Great when you need durability, retry logicand distributed throttling — but major overkill for a simple I/O-bound task like this.

So in my case, the Semaphore hit the sweet spot: minimal code, no new dependenciesand zero conceptual overhead.

### # lessons learned

This experience reinforced a few key lessons I think every backend engineer should keep in mind:

- **Concurrency ≠ Throughput**: Just because you can run 1,000 threads doesn't mean you should.

- **Every system has a bottleneck**: Find it, respect itand design around it.

- **Backpressure is a sign of respect**: It's your system saying, "I'll go as fast as you can keep up."

Simplicity scales better than complexity: A small, elegant fix often beats an over-engineered reactive solution.

### # wrapping up

At first glance, this was just a story about limiting concurrency.
But in a deeper sense, it's about the philosophy of system design.

Modern software engineering often celebrates "scaling up" — more threads, more requests, more throughput. But the best systems don't just scale up; they balance themselves. They know when to speed up, when to hold backand when to let the other side breathe.

Virtual threads gave me the freedom to scale; Semaphores gave me the discipline to do it wisely.
Together, they form a powerful pairing — one that respects both performance and stability.

Because in distributed systems, control often matters more than speed.

> Just some personal notes, hoping to bring a little value. If you find it helpful, feel free to share it with your friends & colleagues!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
