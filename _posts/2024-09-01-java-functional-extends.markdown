---
layout: post
title: "Java Functional extends"
date: 2024-09-01 19:29:39 +0700
categories: [Software Development]
tags: [Java, Functional Programming]
---

Như các bạn đã biết, trong Java đã hỗ trợ lập trình hàm từ lâu. Tuy nhiên số lượng param còn rất hạn chế.

Chẳng hạn như ví dụ sau:

```java
public class FunctionListExample {
    public static void main(String[] args) {
        List<String> names = Arrays.asList("Alice", "Bob", "Charlie");

        // Function to convert names to uppercase
        Function<String, String> toUpperCase = str -> str.toUpperCase();

        // Apply function to list
        List<String> upperNames = names.stream()
                                       .map(toUpperCase)
                                       .collect(Collectors.toList());

        System.out.println("Original names: " + names);
        System.out.println("Uppercase names: " + upperNames);
    }
}
```
Nhân lúc rãnh rồi, mình implement sẵn một số function được mở rộng từ Function<T,R> sẵn có trong Java.

### BiFunction
BiFunction là interface có 2 tham số đầu vào và 1 kết quả đầu ra. Này trong Java cũng có sẵn rồi.

```java
import java.util.function.BiFunction;

public class BiFunctionExample {
    public static void main(String[] args) {
        BiFunction<Integer, Integer, Integer> sum = (a, b) -> a + b;
        System.out.println("Sum: " + sum.apply(5, 7)); // Output: Sum: 12
    }
}
```

### TriFunction
TriFunction là interface có 3 tham số đầu vào và 1 kết quả đầu ra.

```java
/**
 * Represents a function that accepts three arguments and produces a result.
 * This is a three-arity extension to the functional interfaces {@link Function}
 * and {@link java.util.function.BiFunction BiFunction} from the JDK.
 *
 * @param <T> the type of the first argument to the function
 * @param <U> the type of the second argument to the function
 * @param <V> the type of the third argument to the function
 * @param <R> the type of the result of the function
 */
@FunctionalInterface
public interface TriFunction<T, U, V, R> {

    R apply(T t, U u, V v);

    default <S> TriFunction<T, U, V, S> andThen(Function<? super R, S> after) {
        return (t, u, v) -> after.apply(apply(t, u, v));
    }

}
```

Ví dụ:

```java
public class TriFunctionExample {
    public static void main(String[] args) {
        TriFunction<Integer, Integer, Integer, String> sumAndFormat = 
            (a, b, c) -> "Sum: " + (a + b + c);
        System.out.println(sumAndFormat.apply(2, 3, 5)); // Output: Sum: 10
    }
}
```

### QuadFunction
QuadFunction là interface có 4 tham số đầu vào và 1 kết quả đầu ra.

```java
/**
 * Represents a function that accepts four arguments and produces a result.
 * This is a four-arity extension to the functional interfaces {@link Function}
 * and {@link java.util.function.BiFunction BiFunction} from the JDK.
 *
 * @param <T> the type of the first argument to the function
 * @param <U> the type of the second argument to the function
 * @param <V> the type of the third argument to the function
 * @param <W> the type of the fourth argument to the function
 * @param <R> the type of the result of the function
 *
 * @see TriFunction
 */
@FunctionalInterface
public interface QuadFunction<T, U, V, W, R> {

    R apply(T t, U u, V v, W w);

    default <S> QuadFunction<T, U, V, W, S> andThen(Function<? super R, S> after) {
        return (t, u, v, w) -> after.apply(apply(t, u, v, w));
    }

}
```

Ví dụ:

```java
public class QuadFunctionExample {
    public static void main(String[] args) {
        QuadFunction<Integer, Integer, Integer, Integer, Integer> exc = 
            (a, b, c, d) -> a * b * c * d;
        System.out.println(exc.apply(1, 2, 3, 4)); // Output: 24
    }
}
```

### PentaFunction
PentaFunction là interface có 5 tham số đầu vào.

```java
/**
 * Represents a function that accepts five arguments and produces a result.
 * This is a five-arity extension to the functional interfaces {@link Function}
 * and {@link java.util.function.BiFunction BiFunction} from the JDK.
 *
 * @param <T> the type of the first argument to the function
 * @param <U> the type of the second argument to the function
 * @param <V> the type of the third argument to the function
 * @param <W> the type of the fourth argument to the function
 * @param <X> the type of the fifth argument to the function
 * @param <R> the type of the result of the function
 *
 * @see QuadFunction
 */
@FunctionalInterface
public interface PentaFunction<T, U, V, W, X, R> {

    R apply(T t, U u, V v, W w, X x);

    default <S> PentaFunction<T, U, V, W, X, S> andThen(Function<? super R, S> after) {
        return (t, u, v, w, x) -> after.apply(apply(t, u, v, w, x));
    }

}
```

Ví dụ:

```java
public class PentaFunctionExample {
    public static void main(String[] args) {
        PentaFunction<Integer, Integer, Integer, Integer, Integer, Double> average = 
            (a, b, c, d, e) -> (a + b + c + d + e) / 5.0;
        System.out.println(average.apply(10, 20, 30, 40, 50)); // Output: 30.0
    }
}
```

### HexaFunction
HexaFunction là interface có 6 tham số đầu vào.

```java
/**
 * Represents a function that accepts six arguments and produces a result.
 * This is a six-arity extension to the functional interfaces {@link Function}
 * and {@link java.util.function.BiFunction BiFunction} from the JDK.
 *
 * @param <T> the type of the first argument to the function
 * @param <U> the type of the second argument to the function
 * @param <V> the type of the third argument to the function
 * @param <W> the type of the fourth argument to the function
 * @param <X> the type of the fifth argument to the function
 * @param <Y> the type of the sixth argument to the function
 * @param <R> the type of the result of the function
 *
 * @see PentaFunction
 */
@FunctionalInterface
public interface HexaFunction<T, U, V, W, X, Y, R> {

    R apply(T t, U u, V v, W w, X x, Y y);

    default <S> HexaFunction<T, U, V, W, X, Y, S> andThen(Function<? super R, S> after) {
        return (t, u, v, w, x, y) -> after.apply(apply(t, u, v, w, x, y));
    }

}
```

Ví dụ:

```java
public class HexaFunctionExample {
    public static void main(String[] args) {
        HexaFunction<Integer, Integer, Integer, Integer, Integer, Integer, Integer> sum = 
            (a, b, c, d, e, f) -> a + b + c + d + e + f;
        System.out.println(sum.apply(1, 2, 3, 4, 5, 6)); // Output: 21
    }
}
```

### HeptaFunction
HeptaFunction (hay có thể gọi là SeptiFunction) là interface có 7 tham số đầu vào.

```java
/**
 * Represents a function that accepts seven arguments and produces a result.
 * This is a seven-arity extension to the functional interfaces {@link Function}
 * and {@link java.util.function.BiFunction BiFunction} from the JDK.
 *
 * @param <T> the type of the first argument to the function
 * @param <U> the type of the second argument to the function
 * @param <V> the type of the third argument to the function
 * @param <W> the type of the fourth argument to the function
 * @param <X> the type of the fifth argument to the function
 * @param <Y> the type of the sixth argument to the function
 * @param <Z> the type of the seventh argument to the function
 * @param <R> the type of the result of the function
 *
 * @see HexaFunction
 */
@FunctionalInterface
public interface HeptaFunction<T, U, V, W, X, Y, Z, R> {

    R apply(T t, U u, V v, W w, X x, Y y, Z z);

    default <S> HeptaFunction<T, U, V, W, X, Y, Z, S> andThen(Function<? super R, S> after) {
        return (t, u, v, w, x, y, z) -> after.apply(apply(t, u, v, w, x, y, z));
    }

}
```

Ví dụ:

```java
public class HeptaFunctionExample {
    public static void main(String[] args) {
        HeptaFunction<String, String, String, String, String, String, String, String> concat = 
            (a, b, c, d, e, f, g) -> String.join("-", a, b, c, d, e, f, g);
        System.out.println(concat.apply("A", "B", "C", "D", "E", "F", "G")); 
        // Output: A-B-C-D-E-F-G
    }
}
```

### OctaFunction
OctaFunction là interface có 8 tham số đầu vào.

```java
/**
 * Represents a function that accepts eight arguments and produces a result.
 * This is an eight-arity extension to the functional interfaces {@link Function}
 * and {@link java.util.function.BiFunction BiFunction} from the JDK.
 *
 * @param <T> the type of the first argument to the function
 * @param <U> the type of the second argument to the function
 * @param <V> the type of the third argument to the function
 * @param <W> the type of the fourth argument to the function
 * @param <X> the type of the fifth argument to the function
 * @param <Y> the type of the sixth argument to the function
 * @param <Z> the type of the seventh argument to the function
 * @param <A> the type of the eight argument to the function
 * @param <R> the type of the result of the function
 *
 * @see SeptiFunction
 */
@FunctionalInterface
public interface OctaFunction<T, U, V, W, X, Y, Z, A, R> {

    R apply(T t, U u, V v, W w, X x, Y y, Z z, A a);

    default <S> OctaFunction<T, U, V, W, X, Y, Z, A, S> andThen(Function<? super R, S> after) {
        return (t, u, v, w, x, y, z, a) -> after.apply(apply(t, u, v, w, x, y, z, a));
    }

}
```

Ví dụ:

```java
public class OctaFunctionExample {
    public static void main(String[] args) {
        OctaFunction<Integer, Integer, Integer, Integer, Integer, Integer, Integer, Integer, Integer> sum = 
            (a, b, c, d, e, f, g, h) -> a + b + c + d + e + f + g + h;
        System.out.println(sum.apply(1, 2, 3, 4, 5, 6, 7, 8)); // Output: 36
    }
}
```

### NonaFunction
NonaFunction là interface có 9 tham số đầu vào.

```java
/**
 * Represents a function that accepts nine arguments and produces a result.
 * This is a nine-arity extension to the functional interfaces {@link Function}
 * and {@link java.util.function.BiFunction BiFunction} from the JDK.
 *
 * @param <T> the type of the first argument to the function
 * @param <U> the type of the second argument to the function
 * @param <V> the type of the third argument to the function
 * @param <W> the type of the fourth argument to the function
 * @param <X> the type of the fifth argument to the function
 * @param <Y> the type of the sixth argument to the function
 * @param <Z> the type of the seventh argument to the function
 * @param <A> the type of the eight argument to the function
 * @param <B> the type of the ninth argument to the function
 * @param <R> the type of the result of the function
 *
 * @see OctoFunction
 */
@FunctionalInterface
public interface NonaFunction<T, U, V, W, X, Y, Z, A, B, R> {

    R apply(T t, U u, V v, W w, X x, Y y, Z z, A a, B b);

    default <S> NonaFunction<T, U, V, W, X, Y, Z, A, B, S> andThen(Function<? super R, S> after) {
        return (t, u, v, w, x, y, z, a, b) -> after.apply(apply(t, u, v, w, x, y, z, a, b));
    }

}
```

Ví dụ:

```java
public class NonaFunctionExample {
    public static void main(String[] args) {
        NonaFunction<String, String, String, String, String, String, String, String, String, Integer> countLength = 
            (a, b, c, d, e, f, g, h, i) -> a.length() + b.length() + c.length() + d.length() + e.length() 
                                          + f.length() + g.length() + h.length() + i.length();
        System.out.println(countLength.apply("A", "BB", "CCC", "DDDD", "EEEEE", "F", "GG", "HHH", "IIII")); 
        // Output: 24
    }
}
```

### DecaFunction
DecaFunction là interface có 10 tham số đầu vào.

```java
/**
 * Represents a function that accepts ten arguments and produces a result.
 * This is a ten-arity extension to the functional interfaces {@link Function}
 * and {@link java.util.function.BiFunction BiFunction} from the JDK.
 *
 * @param <T> the type of the first argument to the function
 * @param <U> the type of the second argument to the function
 * @param <V> the type of the third argument to the function
 * @param <W> the type of the fourth argument to the function
 * @param <X> the type of the fifth argument to the function
 * @param <Y> the type of the sixth argument to the function
 * @param <Z> the type of the seventh argument to the function
 * @param <A> the type of the eight argument to the function
 * @param <B> the type of the ninth argument to the function
 * @param <C> the type of the tenth argument to the function
 * @param <R> the type of the result of the function
 *
 * @see NonaFunction
 */
@FunctionalInterface
public interface DecaFunction<T, U, V, W, X, Y, Z, A, B, C, R> {

    R apply(T t, U u, V v, W w, X x, Y y, Z z, A a, B b, C c);

    default <S> DecaFunction<T, U, V, W, X, Y, Z, A, B, C, S> andThen(Function<? super R, S> after) {
        return (t, u, v, w, x, y, z, a, b, c) -> after.apply(apply(t, u, v, w, x, y, z, a, b, c));
    }

}
```

Ví dụ:

```java
public class DecaFunctionExample {
    public static void main(String[] args) {
        DecaFunction<Integer, Integer, Integer, Integer, Integer, Integer, Integer, Integer, Integer, Integer, Integer> exc = 
            (a, b, c, d, e, f, g, h, i, j) -> a * b * c * d * e * f * g * h * i * j;
        System.out.println(exc.apply(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)); // Output: 3628800
    }
}
```

Chúng ta có thể mở rộng lên đến n tham số. Tuy nhiên không ai làm như vậy cả. Quá nhiều param lại mang đến những nhược điểm khác.

Có thể extends tương tự với các Functional khác của Java như: Consumer<T>, Predicate<T>, Supplier<T>.

### Lời kết

Việc sử dụng các funtion trên giúp code của bạn trở nên ngầu hơn. Tuy nhiên khá khó để đọc hiểu cho người mới tiếp cận.

Functional phù hợp với các các logic xử lý liên quan đến stream, CompletableFuture hay logic cần tái sử dụng hoặc truyền qua nhiều module hoặc cần kết hợp nhiều hàm nhỏ thành hàm lớn hơn.


> P/S: Nếu bạn thấy bài viết này hữu ích, đừng quên chia sẻ với bạn bè và đồng nghiệp của mình nhé!

Happy coding! 😎 👍🏻 🚀 🔥