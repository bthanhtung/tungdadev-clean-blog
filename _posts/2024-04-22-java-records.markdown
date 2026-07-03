---
layout: post
title: "Java Records"
date: 2024-04-22 19:29:39 +0700
categories: [Software Development]
tags: [Java]
---

Java Records được giới thiệu trong Java 14 và được thêm chính thức trong Java 16.

Tuy nhiên, nhiều developer vẫn chưa tận dụng hết tiềm năng của Java Record. Chính vì lẽ đó, bài viết này ra đời nhằm mục đích giới thiệu về những sức mạnh mà Records có thể mang lại.

Bắt đầu thôi :v

### 1. Java Record là gì?
Thông thường một class truyền thống trong Java sẽ tương tự thế này:
```java
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class StudentDetails {
    private  final String name;
    private final int studentNumber;

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        StudentDetails that = (StudentDetails) o;
        return studentNumber == that.studentNumber && Objects.equals(name, that.name);
    }

    @Override
    public int hashCode() {
        return Objects.hash(name, studentNumber);
    }

    @Override
    public String toString() {
        return "StudentDetails{" +
                "name='" + name + '\'' +
                ", studentNumber=" + studentNumber +
                '}';
    }
}
```
Class StudentDetails đơn giản với hai trường: `name` và `studentNumber`. Các trường này là `private` và `final`, nghĩa là chúng không thể thay đổi sau khi đối tượng được tạo.

Để quản lý các trường này, cần một `constructor`, các method `getter/setter`, một method `equals`, một method `hashCode` và một method `toString`. Điều này tạo ra gần 50 dòng mã (nếu không sử dụng lombok), cho thấy các class Java trước khi `Records` ra đời sẽ trông dài dòng như thế nào :)).

Để tạo một đối tượng `student` từ class `StudentDetails`, làm đơn giản như như cái thuở mới bập boẹ học Java thôi:
```java
public class Main {
    public static void main(String[] args) {
          StudentDetails student = new StudentDetails("TungDaDev" , 6789);
    }
}
```

Nhưng nếu code với `Record` thì sao nhỉ? Hãy xem cách triển khai được đơn giản hóa ra làm sao nè:
```java
public record StudentRecord(String name, int studentNumber) {
}

public class Main {
    public static void main(String[] args) {
          StudentRecord student = new StudentRecord("TungDaDEv" , 6789);
    }
}
```

Với `Record`, chương trình được giảm thiểu tối đa số dòng code, trông ngắn gọn, dễ hiểu và dễ đọc hơn rất nhiều.


### 2. Ưu điểm của Java Record và những thứ có thể làm với nó
- _Giảm boilerplate code_: Java Records tự động tạo các phương thức cần thiết như `equals()`, `hashCode()` và `toString()`.

- _Tính bất biến (Immutability)_: Theo mặc định, tất cả các trường trong một Records đều là `private` và `final`, đảm bảo tính bất biến.

- _Custom constructors_: Records cung cấp một `constructor` chuẩn mặc định, nhưng có thể `override` nó.
```java
public record StudentRecord(String name, int studentNumber) {
    public StudentRecord (String name , int studentNumber){
        if (studentNumber <= 0) {
            throw new IllegalArgumentException("Student number must be positive.");
        }
    }
}
```
- Records còn hỗ trợ hàm tạo nhỏ gọn, chỉ khả dụng cho các class Records.
```java
//compact contructor
public record StudentRecord(String name, int studentNumber) {
    public StudentRecord {
        if (studentNumber <= 0) {
            throw new IllegalArgumentException("Student number must be positive.");
        }
    }
}
```

- _Interface Implementaton_: Records có thể `implements` các Interface khác.
```java
public record StudentRecord(String name, int studentNumber) implements School {
}
```

- _Custom methods_: Records cho phép định nghĩa thêm các method public.
```java
public record StudentRecord(String name, int studentNumber) {
    public String name() {
        return name;
    }
}
```

- Records có thể chứa các method và field static.
- Records có thể khai báo theo kiểu generic.
```java
public record Student<T>(String name, T studentNumber) {
}
```

### 3. Vậy không làm gì được với Java records?
- _Define private instance fields_: Tất cả các trường trong một Record đều ngầm định là `private` và `final`.
- _Inherit record classes_: Record không thể extends các class khác.



### Lời kết

Nhiều developer vẫn chưa quen với các tính năng mới này, nhưng việc tích hợp `Java Records` vào các dự án có thể dẫn đến mã sạch hơn, dễ bảo trì hơn.

Hãy thử Java Records và xem tốc độ code sẽ được tăng tốc như thế nào :D

> P/S: Nếu bạn thấy bài viết này hữu ích, đừng quên chia sẻ với bạn bè và đồng nghiệp của mình nhé!

Happy coding! 😎