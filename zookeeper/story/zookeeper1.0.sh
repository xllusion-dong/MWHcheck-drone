#!/bin/bash
#version:1.0
#monitor:zookeeper/os
#update: 根据需求，将整体脚本做了切割，以独立产品做数据采集，调整os的采集文本
#update：security baseline
#update-date:2022-03-30

#----------------------------------------OS层数据采集------------------------------------------------
function collect_sys_info() {

    echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo "|                      os info                            |"
    echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo ""

    echo "--------------系统检查--------------"
    IP_Address=$(ip addr show | grep 'state UP' -A 2 | grep "inet " | grep -v 127.0.0. | head -1 | cut -d" " -f6 | cut -d/ -f1)
    echo "IP:$IP_Address"
    Hostname=$(hostname -s)
    echo "Hostname:$Hostname"
    Architecture=$(getconf LONG_BIT)
    echo "Architecture:$Architecture"
    Kernel_Release=$(uname -r)
    echo "Kernel_Release:$Kernel_Release"
    #if [ $(whoami) == "root" ]; then
    #    Physical_Memory=$(sudo dmidecode | grep "^[[:space:]]*Size.*MB$" | uniq -c | sed 's/ \t*Size: /\*/g' | sed 's/^ *//g')
    #    echo "Physical_Memory:$Physical_Memory"
    #else
    #    echo "Physical_Memory:null"
    #fi
    Cpu_Cores=$(cat /proc/cpuinfo | grep "cpu cores" | uniq | awk -F ': ' '{print $2}')
    echo "Cpu_Cores:$Cpu_Cores"
    Cpu_Proc_Num=$(cat /proc/cpuinfo | grep "processor" | uniq | wc -l)
    echo "Cpu_Proc_Num:$Cpu_Proc_Num"
    LastReboot=$(who -b | awk '{print $3,$4}')
    echo "LastReboot:$LastReboot"
    Uptime=$(uptime | sed 's/.*up \([^,]*\), .*/\1/')
    echo "Uptime:$Uptime"
    Load=$(uptime | awk -F ":" '{print $NF}')
    echo "Load:$Load"
    MemTotal=$(cat /proc/meminfo | awk '/^MemTotal/{print $2}') #内存总量
    memTotalReal01=$(convert_unit $MemTotal)
    echo "MemTotal:$memTotalReal01"
    memTotalReal=$((${memTotalReal01//.*/+1}))
    ###根据memTotalReal确定Physical_Memory物理内存
    case $memTotalReal in
    4)
        Physical_Memory=4096M
        echo "Physical_Memory:$Physical_Memory"
        ;;
    8)
        Physical_Memory=8192M
        echo "Physical_Memory:$Physical_Memory"
        ;;
    16)
        Physical_Memory=16384M
        echo "Physical_Memory:$Physical_Memory"
        ;;
    32)
        Physical_Memory=32768M
        echo "Physical_Memory:$Physical_Memory"
        ;;
    64)
        Physical_Memory=65536M
        echo "Physical_Memory:$Physical_Memory"
        ;;
    128)
        Physical_Memory=131072M
        echo "Physical_Memory:$Physical_Memory"
        ;;
    esac

    MemFree=$(cat /proc/meminfo | awk '/^MemFree/{print $2}') #空闲内存
    echo "MemFree:$(convert_unit $MemFree)"
    MemBuffers=$(cat /proc/meminfo | awk '/^Buffers/{print $2}')    #Buffers
    MemCached=$(cat /proc/meminfo | awk '/^Cached/{print $2}')      #Cached
    MemUsed=$(expr $MemTotal - $MemFree - $MemBuffers - $MemCached) #已用内存
    echo "MemUsed:$(convert_unit $MemUsed)"
    Mem_Rate=$(awk 'BEGIN{printf"%.2f\n",'$MemUsed' / '$MemTotal' *100}') #保留小数点后2位
    echo "Mem_Rate:$Mem_Rate%"
    Swap_Method=$(cat /proc/sys/vm/swappiness)
    Openfile=$(ulimit -a | grep "open files" | awk '{print $NF}')
    echo "Openfile:$Openfile"
    echo "Swap_Method:$Swap_Method"
    Usesum=0
    Totalsum=0
    disknum=$(df -hlT | wc -l)
    for ((n = 2; n <= $disknum; n++)); do
        use=$(df -k | awk NR==$n'{print int($3)}')
        pertotal=$(df -k | awk NR==$n'{print int($2)}')
        Usesum=$(($Usesum + $use))          #计算已使用的总量
        Totalsum=$(($Totalsum + $pertotal)) #计算总量
    done
    Freesum=$(($Totalsum - $Usesum))
    Diskutil=$(awk 'BEGIN{printf"%.2f\n",'$Usesum' / '$Totalsum'*100}')
    Freeutil=$(awk 'BEGIN{printf"%.2f\n",100 - '$Diskutil'}')

    #磁盘总量
    if [ $Totalsum -ge 0 -a $Totalsum -lt 1024 ]; then
        echo "Totalsum:$To'ta'l'su'm K"

    elif [ $Totalsum -gt 1024 -a $Totalsum -lt 1048576 ]; then
        Totalsum=$(awk 'BEGIN{printf"%.2f\n",'$Totalsum' / 1024}')
        echo "Totalsum:$Totalsum M"

    elif [ $Totalsum -gt 1048576 ]; then
        Totalsum=$(awk 'BEGIN{printf"%.2f\n",'$Totalsum' / 1048576}')
        echo "Totalsum:$Totalsum G"

    fi

    #磁盘已使用总量
    if [ $Usesum -ge 0 -a $Usesum -lt 1024 ]; then
        echo "Usesum:$Usesum K"

    elif [ $Usesum -gt 1024 -a $Usesum -lt 1048576 ]; then
        Usesum=$(awk 'BEGIN{printf"%.2f\n",'$Usesum' / 1024}')
        echo "Usesum:$Usesum M"

    elif [ $Usesum -gt 1048576 ]; then
        Usesum=$(awk 'BEGIN{printf"%.2f\n",'$Usesum' / 1048576}')
        echo "Usesum:$Usesum G"

    fi

    #磁盘未使用总量
    if [ $Freesum -ge 0 -a $Freesum -lt 1024 ]; then
        echo "Freesum:$Freesum K"

    elif [ $Freesum -gt 1024 -a $Freesum -lt 1048576 ]; then
        Freesum=$(awk 'BEGIN{printf"%.2f\n",'$Freesum' / 1024}')
        echo "Freesum:$Freesum M"

    elif [ $Freesum -gt 1048576 ]; then
        Freesum=$(awk 'BEGIN{printf"%.2f\n",'$Freesum' / 1048576}')
        echo "Freesum:$Freesum G"
    fi
    #磁盘占用率
    echo "Diskutil:$Diskutil%"

    #磁盘空闲率
    echo "Freeutil:$Freeutil%"

    #
    iostat=$(which iostat)
    iostat_status=$(echo $?)
    if [ $iostat_status -eq 0 ]; then
        IO_User=$(iostat -x -k 2 1 | grep -1 avg | grep -v avg | grep -v ^$ | awk -F ' ' '{print $1}')
        IO_System=$(iostat -x -k 2 1 | grep -1 avg | grep -v avg | grep -v ^$ | awk -F ' ' '{print $3}')
        IO_Wait=$(iostat -x -k 2 1 | grep -1 avg | grep -v avg | grep -v ^$ | awk -F ' ' '{print $4}')
        IO_Idle=$(iostat -x -k 2 1 | grep -1 avg | grep -v avg | grep -v ^$ | awk -F ' ' '{print $NF}')
        echo "IO_User:$IO_User%"
        echo "IO_System:$IO_System%"
        echo "IO_Wait:$IO_Wait%"
        echo "IO_Idle:$IO_Idle%"
    else
        echo "IO_User:null"
        echo "IO_System:null"
        echo "IO_Wait:null"
        echo "IO_Idle:null"
    fi
    #TCP参数获取
    if [ -e /proc/sys/net/ipv4/tcp_tw_recycle ]; then
        Tcp_Tw_Recycle=$(sysctl net.ipv4.tcp_tw_recycle | awk -F "=" '{print $2}')
        echo "Tcp_Tw_Recycle:$Tcp_Tw_Recycle"
    else
        echo "Tcp_Tw_Recycle:null"
    fi
    #该参数的作用是快速回收timewait状态的连接。上面虽然提到系统会自动删除掉timewait状态的连接，但如果把这样的连接重新利用起来岂不是更好。
    #所以该参数设置为1就可以让timewait状态的连接快速回收，它需要和下面的参数配合一起使用
    Tcp_Tw_Reuse=$(sysctl net.ipv4.tcp_tw_reuse | awk -F "=" '{print $2}')
    echo "Tcp_Tw_Reuse:$Tcp_Tw_Reuse"
    #该参数设置为1，将timewait状态的连接重新用于新的TCP连接，要结合上面的参数一起使用。
    Tcp_Fin_Timeout=$(sysctl net.ipv4.tcp_fin_timeout | awk -F "=" '{print $2}')
    echo "Tcp_Fin_Timeout:$Tcp_Fin_Timeout"
    #tcp连接的状态中，客户端上有一个是FIN-WAIT-2状态，它是状态变迁为timewait前一个状态。
    #该参数定义不属于任何进程该连接状态的超时时间，默认值为60，建议调整为6。
    Tcp_Keepalive_Time=$(sysctl net.ipv4.tcp_keepalive_time | awk -F "=" '{print $2}')
    echo "Tcp_Keepalive_Time:$Tcp_Keepalive_Time"
    #表示当keepalive起用的时候，TCP发送keepalive消息的频度。缺省是2小时，改为30分钟。
    Tcp_Keepalive_Probes=$(sysctl net.ipv4.tcp_keepalive_probes | awk -F "=" '{print $2}')
    echo "Tcp_Keepalive_Probes:$Tcp_Keepalive_Probes"
    #如果对方不予应答，探测包的发送次数
    Tcp_Keepalive_Intvl=$(sysctl net.ipv4.tcp_keepalive_intvl | awk -F "=" '{print $2}')
    echo "Tcp_Keepalive_Intvl:$Tcp_Keepalive_Intvl"
    #keepalive探测包的发送间隔

    echo "--------------原始数据采集_补充--------------"
    echo "----->>>---->>>  CPU usage"
    sar 2 5
    echo ""
    echo "----->>>---->>>  resource limit"
    cat /etc/security/limits.conf | grep -v '^#' | grep -v '^$'
    echo ""
    echo "----->>>---->>>  io scheduler"
    dmesg | grep -i scheduler
    echo ""
    echo "----->>>---->>>  disk mount "
    df -h

}
#单位转换函数
function convert_unit() {
    result=$1
    if [ $result -ge 1048576 ]; then
        value=1048576                                                 #1024*1024
        result_gb=$(awk 'BEGIN{printf"%.2f\n",'$result' / '$value'}') #将KB转换成GB，并保留2位小数
        echo $result_gb"GB"
    elif [ $result -ge 1024 ]; then
        value=1024
        result_mb=$(awk 'BEGIN{printf"%.2f\n",'$result' / '$value'}') #将KB转换成MB，并保留2位小数
        echo $result_mb"MB"
    else
        echo $result"KB"
    fi
}

#----------------------------------------zookeeper info------------------------------------------------

function zookeeper_inquiry_info() {
    echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo "|                      zookeeper info                     |"
    echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo ""
    ip=$(ip addr show | grep 'state UP' -A 2 | grep "inet " | grep -v 127.0.0. | head -1 | cut -d" " -f6 | cut -d/ -f1)
    echo $ip
    zookeeper_pid_member=$(ps -ef | grep Dzookeeper.root | grep -v grep | awk -F " " '{print $2}' | wc -l)
    if [ $zookeeper_pid_member == 0 ]; then
        echo "当前服务器没有zookeeper进程，不做信息采集！"
        exit 1
    else
        echo "当前服务器存在zookeeper进程，开始做信息采集！！！"
        echo "当前服务器zookeeper进程信息!"
        ps -ef | grep java | grep zookeeper
        check_nc=$(rpm -qa nmap* | wc -l)
        for line in $(ps -ef | grep Dzookeeper.root | grep -v grep | awk -F " " '{print $2}'); do
            echo "获取当前zookeeper的配置文件,当前获取配置的节点为$ip-$line"
            zk_dir_log=$(ps -ef | grep $line | grep Dzookeeper.root | grep -v grep | awk -F "-Dzookeeper.log.dir" '{print $2}' | awk -F "=" '{print $2}' | awk -F " " '{print $1}')
            zk_config=$(ps -ef | grep zookeeper | grep $line | grep -v grep | awk -F " " '{print $NF}')
            cd $zk_dir_log
            echo "开始进行日志查询操作，当前查询节点为$ip-$line"
            for check_zookeeper_log in $(ls -lrt | grep out | awk -F " " '{print $NF}'); do
                check_zk_log=$(cat $check_zookeeper_log | tail -n 5000)
                echo "开始检查zookeeper日志"
                echo "开始检查当前zookeeper-log中是否包含Connection refused: no further information报错信息；"
                echo "$check_zk_log" | grep -i "Connection refused: no further information"
                echo "开始检查当前zookeeper-log中是否包含Too many connections报错信息；"
                echo "$check_zk_log" | grep -i "Too many connections"
                echo "开始检查当前zookeeper-log中是否包含Caused by报错信息；"
                echo "$check_zk_log" | grep -i "Caused by"
                echo "开始检查当前zookeeper-log中是否包含ERROR报错信息；"
                echo "$check_zk_log" | grep -i "ERROR" | grep -vi "开始检查当前zookeeper-log中是否包含ERROR报错信息" | grep -vi "Connection refused: no further information" | grep -vi "Too many connections" | grep -vi "Caused by"
                echo "END！！！"
            done
            cd ../conf
            echo "开始进行查询操作，当前查询节点为$ip-$line"
            dir=$(dirname $zk_dir_log)
            cd $dir && cd bin
            echo "获取zookeeper的status信息和version信息"
            sh zkServer.sh status && sh zkServer.sh version
            echo "查看zookeeper的配置信息"
            cat $zk_config
            echo "通过zoo.cfg获取当前zookeeper的port信息"
            zookeeper_port=$(cat $zk_config | grep clientPort= | awk -F "=" '{print $2}')
            echo "通过zkCli.sh获取信息"

            echo ls / | sh zkCli.sh -server $ip:$zookeeper_port | grep -A 20 WATCHER
            echo config -s | sh zkCli.sh -server $ip:$zookeeper_port | grep -A 20 WATCHER
            echo version | sh zkCli.sh -server $ip:$zookeeper_port | grep -A 20 WATCHER
            if [ $check_nc -eq 0 ]; then
                echo "Zookeeper无法执行四字命令，缺少nc组件！！！"
            else
                a=$(grep -wn "4lw.commands.whitelist" $zk_config | awk -F ':' '{print $1}')
                if [ $a ]; then
                    commands=$(cat $zk_config | grep '4lw.commands.whitelist')
                    if [ $commands = '4lw.commands.whitelist=*' ]; then
                        echo "==============================START-NC============================"
                        echo "conf命令用于输出ZooKeeper服务器运行时使用的基本配置信息，包括clientPort、dataDir和tickTime等。"
                        echo conf | nc $ip $zookeeper_port
                        echo "cons命令用于输出当前这台服务器上所有客户端连接的详细信息，包括每个客户端的客户端IP、会话ID和最后一次与服务器交互的操作类型等。"
                        echo cons | nc $ip $zookeeper_port
                        echo "envi命令用于输出ZooKeeper所在服务器运行时的环境信息，包括os.version、java.version和user.home等"
                        echo envi | nc $ip $zookeeper_port
                        echo "stat命令用于获取ZooKeeper服务器的运行时状态信息，包括基本的ZooKeeper版本、打包信息、运行时角色、集群数据节点个数等信息。"
                        echo stat | nc $ip $zookeeper_port
                        echo "wchc命令用于输出当前服务器上管理的Watcher的详细信息，以会话为单位进行归组，同时列出被该会话注册了Watcher的节点路径。"
                        echo wchs | nc $ip $zookeeper_port
                        echo "mntr命令用于输出比stat命令更为详尽的服务器统计信息，包括请求处理的延迟情况、服务器内存数据库大小和集群的数据同步情况。"
                        echo mntr | nc $ip $zookeeper_port
                        echo "==============================END-NC============================"
                    else
                        commands=$(cat $zk_config | grep '4lw.commands.whitelist' | awk -F '=' '{print $2}')
                        command=$(echo $commands | awk -F ',' '{for(i=1;i<=NF;i++) print $i}')
                        for i in $command; do
                            echo $i | nc $ip $zookeeper_port
                        done

                    fi
                else
                    echo "zookeeper配置文件中没有配置四字命令！！ ！ "
                fi

            fi
        done
    fi

}

function zookeeper_security_baseline() {
    echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo "|                    zookeeper security baseline         |"
    echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo ""

    echo "当前服务器zookeeper进程信息!"
    for line in $(ps -ef | grep Dzookeeper.root | grep -v grep | awk -F " " '{print $2}'); do
        echo "获取当前zookeeper的配置文件,当前获取配置的节点为$ip-$line"
        echo "安全基线1:端口保护;修改zookeeper默认监听端口2181为不易猜测的端口。"
        cat $zk_config
        security_baseline_port=$(cat $zk_config | grep clientPort= | awk -F "=" '{print $2}') && echo "security_baseline_port:$security_baseline_port"
        echo "安全基线2:预防DOS攻击;建议限制zookeeper客户端的最大连接数。"
        security_baseline_maxClientCnxns=$(cat $zk_config | grep maxClientCnxns | awk -F "=" '{print $2}') && echo "security_baseline_maxClientCnxns:$security_baseline_maxClientCnxns"
        echo "安全基线3:zookeeper的管理控制台，建议禁用。"
        security_baseline_console=$(cat $dir/bin/zkServer.sh | grep -i "Dzookeeper.admin.enableServer=false" | wc -l) && echo "security_baseline_console:$security_baseline_console"
        echo "安全基线4:zookeeper的授权访问。"
        security_baseline_acl=$(echo getAcl / | sh zkCli.sh -server $ip:$zookeeper_port | grep -i "world" | wc -l) && echo "security_baseline_acl:$security_baseline_acl"
        echo "安全基线5:zookeeper的日志审计。"
        security_baseline_audit=$(cat $zk_config | grep -i "audit.enable=true" | wc -l) && echo "security_baseline_audit:$security_baseline_audit"
        echo "安全基线6:zookeeper的事务日志与快照日志分离。"
        security_baseline_log=$(cat $zk_config | grep -Ei '(dataDir|dataLogDir)' | grep -v '^#' | wc -l) && echo "security_baseline_log:$security_baseline_log"
        echo "安全基线7:zookeeper的日志清理。"
        security_baseline_clean=$(cat $zk_config | grep -i "autopurge" | wc -l) && echo "security_baseline_clean:$security_baseline_clean"
        echo "安全基线8:zookeeper的非特权用户运行。"
        security_baseline_root=$(ps -ef | grep Dzookeeper.root | grep -v grep | awk -F " " '{print $1}') && echo "security_baseline_root:$security_baseline_root"
        echo "安全基线9:zookeeper的目录权限控制。"
        security_baseline_dir=$(ls -lrt $zk_dir_log | grep -v total | head -n 1 | awk -F " " '{print $3}') && echo "security_baseline_dir:$security_baseline_dir"
        echo "安全基线10:zookeeper限制监听地址。"
        security_baseline_clientPortAddress=$(cat $zk_config | grep -i "clientPortAddress" | wc -l) && echo "security_baseline_clientPortAddress:$security_baseline_clientPortAddress"
        echo "安全基线11:zookeeper四字命令。"
        security_baseline_4lw=$(cat $zk_config | grep '4lw.commands.whitelist' | wc -l) && echo "security_baseline_4lw:$security_baseline_4lw"

        echo "安全基线1:端口保护;修改zookeeper默认监听端口2181为不易猜测的端口。"
        security_baseline_port=$(cat $zk_config | grep clientPort= | awk -F "=" '{print $2}')
        if [ $security_baseline_port -eq 2181 ]; then
            security_baseline_port1="Failed"
            echo "security_baseline_port1:$security_baseline_port1"
        else
            security_baseline_port1="Paas"
            echo "security_baseline_port1:$security_baseline_port1"
        fi
        echo "安全基线2:预防DOS攻击;建议限制zookeeper客户端的最大连接数。"
        security_baseline_maxClientCnxns=$(cat $zk_config | grep maxClientCnxns | awk -F "=" '{print $2}')
        if [ $security_baseline_maxClientCnxns -le 1000 ]; then
            security_baseline_maxClientCnxns1="Paas"
            echo "security_baseline_maxClientCnxns1:$security_baseline_maxClientCnxns1"
        else
            security_baseline_maxClientCnxns1="Failed"
            echo "security_baseline_maxClientCnxns1:$security_baseline_maxClientCnxns1"
        fi
        echo "安全基线3:zookeeper的管理控制台，建议禁用。"
        security_baseline_console=$(cat $dir/bin/zkServer.sh | grep -i "Dzookeeper.admin.enableServer=false" | wc -l)
        if [ $security_baseline_console -eq 0 ]; then
            security_baseline_console1="Failed"
            echo "security_baseline_console1:$security_baseline_console1"
        else
            security_baseline_console1="Paas"
            echo "security_baseline_console1:$security_baseline_console1"
        fi
        echo "安全基线4:zookeeper的授权访问。"
        security_baseline_acl=$(echo getAcl / | sh zkCli.sh -server $ip:$zookeeper_port | grep -i "world" | wc -l)
        if [ $security_baseline_acl -eq 0 ]; then
            security_baseline_acl1="Failed"
            echo "security_baseline_acl1:$security_baseline_acl1"
        else
            security_baseline_acl1="Paas"
            echo "security_baseline_acl1:$security_baseline_acl1"
        fi
        echo "安全基线5:zookeeper的日志审计。"
        security_baseline_audit=$(cat $zk_config | grep -i "audit.enable=true" | wc -l)
        if [ $security_baseline_audit -eq 0 ]; then
            security_baseline_audit1="Failed"
            echo "security_baseline_audit1:$security_baseline_audit1"
        else
            security_baseline_audit1="Paas"
            echo "security_baseline_audit1:$security_baseline_audit1"
        fi
        echo "安全基线6:zookeeper的事务日志与快照日志分离。"
        security_baseline_log=$(cat $zk_config | grep -Ei '(dataDir|dataLogDir)' | grep -v '^#' | wc -l)
        if [ $security_baseline_log -eq 2 ]; then
            security_baseline_log1="Paas"
            echo "security_baseline_log1:$security_baseline_log1"
        else
            security_baseline_log1="Failed"
            echo "security_baseline_log1:$security_baseline_log1"
        fi
        echo "安全基线7:zookeeper的日志清理。"
        security_baseline_clean=$(cat $zk_config | grep -i "autopurge" | wc -l)
        if [ $security_baseline_clean -eq 0 ]; then
            security_baseline_clean1="Failed"
            echo "security_baseline_clean1:$security_baseline_clean1"
        else
            security_baseline_clean1="Paas"
            echo "security_baseline_clean1:$security_baseline_clean1"
        fi
        echo "安全基线8:zookeeper的非特权用户运行。"
        security_baseline_root=$(ps -ef | grep Dzookeeper.root | grep -v grep | awk -F " " '{print $1}')
        if [ $security_baseline_root == "root" ]; then
            security_baseline_root1="Failed"
            echo "security_baseline_root1:$security_baseline_root1"
        else
            security_baseline_root1="Paas"
            echo "security_baseline_root1:$security_baseline_root1"
        fi
        echo "安全基线9:zookeeper的目录权限控制。"
        security_baseline_dir=$(ls -lrt $zk_dir_log | grep -v total | head -n 1 | awk -F " " '{print $3}')
        if [ $security_baseline_dir == "root" ]; then
            security_baseline_dir1="Failed"
            echo "security_baseline_dir1:$security_baseline_dir1"
        else
            security_baseline_dir1="Paas"
            echo "security_baseline_dir1:$security_baseline_dir1"
        fi
        echo "安全基线10:zookeeper限制监听地址。"
        security_baseline_clientPortAddress=$(cat $zk_config | grep -i "clientPortAddress" | wc -l)
        if [ $security_baseline_clientPortAddress -eq 0 ]; then
            security_baseline_clientPortAddress1="Failed"
            echo "security_baseline_clientPortAddress1:$security_baseline_clientPortAddress1"
        else
            security_baseline_clientPortAddress1="Paas"
            echo "security_baseline_clientPortAddress1:$security_baseline_clientPortAddress1"
        fi
        echo "安全基线11:zookeeper四字命令。"
        security_baseline_4lw=$(cat $zk_config | grep '4lw.commands.whitelist' | wc -l)
        if [ $security_baseline_4lw -eq 0 ]; then
            security_baseline_4lw1="Paas"
            echo "security_baseline_4lw1:$security_baseline_4lw1"
        else
            security_baseline_4lw1="Failed"
            echo "security_baseline_4lw1:$security_baseline_4lw1"
        fi
    done
}

function get_zookeeper_main() {
    ####check /tmp/tmpcheck Is empty
    tmpcheck_dir="/tmp/enmoResult/tmpcheck/"
    if [ "$(ls -A $tmpcheck_dir)" ]; then
        echo "$tmpcheck_dir is not empty!!!"
        rm -rf $tmpcheck_dir/*
        echo "clean $tmpcheck_dir !!!"
    else
        echo "$tmpcheck_dir is empty!!!"
    fi
    ####get system info
    filename1=$HOSTNAME"_"zookeeper"_"os_""$ipinfo"_"$qctime".txt"
    collect_sys_info >>"$filepath""$filename1"
    filename2=$HOSTNAME"_"zookeeper"_"$ipinfo"_"$qctime".txt"
    zookeeper_inquiry_info >>"$filepath""$filename2"
    zookeeper_security_baseline >>"$filepath""$filename2"

    #tar -czvf /tmp/enmoResult/tmpcheck/"$HOSTNAME"_"zookeeper"_"$ipinfo"_"$qctime".tar.gz /tmp/enmoResult

    echo -e "___________________"
    echo -e "Collection info Finished."
    echo -e "Result File Path:" $filepath
    echo -e "\n"
    cd /tmp/enmoResult/tmpcheck
}
#----------------------------------------END------------------------------------------------
######################Main##########################
filepath="/tmp/enmoResult/tmpcheck/"
excmkdir=$(which mkdir | awk 'NR==1{print}')
$excmkdir -p $filepath
qctime=$(date +'%Y%m%d%H%M%S')
ipinfo=$(ip addr show | grep 'state UP' -A 2 | grep "inet " | grep -v 127.0.0. | head -1 | cut -d" " -f6 | cut -d/ -f1)

echo "###########################################"
echo "Start performing zookeeper patrols！！！"
get_zookeeper_main

data_path=/tmp/enmoResult/tmpcheck
function get_os_jsondata() {
    mkdir -p /tmp/enmoResult/zookeeper
    new_data=/tmp/enmoResult/zookeeper
    if [ "$(ls -A $new_data)" ]; then
        echo "$new_data is not empty!!!"
        rm -rf $new_data/*
        echo "clean $new_data !!!"
    else
        echo "$new_data is empty!!!"
    fi
    cd $data_path
    file=$filename1
    ip=$(ls $file | awk -F "_" '{print $4}')
    result=$(echo $ip | grep "addr")
    if [[ "$result" != "" ]]; then
        ip=${ip#*:}
    fi
    new_document=$new_data/zookeeper_$ip.json
    #echo "=====================OS基础信息=====================" >> $new_document
    IP_Address=$(cat $file | grep IP | awk -F ":" '{print $2}') && echo "\"IP_Address\"":"\"$IP_Address\"""," >>$new_document
    Hostname=$(cat $file | grep Hostname | awk -F ":" '{print $2}') && echo "\"Hostname\"":"\"$Hostname\"""," >>$new_document
    Architecture=$(cat $file | grep Architecture | awk -F ":" '{print $2}') && echo "\"Architecture\"":"\"$Architecture\"""," >>$new_document
    Kernel_Release=$(cat $file | grep Kernel_Release | awk -F ":" '{print $2}') && echo "\"Kernel_Release\"":"\"$Kernel_Release\"""," >>$new_document
    Physical_Memory=$(cat $file | grep Physical_Memory | awk -F ":" '{print $2}') && echo "\"Physical_Memory\"":"\"$Physical_Memory\"""," >>$new_document
    Cpu_Cores=$(cat $file | grep Cpu_Cores | awk -F ":" '{print $2}') && echo "\"Cpu_Cores\"":"\"$Cpu_Cores\"""," >>$new_document
    Cpu_Proc_Num=$(cat $file | grep Cpu_Proc_Num | awk -F ":" '{print $2}') && echo "\"Cpu_Proc_Num\"":"\"$Cpu_Proc_Num\"""," >>$new_document
    LastReboot=$(cat $file | grep LastReboot | awk -F ":" '{print $2}') && echo "\"LastReboot\"":"\"$LastReboot\"""," >>$new_document
    Uptime=$(cat $file | grep Uptime | awk -F ":" '{print $2}') && echo "\"Uptime\"":"\"$Uptime\"""," >>$new_document
    Load=$(cat $file | grep Load | awk -F ":" '{print $2}') && echo "\"Load\"":"\"$Load\"""," >>$new_document
    MemTotal=$(cat $file | grep MemTotal | awk -F ":" '{print $2}') && echo "\"MemTotal\"":"\"$MemTotal\"""," >>$new_document
    MemFree=$(cat $file | grep MemFree | awk -F ":" '{print $2}') && echo "\"MemFree\"":"\"$MemFree\"""," >>$new_document
    MemUsed=$(cat $file | grep MemUsed | awk -F ":" '{print $2}') && echo "\"MemUsed\"":"\"$MemUsed\"""," >>$new_document
    Mem_Rate=$(cat $file | grep Mem_Rate | awk -F ":" '{print $2}') && echo "\"Mem_Rate\"":"\"$Mem_Rate\"""," >>$new_document
    Openfile=$(cat $file | grep Openfile | awk -F ":" '{print $2}') && echo "\"Openfile\"":"\"$Openfile\"""," >>$new_document
    Swap_Method=$(cat $file | grep Swap_Method | awk -F ":" '{print $2}') && echo "\"Swap_Method\"":"\"$Swap_Method\"""," >>$new_document
    Totalsum=$(cat $file | grep Totalsum | awk -F ":" '{print $2}') && echo "\"Totalsum\"":"\"$Totalsum\"""," >>$new_document
    Usesum=$(cat $file | grep Usesum | awk -F ":" '{print $2}') && echo "\"Usesum\"":"\"$Usesum\"""," >>$new_document
    Freesum=$(cat $file | grep Freesum | awk -F ":" '{print $2}') && echo "\"Freesum\"":"\"$Freesum\"""," >>$new_document
    Diskutil=$(cat $file | grep Diskutil | awk -F ":" '{print $2}') && echo "\"Diskutil\"":"\"$Diskutil\"""," >>$new_document
    Freeutil=$(cat $file | grep Freeutil | awk -F ":" '{print $2}') && echo "\"Freeutil\"":"\"$Freeutil\"""," >>$new_document
    IO_User=$(cat $file | grep IO_User | awk -F ":" '{print $2}') && echo "\"IO_User\"":"\"$IO_User\"""," >>$new_document
    IO_System=$(cat $file | grep IO_System | awk -F ":" '{print $2}') && echo "\"IO_System\"":"\"$IO_System\"""," >>$new_document
    IO_Wait=$(cat $file | grep IO_Wait | awk -F ":" '{print $2}') && echo "\"IO_Wait\"":"\"$IO_Wait\"""," >>$new_document
    IO_Idle=$(cat $file | grep IO_Idle | awk -F ":" '{print $2}') && echo "\"IO_Idle\"":"\"$IO_Idle\"""," >>$new_document
    Tcp_Tw_Recycle=$(cat $file | grep Tcp_Tw_Recycle | awk -F ":" '{print $2}') && echo "\"Tcp_Tw_Recycle\"":"\"$Tcp_Tw_Recycle\"""," >>$new_document
    Tcp_Tw_Reuse=$(cat $file | grep Tcp_Tw_Reuse | awk -F ":" '{print $2}') && echo "\"Tcp_Tw_Reuse\"":"\"$Tcp_Tw_Reuse\"""," >>$new_document
    Tcp_Fin_Timeout=$(cat $file | grep Tcp_Fin_Timeout | awk -F ":" '{print $2}') && echo "\"Tcp_Fin_Timeout\"":"\"$Tcp_Fin_Timeout\"""," >>$new_document
    Tcp_Keepalive_Time=$(cat $file | grep Tcp_Keepalive_Time | awk -F ":" '{print $2}') && echo "\"Tcp_Keepalive_Time\"":"\"$Tcp_Keepalive_Time\"""," >>$new_document
    Tcp_Keepalive_Probes=$(cat $file | grep Tcp_Keepalive_Probes | awk -F ":" '{print $2}') && echo "\"Tcp_Keepalive_Probes\"":"\"$Tcp_Keepalive_Probes\"""," >>$new_document
    Tcp_Keepalive_Intvl=$(cat $file | grep Tcp_Keepalive_Intvl | awk -F ":" '{print $2}') && echo "\"Tcp_Keepalive_Intvl\"":"\"$Tcp_Keepalive_Intvl\"""," >>$new_document
}

function get_zookeeper_data() {
    new_data=/tmp/enmoResult/zookeeper
    cd $data_path
    file1=$filename2
    ip_1=$(ls $file1 | awk -F "_" '{print $3}')
    new_document=$new_data/zookeeper_$ip_1.json
    #echo "=====================Zookeeper基础信息=====================" >> $new_document
    Zookeeper_version=$(cat $file1 | grep "Apache ZooKeeper") && echo "\"Zookeeper_version\"":"\"$Zookeeper_version\"""," >>$new_document
    Zookeeper_mode=$(cat $file1 | grep "Mode" | head -n1 | awk -F ":" '{print $2}') && echo "\"Zookeeper_mode\"":"\"$Zookeeper_mode\"""," >>$new_document
    Installation_path=$(cat $file1 | grep -io 'Dzookeeper.log.dir=.*' | awk -F "=" '{print $2}' | cut -d "." -f1) && echo "\"Installation_path\"":"\"$Installation_path\"""," >>$new_document
    #Start_User=`cat $file1  |grep -A1 "当前服务器zookeeper进程信息!" |grep -v "当前服务器zookeeper进程信息!"|awk -F " " '{print $1}'` && echo "\"Start_User\"":"\"$Start_User\"""," >> $new_document
    JVM_Instal_path=$(cat $file1 | grep -A1 "当前服务器zookeeper进程信息" | grep -v "当前服务器zookeeper进程信息" | grep -v grep | awk -F " " '{print $8}') && echo "\"JVM_Instal_path\"":"\"$JVM_Instal_path\"""," >>$new_document
    JVM_run_parameters=$(cat $file1 | egrep -io 'Xmx.*|Xms.*' | awk -F "-Djava" '{print $1}') && echo "\"JVM_run_parameters\"":"\"$JVM_run_parameters\"""," >>$new_document
    Start_User=$(ps -ef | grep Dzookeeper.root | grep -v grep | awk -F " " '{print $1}') && echo "\"Start_User\"":"\"$Start_User\"""," >>$new_document
    Server_Port=$(cat $file1 | grep clientPort | head -n1 | awk -F "=" '{print $NF}') && echo "\"Server_Port\"":"\"$Server_Port\"""," >>$new_document
    #echo "=====================Zookeeper配置文件=====================" >> $new_document
    Zookeeper_config=$(cat $file1 | sed -n /查看zookeeper的配置信息/,/通过zoo.cfg获取当前zookeeper的port信息/p | grep -v 通过zoo.cfg获取当前zookeeper的port信息 | grep -v 看zookeeper的配置信息 | grep -v "^#" | grep -v "^$") && echo "\"Zookeeper_config\"":"\"$Zookeeper_config\"""," >>$new_document
    #echo "=====================Zookeeper运行数据=====================" >> $new_document
    Zookeeper_runtime_status=$(cat $file1 | sed -n /START-NC/,/END-NC/p | grep -v "END-NC" | grep -v "START-NC")
    Zookeeper_runtime_status_num=$(cat $file1 | sed -n /START-NC/,/END-NC/p | grep -v "END-NC" | grep -v "START-NC" | wc -l)
    if [ $Zookeeper_runtime_status_num -eq 0 ]; then
        echo "\"Zookeeper_runtime_status\"":"'暂无Zookeeper运行数据！'""," >>$new_document
    else
        echo "\"Zookeeper_runtime_status\"":"'$Zookeeper_runtime_status'""," >>$new_document
    fi
    #echo "=====================Zookeeper日志=====================" >> $new_document
    check_log_num=$(cat $file1 | sed -n /开始检查zookeeper日志/,/END！！！/p | grep -v "开始检查zookeeper日志" | grep -v "END！！！" | wc -l)
    if [ $check_log_num -eq 4 -o $check_log_num -eq 8 -o $check_log_num -eq 12 ]; then
        Check_log_health=$(echo "\"Check_log_health\"":"\"日志无异常。\"""," >>$new_document)
    else
        Check_log_health=$(cat $file1 | sed -n /开始检查zookeeper日志/,/END！！！/p | grep -v "开始检查zookeeper日志" | grep -v "END！！！") && echo "\"Check_log_health\"":"'$Check_log_health'""," >>$new_document
    fi
}

function get_zookeeper_security_baseline() {
    new_document=$new_data/zookeeper_$ip_1.json

    Security_Baseline_Port=$(cat $file1 | grep security_baseline_port | grep -v security_baseline_port1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Port\"":"\"$Security_Baseline_Port\"""," >>$new_document
    Security_Baseline_MaxClientCnxns=$(cat $file1 | grep security_baseline_maxClientCnxns | grep -v security_baseline_maxClientCnxns1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_MaxClientCnxns\"":"\"$Security_Baseline_MaxClientCnxns\"""," >>$new_document
    Security_Baseline_Console=$(cat $file1 | grep security_baseline_console | grep -v security_baseline_console1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Console\"":"\"$Security_Baseline_Console\"""," >>$new_document
    Security_Baseline_Acl=$(cat $file1 | grep security_baseline_acl | grep -v security_baseline_acl1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Acl\"":"\"$Security_Baseline_Acl\"""," >>$new_document
    Security_Baseline_Audit=$(cat $file1 | grep security_baseline_audit | grep -v security_baseline_audit1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Audit\"":"\"$Security_Baseline_Audit\"""," >>$new_document
    Security_Baseline_Log=$(cat $file1 | grep security_baseline_log | grep -v security_baseline_log1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Log\"":"\"$Security_Baseline_Log\"""," >>$new_document
    Security_Baseline_Clean=$(cat $file1 | grep security_baseline_clean | grep -v security_baseline_clean1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Clean\"":"\"$Security_Baseline_Clean\"""," >>$new_document
    Security_Baseline_Root=$(cat $file1 | grep security_baseline_root | grep -v security_baseline_root1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Root\"":"\"$Security_Baseline_Root\"""," >>$new_document
    Security_Baseline_Dir=$(cat $file1 | grep security_baseline_dir | grep -v security_baseline_dir1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Dir\"":"\"$Security_Baseline_Dir\"""," >>$new_document
    Security_Baseline_ClientPortAddress=$(cat $file1 | grep security_baseline_clientPortAddress | grep -v security_baseline_clientPortAddress1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_ClientPortAddress\"":"\"$Security_Baseline_ClientPortAddress\"""," >>$new_document
    Security_Baseline_4lw=$(cat $file1 | grep security_baseline_4lw | grep -v security_baseline_4lw1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_4lw\"":"\"$Security_Baseline_4lw\"""," >>$new_document

    Security_Baseline_Port1=$(cat $file1 | grep security_baseline_port1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Port1\"":"\"$Security_Baseline_Port1\"""," >>$new_document
    Security_Baseline_MaxClientCnxns1=$(cat $file1 | grep security_baseline_maxClientCnxns1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_MaxClientCnxns1\"":"\"$Security_Baseline_MaxClientCnxns1\"""," >>$new_document
    Security_Baseline_Console1=$(cat $file1 | grep security_baseline_console1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Console1\"":"\"$Security_Baseline_Console1\"""," >>$new_document
    Security_Baseline_Acl1=$(cat $file1 | grep security_baseline_acl1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Acl1\"":"\"$Security_Baseline_Acl1\"""," >>$new_document
    Security_Baseline_Audit1=$(cat $file1 | grep security_baseline_audit1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Audit1\"":"\"$Security_Baseline_Audit1\"""," >>$new_document
    Security_Baseline_Log1=$(cat $file1 | grep security_baseline_log1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Log1\"":"\"$Security_Baseline_Log1\"""," >>$new_document
    Security_Baseline_Clean1=$(cat $file1 | grep security_baseline_clean1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Clean1\"":"\"$Security_Baseline_Clean1\"""," >>$new_document
    Security_Baseline_Root1=$(cat $file1 | grep security_baseline_root1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Root1\"":"\"$Security_Baseline_Root1\"""," >>$new_document
    Security_Baseline_Dir1=$(cat $file1 | grep security_baseline_dir1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Dir1\"":"\"$Security_Baseline_Dir1\"""," >>$new_document
    Security_Baseline_ClientPortAddress1=$(cat $file1 | grep security_baseline_clientPortAddress1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_ClientPortAddress1\"":"\"$Security_Baseline_ClientPortAddress1\"""," >>$new_document
    Security_Baseline_4lw1=$(cat $file1 | grep security_baseline_4lw1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_4lw1\"":"\"$Security_Baseline_4lw1\"" >>$new_document

}

echo "Start Zookeeper Date Extraction!!!"
get_os_jsondata
get_zookeeper_data
get_zookeeper_security_baseline
cd $data_path
tar -czvf /tmp/enmoResult/"$HOSTNAME"_"zookeeper"_"$ipinfo"_"$qctime".tar.gz /tmp/enmoResult
