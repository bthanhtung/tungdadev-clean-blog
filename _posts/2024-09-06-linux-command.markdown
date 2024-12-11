---
layout: post
title: "Hơn 100 lệnh Linux thường gặp"
date: 2024-09-06 19:29:39 +0700
categories: [Information Technology, Software]
tags: [Linix]
---

Đối với lập trình viên, đặc biệt là các cá nhân làm trong mảng backend, devops thường rất chuộng và say sưa với hệ điều hành linux. Thậm chí có người còn xem nó là chân ái.

Trong thực tế, khi các service được cài trên các server thì việc developer thao tác với linux nói chung và các dòng lệnh nói riêng là điều không thể tránh khỏi. Thế nên, biết càng nhiều, nhớ càng nhiều lệnh linux sẽ giúp ích phần nào giúp tăng giá trị bản thân và nâng cao hiệu quả công việc.

Ngoài ra, việc sử dụng các dòng lệnh sẽ khiến bạn trông ngầu hơn trong mắt người khác. Thật đấy, không đùa đâu :))) Không tin thì đọc bài xong rồi ra quán cafe ngồi thực hành để kiểm chứng nhé. :)))

### 1. Quản lý tệp và thư mục

- `ls` - Liệt kê nội dung thư mục --> Xem danh sách file kèm chi tiết trong thư mục hiện tại.
```zsh
tungdadev@linux:~$ ls -l
```

- `cd` - Thay đổi thư mục --> Điều hướng đến thư mục dự án web.
```zsh
tungdadev@linux:~$ cd /var/www
```


- `pwd` - Kiểm tra đường dẫn hiện tại.
```zsh
tungdadev@linux:~$ pwd
/home/tungdadev
```

- mkdir - Tạo thư mục mới.
```zsh
tungdadev@linux:~$ mkdir new_project
```

- `rmdir` - Xóa thư mục rỗng.
```zsh
tungdadev@linux:~$ rmdir old_folder
```

- `rm` - Xóa tệp hoặc thư mục. --> Xóa thư mục và tất cả nội dung bên trong.
```zsh
tungdadev@linux:~$ rm -r temp_folder
```

- `cp` - Sao chép tệp hoặc thư mục --> Backup file quan trọng.
```zsh
tungdadev@linux:~$ cp file.txt /backup/file.txt
```

- `mv` - Di chuyển hoặc đổi tên tệp/thư mục --> 
```zsh
tungdadev@linux:~$ mv old_name.txt new_name.txt
```

- `find` - Tìm kiếm file hoặc thư mục.
```zsh
tungdadev@linux:~$ find /var/log -name "*.log"
```
Tìm log file trong thư mục /var/log.

- `touch` - Tạo tệp rỗng mới.
```zsh
tungdadev@linux:~$ touch index.html
```


### 2. Quản lý người dùng và quyền

- `whoami` - Hiển thị user hiện tại.
```zsh
tungdadev@linux:~$ whoami
tungdadev
```

- `id` - Hiển thị thông tin user.
```zsh
tungdadev@linux:~$ id
uid=1000(tungdadev) gid=1000(tungdadev) groups=1000(tungdadev)
```
Kiểm tra UID và GID.

- `chmod` - Thay đổi quyền truy cập tệp --> Gán quyền thực thi cho script.
```zsh
tungdadev@linux:~$ chmod 755 script.sh
```

- `chown` - Thay đổi chủ sở hữu tệp/thư mục --> Gán quyền sở hữu file cấu hình cho root.
```zsh
tungdadev@linux:~$ chown root:root config.conf
```

- `passwd` - Đổi mật khẩu người dùng -- > Thay đổi mật khẩu cho tài khoản hiện tại.
```zsh
tungdadev@linux:~$ passwd
```


### 3. Quản lý hệ thống

- `top` - Giám sát tiến trình và tài nguyên hệ thống theo thời gian thực --> Kiểm tra CPU/RAM của hệ thống đang sử dụng.
```zsh
tungdadev@linux:~$ top
```

- `htop` - Phiên bản nâng cao của top --> Quản lý tiến trình với giao diện thân thiện.
```zsh
tungdadev@linux:~$ htop
```

- `df` - Hiển thị thông tin dung lượng ổ đĩa --> Xem dung lượng ổ đĩa còn trống.
```zsh
tungdadev@linux:~$ df -h
```


- `du` - Kiểm tra dung lượng thư mục hoặc tệp --> Xem dung lượng log file chiếm.
```zsh
tungdadev@linux:~$ du -sh /var/log
```


- `free` - Kiểm tra dung lượng RAM.
```zsh
tungdadev@linux:~$ free -h
```

- `uptime` - Hiển thị thời gian hoạt động của hệ thống. --> Kiểm tra thời gian chạy của server.
```zsh
tungdadev@linux:~$ uptime
```

- `reboot` - Khởi động lại hệ thống.
```zsh
tungdadev@linux:~$ sudo reboot
```

- `shutdown` - Tắt máy.
```zsh
tungdadev@linux:~$ sudo shutdown now
```

- `systemctl` - Quản lý dịch vụ hệ thống. --> Khởi động lại dịch vụ Nginx:
```zsh
tungdadev@linux:~$ sudo systemctl restart nginx
```

- `journalctl` - Xem log hệ thống --> Kiểm tra log của dịch vụ Nginx:
```zsh
tungdadev@linux:~$ sudo journalctl -u nginx
```


### 4. Xử lý mạng
- `ping` - Kiểm tra kết nối mạng.
```zsh
tungdadev@linux:~$ ping google.com
```

- `curl` - Gửi yêu cầu HTTP. --> Kiểm tra trạng thái HTTP của website.
```zsh
tungdadev@linux:~$ curl -I https://example.com
```

- `wget` - Tải tệp từ URL. --> Tải tệp trực tuyến.
```zsh
tungdadev@linux:~$ wget https://example.com/file.zip
```

- `netstat` - Xem thông tin kết nối mạng --> Kiểm tra port đang mở
```zsh
tungdadev@linux:~$ netstat -tuln
```


- `ifconfig` - Cấu hình và kiểm tra mạng. --> Kiểm tra IP địa chỉ.
```zsh
tungdadev@linux:~$ ifconfig
```


- `ip` - Thay thế hiện đại của ifconfig. --> Xem thông tin mạng.
```zsh
tungdadev@linux:~$ ip addr show
```

- `nslookup` - Tra cứu DNS. --> Kiểm tra thông tin tên miền.
```zsh
tungdadev@linux:~$ nslookup google.com
```


- `traceroute` - Theo dõi đường đi của gói tin. --> Xác định sự cố mạng.
```zsh
tungdadev@linux:~$ traceroute example.com
```


- `nmap` - Quét port và dịch vụ. --> Kiểm tra bảo mật mạng.
```zsh
tungdadev@linux:~$ nmap -sT localhost
```


- `ss` - Xem trạng thái socket. --> Theo dõi kết nối TCP/UDP.
```zsh
tungdadev@linux:~$ ss -tuln
```


### 5. Quản lý gói phần mềm
- `apt-get` - Quản lý gói phần mềm. --> Cài đặt Nginx.
```zsh
tungdadev@linux:~$ sudo apt-get install nginx
```


- `apt` - Phiên bản cải tiến của apt-get. --> Cập nhật thông tin gói.
```zsh
tungdadev@linux:~$ sudo apt update
```

- `dpkg` - Quản lý gói cấp thấp. --> Cài đặt gói .deb thủ công.
```zsh
tungdadev@linux:~$ sudo dpkg -i package.deb
```


- `snap` - Quản lý ứng dụng Snap. --> Cài đặt Visual Studio Code.
```zsh
tungdadev@linux:~$ sudo snap install vscode --classic
```


- `flatpak` - Quản lý ứng dụng Flatpak. --> Cài đặt Firefox từ Flathub.
```zsh
tungdadev@linux:~$ flatpak install flathub org.mozilla.firefox
```



### 6. Phân tích log

- `tail` - Xem dòng cuối của tệp log. --> Theo dõi log hệ thống theo thời gian thực.
```zsh
tungdadev@linux:~$ tail -f /var/log/syslog
```


- `head` - Xem dòng đầu của tệp. --> Xem 20 dòng đầu của log.
```zsh
tungdadev@linux:~$ head -n 20 /var/log/syslog
```


- `cat` - Hiển thị nội dung file. --> Đọc nội dung log truy cập của Nginx.
```zsh
tungdadev@linux:~$ cat /var/log/nginx/access.log
```


- `less` - Đọc tệp log dài với cuộn trang. --> Duyệt log kernel dài.
```zsh
tungdadev@linux:~$ less /var/log/dmesg
```


- `grep` - Tìm kiếm chuỗi trong file log. --> Tìm lỗi trong log hệ thống.
```zsh
tungdadev@linux:~$ grep "error" /var/log/syslog
```


- `awk` - Trích xuất và xử lý dữ liệu từ file log. --> Lấy IP và timestamp từ log Nginx.
```zsh
tungdadev@linux:~$ awk '{print $1, $4}' /var/log/nginx/access.log
```


- `cut` - Cắt trường trong file log. --> Lấy cột đầu tiên (IP).
```zsh
tungdadev@linux:~$ cut -d' ' -f1 /var/log/nginx/access.log
```


- `sort` - Sắp xếp dữ liệu log.
```zsh
tungdadev@linux:~$ sort /var/log/nginx/access.log
```

- `uniq` - Loại bỏ dòng lặp trong log. --> Tìm các dòng truy cập duy nhất.
```zsh
tungdadev@linux:~$ sort /var/log/nginx/access.log | uniq
```


- `wc` - Đếm dòng, từ hoặc byte trong file log. --> Đếm số dòng log.
```zsh
tungdadev@linux:~$ wc -l /var/log/syslog
```



### 7. Xử lý file hệ thống

- `stat` - Hiển thị thông tin chi tiết của tệp. --> Xem thời gian sửa đổi cuối cùng của file.
```zsh
tungdadev@linux:~$ stat file.txt
```


- `file` - Xác định loại tệp. --> Kiểm tra định dạng tệp
```zsh
tungdadev@linux:~$ file image.png
```


- `ln` - Tạo liên kết cứng hoặc liên kết mềm (symlink). --> Tạo symlink cho Python.
```zsh
tungdadev@linux:~$ ln -s /usr/bin/python3 /usr/bin/python
```


- `fsck` - Kiểm tra và sửa lỗi hệ thống file. --> Sửa lỗi trên phân vùng /dev/sda1.
```zsh
tungdadev@linux:~$ sudo fsck /dev/sda1
```


- `mount` - Gắn kết hệ thống file. --> Gắn USB vào hệ thống.
```zsh
tungdadev@linux:~$ sudo mount /dev/sdb1 /mnt
```


- `umount` - Tháo gắn hệ thống file. --> Ngắt kết nối USB.
```zsh
tungdadev@linux:~$ sudo umount /mnt
```


- `df` - Kiểm tra dung lượng phân vùng. --> Xem không gian trống.
```zsh
tungdadev@linux:~$ df -h
```


- `blkid` - Liệt kê UUID của các thiết bị lưu trữ. --> Xác định UUID cho thiết lập /etc/fstab.
```zsh
tungdadev@linux:~$ sudo blkid
```


- `parted` - Quản lý phân vùng ổ cứng. --> Xem phân vùng ổ đĩa.
```zsh
tungdadev@linux:~$ sudo parted /dev/sda print
```


- `mkfs` - Tạo hệ thống file mới trên phân vùng. --> Format USB sang định dạng ext4.
```zsh
tungdadev@linux:~$ sudo mkfs.ext4 /dev/sdb1
```


### 8. Các tiện ích khác

- `date` - Hiển thị ngày giờ hiện tại. --> Kiểm tra thời gian hệ thống.
```zsh
tungdadev@linux:~$ date
```


- `cal` - Hiển thị lịch. --> Xem lịch tháng hiện tại.
```zsh
tungdadev@linux:~$ cal
```


- `echo` - In chuỗi ra terminal. --> Kiểm tra output cơ bản.
```zsh
tungdadev@linux:~$ echo "Hello, Linux!"
```


- `man` - Hiển thị tài liệu hướng dẫn lệnh. --> Tìm hiểu cách dùng lệnh.
```zsh
tungdadev@linux:~$ man ls
```


- `alias` - Tạo bí danh cho lệnh. --> Tăng tốc độ thao tác.
```zsh
tungdadev@linux:~$ alias ll="ls -l"
```


- `uname` - Xem thông tin hệ thống. --> Kiểm tra kernel.
```zsh
tungdadev@linux:~$ uname -a
```


- `iptables` - Quản lý tường lửa. --> Kiểm tra server uptime.
```zsh
tungdadev@linux:~$ sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
```


- `ps` - Liệt kê tiến trình đang chạy. --> Theo dõi các tiến trình.
```zsh
tungdadev@linux:~$ ps aux
```


- `kill` - Dừng tiến trình. --> Kết thúc tiến trình bị treo.
```zsh
tungdadev@linux:~$ kill -9 12345
```


- `tar` - Nén và giải nén tệp. --> Nén thư mục dự án.
```zsh
tungdadev@linux:~$ tar -czvf archive.tar.gz folder
```


- `gzip` - Nén file bằng gzip. --> Nén file văn bản.
```zsh
tungdadev@linux:~$ gzip file.txt
```


- `gunzip` - Giải nén file gzip. --> Giải nén file nén .gz.
```zsh
tungdadev@linux:~$ gunzip file.txt.gz
```


- `zip` - Nén file/thư mục thành định dạng .zip. --> Tạo file zip từ thư mục.
```zsh
tungdadev@linux:~$ zip -r archive.zip folder
```


- `unzip` - Giải nén file .zip. --> Giải nén các tệp zip.
```zsh
tungdadev@linux:~$ unzip archive.zip
```


- `scp` - Sao chép file qua SSH. --> Chuyển file lên server từ xa.
```zsh
tungdadev@linux:~$ scp file.txt user@remote:/path
```


- `rsync` - Đồng bộ file/thư mục. --> Đồng bộ dữ liệu với server.
```zsh
tungdadev@linux:~$ rsync -av folder/ user@remote:/path
```


- `find` - Tìm kiếm file/thư mục. --> Tìm tất cả file log trong thư mục /home.
```zsh
tungdadev@linux:~$ find /home -name "*.log"
```

- `locate` - Tìm kiếm file nhanh chóng. --> Xác định vị trí file nhanh.
```zsh
tungdadev@linux:~$ locate file.txt
```


- `xargs` - Thực hiện lệnh trên kết quả đầu vào. --> Xóa tất cả file log trong thư mục hiện tại.
```zsh
tungdadev@linux:~$ find . -name "*.log" | xargs rm
```


- `diff` - So sánh hai file. --> Kiểm tra sự khác nhau giữa hai file.
```zsh
tungdadev@linux:~$ diff file1.txt file2.txt
```


- `cmp` - So sánh nội dung file. --> Kiểm tra file có giống nhau không.
```zsh
tungdadev@linux:~$ cmp file1.txt file2.txt
```


- `comm` - So sánh hai file, hiển thị phần chung và khác biệt. --> Kiểm tra phần trùng và khác biệt.
```zsh
tungdadev@linux:~$ comm file1.txt file2.txt
```


- `tee` - Ghi dữ liệu vào file và hiển thị ra màn hình. --> Lưu và hiển thị kết quả đồng thời.
```zsh
tungdadev@linux:~$ echo "Hello" | tee file.txt
```


- `cut` - Cắt các phần cụ thể trong file hoặc dòng văn bản. --> Lấy cột đầu tiên từ file CSV.
```zsh
tungdadev@linux:~$ cut -d',' -f1 data.csv
```


- `tr` - Chuyển đổi hoặc xóa ký tự. --> Chuyển chuỗi sang chữ in hoa.
```zsh
tungdadev@linux:~$ echo "hello" | tr 'a-z' 'A-Z'
```


- `sed` - Thay thế nội dung trong file. --> Thay thế từ "old" bằng "new" trong file.
```zsh
tungdadev@linux:~$ sed -i 's/old/new/g' file.txt
```


- `head` - Hiển thị một số dòng đầu tiên của file. --> Xem 10 dòng đầu của file.
```zsh
tungdadev@linux:~$ head -n 10 file.txt
```


- `tail` - Hiển thị một số dòng cuối cùng của file. --> Xem 10 dòng cuối của file.
```zsh
tungdadev@linux:~$ tail -n 10 file.txt
```


- `watch` - Chạy lệnh theo chu kỳ thời gian. --> Theo dõi dung lượng ổ đĩa mỗi 5 giây.
```zsh
tungdadev@linux:~$ watch -n 5 df -h
```


- `iotop` - Theo dõi hoạt động I/O. --> Giám sát việc sử dụng I/O của các tiến trình.
```zsh
tungdadev@linux:~$ sudo iotop
```


- `who` - Xem ai đang đăng nhập vào hệ thống.
```zsh
tungdadev@linux:~$ who
```

- `w` - Hiển thị thông tin chi tiết người dùng đăng nhập.
```zsh
tungdadev@linux:~$ w
```

- `history` - Hiển thị lịch sử lệnh đã chạy.
```zsh
tungdadev@linux:~$ history
```

- `clear` - Xóa màn hình terminal.
```zsh
tungdadev@linux:~$ clear
```

- `alias` - Tạo bí danh cho lệnh.
```zsh
tungdadev@linux:~$ alias ll='ls -la'
```

- `unalias` - Xóa bí danh lệnh.
```zsh
tungdadev@linux:~$ unalias ll
```

- `chmod` - Thay đổi quyền truy cập file. --> Cấp quyền thực thi cho script.
```zsh
tungdadev@linux:~$ chmod 755 script.sh
```


- `chown` - Thay đổi chủ sở hữu file/thư mục. --> Chuyển quyền sở hữu file.
```zsh
tungdadev@linux:~$ sudo chown user:group file.txt
```


- `ln` - Tạo liên kết (cứng/mềm).
```zsh
tungdadev@linux:~$ ln -s /path/to/target linkname
```

- `vmstat` - Giám sát tài nguyên hệ thống. --> Xem hiệu suất CPU, bộ nhớ.
```zsh
tungdadev@linux:~$ vmstat 1
```


- `ufw` - Tường lửa đơn giản hóa.
```zsh
tungdadev@linux:~$ sudo ufw allow 22/tcp
```

- `arp` - Hiển thị bảng ARP. --> Kiểm tra địa chỉ MAC của thiết bị mạng.
```zsh
tungdadev@linux:~$ arp -a
```


-. `hostnamectl` - Quản lý tên máy chủ. --> Đổi tên máy chủ.
```zsh
tungdadev@linux:~$ hostnamectl set-hostname new-host
```


- `useradd` - Tạo người dùng mới. --> Thêm tài khoản mới.
```zsh
tungdadev@linux:~$ sudo useradd -m -s /bin/bash newuser
```


- `usermod` - Sửa thông tin người dùng. --> Cấp quyền sudo cho tài khoản.
```zsh
tungdadev@linux:~$ sudo usermod -aG sudo newuser
```


- `groupadd` - Tạo nhóm mới. --> Thêm nhóm phát triển.
```zsh
tungdadev@linux:~$ sudo groupadd devgroup
```


- `groups` - Hiển thị nhóm của người dùng. --> Xem nhóm mà tài khoản thuộc về.
```zsh
tungdadev@linux:~$ groups tungdadev
```


- `last` - Xem lịch sử đăng nhập. -=-> Theo dõi thời gian đăng nhập.
```zsh
tungdadev@linux:~$ last
```


- `logrotate` - Quản lý vòng đời log. --> Xoay vòng log định kỳ.
```zsh
tungdadev@linux:~$ sudo logrotate /etc/logrotate.conf
```


- `cron` - Lên lịch tác vụ tự động. --> Tạo tác vụ chạy định kỳ.
```zsh
tungdadev@linux:~$ crontab -e
```



### Lời kết

Sử dụng thành thạo các lệnh linux trong công việc sẽ giúp bạn trông như được buff lên đến 100% sức mạnh, đủ sức cân cả server :)))

Các lệnh linux cũng có thể sử dụng trên MacOS, do bản chất 2 hệ điều hành đều dựa trên Unix nên cơ bản là tương đồng nhau.

Việc nhớ các lệnh có vẻ sẽ rất khó khăn với nhiều người. Đừng lo, mấy anh developer siêu lười đã tạo sẵn các extention hỗ trợ việc gợi ý. Nhưng hẹn ở một bài viết khác nhé. :D

> P/S: Nếu bạn thấy bài viết này hữu ích, đừng quên chia sẻ với bạn bè và đồng nghiệp của mình nhé!

Happy coding! 😎 👍🏻 🚀 🔥