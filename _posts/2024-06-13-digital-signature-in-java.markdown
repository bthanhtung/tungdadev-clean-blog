---
layout: post
title: "chữ ký số trong java"
date: 2024-06-13 19:29:39 +0700
categories: [Software Development]
tags: [java, software-development, digital-signature, java21, vietnamese]
---

Bạn là engineer hay developer làm việc trong các lĩnh vực tài chính, bảo hiểm hay bất kì domain nào khác thì việc đảm bảo tính toàn vẹn và chính xác của luồng dữ liệu là hết sức cần thiết.

Khi đó chữ ký số là giải pháp thực sự hữu ích cho yêu cầu này.

Vậy, bạn cần gì để ký dữ liệu? Trước hết, bạn cần một cặp khóa bất đối xứng. Nó bao gồm một `private-key`, chỉ người ký mới có quyền truy cập, và một `public-key` hoặc tốt hơn là một `certificate`. `Public-key` hoặc `certificate` này sẽ được cung cấp công khai cho mọi người.

### # chữ ký trong Java thuần túy

Cách đơn giản nhất để tạo một chữ ký trong Java như sau:

```java
Signature ecdsaSignature = Signature.getInstance("SHA256withECDSA");
ecdsaSignature.initSign(eccPrivateKey);
ecdsaSignature.update(dataToSign);
byte[] signature = ecdsaSignature.sign();
```

Sử dụng đoạn mã này, bạn sẽ tạo ra một chữ ký thô `(raw signature)` - có nghĩa là giá trị băm `(hash)` của dữ liệu đã được tính toán và giá trị băm này được mã hóa bằng `private-key`.

Vì vậy, để kiểm tra xem dữ liệu có bị chỉnh sửa hay không, bạn chỉ cần tính toán giá trị băm của dữ liệu cần kiểm tra, giải mã chữ ký và so sánh kết quả. Quá trình này được gọi là xác minh `(verify)` chữ ký:

```java
Signature ecdsaSignature = Signature.getInstance("SHA256withECDSA");
ecdsaSignature.initVerify(certificate);
ecdsaSignature.update(dataToVerify);
boolean isValide = ecdsaSignature.verify(rawSignature);
```

#### # ưu điểm

- Chữ ký có kích thước nhỏ, mã nguồn ngắn gọn và rõ ràng, rất phù hợp nếu bạn cần giữ chữ ký đơn giản và nhanh chóng.

#### # nhược điểm

- Người kiểm tra `(verifier)` phải biết chứng chỉ (certificate) cần sử dụng để xác minh chữ ký.
- Người kiểm tra cũng phải biết thuật toán cần sử dụng để xác minh.
- Người ký `(signer)` và người kiểm tra phải liên kết dữ liệu và ký với nhau.
- Loại chữ ký này rất phù hợp để sử dụng trong một hệ thống duy nhất.

### cú pháp mã hóa (Cryptographic Message Syntax - CMS)

Để tránh những bất lợi kể trên, việc sử dụng một định dạng chữ ký chuẩn là rất hữu ích. Tiêu chuẩn được sử dụng ở đây là `Cryptographic Message Syntax (CMS)` được định nghĩa trong `RFC5652`.

`CMS` mô tả một số tiêu chuẩn về dữ liệu mã hóa, nhưng chúng ta sẽ tập trung vào định dạng `Signed-data`. Dữ liệu được ký theo định dạng này chứa nhiều thông tin hữu ích, giúp bạn xác minh chữ ký dễ dàng hơn. Vậy làm thế nào để tạo cấu trúc dữ liệu như vậy?

`Java` cung cấp một interface cho các thao tác mã hóa thông qua `Java Cryptography Extension (JCE)`. Đây là phương pháp tốt nhất để thực hiện các thao tác mã hóa. Các triển khai của `JCE` được gọi là `JCE providers`, theo đó, bộ JDK của bạn đã có sẵn một `JCE provider` mang tên `SUN`.

Tuy nhiên, `JCE` không cung cấp interface cho `Cryptographic Message Syntax`. Vì vậy, bạn cần sử dụng một thư viện mã hóa khác. `BouncyCastle` là một lựa chọn tốt. Đây là một `JCE` provider với nhiều chức năng mã hóa bổ sung ở mức độ trừu tượng cao. Mã nguồn để tạo một chữ ký với `CMS` và `BouncyCastle` có thể trông như sau (tham khảo JavaDoc của BouncyCastle):

```java
List certList = new ArrayList();
CMSTypedData  msg = new CMSProcessableByteArray("Hello world!".getBytes());
certList.add(signCert);
Store certs = new JcaCertStore(certList);
CMSSignedDataGenerator gen = new CMSSignedDataGenerator();
ContentSigner sha256Signer = new JcaContentSignerBuilder("SHA256withECDSA").build(signKP.getPrivate());

gen.addSignerInfoGenerator(
  new JcaSignerInfoGeneratorBuilder(
    new JcaDigestCalculatorProviderBuilder().build())
      .build(sha256Signer, signCert));

gen.addCertificates(certs);
CMSSignedData sigData = gen.generate(msg, false);
```

Lưu ý rằng bạn có thể xác định liệu dữ liệu có nên được đưa vào bên trong `CMS Container` cùng với chữ ký hay không. Nói cách khác, bạn có thể chọn tạo một chữ ký attached (đính kèm) hoặc detached (tách rời).

`CMS Container` thường bao gồm các thành phần sau:

- Chữ ký.
- Chứng chỉ (certificate) có thể được sử dụng để xác minh.
- Thuật toán mã hóa số.
- Có thể bao gồm cả dữ liệu đã được ký.

Ngoài ra, bạn cũng có thể tạo nhiều chữ ký cho cùng một dữ liệu và đưa tất cả vào cùng một container, nghĩa là nhiều người ký (signers) có thể ký cùng một dữ liệu và gửi tất cả các chữ ký trong cùng một container.

Dưới đây là đoạn mã để xác minh một `CMSSignedData` (tham khảo JavaDoc của BouncyCastle):

```java
Store certStore = cmsSignedData.getCertificates();
SignerInformationStore signers = cmsSignedData.getSignerInfos();
Collection c = signers.getSigners();
Iterator it = c.iterator();

while (it.hasNext()){
  SignerInformation signer = (SignerInformation)it.next();
  Collection certCollection = certStore.getMatches(signer.getSID());
  Iterator certIt = certCollection.iterator();
  X509CertificateHolder cert = (X509CertificateHolder)certIt.next();
  if (signer.verify(new JcaSimpleSignerInfoVerifierBuilder().build(cert))) {
    // successfully verified
  }
}
```

### # light Weight

Nếu bạn muốn sử dụng toàn bộ các chức năng của một triển khai `JCE`, bạn cần cài đặt `"unlimited strength jurisdiction policy files"` cho `JVM`. Nếu không, bạn có thể gặp phải lỗi như sau:

```java
java.lang.SecurityException: Unsupported keysize or algorithm parameters
or java.security.InvalidKeyException: Illegal key size
```

> Lý do gây ra ngoại lệ này là do các hạn chế về công nghệ mã hóa trước năm 2000. Những hạn chế này đã giới hạn độ dài của khóa. Thật không may, sau khi cài đặt mặc định, JDK vẫn không có triển khai để không bị hạn chế, và đó là lý do tại sao bạn phải cài đặt các `file policy` bổ sung.

Như vậy, đó không phải là vấn đề lớn và bạn có thể cài đặt thêm các file policy cho JVM.

Nhưng nếu bạn muốn phân phối ứng dụng của mình thì sao? Việc này có thể khá khó khăn nhưng đừng lo, thư viện `BouncyCastle` là mọt giải pháp cấp cứu kịp thời. Nó cung cấp một _phiên bản nhẹ_ của các thao tác mã hóa, các thao tác này không sử dụng bất kỳ `JCE provider` nào.

Vì vậy, không cần phải cài đặt thêm các file policy nữa :))). Có thể bạn đã thấy một số class của `BouncyCastle` bắt đầu với `JCE (Java Cryptography Extension)` hoặc `JCA (Java Cryptography Architecture)`. Những lớp này sử dụng `JCE provider`. Các lớp _phiên bản nhẹ_ bắt đầu với `BouncyCastle` và như đã nói ở trên, không sử dụng `JCE provider`. Code để ký với _phiên bản nhẹ_ như sau:

```java
X509Certificate certificate = ...;

X509CertificateHolder x509CertificateHolder = new X509CertificateHolder(certificate.getEncoded());
String certAlgorithm = certificate.getPublicKey().getAlgorithm();

CMSTypedData message = new CMSProcessableByteArray(dataToSign);

AlgorithmIdentifier sigAlgId = new DefaultSignatureAlgorithmIdentifierFinder().find("SHA256WithECDSA");

AlgorithmIdentifier digAlgId = new DefaultDigestAlgorithmIdentifierFinder().find(sigAlgId);
AsymmetricKeyParameter privateKeyParameter = PrivateKeyFactory.createKey(
                                                      softCert.getPrivateKey().getEncoded());

ContentSigner signer = new BcECDSAContentSignerBuilder(sigAlgId, digAlgId).build(privateKeyParameter);

SignerInfoGeneratorBuilder signerInfoGeneratorBuilder =
                       new SignerInfoGeneratorBuilder(new BcDigestCalculatorProvider());
SignerInfoGenerator infoGenerator = signerInfoGeneratorBuilder.build(signer, x509CertificateHolder);

CMSSignedDataGenerator dataGenerator = new CMSSignedDataGenerator();
dataGenerator.addSignerInfoGenerator(infoGenerator);

dataGenerator.addCertificate(x509CertificateHolder);

CMSSignedData signedData = dataGenerator.generate(message, true);
```

Bạn sẽ nhận được cùng một `container CMS` mà không cần cài đặt bất kỳ bản vá nào. Bạn có thể xác minh dữ liệu với đoạn mã sau:

```java
Collection<SignerInformation> signers = cmsSignedData.getSignerInfos().getSigners();
List<SignerInformation> signerList = new ArrayList<>(signers);
SignerInformation signerFromCMS = signerList.get(0);
SignerId sid = signerFromCMS.getSID();

Store store = cmsSignedData.getCertificates();
Collection<X509CertificateHolder> certificateCollection = store.getMatches(sid);
ArrayList<X509CertificateHolder> x509CertificateHolders = new ArrayList<>(certificateCollection);
// we use the first certificate
X509CertificateHolder x509CertificateHolder = x509CertificateHolders.get(0);

BcECSignerInfoVerifierBuilder verifierBuilder = new BcECSignerInfoVerifierBuilder(new BcDigestCalculatorProvider());
SignerInformationVerifier verifier = verifierBuilder.build(x509CertificateHolder);
boolean result = signerFromCMS.verify(verifier);
```

Có hai cách để tạo chữ ký và xác minh chữ ký.

Cách đầu tiên là tạo chữ ký thô. Cách này rất ngắn gọn và rõ ràng, nhưng nó không cung cấp đủ thông tin về quá trình ký.

Cách thứ hai là tạo một `CMS container`, phương pháp này phức tạp hơn một chút nhưng cung cấp công cụ mạnh mẽ để làm việc với chữ ký. Nếu bạn không muốn sử dụng bất kỳ `JCE provider` nào, bạn có thể sử dụng phiên bản `Light Weight` của các thao tác mã hóa do `BouncyCastle` cung cấp.

### # lời kết

Chữ ký số trong môi trường phát triển phần mềm giờ đây đã không còn xa lạ gì với các anh/chị/em developer nữa. Tuy nhiên các phiên bản và kỹ thuật mã hoá ngày càng được nâng cấp, customized để tránh xa vòng tay của hacker.

Apply được chữ kí số để đảm bảo luồng dữ liệu đã nâng cao bảo mật cho hệ thống. Customized lại nữa thì chắc có trời mới biết bạn làm gì trong code đó nếu không public ra bên ngoài.

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.

**Reference**:

- [**Digital Signature in Java**](https://reflectoring.io/how%20to%20sign/)
