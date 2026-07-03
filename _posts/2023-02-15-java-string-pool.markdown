---
layout: post
title: "java string pool"
date: 2023-02-15 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, interview, vietnamese]
---

Trong lập trình Java, việc quản lý bộ nhớ hiệu quả là yếu tố then chốt giúp ứng dụng hoạt động nhanh chóng và ổn định. Một trong những cơ chế tối ưu hóa bộ nhớ mạnh mẽ nhưng ít được nhắc đến là Java String Pool – vùng nhớ đặc biệt dành riêng cho các chuỗi ký tự (String). Cơ chế này cho phép Java tái sử dụng các chuỗi bất biến, giúp tiết kiệm bộ nhớ và cải thiện hiệu suất chương trình.

Dù String Pool là một khái niệm quen thuộc với nhiều lập trình viên Java, nhưng không phải ai cũng hiểu rõ cách thức hoạt động và những "bí mật" ẩn sau nó. Bài viết này sẽ cung cấp góc nhìn chi tiết về String Pool, kèm theo các ví dụ minh họa và giải thích các câu hỏi thường gặp trong phỏng vấn liên quan đến chủ đề này.

### # string pool là gì?

`Java String Pool` là một vùng nhớ đặc biệt nơi Java lưu trữ các giá trị chuỗi ký tự (string literal). Cơ chế này giúp tiết kiệm bộ nhớ và cải thiện hiệu suất bằng cách tái sử dụng các đối tượng chuỗi bất biến (immutable).

Sơ lượt về Java String Pool:

- String Interning: Khi bạn tạo một chuỗi ký tự dạng literal, Java sẽ kiểm tra xem chuỗi đó đã tồn tại trong String Pool chưa. Nếu có, chuỗi hiện tại sẽ được tái sử dụng; nếu chưa, chuỗi mới sẽ được thêm vào String Pool.
- Quản lý bộ nhớ: String Pool giúp quản lý bộ nhớ hiệu quả bằng cách tránh tạo ra nhiều đối tượng chuỗi có cùng giá trị.
- Tính bất biến: Vì các chuỗi trong Java là bất biến, chúng an toàn để chia sẻ và tái sử dụng trong String Pool.

### # ví dụ

**_Sử dụng String Pool cơ bản_**

```java
public class StringPoolExample {
    public static void main(String[] args) {
        String str1 = "Hello";
        String str2 = "Hello";
        String str3 = new String("Hello");

        // So sánh các string literal
        System.out.println(str1 == str2); // true

        // So sánh literal với một đối tượng String mới
        System.out.println(str1 == str3); // false

        // Sử dụng phương thức intern()
        String str4 = str3.intern();
        System.out.println(str1 == str4); // true
    }
}
```

**_String Pool và Interning_**

```java
public class StringInternExample {
    public static void main(String[] args) {
        String s1 = new String("world");
        String s2 = "world";

        System.out.println(s1 == s2); // false

        String s3 = s1.intern();

        System.out.println(s2 == s3); // true
    }
}
```

### # một số câu hỏi phỏng vấn thường gặp

#### Câu 1: Kết quả của đoạn mã sau là gì?

```java
public class StringPoolInterview {
    public static void main(String[] args) {
        String s1 = "Java";
        String s2 = new String("Java");
        String s3 = s2.intern();

        System.out.println(s1 == s2); // Kết quả?
        System.out.println(s1 == s3); // Kết quả?
    }
}
```

_Đáp án:_

- `s1 == s2` sẽ in ra `false` vì `s1` là string literal trong khi `s2` là một đối tượng String mới.
- `s1 == s3` sẽ in ra `true` vì `s3` đã được intern và trỏ đến cùng chuỗi trong String Pool với `s1`.

#### Câu 2: Đoạn mã sau sẽ cho kết quả gì?

```java
public class StringPoolTrick {
    public static void main(String[] args) {
        String s1 = "hello";
        String s2 = "he" + "llo";

        System.out.println(s1 == s2); // Kết quả?

        String s3 = "he";
        String s4 = s3 + "llo";

        System.out.println(s1 == s4); // Kết quả?
    }
}
```

_Đáp án_:

- `s1 == s2` sẽ in ra `true` vì cả hai đều là hằng số tại thời điểm biên dịch (compile-time constant) và trỏ đến cùng một chuỗi trong String Pool.
- `s1 == s4` sẽ in ra `false` vì `s4` được tạo ra tại runtime và không tự động intern.

#### Câu 3: Sự khác biệt giữa new String("abc") và String s = "abc" là gì?

_Đáp án_:

`new String("abc")` tạo một đối tượng `String` mới trong heap, ngay cả khi `"abc"` đã tồn tại trong String Pool.

`String s = "abc"` sử dụng string literal, trỏ đến String Pool và tái sử dụng chuỗi nếu nó đã tồn tại.

#### Câu 4: Kết quả của đoạn mã sau là gì?

```java
public class StringPoolBehavior {
    public static void main(String[] args) {
        String s1 = "abc";
        String s2 = "a" + "b" + "c";

        System.out.println(s1 == s2); // Kết quả?

        String s3 = "a";
        String s4 = "bc";
        String s5 = s3 + s4;

        System.out.println(s1 == s5); // Kết quả?
    }
}
```

_Đáp án:_

- `s1 == s2` sẽ in ra `true` vì `s2` là biểu thức hằng số tại thời điểm biên dịch và trỏ đến cùng chuỗi trong String Pool với `s1`.
- `s1 == s5` sẽ in ra `false` vì `s5` được tạo ra tại runtime và không tự động intern.

#### Câu 5: String Pool là một phần của heap hay stack?

_Đáp án_: String Pool là một phần của heap memory. Đây là vùng nhớ đặc biệt trong heap để lưu trữ string literal.

### # lời kết

Java String Pool là một cơ chế đơn giản nhưng đóng vai trò quan trọng trong việc quản lý bộ nhớ và tối ưu hiệu suất ứng dụng Java. Hiểu rõ về String Pool không chỉ giúp lập trình viên viết code hiệu quả hơn mà còn mang lại lợi thế lớn trong các buổi phỏng vấn kỹ thuật.

Qua bài viết này, bạn đã nắm được cách hoạt động của String Pool, sự khác biệt giữa chuỗi tạo bằng literal và new String(), cũng như cách sử dụng phương thức intern(). Hãy tiếp tục thực hành và áp dụng kiến thức này vào các dự án thực tế để củng cố thêm kỹ năng lập trình Java của mình.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
