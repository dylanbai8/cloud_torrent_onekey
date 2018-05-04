# Cloud Torrent 一键安装脚本 （内置 bbr 支持 openvz）

使用：登陆 Root 执行一键脚本
```
wget -N https://git.io/t.sh && chmod +x t.sh && bash t.sh
```

一键卸载 Cloud Torrent
```
bash t.sh -u
```

添加/修改 用户名、密码、端口
```
bash t.sh -p
```

小内存 vps 添加系统定时重启任务
```
(crontab -l ; echo "0 16 * * * /sbin/reboot") | crontab -
```
