#!/bin/bash
#version:1.0
#monitor:kafka/os
#update: 根据需求，将整体脚本做了切割，以独立产品做数据采集
#update：security baseline
#update：修复kafka脚本获取Cluster_Description、Topic_list数据失败错误，新增kafka2.2版本之前的 --zookeeper参数的获取
#update-date:2022-09-01

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
    Physical_Memory=$(sudo dmidecode | grep "^[[:space:]]*Size.*MB$" | uniq -c | sed 's/ \t*Size: /\*/g' | sed 's/^ *//g')
    echo "Physical_Memory:$Physical_Memory"
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
    echo "MemTotal:$(convert_unit $MemTotal)"
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
    IO_User=$(iostat -x -k 2 1 | tail -6 | grep -v Device: | grep -v vda | grep -v avg | awk -F " " '{print $2}')
    IO_System=$(iostat -x -k 2 1 | tail -6 | grep -v Device: | grep -v vda | grep -v avg | awk -F " " '{print $4}')
    IO_Wait=$(iostat -x -k 2 1 | tail -6 | grep -v Device: | grep -v vda | grep -v avg | awk -F " " '{print $5}')
    IO_Idle=$(iostat -x -k 2 1 | tail -6 | grep -v Device: | grep -v vda | grep -v avg | awk -F " " '{print $NF}')
    echo "IO_User:$IO_User%"
    echo "IO_System:$IO_System%"
    echo "IO_Wait:$IO_Wait%"
    echo "IO_Idle:$IO_Idle%"
    #TCP参数获取
    Tcp_Tw_Recycle=$(sysctl net.ipv4.tcp_tw_recycle | awk -F "=" '{print $2}')
    echo "Tcp_Tw_Recycle:$Tcp_Tw_Recycle"
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

#----------------------------------------kafka info------------------------------------------------

function kafka_inquiry_info() {
    ip=$(ip addr show | grep "inet " | grep -v 127.0.0. | head -1 | cut -d" " -f6 | cut -d/ -f1)
    date=$(date +%Y-%m)
    echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo "|                      kafka info                         |"
    echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo ""
    echo "当前服务器Kafka进程地址(供参考)：" && ps -ef | grep kafka.Kafka | grep -v grep
    kafka_pid=$(ps -ef | grep kafka.Kafka | grep -v grep | awk -F " " '{print $2}')
    kafka__bin=$(pwdx $kafka_pid | awk -F ":" '{print $2}')
    kafka_dir=$(dirname $kafka__bin)
    kafka_config="$kafka_dir/config/server.properties"
    kafka_config_dir="$kafka_dir/config"
    kafka_bin="$kafka_dir/bin"
    echo "|       获取kafka-IP/PORT/LOG/ZK-IP/PORT信息             |"
    kafka_ip_member=$(cat $kafka_config | grep listeners=PLAINTEXT:// | grep -v ^# | awk -F "//" '{print $2}' | awk -F ":" '{print $1}' | grep -v '^$' | wc -l)
    if [ $kafka_ip_member == 0 ]; then
        kafka_ip=$ip
    else
        kafka_ip=$(cat $kafka_config | grep listeners=PLAINTEXT:// | grep -v ^# | awk -F "//" '{print $2}' | awk -F ":" '{print $1}' | grep -v '^$')
    fi
    kafka_port=$(cat $kafka_config | grep listeners=PLAINTEXT:// | grep -v ^# | awk -F "//" '{print $2}' | awk -F ":" '{print $2}' | grep -v '^$')
    kafka_ip_port=$(cat $kafka_config | grep kafka.connect= | grep -v ^# | awk -F "=" '{print $2}')
    zookeeper_ip_port=$(cat $kafka_config | grep zookeeper.connect | grep -v ^# | grep -v timeout | awk -F "=" '{print $NF}')
    kafka_log="$kafka_dir/logs"

    #新增加对kafka版本的逻辑判断，因为kafka在2.2版本前后对下面的脚本传参形式不同，分为--zookeeper和--bootstrap-server两种
    Kafka_Version=$($kafka_bin/kafka-configs.sh --version | awk -F " " '{print $1}' | tr -cd "[0-9]")

    if [ $Kafka_Version -ge "220" ]; then
        echo "开始进行查询操作，当前查询节点为$kafka_ip-$kafka_port"
        echo ""
        echo "================查询集群描述======================"
        $kafka_bin/kafka-topics.sh --describe --bootstrap-server $kafka_ip:$kafka_port
        echo ""
        echo "================查询topic列表======================"
        $kafka_bin/kafka-topics.sh --list --bootstrap-server $kafka_ip:$kafka_port
        echo ""
        echo "================新消费者列表查询======================"
        $kafka_bin/kafka-consumer-groups.sh --bootstrap-server $kafka_ip:$kafka_port --describe --all-groups
        echo ""
        echo "================查询消费者成员信息======================"
        $kafka_bin/kafka-consumer-groups.sh --bootstrap-server $kafka_ip:$kafka_port --describe --all-groups --members --verbose
        echo ""
        echo "================查询消费者状态信息======================"
        $kafka_bin/kafka-consumer-groups.sh --bootstrap-server $kafka_ip:$kafka_port --describe --all-groups --state
        echo ""
        echo "================查询Kafka动静态配置======================"
        $kafka_bin/kafka-configs.sh --bootstrap-server $kafka_ip:$kafka_port --entity-type topics --describe -all
        $kafka_bin/kafka-configs.sh --bootstrap-server $kafka_ip:$kafka_port --entity-type clients --describe -all
        $kafka_bin/kafka-configs.sh --bootstrap-server $kafka_ip:$kafka_port --entity-type users --describe -all
        $kafka_bin/kafka-configs.sh --bootstrap-server $kafka_ip:$kafka_port --entity-type brokers --describe -all
        echo ""
        echo "================查询Kafka版本信息======================"
        $kafka_bin/kafka-configs.sh --version
        echo ""
        echo "================查询Kafka磁盘信息======================"
        $kafka_bin/kafka-log-dirs.sh --bootstrap-server $kafka_ip:$kafka_port --describe
        echo ""
    else
        echo "开始进行查询操作，当前查询节点为$kafka_ip-$kafka_port"
        echo ""
        echo "================查询集群描述======================"
        $kafka_bin/kafka-topics.sh --describe --zookeeper $zookeeper_ip_port
        echo ""
        echo "================查询topic列表======================"
        $kafka_bin/kafka-topics.sh --list --zookeeper $zookeeper_ip_port
        echo ""
        echo "================新消费者列表查询======================"
        kafka_consumer_group_list=$($kafka_bin/kafka-consumer-groups.sh --bootstrap-server $kafka_ip:$kafka_port --list)
        for i in $kafka_consumer_group_list; do
            $kafka_bin/kafka-consumer-groups.sh --bootstrap-server $kafka_ip:$kafka_port --describe --group $i
        done
        echo ""
        echo "================查询消费者成员信息======================"
        for i in $kafka_consumer_group_list; do
            $kafka_bin/kafka-consumer-groups.sh --bootstrap-server $kafka_ip:$kafka_port --describe --group $i --members --verbose
        done
        echo ""
        echo "================查询消费者状态信息======================"
        for i in $kafka_consumer_group_list; do
            $kafka_bin/kafka-consumer-groups.sh --bootstrap-server $kafka_ip:$kafka_port --describe --group $i --state
        done
        echo ""
        echo "================查询Kafka动静态配置======================"
        $kafka_bin/kafka-configs.sh --zookeeper $zookeeper_ip_port --entity-type topics --describe
        $kafka_bin/kafka-configs.sh --zookeeper $zookeeper_ip_port --entity-type clients --describe
        $kafka_bin/kafka-configs.sh --zookeeper $zookeeper_ip_port --entity-type users --describe
        $kafka_bin/kafka-configs.sh --zookeeper $zookeeper_ip_port --entity-type brokers --describe
        echo ""
        echo "================查询Kafka版本信息======================"
        $kafka_bin/kafka-configs.sh --version
        echo ""
        echo "================查询Kafka磁盘信息======================"
        $kafka_bin/kafka-log-dirs.sh --bootstrap-server $kafka_ip:$kafka_port --describe
        echo ""
    fi

    echo "===============如果开启JMX，获取mebean所有数据============"
    jmx_port_memeber=$(cat $kafka_bin/kafka-server-start.sh | grep -i JMX_port | grep -v ^# | wc -l)

    if [ $jmx_port_memeber == 0 ]; then
        echo "暂未开启JMX端口，不做mebean数据采集"
    else
        jmx_port=$(cat $kafka_bin/kafka-server-start.sh | grep -i JMX_port | awk -F "=" '{print $2}')
        $kafka_bin/kafka-run-class.sh kafka.tools.JmxTool --jmx-url service:jmx:rmi:///jndi/rmi://$kafka_ip:$jmx_port/jmxrmi --report-format csv --one-time 1
    fi
    echo "开始进行日志查询操作，当前查询节点为$kafka_ip-$kafka_port "
    #这个情况一般是由于副本所在节点网络I/O负载开销过大导致的，如果分区太少，可适当增加分区分散节点压力，或者手动将分区副本分配值网络负载低的节点。
    #echo "检查是否有分区发生 ISR频繁扩张收缩"
    #检查分区 leader 选举值是否处于正常水平在controller.log文件中搜索“Topics not in Preferred replica”。
    #echo "检查分区 leader 选举值是否处于正常水平"
    #检查controller是否频繁选举在controller.log文件中搜索“Controller moved to another broker”。
    #echo "检查controller是否频繁选举"
    cd $kafka_log
    for check_isr in $(ls -lrt | grep controller.log$ | awk -F " " '{print $NF}'); do
        less -mN $check_isr | grep -i "Shrinking ISR"
        less -mN $check_isr | grep -i "Topics not in Preferred replica"
        less -mN $check_isr | grep -i "Controller  moved to another broker"
    done

    #echo "检查是否有客户端频繁断开连接"
    #检查是否有客户端频繁断开连接在kafkaServer.out文件中搜索 “Attempting to send response via channel for which there is no open connection”。
    less -mN $kafka_log/kafkaServer.out | grep "Attempting to send response via channel for which there is no open connection"

    #echo "若存在大量短连接客户端频繁与集群断开重连会严重影响集群性能，增大消息发送耗时，如:Spark消费。"
    #echo "消费组是否出现频繁重平衡现象"
    less -mN $kafka_log/kafkaServer.out | grep "Preparing to rabalance group"
    #echo "若出现此问题，首先检查是否有节点网络不稳定导致频繁重连zk，如果有需要修复网络通道，若没有则检查session.timeout.ms、max.poll.interval.ms、heartbeat.interval.ms 参数是否能够满足业务消费逻辑。"
    echo "END!!!"
    echo ""
    echo "==============配置文件获取============"
    cd $kafka_config_dir
    echo "==============cat server.properties================="
    cat server.properties
    echo "==============cat producer.properties================="
    cat producer.properties
    echo "==============cat consumer.properties================="
    cat consumer.properties
    echo "==============cat log4j.properties================="
    cat log4j.properties
}

function kafka_security_baseline() {
    echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo "|                    kafka security baseline              |"
    echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
    echo ""

    echo "当前服务器kafka进程信息!"
    for line in $(ps -ef | grep kafka.Kafka | grep -v grep | awk -F " " '{print $2}'); do
        echo "获取当前kafka的配置文件,当前获取配置的节点为$ip-$line"
        echo "基线1:端口保护;修改kafka默认监听端口9092为不易猜测的端口。"
        security_baseline_port=$(cat $kafka_config_dir/server.properties | grep listeners= | grep -v "#" | awk -F ":" '{print $NF}') && echo "security_baseline_port:$security_baseline_port"
        if [ $security_baseline_port -eq 9092 ]; then
            security_baseline_port1="Failed"
            echo "security_baseline_port1:$security_baseline_port1"
        else
            security_baseline_port1="Pass"
            echo "security_baseline_port1:$security_baseline_port1"
        fi
        echo "基线2:kafka的非特权用户运行。"
        security_baseline_root=$(ps -ef | grep kafka.Kafka | grep -v grep | awk -F " " '{print $1}') && echo "security_baseline_root:$security_baseline_root"
        if [ $security_baseline_root == "root" ]; then
            security_baseline_root1="Failed"
            echo "security_baseline_root1:$security_baseline_root1"
        else
            security_baseline_root1="Pass"
            echo "security_baseline_root1:$security_baseline_root1"
        fi
        echo "基线3:kafka的目录权限控制。"
        security_baseline_dir=$(ls -lrt $kafka_dir | grep -v total | head -n 1 | awk -F " " '{print $3}') && echo "security_baseline_dir:$security_baseline_dir"
        if [ $security_baseline_dir == "root" ]; then
            security_baseline_dir1="Failed"
            echo "security_baseline_dir1:$security_baseline_dir1"
        else
            security_baseline_dir1="Pass"
            echo "security_baseline_dir1:$security_baseline_dir1"
        fi
        echo "基线4:kafka默认分区数，不为1。"
        security_baseline_partitions=$(cat $kafka_config_dir/server.properties | grep num.partitions | awk -F "=" '{print $NF}') && echo "security_baseline_partitions:$security_baseline_partitions"
        if [ $security_baseline_partitions -eq 1 ]; then
            security_baseline_partitions1="Failed"
            echo "security_baseline_partitions1:$security_baseline_partitions1"
        else
            security_baseline_partitions1="Pass"
            echo "security_baseline_partitions1:$security_baseline_partitions1"
        fi
        echo "基线5:kafka是否允许自动创建topic，建议为false。"
        security_baseline_atuocreate=$(cat $kafka_config_dir/server.properties | grep "auto.create.topics" | awk -F "=" '{print $NF}') && echo "security_baseline_atuocreate:$security_baseline_atuocreate"
        if [[ $security_baseline_atuocreate == "false" || $security_baseline_atuocreate == "" ]]; then
            security_baseline_atuocreate1="Pass"
            echo "security_baseline_atuocreate1:$security_baseline_atuocreate1"
        else
            security_baseline_atuocreate1="Failed"
            echo "security_baseline_atuocreate1:$security_baseline_atuocreate1"
        fi
        echo "基线6:kafka的log-dir目录是否在tmp目录下。"
        security_baseline_logdir=$(cat $kafka_config_dir/server.properties | grep "log.dirs" | awk -F "=" '{print $NF}') && echo "security_baseline_logdir:$security_baseline_logdir"
        #example_dir=/tmp
        result=$(echo $security_baseline_logdir | grep "/tmp" | wc -l)
        if [ $result -eq 1 ]; then
            security_baseline_logdir1="Failed"
            echo "security_baseline_logdir1:$security_baseline_logdir1"
        else
            security_baseline_logdir1="Pass"
            echo "security_baseline_logdir1:$security_baseline_logdir1"
        fi
        echo "基线7:kafka的授权访问，是否有acl认证。"
        security_baseline_acl=$(ls -lrt $kafka_config_dir | grep -v total | awk -F " " '{print $NF}' | grep *jaas* | wc -l) && echo "security_baseline_acl:$security_baseline_acl"
        if [ $security_baseline_acl != 0 ]; then
            security_baseline_acl1="Pass"
            echo "security_baseline_acl1:$security_baseline_acl1"
        else
            security_baseline_acl1="Failed"
            echo "security_baseline_acl1:$security_baseline_acl1"
        fi
    done
}

function get_kafka_main() {

    tmpcheck_dir="/tmp/enmoResult/tmpcheck/"
    if [ "$(ls -A $tmpcheck_dir)" ]; then
        echo "$tmpcheck_dir is not empty!!!"
        rm -rf $tmpcheck_dir/*
        echo "clean $tmpcheck_dir !!!"
    else
        echo "$tmpcheck_dir is empty!!!"
    fi
    ####get system info
    filename1=$HOSTNAME"_"kafka"_"os_""$ipinfo"_"$qctime".txt"
    collect_sys_info >>"$filepath""$filename1"
    filename2=$HOSTNAME"_"kafka"_"$ipinfo"_"$qctime".txt"
    kafka_inquiry_info >>"$filepath""$filename2"
    kafka_security_baseline >>"$filepath""$filename2"

    #tar -czvf /tmp/tmpcheck/"$HOSTNAME"_"$name"_"kafka"_"$ipinfo"_"$qctime".tar.gz /tmp/tmpcheck

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
echo "Start performing kafka patrols！！！"
get_kafka_main

data_path=/tmp/enmoResult/tmpcheck
function get_os_jsondata() {
    mkdir -p /tmp/enmoResult/kafka
    new_data=/tmp/enmoResult/kafka
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
    new_document=$new_data/kafka_$ip.json
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

function get_kafka_data() {
    new_data=/tmp/enmoResult/kafka
    cd $data_path
    file1=$filename2
    ip_1=$(ls $file1 | awk -F "_" '{print $3}')
    new_document=$new_data/kafka_$ip_1.json
    #echo "=====================Kafka基础信息=====================" >> $new_document
    Kafka_version=$(cat $file1 | grep -io "kafka_.*" | awk -F ":" '{print $1}' | awk -F "_" '{print $2}' | cut -d "." -f1-4) && echo "\"Kafka_version\"":"\"$Kafka_version\"""," >>$new_document
    Installation_path=$(cat $file1 | grep -io 'Dkafka.logs.dir=.*' | awk -F "=" '{print $2}' | cut -d "." -f1) && echo "\"Installation_path\"":"\"$Installation_path\"""," >>$new_document
    Start_User=$(cat $file1 | grep -A1 "当前服务器Kafka进程地址(供参考)：" | grep -v "当前服务器Kafka进程地址(供参考)：" | awk -F " " '{print $1}') && echo "\"Start_User\"":"\"$Start_User\"""," >>$new_document
    JVM_Instal_path=$(cat $file1 | grep -A1 "当前服务器Kafka进程地址(供参考)：" | grep -v "当前服务器Kafka进程地址(供参考)：" | awk -F " " '{print $8}') && echo "\"JVM_Instal_path\"":"\"$JVM_Instal_path\"""," >>$new_document
    JVM_run_parameters=$(cat $file1 | grep -io 'Xms.*' | awk -F "-Djava" '{print $1}') && echo "\"JVM_run_parameters\"":"\"$JVM_run_parameters\"""," >>$new_document
    Server_Port=$(cat $file1 | grep "listeners=PLAINTEXT:" | grep -v "sensitive" | grep -v "advertised" | awk -F ":" '{print $NF}') && echo "\"Server_Port\"":"\"$Server_Port\"""," >>$new_document
    #echo "=====================Kafka配置文件=====================" >> $new_document
    Broker_id=$(cat $file1 | grep "broker.id" | grep -v "generation" | grep -v "sensitive")
    delete_topic_enable=$(cat $file1 | grep "delete.topic.enable" | grep -v "generation" | grep -v "sensitive")
    listeners=$(cat $file1 | grep "listeners" | grep -v "generation" | grep -v "sensitive" | grep -v ^#)
    num_network_threads=$(cat $file1 | grep "num.network.threads" | grep -v "generation" | grep -v "sensitive")
    num_io_threads=$(cat $file1 | grep "num.io.threads" | grep -v "generation" | grep -v "sensitive")
    log_dirs=$(cat $file1 | grep "log.dirs" | grep -v "generation" | grep -v "sensitive")
    num_partitions=$(cat $file1 | grep "num.partitions" | grep -v "generation" | grep -v "sensitive")
    num_recovery_threads_per_data_dir=$(cat $file1 | grep "num.recovery.threads.per.data.dir" | grep -v "generation" | grep -v "sensitive")
    default_replication_factor=$(cat $file1 | grep "default.replication.factor" | grep -v "generation" | grep -v "sensitive")
    offsets_topic_replication_factor=$(cat $file1 | grep "offsets.topic.replication.factor" | grep -v "generation" | grep -v "sensitive")
    transaction_state_log_replication_factor=$(cat $file1 | grep "transaction.state.log.replication.factor" | grep -v "generation" | grep -v "sensitive")
    transaction_state_log_min_isr=$(cat $file1 | grep "transaction.state.log.min.isr" | grep -v "generation" | grep -v "sensitive")
    log_retention_hours=$(cat $file1 | grep "log.retention.hours" | grep -v "generation" | grep -v "sensitive")
    log_roll_hour=$(cat $file1 | grep "log.roll.hour" | grep -v "generation" | grep -v "sensitive")
    log_cleaner_enable=$(cat $file1 | grep "log.cleaner.enable" | grep -v "generation" | grep -v "sensitive")
    kafka_connection_timeout_ms=$(cat $file1 | grep "kafka.connection.timeout.ms" | grep -v "generation" | grep -v "sensitive")
    kafka_config=$(echo $Broker_id,$delete_topic_enable,$listeners,$num_network_threads,$num_io_threads,$log_dirs,$num_partitions,$num_recovery_threads_per_data_dir,$default_replication_factor,$offsets_topic_replication_factor,$transaction_state_log_replication_factor,$transaction_state_log_min_isr,$log_retention_hours,$log_roll_hour,$log_cleaner_enable,echo $kafka_connection_timeout_ms)
    echo "\"kafka_config\"":"\"$kafka_config\"""," >>$new_document
    #echo "=====================Kafka运行数据=====================" >> $new_document
    echo "" >>$new_document
    Cluster_Description=$(cat $file1 | sed -n /查询集群描述/,/查询topic列表/p | grep -v 查询topic列表 | grep -v 查询集群描述) && echo "\"Cluster_Description\"":"\"$Cluster_Description\"""," >>$new_document
    Topic_list=$(cat $file1 | sed -n /查询topic列表/,/新消费者列表查询/p | grep -v 新消费者列表查询 | grep -v 查询topic列表) && echo "\"Topic_list\"":"\"$Topic_list\"""," >>$new_document
    New_consumer_list=$(cat $file1 | sed -n /新消费者列表查询/,/查询消费者成员信息/p | grep -v 查询消费者成员信息 | grep -v 新消费者列表查询) && echo "\"New_consumer_list\"":"\"$New_consumer_list\"""," >>$new_document
    New_consumer_member=$(cat $file1 | sed -n /查询消费者成员信息/,/查询消费者状态信息/p | grep -v 查询消费者状态信息 | grep -v 查询消费者成员信息) && echo "\"New_consumer_member\"":"\"$New_consumer_member\"""," >>$new_document
    Check_consumer_status=$(cat $file1 | sed -n /查询消费者状态信息/,/查询Kafka动静态配置/p | grep -v 查询Kafka动静态配置 | grep -v 查询消费者状态信息) && echo "\"Check_consumer_status\"":"\"$Check_consumer_status\"""," >>$new_document
    Check_kafka_version=$(cat $file1 | sed -n /查询Kafka版本信息/,/查询Kafka磁盘信息/p | grep -v 查询Kafka版本信息 | grep -v 查询Kafka磁盘信息) && echo "\"Check_kafka_version\"":"\"$Check_kafka_version\"""," >>$new_document
    Check_dir_info=$(cat $file1 | sed -n /查询Kafka磁盘信息/,/如果开启JMX/p | grep -v 查询Kafka磁盘信息 | grep -v 如果开启JMX) && echo "\"Check_dir_info\"":"\'$Check_dir_info\'""," >>$new_document
    #echo "=====================Kafka日志=====================" >>$new_document
    if [ $(cat $file1 | sed -n /开始进行日志查询操作/,/END!!!/p | grep -v "开始进行日志查询操作" | grep -v "END!!!" | wc -l) -eq "0" ]; then
        Check_log_health=$(echo "\"Check_log_health\"":"\"日志无异常。\"""," >>$new_document)
    else
        Check_log_health=$(cat $file1 | sed -n /开始进行日志查询操作/,/END!!!/p | grep -v "开始进行日志查询操作" | grep -v "END!!!") && echo "\"Check_log_health\"":"\"$Check_log_health\"""," >>$new_document
    fi

}
function get_kafka_security_baseline() {
    new_document=$new_data/kafka_$ip_1.json
    Security_Baseline_Port=$(cat $file1 | grep security_baseline_port | grep -v security_baseline_port1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Port\"":"\"$Security_Baseline_Port\"""," >>$new_document
    Security_Baseline_Root=$(cat $file1 | grep security_baseline_root | grep -v security_baseline_root1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Root\"":"\"$Security_Baseline_Root\"""," >>$new_document
    Security_Baseline_Dir=$(cat $file1 | grep security_baseline_dir | grep -v security_baseline_dir1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Dir\"":"\"$Security_Baseline_Dir\"""," >>$new_document
    Security_Baseline_Partitions=$(cat $file1 | grep security_baseline_partitions | grep -v security_baseline_partitions1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Partitions\"":"\"$Security_Baseline_Partitions\"""," >>$new_document
    Security_Baseline_Atuocreate=$(cat $file1 | grep security_baseline_atuocreate | grep -v security_baseline_atuocreate1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Atuocreate\"":"\"$Security_Baseline_Atuocreate\"""," >>$new_document
    Security_Baseline_Logdir=$(cat $file1 | grep security_baseline_logdir | grep -v security_baseline_logdir1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Logdir\"":"\"$Security_Baseline_Logdir\"""," >>$new_document
    Security_Baseline_Acl=$(cat $file1 | grep security_baseline_acl | grep -v security_baseline_acl1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Acl\"":"\"$Security_Baseline_Acl\"""," >>$new_document

    Security_Baseline_Port1=$(cat $file1 | grep security_baseline_port1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Port1\"":"\"$Security_Baseline_Port1\"""," >>$new_document
    Security_Baseline_Root1=$(cat $file1 | grep security_baseline_root1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Root1\"":"\"$Security_Baseline_Root1\"""," >>$new_document
    Security_Baseline_Dir1=$(cat $file1 | grep security_baseline_dir1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Dir1\"":"\"$Security_Baseline_Dir1\"""," >>$new_document
    Security_Baseline_Partitions1=$(cat $file1 | grep security_baseline_partitions1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Partitions1\"":"\"$Security_Baseline_Partitions1\"""," >>$new_document
    Security_Baseline_Atuocreate1=$(cat $file1 | grep security_baseline_atuocreate1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Atuocreate1\"":"\"$Security_Baseline_Atuocreate1\"""," >>$new_document
    Security_Baseline_Logdir1=$(cat $file1 | grep security_baseline_logdir1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Logdir1\"":"\"$Security_Baseline_Logdir1\"""," >>$new_document
    Security_Baseline_Acl1=$(cat $file1 | grep security_baseline_acl1 | awk -F ":" '{print $2}') && echo "\"Security_Baseline_Acl1\"":"\"$Security_Baseline_Acl1\"" >>$new_document

}
echo "Start Kafka Date Extraction!!!"
get_os_jsondata
get_kafka_data
get_kafka_security_baseline
cd $data_path
tar -czvf /tmp/enmoResult/"$HOSTNAME"_"kafka"_"$ipinfo"_"$qctime".tar.gz /tmp/enmoResult
