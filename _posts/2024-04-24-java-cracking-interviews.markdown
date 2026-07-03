---
layout: post
title: "Java Craking Interviews"
date: 2024-04-24 19:29:39 +0700
categories: [Software Development]
tags: [Java, Interview]
---

Java 8 đã giới thiệu nhiều tính năng và cải tiến mạnh mẽ, đặc biệt là về lập trình chức năng và xử lý luồng. Dưới đây là một số câu hỏi phỏng vấn Java 8 ở mức độ dễ mà mình từ gặp và lượm lặt được.

### 1. Counting Characters
**Description**: Cho một chuỗi ngẫu nhiên, viết chương trình đếm số lần xuất hiện của từng ký tự trong chuỗi đó.

**Input example**: `CrisDaDevIsASoftwareEngineer`

**Expected result**: `{A=1, a=2, C=1, D=2, E=1, e=4, f=1, g=1, I=1, i=2, n=2, o=1, r=3, S=1, s=2, t=1, v=1, w=1}`
```java
public static Map<Character, Long> countCharacters(String str) {
        return str.chars() // Convert string to a stream of char values (int)
                .mapToObj(c -> (char) c) // Convert int values back to chars
                .collect(Collectors.groupingBy(Function.identity(), Collectors.counting()));
    }

public static void main(String[] args) {
    String input = "CrisDaDevIsASoftwareEngineer";
    Map<Character, Long> charCount = countCharacters(input);
    System.out.println(charCount);
}
```

Giải thích:
- `chars()`: chuyển đổi chuỗi thành một `stream` ký tự số nguyên.
- `mapToObj(c -> (char) c)` chuyển đổi số nguyên --> ký tự.
- `Collectors.groupingBy(Function.identity(), Collectors.counting())`: nhóm các ký tự lại với nhau và đếm số lần xuất hiện của chúng.


### 2. Finding Duplicates
**Description**: Cho một chuỗi ngẫu nhiên, viết chương trình tìm các kí tự xuát hiện nhiều hơn 1 lần.

**Input example**: `CrisDaDevIsASoftwareEngineer`

**Expected result**: `[a, r, s, D, e, i, n]`
```java
public static Map<Character, Long> findDuplicates(String str) {
    return str.chars()
            .mapToObj(c -> (char) c)
            .collect(Collectors.groupingBy(Function.identity(), Collectors.counting()))
            .entrySet().stream()
            .filter(entry -> entry.getValue() > 1)
            .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue));
}

public static void main(String[] args) {
    String input = "CrisDaDevIsASoftwareEngineer";
    Map<Character, Long> duplicates = findDuplicates(input);
    System.out.println(duplicates.keySet());
}
```

Giải thích: Tương tự như đếm ký tự nhưng lọc kết quả để chỉ bao gồm những ký tự xuất hiện nhiều lần.

### 3. Finding the First Unique Character
**Description**: Cho một chuỗi ngẫu nhiên, tìm ký tự duy nhất đầu tiên trong chuỗi đó.

**Input example**: `CrisDaDevIsASoftwareEngineer`

**Expected result**: `C`
```java
public static Character findFirstUnique(String str) {
    return str.chars()
            .mapToObj(c -> (char) c)
            .collect(Collectors.groupingBy(Function.identity(), LinkedHashMap::new, Collectors.counting()))
            .entrySet().stream()
            .filter(entry -> entry.getValue() == 1)
            .map(Map.Entry::getKey)
            .findFirst()
            .orElse(null);
}

public static void main(String[] args) {
    String input = "iFollowMilindMehta";
    Character firstUnique = findFirstUnique(input);
    System.out.println(firstUnique);
}
```

Giải thích: Sử dụng `LinkedHashMap` để duy trì thứ tự chèn giúp tìm ký tự duy nhất đầu tiên.


### 4. Second Highest Number in an Array
**Description**: Viết chương trình Java để tìm số lớn thứ hai trong một mảng cho trước.

**Input example**: `{1, 9, 3, 19, 28, 29, 24, 36}`

**Expected result**: `29`
```java
public static Integer findSecondHighest(int[] numbers) {
    return Arrays.stream(numbers)
            .boxed()
            .sorted(Comparator.reverseOrder())
            .skip(1)
            .findFirst()
            .orElse(null);
}

public static void main(String[] args) {
    int[] input = {1, 9, 3, 19, 28, 29, 24, 36};
    Integer secondHighest = findSecondHighest(input);
    System.out.println(secondHighest);
}
```

Giải thích: dùng `stream` sắp xếp mảng theo thứ tự ngược lại, bỏ qua phần tử đầu tiên và truy xuất phần tử thứ hai.


### 5. Finding the Longest String in an Array
**Description**: Viết chương trình Java để tìm chuỗi dài nhất trong một mảng.

**Input example**: `{"TungDaDev", "CrisDaDev", "MikeCorleone", "Jessi", "Microservice", "SpringBoot"}`

**Expected result**: `Microservice`
```java
public static String findLongestString(String[] strings) {
    return Arrays.stream(strings)
            .reduce((str1, str2) -> str1.length() > str2.length() ? str1 : str2)
            .orElse(null);
}

public static void main(String[] args) {
    String[] input = {"TungDaDev", "CrisDaDev", "MikeCorleone", "Jessi", "Microservice", "SpringBoot"};
    String longestString = findLongestString(input);
    System.out.println(longestString);
}
```

Cái này thì đâu cần phải giải thích gì nữa đâu phải không ^^


### 6. Finding Elements that Start with a Specific Digit
**Description**: Viết chương trình Java để tìm các phần tử trong mảng bắt đầu bằng chữ số 1.

**Input example**: `{1, 3, 11, 24, 33, 18, 42, 56, 19, 28, 16}`

**Expected result**: `[1, 11, 18, 19, 16]`
```java
public static List<String> findElementsStartingWithOne(int[] numbers) {
    return Arrays.stream(numbers)
            .boxed()
            .map(String::valueOf)
            .filter(str -> str.startsWith("1"))
            .collect(Collectors.toList());
}

public static void main(String[] args) {
    int[] input = {1, 3, 11, 24, 33, 18, 42, 56, 19, 28, 16};
    List<String> result = findElementsStartingWithOne(input);
    System.out.println(result);
}
```

Giải thích: Chuyển đổi số thành chuỗi và lọc những số bắt đầu bằng chữ số 1.

### Lời kết

Hiểu các khái niệm Java 8 cơ bản này và có thể triển khai mọt cách nhuần nhuyễn sẽ giúp ích rất nhiều cho bạn trong các cuộc phỏng vấn. Những ví dụ này bao gồm các khái niệm chính như `stream`, `biểu thức lambda`, `functional programming` và `thao tác dữ liệu`.

Thực hành các chương trình này để nắm vững các tính năng của Java 8 và giúp các bài code intervers trở nên ngầu lòi và xịn xò hơn các cách code Java truyền thống.

> P/S: Nếu bạn thấy bài viết này hữu ích, đừng quên chia sẻ với bạn bè và đồng nghiệp của mình nhé!

Happy coding! 😎 👍🏻 🚀 🔥

**Reference**:
- [**Cracking Java 8 Interviews**](https://milindmehta89.medium.com/cracking-java-8-interviews-must-know-questions-and-practical-examples-a13c2c6409f8)