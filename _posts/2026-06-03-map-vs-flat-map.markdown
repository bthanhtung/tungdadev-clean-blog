---
layout: post
title: "map vs flatMap trong Java — Stream, Optional & CompletableFuture"
date: 2026-06-03 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, best-practices, vietnamese]
---

### # tại sao hay nhầm?

Cả `map` và `flatMap` đều transform giá trị bên trong container (Stream, Optional, CompletableFuture). Khác biệt duy nhất: **flatMap "bóc" thêm 1 lớp wrapper** mà map không làm.

Hiểu đơn giản:

- `map(f)`: apply f → wrap kết quả vào container → có thể tạo nested container
- `flatMap(f)`: apply f (f tự trả container) → KHÔNG wrap thêm → flatten

### # stream: map vs flatMap

#### # map — 1:1 transformation

```java
// Mỗi element → 1 element mới
List<String> names = List.of("john", "jane", "bob");

List<String> upper = names.stream()
   .map(String::toUpperCase)    // "john" → "JOHN"
   .toList();
// ["JOHN", "JANE", "BOB"]

// map với function trả về object khác
List<Order> orders = ...;
List<UUID> customerIds = orders.stream()
   .map(Order::getCustomerId)   // Order → UUID
   .distinct()
   .toList();
```

#### # flatMap — 1:N transformation (flatten nested collections)

Khi function trả về collection/stream, `map` tạo `Stream<Stream<T>>` — nested. `flatMap` flatten thành `Stream<T>`.

```java
// Mỗi order có nhiều items → lấy TẤT CẢ items từ TẤT CẢ orders
List<Order> orders = List.of(order1, order2, order3);

// map → Stream<List<OrderItem>> (nested!)
List<List<OrderItem>> nested = orders.stream()
   .map(Order::getItems)  // Order → List<OrderItem>
   .toList();
// [[item1, item2], [item3], [item4, item5]] — NESTED

// flatMap → Stream<OrderItem> (flat!)
List<OrderItem> allItems = orders.stream()
   .flatMap(order -> order.getItems().stream())  // Order → Stream<OrderItem>
   .toList();
// [item1, item2, item3, item4, item5] — FLAT
```

#### # real-world examples

```java
// Lấy tất cả tags từ tất cả products
List<String> allTags = products.stream()
   .flatMap(product -> product.getTags().stream())
   .distinct()
   .sorted()
   .toList();

// Lấy tất cả permissions từ tất cả roles của user
Set<String> permissions = user.getRoles().stream()
   .flatMap(role -> role.getPermissions().stream())
   .collect(Collectors.toSet());

// Parse CSV lines → individual fields
List<String> allFields = csvLines.stream()
   .flatMap(line -> Arrays.stream(line.split(",")))
   .map(String::trim)
   .toList();

// Multi-level flatten: workspace → projects → tasks
List<Task> allTasks = workspaces.stream()
   .flatMap(ws -> ws.getProjects().stream())
   .flatMap(project -> project.getTasks().stream())
   .filter(task -> task.getStatus() == TaskStatus.OPEN)
   .toList();
```

### # optional: map vs flatMap

Khi function trả về `Optional`, `map` tạo `Optional<Optional<T>>`. `flatMap` giữ `Optional<T>`.

#### # map — function trả về plain value

```java
Optional<User> user = userRepository.findById(userId);

// map: User → String (plain value)
Optional<String> email = user.map(User::getEmail);
// Optional<"john@mail.com"> hoặc Optional.empty()

Optional<String> upperName = user
   .map(User::getName)
   .map(String::toUpperCase);
```

#### # flatMap — function trả về Optional

```java
// findById trả Optional → cần flatMap
Optional<User> user = userRepository.findById(userId);

// map → Optional<Optional<Address>>
Optional<Optional<Address>> nested = user.map(User::getAddress);
// Nếu User::getAddress return Optional<Address>

// flatMap → Optional<Address>
Optional<Address> address = user.flatMap(User::getAddress);

// Chain multiple Optional operations
Optional<String> city = userRepository.findById(userId)      // Optional<User>
   .flatMap(User::getAddress)                                // Optional<Address>
   .flatMap(Address::getCity)                                // Optional<String>
   .map(String::toUpperCase);                                // Optional<String>
```

#### # practical pattern

```java
// Service method returning Optional
public Optional<ProductDTO> getProductWithCategory(UUID productId) {
   return productRepository.findById(productId)           // Optional<Product>
       .flatMap(product ->
           categoryRepository.findById(product.getCategoryId())  // Optional<Category>
               .map(category -> toDTO(product, category)));      // Optional<ProductDTO>
}

// Avoid nested optionals
public Optional<String> getWorkspaceName(UUID userId) {
   return userRepository.findById(userId)                  // Optional<User>
       .flatMap(user -> workspaceRepository.findById(user.getDefaultWorkspaceId()))  // Optional<Workspace>
       .map(Workspace::getName);                           // Optional<String>
}
```

### # CompletableFuture: thenApply vs thenCompose

Trong CompletableFuture, pattern giống hệt:

- `thenApply` = `map` (function trả plain value)
- `thenCompose` = `flatMap` (function trả CompletableFuture)

```java
CompletableFuture<User> userFuture = CompletableFuture.supplyAsync(() -> fetchUser(userId));

// thenApply (= map): User → String
CompletableFuture<String> nameFuture = userFuture
   .thenApply(User::getName);  // plain value

// thenApply khi function trả Future → nested!
CompletableFuture<CompletableFuture<Order>> nested = userFuture
   .thenApply(user -> fetchOrderAsync(user.getId()));  // Returns CF → nested CF<CF<Order>>

// thenCompose (= flatMap): flatten
CompletableFuture<Order> orderFuture = userFuture
   .thenCompose(user -> fetchOrderAsync(user.getId()));  // Returns CF → flat CF<Order>

// Chain
CompletableFuture<String> result = CompletableFuture
   .supplyAsync(() -> fetchUser(userId))               // CF<User>
   .thenCompose(user -> fetchOrdersAsync(user.getId())) // CF<List<Order>>
   .thenApply(orders -> orders.size() + " orders");     // CF<String>
```

### # lời kết

| Context           | map equivalent | flatMap equivalent | Khi nào dùng flatMap           |
| ----------------- | -------------- | ------------------ | ------------------------------ |
| Stream            | map()          | flatMap()          | Function trả Stream/Collection |
| Optional          | map()          | flatMap()          | Function trả Optional          |
| CompletableFuture | thenApply()    | thenCompose()      | Function trả CompletableFuture |
| Reactor Mono      | map()          | flatMap()          | Function trả Mono/Flux         |

**Rule đơn giản**: Nếu function bạn truyền vào ĐÃ wrap kết quả trong container (Optional, Stream, Future...) → dùng flatMap. Nếu function trả plain value → dùng map.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
