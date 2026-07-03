---
layout: post
title: "101+ lệnh linux thường gặp"
date: 2025-03-20 19:29:39 +0700
categories: [Software Development]
tags: [linux, software-development, commands, vietnamese]
---

Đối với lập trình viên, đặc biệt là các cá nhân làm trong mảng backend, devops thường rất chuộng và say sưa với hệ điều hành linux. Thậm chí có người còn xem nó là chân ái.

Trong thực tế, khi các service được cài trên các server thì việc developer thao tác với linux nói chung và các dòng lệnh nói riêng là điều không thể tránh khỏi. Thế nên, biết càng nhiều, nhớ càng nhiều lệnh linux sẽ giúp ích phần nào giúp tăng giá trị bản thân và nâng cao hiệu quả công việc.

Ngoài ra, việc sử dụng các dòng lệnh sẽ khiến bạn trông ngầu hơn trong mắt người khác. Thật đấy, không đùa đâu :))) Không tin thì đọc bài xong rồi ra quán cafe ngồi thực hành để kiểm chứng nhé. :)))

### # quản lý tệp và thư mục

`ls`: liệt kê nội dung thư mục, dùng để xem danh sách file kèm chi tiết trong thư mục hiện tại.

```zsh
tungdadev@linux:~$ ls -l
```

Ngoài ra `ls` còn kết hợp với các tham số khác như: `-ll`, `-la`.

`cd`: viết tắt của `change directory`, dùng để di chuyển đến thưc mục đích.\
Chẳng hạn muốn di chuyển đến thư mục `/var/mb-server/log`, ta làm như sau:

```zsh
tungdadev@linux:~$ cd /var/mb-server/log
```

`pwd`: viết tắt từ `print working directory`, được dùng để in ra đường dẫn đến thư mục làm việc hiện tại.

```zsh
tungdadev@linux:~$ pwd
/home/tungdadev
```

`mkdir`: viết tắt của `make directory` dùng để tạo thư mục mới.

```zsh
tungdadev@linux:~$ mkdir new_project
```

`rmdir`: xóa thư mục rỗng.

```zsh
tungdadev@linux:~$ rmdir old_folder
```

`rm`: xóa tệp hoặc thư mục --> Xóa thư mục và tất cả nội dung bên trong.

```zsh
tungdadev@linux:~$ rm -r temp_folder
```

`cp`: sao chép tệp hoặc thư mục --> Backup file quan trọng.

```zsh
tungdadev@linux:~$ cp file.txt /backup/file.txt
```

`mv`: di chuyển hoặc đổi tên tệp/thư mục.

```zsh
tungdadev@linux:~$ mv old_name.txt new_name.txt
```

`find`: tìm kiếm file hoặc thư mục. Giả sử tìm log file trong thư mục `/var/log`.

```zsh
tungdadev@linux:~$ find /var/log -name "*.log"
```

`touch`: tạo tệp rỗng mới.

```zsh
tungdadev@linux:~$ touch index.html
```

### # quản lý người dùng và quyền

`whoami`: hiển thị user hiện tại.

```zsh
tungdadev@linux:~$ whoami
tungdadev
```

`id`: hiển thị thông tin user.

```zsh
tungdadev@linux:~$ id
uid=1000(tungdadev) gid=1000(tungdadev) groups=1000(tungdadev)
```

`chmod`: thay đổi quyền truy cập tệp --> Gán quyền thực thi cho script.

```zsh
tungdadev@linux:~$ chmod 755 script.sh
```

`chown`: thay đổi chủ sở hữu tệp/thư mục --> Gán quyền sở hữu file cấu hình cho root.

```zsh
tungdadev@linux:~$ chown root:root config.conf
```

`passwd`: đổi mật khẩu người dùng -- > Thay đổi mật khẩu cho tài khoản hiện tại.

```zsh
tungdadev@linux:~$ passwd
```

### # quản lý hệ thống

`top`: giám sát tiến trình và tài nguyên hệ thống theo thời gian thực --> Kiểm tra CPU/RAM của hệ thống đang sử dụng.

```zsh
tungdadev@linux:~$ top
```

`htop`: phiên bản nâng cao của top --> Quản lý tiến trình với giao diện thân thiện.

```zsh
tungdadev@linux:~$ htop
```

`df`: hiển thị thông tin dung lượng ổ đĩa --> Xem dung lượng ổ đĩa còn trống.

```zsh
tungdadev@linux:~$ df -h
```

`du`: kiểm tra dung lượng thư mục hoặc tệp --> Xem dung lượng log file chiếm.

```zsh
tungdadev@linux:~$ du -sh /var/log
```

`free`: kiểm tra dung lượng RAM. Trên window hay mac, bạn chỉ cẩn click mở phần mềm mặc định là xong. Linux cũng có, nhưng mà thôi, xài lệnh cho nó ngầu. Ah mà trên server trong các dự án thực tế làm gì có UI mà xài :))) Nên nhớ lệnh đi nhé.

```zsh
tungdadev@linux:~$ free -h
```

`uptime`: kiển thị thời gian hoạt động của hệ thống. --> Kiểm tra thời gian chạy của server.

```zsh
tungdadev@linux:~$ uptime
```

`reboot`: khởi động lại hệ thống. Nó tương tự nút `Restart` của window vậy á.

```zsh
tungdadev@linux:~$ sudo reboot
```

`shutdown`: tắt máy. Nó nhanh hơn việc cầm chuột rồi click click mấy cái nữa phải không?

```zsh
tungdadev@linux:~$ sudo shutdown now
```

`systemctl`: quản lý dịch vụ hệ thống. Lệnh này dùng nhiều trong dự án thực tế nè, restart/start/stop các service đều kết hợp với nó. Chẳng hạn như, khởi động lại dịch vụ Nginx:

```zsh
tungdadev@linux:~$ sudo systemctl restart nginx
```

`journalctl`: xem log hệ thống --> Kiểm tra log của dịch vụ Nginx:

```zsh
tungdadev@linux:~$ sudo journalctl -u nginx
```

### # xử lý mạng

`ping`: kiểm tra kết nối mạng.

```zsh
tungdadev@linux:~$ ping google.com
```

`curl`: gửi yêu cầu HTTP. --> Kiểm tra trạng thái HTTP của website.

```zsh
tungdadev@linux:~$ curl -I https://example.com
```

`wget`: tải tệp từ URL. --> Tải tệp trực tuyến.

```zsh
tungdadev@linux:~$ wget https://example.com/file.zip
```

`netstat`: xem thông tin kết nối mạng --> Kiểm tra port đang mở

```zsh
tungdadev@linux:~$ netstat -tuln
```

`ifconfig`: cấu hình và kiểm tra mạng. --> Kiểm tra IP địa chỉ.

```zsh
tungdadev@linux:~$ ifconfig
```

`ip`: thay thế hiện đại của ifconfig. --> Xem thông tin mạng.

```zsh
tungdadev@linux:~$ ip addr show
```

`nslookup`: tra cứu DNS. --> Kiểm tra thông tin tên miền.

```zsh
tungdadev@linux:~$ nslookup google.com
```

`traceroute`: theo dõi đường đi của gói tin. --> Xác định sự cố mạng.

```zsh
tungdadev@linux:~$ traceroute example.com
```

`nmap`: quét port và dịch vụ. --> Kiểm tra bảo mật mạng.

```zsh
tungdadev@linux:~$ nmap -sT localhost
```

`ss`: xem trạng thái socket. --> Theo dõi kết nối TCP/UDP.

```zsh
tungdadev@linux:~$ ss -tuln
```

### # quản lý gói phần mềm

`apt-get`: quản lý gói phần mềm. --> Cài đặt Nginx.

```zsh
tungdadev@linux:~$ sudo apt-get install nginx
```

`apt`: phiên bản cải tiến của apt-get. --> Cập nhật thông tin gói.

```zsh
tungdadev@linux:~$ sudo apt update
```

`dpkg`: quản lý gói cấp thấp. --> Cài đặt gói .deb thủ công.

```zsh
tungdadev@linux:~$ sudo dpkg -i package.deb
```

`snap`: Snap là một hệ thống đóng gói và triển khai đa nền tảng do nhà sản xuất Ubuntu Canonical phát triển cho nền tảng Linux. Nó tương thích với hầu hết các bản phân phối Linux chính như Ubuntu, Debian, Arch Linux, Fedora, CentOS và Manjaro

Ví dụ như cài đặt Visual Studio Code.

```zsh
tungdadev@linux:~$ sudo snap install vscode --classic
```

`flatpak`: Flatpak là một khuôn khổ cho các ứng dụng trên Linux. Với các bản phân phối khác nhau ưu tiên quản lý gói riêng, Flatpak hướng đến mục tiêu cung cấp giải pháp đa nền tảng với các lợi ích khác. Nó giúp công việc của các nhà phát triển trở nên dễ dàng hơn.

Cài đặt Firefox từ Flathub.

```zsh
tungdadev@linux:~$ flatpak install flathub org.mozilla.firefox
```

### # phân tích log

`tail`: xem dòng cuối của tệp log. --> Theo dõi log hệ thống theo thời gian thực.

```zsh
tungdadev@linux:~$ tail -f /var/log/syslog
```

`head`: xem dòng đầu của tệp. --> Xem 20 dòng đầu của log.

```zsh
tungdadev@linux:~$ head -n 20 /var/log/syslog
```

`cat`: hiển thị nội dung file. --> Đọc nội dung log truy cập của Nginx.

```zsh
tungdadev@linux:~$ cat /var/log/nginx/access.log
```

`less`: đọc tệp log dài với cuộn trang. --> Duyệt log kernel dài.

```zsh
tungdadev@linux:~$ less /var/log/dmesg
```

`grep`: tìm kiếm chuỗi trong file log. --> Tìm lỗi trong log hệ thống.

```zsh
tungdadev@linux:~$ grep "error" /var/log/syslog
```

`awk`: trích xuất và xử lý dữ liệu từ file log. --> Lấy IP và timestamp từ log Nginx.

```zsh
tungdadev@linux:~$ awk '{print $1, $4}' /var/log/nginx/access.log
```

`cut`: tắt trường trong file log. --> Lấy cột đầu tiên (IP).

```zsh
tungdadev@linux:~$ cut -d' ' -f1 /var/log/nginx/access.log
```

`sort`: là một công cụ giúp bạn sắp xếp nội dung trong file, rất phổ biến trong hệ điều hành Unix và tương tự Unix.

```zsh
tungdadev@linux:~$ sort /var/log/nginx/access.log
```

`uniq`: là một tiện ích dòng lệnh báo cáo hoặc lọc ra các dòng lặp lại trong một tệp. Nói một cách dễ hiểu, `uniq` là công cụ giúp phát hiện các dòng trùng lặp liền kề và đồng thời xóa các dòng trùng lặp. `uniq` lọc ra các dòng kết hợp liền kề từ tệp đầu vào (được yêu cầu làm đối số) và ghi dữ liệu đã lọc vào tệp đầu ra.

```zsh
tungdadev@linux:~$ sort /var/log/nginx/access.log | uniq
```

`wc`: viết tắt của số từ `(word count)`. Lệnh được sử dụng để đếm số dòng, số từ, số byte và thậm chí cả các ký tự và byte ....

```zsh
tungdadev@linux:~$ wc -l /var/log/syslog
```

### # xử lý file hệ thống

`stat`: hiển thị thông tin chi tiết của tệp tương tự như `ls` nhưng chi tiết hơn.

```zsh
tungdadev@linux:~$ stat file.txt
```

`file`: xác định loại tệp. --> Kiểm tra định dạng tệp

```zsh
tungdadev@linux:~$ file image.png
```

`ln`: `symbolic` link hay liên kết tượng trưng là một tính năng vô cùng hữu ích trong hệ điều hành Linux, giúp chúng ta quản lý hệ thống tệp một cách linh hoạt và hiệu quả hơn. `Symlink` mang lại nhiều lợi ích như:

- Tạo shortcut cho file và thư mục.
- Quản lý cấu trúc thư mục phức tạp.
- Chia sẻ file và thư mục.
- Cập nhật liên kết thay vì file gốc.
- Tạo các liên kết mềm cho các ứng dụng.
- Tiết kiệm không gian đĩa.

Để tạo `symlink` cho Python ta làm như sau:

```zsh
tungdadev@linux:~$ ln -s /usr/bin/python3 /usr/bin/python
```

`fsck`: kiểm tra và sửa lỗi hệ thống file. --> Sửa lỗi trên phân vùng /dev/sda1.

```zsh
tungdadev@linux:~$ sudo fsck /dev/sda1
```

`mount`: gắn kết hệ thống file. --> Gắn USB vào hệ thống.

```zsh
tungdadev@linux:~$ sudo mount /dev/sdb1 /mnt
```

`umount`: tháo gắn hệ thống file. --> Ngắt kết nối USB.

```zsh
tungdadev@linux:~$ sudo umount /mnt
```

`df`: hiển thị dung lượng trống trên các ổ đĩa của máy. Lệnh này còn có thể nhận thêm các tham số và tùy chọn khác nhau, cho phép bạn tùy chỉnh kết quả hiển thị theo ý muốn.

```zsh
tungdadev@linux:~$ df -h
```

`blkid`: có thể được sử dụng để hiển thị nhãn phân vùng hiện tại (nếu có) và UUID của phân vùng đĩa. Chỉ cần chỉ định đường dẫn thiết bị của phân vùng bạn muốn xem.

```zsh
tungdadev@linux:~$ sudo blkid
```

`parted`: là chương trình phân vùng đĩa và thay đổi kích thước phân vùng. Nó cho phép bạn tạo, hủy, thay đổi kích thước, di chuyển và sao chép các phân vùng `ext2, linux-swap, FAT, FAT32 và reiserfs`. Đây là công cụ thiết yếu cho người dùng Linux cần quản lý lưu trữ đĩa.

```zsh
tungdadev@linux:~$ sudo parted /dev/sda print
```

`mkfs`: là một công cụ quan trọng trong Linux để quản lý hệ thống tệp. Nó chủ yếu được sử dụng để định dạng hoặc tạo hệ thống tệp mới, về cơ bản là cấu trúc lưu trữ dữ liệu trên đĩa

Ví dụ: format USB sang định dạng ext4.

```zsh
tungdadev@linux:~$ sudo mkfs.ext4 /dev/sdb1
```

### # các tiện ích khác

`date`: hiển thị ngày giờ hiện tại. --> Kiểm tra thời gian hệ thống.

```zsh
tungdadev@linux:~$ date
```

`cal`: được sử dụng trong Linux để in lịch. Chỉ cần nhập cal để hiển thị lịch tháng hiện tại. Nếu không có đối số nào được cung cấp, lệnh cal sẽ hiển thị lịch tháng hiện tại với ngày hiện tại được tô sáng.

```zsh
tungdadev@linux:~$ cal
```

`echo`: là lệnh Linux tích hợp được sử dụng để hiển thị văn bản được truyền vào dưới dạng đối số. Đây là một trong những lệnh Linux cơ bản được sử dụng trong tập lệnh shell và tệp Bash để hiển thị văn bản trạng thái đầu ra tại dòng lệnh.

```zsh
tungdadev@linux:~$ echo "Hello, Linux!"
```

`man`: là một công cụ mạnh mẽ trong hệ điều hành Linux cho phép người dùng truy cập thông tin chi tiết về nhiều lệnh, tiện ích và lệnh gọi hệ thống. Lệnh `man` cung cấp tài liệu toàn diện, giúp người dùng hiểu cách sử dụng và cấu hình các thành phần khác nhau của môi trường Linux.

```zsh
tungdadev@linux:~$ man ls
```

`alias`: bí danh (alias) là một phím tắt tham chiếu đến một lệnh. Bí danh thay thế một chuỗi gọi một lệnh trong Linux shell bằng một chuỗi khác do người dùng xác định. Bí danh chủ yếu được sử dụng để thay thế các lệnh dài, nâng cao hiệu quả và tránh các lỗi chính tả tiềm ẩn.

```zsh
tungdadev@linux:~$ alias ll="ls -l"
```

`uname`: hiển thị thông tin về nhân hệ thống, bao gồm tên nhân, tên máy chủ, bản phát hành nhân, phiên bản nhân và tên phần cứng máy.

```zsh
tungdadev@linux:~$ uname -a
```

`iptables`: là một công cụ mạnh mẽ được sử dụng để quản lý các quy tắc tường lửa và lưu lượng mạng. Nó tạo điều kiện cho phép người quản trị cấu hình các quy tắc giúp lọc, dịch hoặc chuyển tiếp các gói tin.

```zsh
tungdadev@linux:~$ sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
```

`ps`: liệt kê tiến trình đang chạy, là công cụ đơn giản và hiệu quả để theo dõi các tiến trình.

```zsh
tungdadev@linux:~$ ps aux
```

`kill`: à công cụ tinh túy để chấm dứt các tiến trình trong Linux. Nó gửi tín hiệu đến các tiến trình, yêu cầu chúng chấm dứt một cách nhẹ nhàng. Theo mặc định, kill gửi tín hiệu SIGTERM , cho phép tiến trình thực hiện bất kỳ tác vụ dọn dẹp nào trước khi thoát.

```zsh
tungdadev@linux:~$ kill -9 12345
```

`tar`: là một công cụ mạnh mẽ dùng để tạo, quản lý và giải nén các tập tin lưu trữ. Chúng hoạt động bằng cách gom nhiều tệp và thư mục thành một tập tin duy nhất, được gọi là kho lưu trữ. Kho lưu trữ này có thể được nén bằng các thuật toán khác nhau để giảm kích thước.

```zsh
tungdadev@linux:~$ tar -czvf archive.tar.gz folder
```

`gzip`: là một trong những thuật toán nén file phổ biến nhất, nó cho phép bạn giảm kích thước của file và giữ nguyên thông tin về dữ liệu, quyền sở hữu và timestamp của file gốc. Phần đuôi mở rộng của loại file này là .gz, bạn cũng có thể sử dụng lệnh gzip để giải nén sau khi nén nó.

```zsh
tungdadev@linux:~$ gzip file.txt
```

`gunzip`: cho phép khôi phục file nén về trạng thái gốc một cách dễ dàng.

```zsh
tungdadev@linux:~$ gunzip file.txt.gz
```

`zip`: nén file/thư mục thành định dạng .zip. --> Tạo file zip từ thư mục.

```zsh
tungdadev@linux:~$ zip -r archive.zip folder
```

`unzip`: giải nén file .zip. --> Giải nén các tệp zip.

```zsh
tungdadev@linux:~$ unzip archive.zip
```

`scp`: viết tắt của `Secure Copy` (sao chép an toàn), là một tiện ích dòng lệnh trong hệ điều hành dựa trên Linux cho phép người dùng sao chép tệp giữa máy chủ từ xa và máy chủ cục bộ. Vì lệnh này chuyển tệp qua mạng đến một số máy chủ lưu trữ khác, nên cần có quyền truy cập SSH.

```zsh
tungdadev@linux:~$ scp file.txt user@remote:/path
```

`rsync`: được sử dụng phổ biến nhất để sao chép và đồng bộ hóa các tập tin và thư mục từ xa cũng như cục bộ trong hệ thống Linux/Unix.

```zsh
tungdadev@linux:~$ rsync -av folder/ user@remote:/path
```

`locate`: tìm kiếm hệ thống file cho các file và thư mục có tên khớp với một mẫu nhất định. Cú pháp lệnh dễ nhớ và kết quả được hiển thị gần như ngay lập tức.

```zsh
tungdadev@linux:~$ locate file.txt
```

`xargs`: thực hiện lệnh trên kết quả đầu vào. --> Xóa tất cả file log trong thư mục hiện tại.

```zsh
tungdadev@linux:~$ find . -name "*.log" | xargs rm
```

`diff`: à một tiện ích đa năng được cài đặt sẵn trên hầu hết các bản phân phối Linux. Mục đích chính của nó là so sánh nội dung của hai tệp và hiển thị sự khác biệt giữa chúng. Lệnh cung cấp một cách toàn diện để làm nổi bật các thay đổi, bổ sung và xóa theo định dạng rõ ràng và dễ đọc.

```zsh
tungdadev@linux:~$ diff file1.txt file2.txt
```

`cmp`: sử dụng để xác định xem 2 file có giống nhau hay không bằng cách so sánh từ byte của file đó. Nếu 2 file giống nhau sẽ không có kết quả nào được hiển thị trên terminal. Ngược lại, khi có sự khác biệt giữa 2 file, kết quả hiển thị trên terminal sẽ cho biết chi tiết về sự khác biệt đó.

```zsh
tungdadev@linux:~$ cmp file1.txt file2.txt
```

`comm`: là một tiện ích mạnh mẽ cho phép bạn so sánh hai tệp được sắp xếp theo từng dòng, xác định các dòng duy nhất cho mỗi tệp và các dòng chung cho cả hai. Lệnh này đặc biệt hữu ích khi bạn có danh sách, nhật ký hoặc tập dữ liệu cần được so sánh hiệu quả.

```zsh
tungdadev@linux:~$ comm file1.txt file2.txt
```

`tee`: ghi dữ liệu vào file và hiển thị ra màn hình. --> Lưu và hiển thị kết quả đồng thời.

```zsh
tungdadev@linux:~$ echo "Hello" | tee file.txt
```

`cut`: cắt các phần cụ thể trong file hoặc dòng văn bản. --> Lấy cột đầu tiên từ file CSV.

```zsh
tungdadev@linux:~$ cut -d',' -f1 data.csv
```

`tr`: dịch hoặc xóa các ký tự từ đầu vào chuẩn ( stdin ) và ghi kết quả vào đầu ra chuẩn ( stdout ). Sử dụng tr để thực hiện các chuyển đổi văn bản khác nhau, bao gồm chuyển đổi chữ hoa, nén hoặc xóa ký tự và thay thế văn bản cơ bản.

```zsh
tungdadev@linux:~$ echo "hello" | tr 'a-z' 'A-Z'
```

`sed`: có thể dùng để thực hiện nhiều thao tác với file như tìm kiếm, thay thế, chèn và xóa nội dung.

Thay thế từ "old" bằng "new" trong file.

```zsh
tungdadev@linux:~$ sed -i 's/old/new/g' file.txt
```

`watch`: chạy lệnh theo chu kỳ thời gian. --> Theo dõi dung lượng ổ đĩa mỗi 5 giây.

```zsh
tungdadev@linux:~$ watch -n 5 df -h
```

`iotop`: theo dõi hoạt động I/O. --> Giám sát việc sử dụng I/O của các tiến trình.

```zsh
tungdadev@linux:~$ sudo iotop
```

`who`: xem ai đang đăng nhập vào hệ thống.

```zsh
tungdadev@linux:~$ who
```

`w`: hiển thị thông tin chi tiết người dùng đăng nhập.

```zsh
tungdadev@linux:~$ w
```

`history`: hiển thị lịch sử lệnh đã chạy.

```zsh
tungdadev@linux:~$ history
```

`clear`: xóa màn hình terminal.

```zsh
tungdadev@linux:~$ clear
```

`vmstat`: hiển thị thông tin bổ sung, chẳng hạn như số trang tệp vào mỗi giây, số trang tệp ra mỗi giây, nghĩa là bất kỳ trang vào và trang ra VMM nào không phải là trang vào không gian phân trang hoặc trang ra không gian phân trang. Thường dùng để giám sát tài nguyên hệ thống. --> Xem hiệu suất CPU, bộ nhớ.

```zsh
tungdadev@linux:~$ vmstat 1
```

`ufw`: (Uncomplicated Firewall) là một công cụ mạnh mẽ trong Linux được sử dụng để quản lý các quy tắc tường lửa.

```zsh
tungdadev@linux:~$ sudo ufw allow 22/tcp
```

`arp`: là một lệnh dùng để quản lý bảng ánh xạ địa chỉ IP và MAC. Bảng này lưu trữ thông tin về sự tương ứng giữa địa chỉ IP (Internet Protocol) và địa chỉ MAC (Media Access Control) của các thiết bị mạng trên cùng một mạng.

```zsh
tungdadev@linux:~$ arp -a
```

`hostnamectl`: quản lý tên máy chủ. --> Đổi tên máy chủ.

```zsh
tungdadev@linux:~$ hostnamectl set-hostname new-host
```

`useradd`: tạo người dùng mới. --> Thêm tài khoản mới cho hệ thống Linux.

```zsh
tungdadev@linux:~$ sudo useradd -m -s /bin/bash newuser
```

`usermod`: sửa thông tin người dùng.

Ví dụ: Cấp quyền sudo cho tài khoản.

```zsh
tungdadev@linux:~$ sudo usermod -aG sudo newuser
```

`groupadd`: tạo nhóm mới. --> Thêm nhóm phát triển.

```zsh
tungdadev@linux:~$ sudo groupadd devgroup
```

`groups`: hiển thị nhóm của người dùng. --> Xem nhóm mà tài khoản thuộc về.

```zsh
tungdadev@linux:~$ groups tungdadev
```

`last`: xem lịch sử đăng nhập. -=-> Theo dõi thời gian đăng nhập.

```zsh
tungdadev@linux:~$ last
```

`logrotate`: là một tiện ích mạnh mẽ được thiết kế để tự động xoay vòng, nén và xóa các tệp nhật ký. Đây là một công cụ thiết yếu cho quản trị viên hệ thống Linux, đảm bảo rằng các tệp nhật ký được giữ ở kích thước có thể quản lý được và các nhật ký cũ được lưu trữ một cách có hệ thống.

```zsh
tungdadev@linux:~$ sudo logrotate /etc/logrotate.conf
```

`cron`: lên lịch tác vụ tự động. --> Tạo tác vụ chạy định kỳ.

```zsh
tungdadev@linux:~$ crontab -e
```

### # lời kết

Sử dụng thành thạo các lệnh linux trong công việc sẽ giúp bạn trông như được buff lên đến 100% sức mạnh, đủ sức cân cả server :)))

Các lệnh linux cũng có thể sử dụng trên MacOS, do bản chất 2 hệ điều hành đều dựa trên Unix nên cơ bản là tương đồng nhau.

Việc nhớ các lệnh có vẻ sẽ rất khó khăn với nhiều người. Đừng lo, mấy anh developer siêu lười đã tạo sẵn các extention hỗ trợ việc gợi ý. Nhưng hẹn ở một bài viết khác nhé. :D

> Chỉ là những ghi chép cá nhân với hy vọng mang lại chút giá trị. Nếu thấy hữu ích, đừng ngại chia sẻ cho bạn bè & đồng nghiệp nhé!

Happy coding <Twemoji emoji="clinking-beer-mugs" /> 😎 👍🏻 🚀 🔥.
