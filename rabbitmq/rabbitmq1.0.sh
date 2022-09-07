#!/bin/bash
#version:1.0
#monitor:rabbitmq/os
#update: 根据需求，将整体脚本做了切割，以独立产品做数据采集，调整os的采集文本
#update：security baseline
#update：去除对username password的依赖，实现全自动化执行
#update-date:2022-06-15

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

#----------------------------------------rabbitmq info------------------------------------------------

function check_rabbitmq_command_line() {
    echo "|++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo "|                      rabbitmq_command_line info                          |"
    echo "|++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo "开始获取服务器rabbitmq进程信息"
    ps -ef | grep beam.smp | grep -v grep
    echo "获取服务器rabbitmq进程信息结束"
    echo ""
    cd $rabbitmq_sbin
    echo "获取集群中Status状态信息"
    echo ""
    rabbitmq-diagnostics -q cluster_status
    echo ""
    echo "获取集群的用户信息"
    echo ""
    rabbitmq-diagnostics -q list_users
    echo ""
    echo "获取用户的访问控制权限"
    echo ""
    rabbitmq-diagnostics -q list_permissions
    echo ""
    echo "获取queues信息"
    echo ""
    rabbitmq-diagnostics -q list_queues
    echo ""
    echo "获取consumer信息"
    echo ""
    rabbitmq-diagnostics -q list_consumers
    echo ""
    echo "获取connections信息"
    echo ""
    rabbitmq-diagnostics -q list_connections
    echo ""
    echo "rabbitmq_command_line_end!!!"

    for line in $($rabbitmq_sbin/rabbitmq-diagnostics -q cluster_status | grep -A 4 Versions | grep -v Versions | grep -v '^$' | awk -F ":" '{print $1}' | grep -v Main); do
        echo "当前获取的数据为Rabbitmq-$line"
        echo "Ping各个节点通信是否正常, 如果退出代码为0，则Ping成功"
        rabbitmq-diagnostics -q ping --node $line
        echo "获取各个Node的状态信息"
        rabbitmq-diagnostics -q status --node $line
        echo "获取各个Node的Listener信息"
        rabbitmq-diagnostics -q listeners --node $line
        echo "TCP连接检查命令"
        rabbitmq-diagnostics -q check_port_connectivity --node $line
        echo "检查所有的虚拟主机，看是否有失败的vhost"
        rabbitmq-diagnostics -q check_virtual_hosts --node $line
        echo "检查当前主机的插件开启状态"
        rabbitmq-plugins -q list --enabled --node $line
    done

}

function get_log() {
    echo "|++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo "|                      rabbitmq_get_log     info                           |"
    echo "|++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    cd $rabbitmq_sbin
    cd ../var/log/rabbitmq
    for get_rabbitmq_log in $(ls -lrt | grep .log$ | awk -F " " '{print $NF}'); do
        echo "当前过滤的日志为: $get_rabbitmq_log"
        echo "开始检查当前rabbitmq-log中是否包含Exceptions报错信息；"
        less -mN $get_rabbitmq_log | grep -i "Exceptions"
        echo "开始检查当前rabbitmq-log中是否包含ERROR报错信息；"
        less -mN $get_rabbitmq_log | grep -i "Error"
        echo "Log_check_end!!!"
    done

}

function get_config() {
    echo "|++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo "|                      rabbitmq_get_config     info                        |"
    echo "|++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    cd $rabbitmq_sbin
    cd ../etc/rabbitmq
    for get_rabbitmq_config in $(ls -lrt | grep conf$ | awk -F " " '{print $NF}'); do
        echo "当前输出内容为: $get_rabbitmq_config 配置信息"
        cat $get_rabbitmq_config
    done
}

function rabbitmq_security_baseline() {
    echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo "|                    rabbitmq security baseline           |"
    echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo ""

    echo "当前服务器rabbitmq进程信息!"
    for line in $(netstat -anpt | grep LISTEN | grep beam.smp | awk -F ' ' '{print $NF}' | awk -F '/' '{print $1}' | head -n 1); do
        echo "获取当前rabbitmq的配置文件,当前获取配置的节点为$ip-$line"
        echo "安全基线1:端口保护;修改rabbitmq默认监听端口5672为不易猜测的端口。"
        security_baseline_port_num2=$(rabbitmq-diagnostics -q listeners | grep -i 5672 | wc -l)
        security_baseline_port_num=$(rabbitmq-diagnostics -q listeners | grep -i 5672 | grep http | awk -F ':' '{print $5}' | awk -F ',' '{print $1}') && echo "security_baseline_port_num:$security_baseline_port_num"
        if [ $security_baseline_port_num2 -eq 3 ]; then
            security_baseline_port_num1="Failed"
            echo "security_baseline_port_num1:$security_baseline_port_num1"
        else
            security_baseline_port_num1="Pass"
            echo "security_baseline_port_num1:$security_baseline_port_num1"
        fi
        echo "安全基线2:建议使用rabbitmq配置文件，默认该文件不存在。"
        security_baseline_config_file2=$(rabbitmq-diagnostics -q status | sed -n /'Config files'/,/'Log file(s)'/p | grep -vi "Config files" | grep -vi "Log file(s)" | grep -v ^$ | wc -l)
        security_baseline_config_file=$(rabbitmq-diagnostics -q status | sed -n /'Config files'/,/'Log file(s)'/p | grep -vi "Config files" | grep -vi "Log file(s)" | grep -v ^$) && echo "security_baseline_config_file:$security_baseline_config_file"
        if [ $security_baseline_config_file2 -eq 1 ]; then
            security_baseline_config_file1="Pass"
            echo "security_baseline_config_file1:$security_baseline_config_file1"
        else
            security_baseline_config_file1="Failed"
            echo "security_baseline_config_file1:$security_baseline_config_file1"
        fi
        echo "安全基线3:rabbitmq的管理控制台，默认不开启，建议不开启。"
        security_baseline_console2=$(rabbitmq-diagnostics -q status | sed -n /'Enabled plugins:'/,/'Data directory'/p | grep -vi 'Enabled plugins:' | grep -vi 'Data directory' | grep rabbitmq_management)
        security_baseline_console=$(rabbitmq-diagnostics -q status | sed -n /'Enabled plugins:'/,/'Data directory'/p | grep -vi 'Enabled plugins:' | grep -vi 'Data directory' | grep rabbitmq_management | wc -l) && echo "security_baseline_console:$security_baseline_console"
        if [ "$security_baseline_console2" == "2" ]; then
            security_baseline_console1="Failed"
            echo "security_baseline_console1:$security_baseline_console1"
        else
            security_baseline_console1="Pass"
            echo "security_baseline_console1:$security_baseline_console1"
        fi
        echo "安全基线4:rabbitmq的非特权用户运行。"
        security_baseline_root=$(ps -ef | grep beam.smp | grep -v grep | awk -F ' ' '{print $1}') && echo "security_baseline_root:$security_baseline_root"
        if [ $security_baseline_root == "root" ]; then
            security_baseline_root1="Failed"
            echo "security_baseline_root1:$security_baseline_root1"
        else
            security_baseline_root1="Pass"
            echo "security_baseline_root1:$security_baseline_root1"
        fi
        echo "安全基线5:rabbitmq的目录权限控制。"
        security_baseline_dir=$(ls -lrt $rabbitmq_sbin | grep -v total | head -n 1 | awk -F " " '{print $3}') && echo "security_baseline_dir:$security_baseline_dir"
        if [ $security_baseline_dir == "root" ]; then
            security_baseline_dir1="Failed"
            echo "security_baseline_dir1:$security_baseline_dir1"
        else
            security_baseline_dir1="Pass"
            echo "security_baseline_dir1:$security_baseline_dir1"
        fi
        echo "安全基线6:删除默认用户访问控制"
        security_baseline_guest2=$(rabbitmqctl list_users | grep guest)
        security_baseline_guest=$(rabbitmqctl list_users | grep guest | wc -l) && echo "security_baseline_guest:$security_baseline_guest"
        if [ "$security_baseline_guest2" == "1" ]; then
            security_baseline_guest1="Failed"
            echo "security_baseline_guest1:$security_baseline_guest1"
        else
            security_baseline_guest1="Pass"
            echo "security_baseline_guest1:$security_baseline_guest1"
        fi
    done
}

function get_rabbitmq_main() {
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
    filename1=$HOSTNAME"_"rabbitmq"_"os_""$ipinfo"_"$qctime".txt"
    collect_sys_info >>"$filepath""$filename1"
    filename2=$HOSTNAME"_"rabbitmq"_"$ipinfo"_"$qctime".txt"

    ip=$(ip addr show | grep 'state UP' -A 2 | grep "inet " | grep -v 127.0.0. | head -1 | cut -d" " -f6 | cut -d/ -f1)
    rabbitmq_pid=$(netstat -anpt | grep LISTEN | grep beam.smp | awk -F ' ' '{print $NF}' | awk -F '/' '{print $1}' | head -n 1)
    rabbitmq_sbin=$(pwdx $rabbitmq_pid | awk -F ":" '{print $NF}')
    date=$(date +%Y%m%d)

    check_rabbitmq_command_line >>"$filepath""$filename2"
    get_log >>"$filepath""$filename2"
    get_config >>"$filepath""$filename2"
    rabbitmq_security_baseline >>"$filepath""$filename2"

    echo -e "___________________"
    echo -e "Collection info Finished."
    echo -e "Result File Path:" $filepath
    echo -e "\n"
    cd /tmp/enmoResult/tmpcheck/
}
#----------------------------------------END------------------------------------------------
######################Main##########################
filepath="/tmp/enmoResult/tmpcheck/"
excmkdir=$(which mkdir | awk 'NR==1{print}')
$excmkdir -p $filepath
qctime=$(date +'%Y%m%d%H%M%S')
ipinfo=$(ip addr show | grep 'state UP' -A 2 | grep "inet " | grep -v 127.0.0. | head -1 | cut -d" " -f6 | cut -d/ -f1)

echo "###########################################"
echo "Start performing rabbitmq patrols！！！"
get_rabbitmq_main

data_path=/tmp/enmoResult/tmpcheck
function get_os_jsondata() {
    mkdir -p /tmp/enmoResult/rabbitmq
    new_data=/tmp/enmoResult/rabbitmq
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
    new_document=$new_data/rabbitmq_$ip.json
    #echo "=====================OS基础信息=====================" >> $new_document
    IP_Address=$(cat $file | grep -w IP | awk -F ":" '{print $2}') && echo "\"IP_Address\"":"\"$IP_Address\"""," >>$new_document
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

function get_rabbitmq_data() {
    new_data=/tmp/enmoResult/rabbitmq
    cd $data_path
    file1=$filename2
    ip_1=$(ls $file1 | awk -F "_" '{print $3}')
    new_document=$new_data/rabbitmq_$ip_1.json
    #echo "=====================Rabbitmq基础信息=====================" >> $new_document
    Rabbitmq_version=$(cat $file1 | sed -n /Versions/,/"Maintenance status"/p | grep -v "Versions" | grep -v "Maintenance status" | grep -v ^$) && echo "\"Rabbitmq_version\"":"\"$Rabbitmq_version\"""," >>$new_document
    Cluster_name=$(cat $file1 | grep "Cluster name" | awk -F ":" '{print $NF}') && echo "\"Cluster_name\"":"\"$Cluster_name\"""," >>$new_document
    Data_directory=$(cat $file1 | sed -n /"Data directory"/,/"Config files"/p | grep -v "Data directory" | grep -v "Config files" | grep -v ^$) && echo "\"Data_directory\"":"\"$Data_directory\"""," >>$new_document
    Log_file=$(cat $file1 | sed -n /"Log file(s)"/,/"Alarms"/p | grep -v "Log file(s)" | grep -v "Alarms" | grep -v ^$) && echo "\"Log_file\"":"\"$Log_file\"""," >>$new_document
    Start_User=$(cat $file1 | sed -n /开始获取服务器rabbitmq进程信息/,/获取服务器rabbitmq进程信息结束/p | awk -F " " '{print $1}') && echo "\"Start_User\"":"\"$Start_User\"""," >>$new_document
    Rabbitmq_Disk_Node=$(cat $file1 | sed -n /"Disk Nodes"/,/"Running Nodes"/p | grep -v "Disk Nodes" | grep -v "Running Nodes") && echo "\"Rabbitmq_Disk_Node\"":"\"$Rabbitmq_Disk_Node\"""," >>$new_document
    File_Descriptors=$(cat $file1 | sed -n /'File Descriptors'/,/'Free Disk Space'/p | grep -Ev '(File Descriptors|Free Disk Space)') && echo "\"File_Descriptors\"":"\"$File_Descriptors\"""," >>$new_document
    Free_Disk_Space=$(cat $file1 | sed -n /'Free Disk Space'/,/'Totals'/p | grep -Ev '(Free Disk Space|Totals)') && echo "\"Free_Disk_Space\"":"\"$Free_Disk_Space\"""," >>$new_document
    Connection_Count=$(cat $file1 | grep "Connection count" | awk -F ":" '{print $2}') && echo "\"Connection_Count\"":"\"$Connection_Count\"""," >>$new_document
    Queue_Count=$(cat $file1 | grep "Queue count" | awk -F ":" '{print $2}') && echo "\"Queue_Count\"":"\"$Queue_Count\"""," >>$new_document
    Virtual_Host_Count=$(cat $file1 | grep "Virtual host count" | awk -F ":" '{print $2}') && echo "\"Virtual_Host_Count\"":"\"$Virtual_Host_Count\"""," >>$new_document
    Total_Memory_Used=$(cat $file1 | grep "Total memory used" | awk -F ":" '{print $2}') && echo "\"Total_Memory_Used\"":"\"$Total_Memory_Used\"""," >>$new_document
    Calculation_Strategy=$(cat $file1 | grep "Calculation strategy" | awk -F ":" '{print $2}') && echo "\"Calculation_Strategy\"":"\"$Calculation_Strategy\"""," >>$new_document
    Memory_High_Watermark_Setting=$(cat $file1 | grep "Memory high watermark setting" | awk -F ":" '{print $2}') && echo "\"Memory_High_Watermark_Setting\"":"\"$Memory_High_Watermark_Setting\"""," >>$new_document
    #echo "=====================Rabbitmq运行数据=====================" >> $new_document
    echo "" >>$new_document
    #获取集群中Status状态信息
    Cluster_status=$(cat $file1 | sed -n /获取集群中Status状态信息/,/获取集群的用户信息/p | grep -v "获取集群中Status状态信息" | grep -v "获取集群的用户信息") && echo "\"Cluster_status\"":"\"$Cluster_status\"""," >>$new_document
    #获取集群的用户信息
    Cluster_users=$(cat $file1 | sed -n /获取集群的用户信息/,/获取用户的访问控制权限/p | grep -v "获取集群的用户信息" | grep -v "获取用户的访问控制权限") && echo "\"Cluster_users\"":"\"$Cluster_users\"""," >>$new_document
    #获取用户的访问控制权限
    Cluster_user_permissions=$(cat $file1 | sed -n /获取用户的访问控制权限/,/获取queues信息/p | grep -v "获取用户的访问控制权限" | grep -v "获取queues信息") && echo "\"Cluster_user_permissions\"":"\"$Cluster_user_permissions\"""," >>$new_document
    #获取queues信息
    Cluster_queues=$(cat $file1 | sed -n /获取queues信息/,/获取consumer信息/p | grep -v "获取queues信息" | grep -v "获取consumer信息") && echo "\"Cluster_queues\"":"\"$Cluster_queues\"""," >>$new_document
    #获取consumer信息
    Cluster_consumer=$(cat $file1 | sed -n /获取consumer信息/,/"获取connections信息"/p | grep -v "获取consumer信息" | grep -v "获取connections信息") && echo "\"Cluster_consumer\"":"\"$Cluster_consumer\"""," >>$new_document
    #获取connections信息
    Cluster_connections=$(cat $file1 | sed -n /获取connections信息/,/"rabbitmq_command_line_end!!!"/p | grep -v "获取connections信息" | grep -v "rabbitmq_command_line_end!!!") && echo "\"Cluster_connections\"":"\"$Cluster_connections\"""," >>$new_document
    #echo "=====================Rabbitmq日志=====================" >> $new_document
    Check_log_health=$(cat $file1 | sed -n /当前过滤的日志为/,/Log_check_end!!!/p | grep -v "当前过滤的日志为" | grep -v "Log_check_end!!!") && echo "\"Check_log_health\"":"\"$Check_log_health\"""," >>$new_document
}

function get_rabbitmq_security_baseline() {
    new_document=$new_data/rabbitmq_$ip_1.json
    security_baseline_port_num=$(cat $file1 | grep security_baseline_port_num | grep -v security_baseline_port_num1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Port_Num\"":"\"$security_baseline_port_num\"""," >>$new_document
    security_baseline_config_file=$(cat $file1 | grep security_baseline_config_file | grep -v security_baseline_config_file1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Config_File\"":"\"$security_baseline_config_file\"""," >>$new_document
    security_baseline_console=$(cat $file1 | grep security_baseline_console | grep -v security_baseline_console1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Console\"":"\"$security_baseline_console\"""," >>$new_document
    security_baseline_root=$(cat $file1 | grep security_baseline_root | grep -v security_baseline_root1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Root\"":"\"$security_baseline_root\"""," >>$new_document
    security_baseline_dir=$(cat $file1 | grep security_baseline_dir | grep -v security_baseline_dir1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Dir\"":"\"$security_baseline_dir\"""," >>$new_document
    security_baseline_guest=$(cat $file1 | grep security_baseline_guest | grep -v security_baseline_guest1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Guest\"":"\"$security_baseline_guest\"""," >>$new_document

    security_baseline_port_num1=$(cat $file1 | grep security_baseline_port_num1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Port_Num1\"":"\"$security_baseline_port_num1\"""," >>$new_document
    security_baseline_config_file1=$(cat $file1 | grep security_baseline_config_file1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Config_File1\"":"\"$security_baseline_config_file1\"""," >>$new_document
    security_baseline_console1=$(cat $file1 | grep security_baseline_console1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Console1\"":"\"$security_baseline_console1\"""," >>$new_document
    security_baseline_root1=$(cat $file1 | grep security_baseline_root1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Root1\"":"\"$security_baseline_root1\"""," >>$new_document
    security_baseline_dir1=$(cat $file1 | grep security_baseline_dir1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Dir1\"":"\"$security_baseline_dir1\"""," >>$new_document
    security_baseline_guest1=$(cat $file1 | grep security_baseline_guest1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Guest1\"":"\"$security_baseline_guest1\"" >>$new_document
}

echo "Start Rabbitmq Date Extraction!!!"
get_os_jsondata
get_rabbitmq_data
get_rabbitmq_security_baseline
cd $data_path
tar -czvf /tmp/enmoResult/"$HOSTNAME"_"rabbitmq"_"$ipinfo"_"$qctime".tar.gz --exclude=/tmp/enmoResult/*.tar.gz --format=ustar /tmp/enmoResult/*
