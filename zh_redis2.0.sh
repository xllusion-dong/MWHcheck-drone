#!/bin/bash
#version:1.8
#monitor:redis/os
#update:1、add Generate patrol json file
#	2、add redis security check 
#update-date:2023-01-15

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
    Physical_Memory=$(expr $memTotalReal \* 1024)M
    echo "Physical_Memory:$Physical_Memory"

    
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

function get_os_jsondata(){
    
    #for file in  $filepath/*_os_*.txt ;

    file="$filepath""$filename1"
	
    #echo "=====================OS基础信息=====================" >> $new_document
    IP_Address=`cat $file |grep IP|awk -F ":" '{print $2}'`&& echo "\"IP_Address\"":"\"$IP_Address\"""," >> $new_document
    Hostname=`cat $file |grep Hostname|awk -F ":" '{print $2}'`&& echo "\"Hostname\"":"\"$Hostname\"""," >> $new_document
    Architecture=`cat $file |grep Architecture|awk -F ":" '{print $2}'`&& echo "\"Architecture\"":"\"$Architecture\"""," >> $new_document
    Kernel_Release=`cat $file |grep Kernel_Release|awk -F ":" '{print $2}'`&& echo "\"Kernel_Release\"":"\"$Kernel_Release\"""," >> $new_document
    Physical_Memory=`cat $file |grep Physical_Memory|awk -F ":" '{print $2}'`&& echo "\"Physical_Memory\"":"\"$Physical_Memory\"""," >> $new_document
    Cpu_Cores=`cat $file |grep Cpu_Cores|awk -F ":" '{print $2}'`&& echo "\"Cpu_Cores\"":"\"$Cpu_Cores\"""," >> $new_document
    Cpu_Proc_Num=`cat $file |grep Cpu_Proc_Num|awk -F ":" '{print $2}'`&& echo "\"Cpu_Proc_Num\"":"\"$Cpu_Proc_Num\"""," >> $new_document
    LastReboot=`cat $file |grep LastReboot|awk -F ":" '{print $2}'`&& echo "\"LastReboot\"":"\"$LastReboot\"""," >> $new_document
    Uptime=`cat $file |grep Uptime|awk -F ":" '{print $2}'`&& echo "\"Uptime\"":"\"$Uptime\"""," >> $new_document
    Load=`cat $file |grep Load|awk -F ":" '{print $2}'`&& echo "\"Load\"":"\"$Load\"""," >> $new_document
    MemTotal=`cat $file |grep MemTotal|awk -F ":" '{print $2}'`&& echo "\"MemTotal\"":"\"$MemTotal\"""," >> $new_document
    MemFree=`cat $file |grep MemFree|awk -F ":" '{print $2}'`&& echo "\"MemFree\"":"\"$MemFree\"""," >> $new_document
    MemUsed=`cat $file |grep MemUsed|awk -F ":" '{print $2}'`&& echo "\"MemUsed\"":"\"$MemUsed\"""," >> $new_document
    Mem_Rate=`cat $file |grep Mem_Rate|awk -F ":" '{print $2}'`&& echo "\"Mem_Rate\"":"\"$Mem_Rate\"""," >> $new_document
    Openfile=`cat $file |grep Openfile|awk -F ":" '{print $2}'`&& echo "\"Openfile\"":"\"$Openfile\"""," >> $new_document
    Swap_Method=`cat $file |grep Swap_Method|awk -F ":" '{print $2}'`&& echo "\"Swap_Method\"":"\"$Swap_Method\"""," >> $new_document
    Totalsum=`cat $file |grep Totalsum|awk -F ":" '{print $2}'`&& echo "\"Totalsum\"":"\"$Totalsum\"""," >> $new_document
    Usesum=`cat $file |grep Usesum|awk -F ":" '{print $2}'`&& echo "\"Usesum\"":"\"$Usesum\"""," >> $new_document
    Freesum=`cat $file |grep Freesum|awk -F ":" '{print $2}'`&& echo "\"Freesum\"":"\"$Freesum\"""," >> $new_document
    Diskutil=`cat $file |grep Diskutil|awk -F ":" '{print $2}'`&& echo "\"Diskutil\"":"\"$Diskutil\"""," >> $new_document
    Freeutil=`cat $file |grep Freeutil|awk -F ":" '{print $2}'`&& echo "\"Freeutil\"":"\"$Freeutil\"""," >> $new_document
    IO_User=`cat $file |grep IO_User|awk -F ":" '{print $2}'`&& echo "\"IO_User\"":"\"$IO_User\"""," >> $new_document
    IO_System=`cat $file |grep IO_System|awk -F ":" '{print $2}'`&& echo "\"IO_System\"":"\"$IO_System\"""," >> $new_document
    IO_Wait=`cat $file |grep IO_Wait|awk -F ":" '{print $2}'`&& echo "\"IO_Wait\"":"\"$IO_Wait\"""," >> $new_document
    IO_Idle=`cat $file |grep IO_Idle|awk -F ":" '{print $2}'`&& echo "\"IO_Idle\"":"\"$IO_Idle\"""," >> $new_document
    Tcp_Tw_Recycle=`cat $file |grep Tcp_Tw_Recycle|awk -F ":" '{print $2}'`&& echo "\"Tcp_Tw_Recycle\"":"\"$Tcp_Tw_Recycle\"""," >> $new_document
    Tcp_Tw_Reuse=`cat $file |grep Tcp_Tw_Reuse|awk -F ":" '{print $2}'`&& echo "\"Tcp_Tw_Reuse\"":"\"$Tcp_Tw_Reuse\"""," >> $new_document
    Tcp_Fin_Timeout=`cat $file |grep Tcp_Fin_Timeout|awk -F ":" '{print $2}'`&& echo "\"Tcp_Fin_Timeout\"":"\"$Tcp_Fin_Timeout\"""," >> $new_document
    Tcp_Keepalive_Time=`cat $file |grep Tcp_Keepalive_Time|awk -F ":" '{print $2}'`&& echo "\"Tcp_Keepalive_Time\"":"\"$Tcp_Keepalive_Time\"""," >> $new_document
    Tcp_Keepalive_Probes=`cat $file |grep Tcp_Keepalive_Probes|awk -F ":" '{print $2}'`&& echo "\"Tcp_Keepalive_Probes\"":"\"$Tcp_Keepalive_Probes\"""," >> $new_document
    Tcp_Keepalive_Intvl=`cat $file |grep Tcp_Keepalive_Intvl|awk -F ":" '{print $2}'`&& echo "\"Tcp_Keepalive_Intvl\"":"\"$Tcp_Keepalive_Intvl\"" >> $new_document
    
}

#----------------------------------------redis info 数据采集------------------------------------------------
function collect_redis_info(){
        echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
        echo "|                       db info                        |"
        echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
	echo "----->>>---->>>  config "
	echo -e "auth $passwd\nconfig get *"| $excredis -h $ipinfo -p $svport | tr -d '\r' 2>/dev/null

        echo "----->>>---->>>  info "
	echo -e "auth $passwd\ninfo"| $excredis -h $ipinfo -p $svport | tr -d '\r' 2>/dev/null

	echo "----->>>---->>>  cluster info "
	echo -e "auth $passwd\ncluster info"| $excredis -h $ipinfo -p $svport | tr -d '\r' 2>/dev/null

        echo "----->>>---->>>  cluster node "
	echo -e "auth $passwd\ncluster nodes"| $excredis -h $ipinfo -p $svport | tr -d '\r' 2>/dev/null

        # echo "----->>>---->>>  bigkeys "
	#echo $($excredis -a $passwd -h $ipinfo -p $svport --bigkeys | grep -v '^#' | tr -d '\r')  2>/dev/null

        echo "----->>>---->>>  slowlog "
	echo -e "auth $passwd\nslowlog get 10"| $excredis -h $ipinfo -p $svport | tr -d '\r' 2>/dev/null

        echo "----->>>---->>>  info commandstats "
	echo -e "auth $passwd\ninfo commandstats"| $excredis -h $ipinfo -p $svport | tr -d '\r' 2>/dev/null

}

function collect_redis_info_no(){
        echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
        echo "|                       db info                        |"
        echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
        echo "----->>>---->>>  config "
	echo "config get *" | $excredis -h $ipinfo -p $svport | tr -d '\r' 2>/dev/null

        echo "----->>>---->>>  info "
	echo "info " | $excredis -h $ipinfo -p $svport | tr -d '\r' 2>/dev/null
 
        echo "----->>>---->>>  cluster info "
	echo "cluster info " | $excredis -h $ipinfo -p $svport | tr -d '\r' 2>/dev/null

        echo "----->>>---->>>  cluster node "
	echo "cluster nodes " | $excredis -h $ipinfo -p $svport | tr -d '\r' 2>/dev/null

        # echo "----->>>---->>>  bigkeys "
        # echo "bigkeys " | $1 -h $2 -p $3 -a $4 --bigkeys
	# echo $($excredis -h $ipinfo -p $svport --bigkeys) | grep -v '^#' | tr -d '\r' 2>/dev/null

        echo "----->>>---->>>  slowlog "
	echo "slowlog get 10" | $excredis -h $ipinfo -p $svport | tr -d '\r' 2>/dev/null

        echo "----->>>---->>>  info commandstats "
	echo "info commandstats " | $excredis -h $ipinfo -p $svport | tr -d '\r' 2>/dev/null

	#echo "----->>>---->>>  log check "
	#echo "explain:Log output from back to front!(日志由后向前输出，取最后30次报错信息，第一条为最后一次报错)"
	#echo ""
	#tac  $(echo "config get logfile " | $1 -h $2 -p $3|awk 'NR==2{print}')|grep -i 'error' |head -n 30
}

#----------------------------------------redis info-JSON------------------------------------------------
function get_redis_info_json(){
    redisfiles=`ls $filepath | grep -v 'os'`
    init=0
    checkfile_number=`ls $filepath | grep -v 'os'|wc -l`
    for checkfile in $redisfiles 
    do	
	echo "{"
	redisfile=$filepath$checkfile
	#redis服务启动用户"
	startUser=`cat $redisfile | grep startUser | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"startUser\":\"$startUser\""","
	#当前redis使用版本信息
	version=`cat $redisfile | grep redis_version | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"redis_version\":\"$version\""","
	#当前redis使用端口信息
	tcp_port=`cat $redisfile | grep tcp_port | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"tcp_port\":\"$tcp_port\""","
	#当前redis运行模式
	redis_mode=`cat $redisfile | grep redis_mode | awk -F ':' '{print $NF}' | tr -d '\r'`
        #当前redis节点角色
        role=`cat $redisfile | grep 'role' | awk -F ':' '{print $NF}' | tr -d '\r'`
        echo "\"role\":\"$role\""","	
	#判断部署模式
	if [ "$redis_mode"x == "standalone"x ];then
           connected_slaves=`cat $redisfile | grep connected_slaves | awk -F ':' '{print $NF}' | tr -d '\r'`
	   role=`cat $redisfile | grep 'role' | awk -F ':' '{print $NF}' | tr -d '\r'`
	   if [ "$connected_slaves"x == "0"x ]&&[ "$role"x == "master"x ];then
		echo "\"redis_mode\":\"standalone\""","
		
	   elif [ "$connected_slaves"x == "0"x ]&&[ "$role"x != "master"x ];then
		echo "\"redis_mode\":\"redis-sentinel\""","
	   else
		echo "\"redis_mode\":\"redis-sentinel\""","
	   fi
	else
	    echo "\"redis_mode\":\"$redis_mode\""","
	fi
	#当前redis所在系统版本
	os=`cat $redisfile | grep 'os:' | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"os\":\"$os\""","
	#当前redis架构情况
	arch_bits=`cat $redisfile | grep arch_bits | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"arch_bits\":\"$arch_bits\""","
	#当前redis使用的配置文件
	config_file=`cat $redisfile | grep config_file | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"config_file\":\"$config_file\""","
	#当前redis启动命令位置
	executable=`cat $redisfile | grep executable | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"executable\":\"$executable\""","
	#redis启动时长，单位是秒
	uptime_in_seconds=`cat $redisfile | grep uptime_in_seconds | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"uptime_in_seconds\":\"$uptime_in_seconds\""","
	#redis启动时长，单位天
	uptime_in_days=`cat $redisfile | grep uptime_in_days | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"uptime_in_days\":\"$uptime_in_days\""","
	#redis内存淘汰策略
	maxmemory_policy=`cat $redisfile | grep maxmemory_policy | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"maxmemory_policy\":\"$maxmemory_policy\""","
	#同一时间redis最大客户端连接数
	maxclients=`cat $redisfile | grep maxclients | awk -F ':' 'END{print $NF}' | tr -d '\r'`
	echo "\"maxclients\":\"$maxclients\""","
	#服务器配置slowlog-log-slower-than 选项的值，默认为空
	slowlog_log_slower_than=`cat $redisfile | grep -A 1 slowlog-log-slower-than | awk 'END {print}' | tr -d '\r'`
	echo "\"slowlog_log_slower_than\":\"$slowlog_log_slower_than\""","
	#redis服务器配置slowlog-max-len 选项的值
	#slowlog_max_len=`cat $redisfile | grep -A 1 slowlog_max_len | awk 'END {print}' | tr -d '\r'`
	#echo "\"slowlog_max_len\":\"$slowlog_max_len\""","
	#redis服务是否配置延时监控
	latency_monitor_threshold=`cat $redisfile | grep -A 1 latency_monitor_threshold | awk 'END {print}' | tr -d '\r'`
	echo "\"latency_monitor_threshold\":\"$latency_monitor_threshold\""","
	#redis连接的客户端（connected_clients）数
	connected_clients=`cat $redisfile | grep connected_clients | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"connected_clients\":\"$connected_clients\""","
	#redis连接拒绝计数
	rejected_connections=`cat $redisfile | grep rejected_connections | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"rejected_connections\":\"$rejected_connections\""","
	#slave自上次与主节点交互以来，经过的秒数
	master_last_io_seconds_ago=`cat $redisfile | grep master_last_io_seconds_ago | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"master_last_io_seconds_ago\":\"$master_last_io_seconds_ago\""","
	#master已连接的从节点数
	connected_slaves=`cat $redisfile | grep connected_slaves | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"connected_slaves\":\"$connected_slaves\""","
	#阻塞客户端数量
	blocked_clients=`cat $redisfile | grep blocked_clients | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"blocked_clients\":\"$blocked_clients\""","
	#redis内存碎片率
	mem_fragmentation_ratio=`cat $redisfile | grep mem_fragmentation_ratio | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"mem_fragmentation_ratio\":\"$mem_fragmentation_ratio\""","
	#redis内存使用量
	used_memory=`cat $redisfile | grep 'used_memory:' | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"used_memory\":\"$used_memory\""","
	#由于 maxmemory 限制，而被回收内存的 key 的总数
	evicted_keys=`cat $redisfile | grep evicted_keys | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"evicted_keys\":\"$evicted_keys\""","
	#keyspace 命中次数
	keyspace_hits=`cat $redisfile | grep keyspace_hits | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"keyspace_hits\":\"$keyspace_hits\""","
	#redis有一系列操作会fork子进程来处理任务的时间，单位为毫秒
	latest_fork_usec=`cat $redisfile | grep latest_fork_usec | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"latest_fork_usec\":\"$latest_fork_usec\""","
	#redis查询执行时间的日志系统
	slowlog=`cat $redisfile | sed -n '/----->>>---->>>  slowlog/,/----->>>---->>>  info commandstats/p' | awk 'NR>2{print line}{line=$0}' | tr -d '\r'`
	if [ $slowlog  ];then
	   echo "\"slowlog\":\"$slowlog\""","
	else
           echo "\"slowlog\":\"Not currently\""","
	fi
	#处理过的命令总数
	total_commands_processed=`cat $redisfile | grep total_commands_processed | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"total_commands_processed\":\"$total_commands_processed\""","
	#keyspace 未命中次数
	keyspace_misses=`cat $redisfile | grep keyspace_misses | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"keyspace_misses\":\"$keyspace_misses\""","
	# redis每秒处理的命令数,服务器的忙碌状态查询
	instantaneous_ops_per_sec=`cat $redisfile | grep instantaneous_ops_per_sec | awk -F ':' '{print $NF}' | tr -d '\r'`
	echo "\"instantaneous_ops_per_sec\":\"$instantaneous_ops_per_sec\""
	#bigkeys查询
	#bigkeys=`cat $redisfile |  sed -n '/----->>>---->>>  bigkeys/,/----->>>---->>>  slowlog/p'|awk 'NR>2{print line}{line=$0}' | tr -d '\r'`
	#echo "\"bigkeys\":\"$bigkeys\""","
	#slowlog查询
	#errorlog=`cat $redisfile | sed -n '/----->>>---->>>  log_check/,//p'|awk 'NR>2{print line}{line=$0}' | tr -d '\r'`
	#echo \""errorlog\":\"$errorlog"\"","
	#echo \""errorlog\":\"$errorlog"\"
 	init=`expr $init + 1`
        echo "}"
	#echo "]"
        [ $init -lt $checkfile_number ] && echo ","
   done	
}	

#获取redis的json信息
function get_redis_jsondata(){
    echo \"redisinfo\": [ >> $new_document
    get_redis_info_json >> $new_document
    echo ] >> $new_document

}

#获取最终json文件
function mwcheck_result_jsondata(){
    new_data="$datapath/checkjson/"
    if [ -d "$new_data" ];then

       if [ "$(ls -A $new_data)" ];then
          echo "$new_data is not empty!!!"
          rm -rf $new_data/*
          echo "clean $new_data !!!"
	    
       else
          echo "$new_data is empty!!!"
       fi
     fi
     $excmkdir -p $new_data
     new_document=$new_data/redis_$ipinfo.json
     #echo "{" > $new_document
     echo \"osinfo\": \{ >> $new_document
     #获取os的json文件
     get_os_jsondata
     echo "}," >> $new_document
     #获取redis的json文件
	
     get_redis_jsondata
     #echo "}" >> $new_document
}


function redis_check_main() {

   filename2=$HOSTNAME"_"redis"_"$svport"_"$ipinfo"_"$qctime".txt"
   if [ ! $passwd  ];then
	collect_redis_info_no >> "$filepath""$filename2"
	echo "startUser:`ps -ef | grep redis | grep $svport | awk 'NR==1{print $1}' | tr -d '\r'`" >> "$filepath""$filename2"
   else
	collect_redis_info  >> "$filepath""$filename2"
	echo "startUser:`ps -ef | grep redis | grep $svport | awk 'NR==1{print $1}' | tr -d '\r'`" >> "$filepath""$filename2"
   fi
   #将巡检结果输出为json
   mwcheck_result_jsondata
   #将本次巡检结果打包
   echo "Patrol data packaging process !!!"
   tar -czvPf /tmp/enmoResult/"$HOSTNAME"_"redis"_"$ipinfo"_"$qctime".tar.gz --exclude=/tmp/enmoResult/*tar* /tmp/enmoResult/
   echo "Patrol data for successful collection !!!" 
   echo -e "___________________"
   echo -e "Collection info Finished."
   echo -e "Result File Path:" $filepath
   echo -e "\n"
   cd /tmp/enmoResult
}

#需要传入password密码
function passwordvalidate() {
    echo $password | egrep [a-z] | egrep [A-Z] | egrep [0-9] | egrep [^0-Z] &>/dev/null
    if (($? == 0)); then
        len=${#password}
        if ((len >= 8)); then
            echo "Process $OPID Redis password Check Conclusion:Paas"
            #echo -e "the password is valid!"
        else
            echo "Process $OPID Redis password Check Conclusion:Did not pass the security check"
        fi
    else
        echo "Process $OPID Redis password Check Conclusion:Did not pass the security check"
    fi

}

#获取redis运行用户
function redisUser(){

    echo "安全基线:用户保护，禁止使用root用户启动redis服务"
    redisrunUser=$(ps -ef|grep $redispid | grep -v grep | awk '{print  $1}')
    if [ x$redisrunUser = x'root' ];
    then
        echo "Process $redispid  redis runUser Check Conclusion:Did not pass the security check"
    else
        echo "Process $redispid  redis runUser Check Conclusion:Pass"
    fi
}


#redis密码认证,并设置高复杂度密码
function redisauthpass(){
    
    echo "安全基线:redis密码认证,并设置高复杂度密码"
    if [ x$role = 'master' ];then
        password=$(grep -v '^#' $configpath | grep requirepass | awk '{print $NF}')
        passwordvalidate
    else
        password=$(grep -v '^#' $configpath | grep masterauth | awk '{print $NF}')
        passwordvalidate
    fi
}

#redis监听端口哦
function redisport(){
    
    echo "安全基线:端口保护，检查redis默认监听端口是否为6379"
    if [ $svport -eq 6379 ]; then
        echo "Process $redispid  redis Port Check Conclusion:Did not pass the security check"
    else
        echo "Process $redispid  redis Port Check Conclusion:Pass"
    fi
}

#redis监听地址
function redisbind(){

    echo "安全基线:Redis监听地址，检查redis默认监听地址是否为0.0.0.0"
    if [[ ! -z $bind ]];
    then
        if [ x$bind = x'0.0.0.0' ];then
            echo "Process $redispid  redis bind Check Conclusion:Did not pass the security check"
        else
            echo "Process $redispid  redis bind Check Conclusion:Pass  绑定地址为：$bind"
        fi
    else
        echo "Process $redispid  redis bind Check Conclusion:Did not pass the security check"
    fi

}

#redis配置文件权限640
function redisconfig(){

    echo "安全基线:Redis配置文件权限，检查redis配置文件权限是否为640"
    redisconfig=$(ls -lt $configpath| awk '{print $1}')
    if [ x$redisconfig = x'-rw-r-----' ];then
        echo "Process $redispid  redis configfile 640 Check Conclusion:Pass"
    else
        echo "Process $redispid  redis configfile 640 Conclusion:Did not pass the security check"
    fi
}
#redis无密码
function redis_info_nopassword(){
     echo "example: /usr/local/redis/bin/redis-cli"
     read -p "Please input your redis-cli path:" path
     excredis=$path
     echo "###############Get Redis Process Info##################"
     ####get system info
     filename1=$HOSTNAME"_"os"_"$ipinfo"_"$qctime".txt"
     collect_sys_info >> "$filepath""$filename1"
#     excredis=`find / -name "redis-cli" | awk 'NR==1'`
     arr_port=`ps aux | grep redis-server |grep -v grep |awk '/redis-server /'|awk '{if ($NF=="[cluster]") print $(NF-1); else print $NF}'|awk -F  ':'  '{print $2}'`
     echo "___________________"
     echo "Redis Service Ports:"$arr_port
     echo "Redis Client Path  :"$excredis
     echo "Start checking the Redis service!!!"
     array=(${arr_port// / })
     for svport in ${array[@]}
     do
        redispingreturn=$(echo -e "ping"|$excredis -h $ipinfo -p $svport) ##return pong
	redispid=$(ps -ef|grep redis-server |grep $svport|grep -v grep | awk '{print $2}')
	#execredispath=$(ls -l /proc/$redispid/exe|awk -F "->" '{print $2}'| tr -d ' '|awk -F "/r    edis-server" '{print $1}')
        if [ x$(echo $redispingreturn | awk '{print $NF}') = x'PONG' ];
        then
            configpath=$(echo -e "info Server" | $excredis -h $ipinfo -p $svport  |grep config_file| awk -F ':' '{print $NF}'| tr -d '\r')
            bind=$(echo -e "config get bind" | $excredis -h $ipinfo -p $svport| tail -1)
	    echo "=====================" >> $security_baseline_document
            echo "" >> $security_baseline_document
            redisUser >> $security_baseline_document
            echo "" >> $security_baseline_document
            redisport >> $security_baseline_document
            echo "" >> $security_baseline_document
            redisbind >> $security_baseline_document
            echo "" >> $security_baseline_document
            redisconfig >> $security_baseline_document
	    echo "=====================" >> $security_baseline_document
            redis_check_main
        else
            echo "may be the redis need password,retry!!!" 
        fi  
        
    done
        
}

#redis存在密码
function redis_info_password(){
     echo "example: /usr/local/redis/bin/redis-cli"
     read -p "Please input your redis-cli path:" path
     excredis=$path
     #echo "###############Get Redis Process Info##################"
     echo "Please enter the redis password manually !!!"
     echo -e "Please input your redis Passwd: \c"
     while :; do
        char=$(
           stty cbreak -echo
           dd if=/dev/tty bs=1 count=1 2>/dev/null
           stty -cbreak echo
        ) #aaaaaaa
        if [ "$char" = "" ]; then
            echo
            break
        fi
        PASS="$PASS$char"
        echo -n "*"
     done
     passwd=$PASS
     echo "###############Get Redis Process Info##################"
     ####get system info
     filename1=$HOSTNAME"_"os"_"$ipinfo"_"$qctime".txt"
     collect_sys_info >> "$filepath""$filename1"
#     excredis=`find / -name "redis-cli" | awk 'NR==1'`
     arr_port=`ps aux | grep redis-server |grep -v grep |awk '/redis-server /'|awk '{if ($NF=="[cluster]") print $(NF-1); else print $NF}'|awk -F  ':'  '{print $2}'`
     echo "___________________"
     echo "Redis Service Ports:"$arr_port
     echo "Redis Client Path  :"$excredis
     echo "Start checking the Redis service!!!"
     array=(${arr_port// / })
     for svport in ${array[@]}
     do
	 redispid=$(ps -ef|grep redis-server |grep $svport|grep -v grep | awk '{print $2}')
	 #execredispath=$(ls -l /proc/$redispid/exe|awk -F "->" '{print $2}'| tr -d ' '|awk -F "/r    edis-server" '{print $1}')
         redispingreturn=$(echo -e "auth $passwd\nping"|$excredis -h $ipinfo -p $svport)
         if [ x$(echo $redispingreturn | awk '{print $NF}') = x'PONG' ];
         then
            configpath=$(echo -e "auth $passwd\ninfo Server" | $excredis -h $ipinfo -p $svport  |grep config_file| awk -F ':' '{print $NF}'| tr -d '\r')
            bind=$(echo -e "auth $passwd\nconfig get bind" | $excredis -h $ipinfo -p $svport| tail -1)
            echo "=====================" >> $security_baseline_document
            echo "" >> $security_baseline_document
            redisUser >> $security_baseline_document
            echo "" >> $security_baseline_document
            redisauthpass >> $security_baseline_document
            echo "" >> $security_baseline_document
            redisport >> $security_baseline_document
            echo "" >> $security_baseline_document
            redisbind >> $security_baseline_document
            echo "" >> $security_baseline_document
            redisconfig >> $security_baseline_document
            echo "=====================" >> $security_baseline_document
            redis_check_main 
         else 
            echo "input password error ,retry!!!"
         fi
     done   

}


#----------------------------------------END------------------------------------------------
######################Main##########################
#指定控制台语音为UTF-8
export LANG=zh_CN.UTF-8
filepath="/tmp/enmoResult/tmpcheck/"
datapath=/tmp/enmoResult/redis
excmkdir=$(which mkdir  | awk 'NR==1{print}'  )

$excmkdir -p   $filepath

qctime=$(date +'%Y%m%d%H%M%S')

ipinfo=$(ip addr show | grep 'state UP' -A 2 | grep "inet " | grep -v 127.0.0. | head -1 | cut -d" " -f6 | cut -d/ -f1)
redis_pid_member=$(ps -eo ruser,pid,args | grep redis-server | grep -v grep  | awk '{ print $2}' | wc -l)
#####check /tmp/tmpcheck Is empty
tmpcheck_dir="/tmp/enmoResult/tmpcheck"
if [ "$(ls -A $tmpcheck_dir)" ];then
    echo "$tmpcheck_dir is not empty!!!"
    rm -rf $tmpcheck_dir/*
    echo "clean $tmpcheck_dir !!!"
else
    echo "$tmpcheck_dir is empty!!!"
fi
#安全基线检查文件存储位置
securitypath=$datapath/security
security_baseline_document=$datapath/security/security_baseline.json
if [ -d "$securitypath" ]; then

    if [ "$(ls -A $securitypath)" ]; then
       echo "$securitypath is not empty!!!"
       rm -rf $securitypath/*
       echo "clean $securitypath !!!"

    else
       echo "$security_baseline_document is empty!!!"
    fi
else
    $excmkdir -p $securitypath
fi
if [ ${redis_pid_member} == 0 ]; then
    echo "There is no redis process on the server!"
    exit 0
else
    echo "The redis process is running on the server,Start Check!"
    echo "###########################################"
cat <<EOF
    Redis config Password choose:
        1(not config password)
        2(config password)
EOF
    echo "###########################################"
    read -p "Please input your check middleware type:" type
    echo "###########################################"
    case "${type}" in
        1)
            redis_info_nopassword
        ;;
        2)
            redis_info_password
        ;;
        quit)
            echo "Quit！！！"
            break
        ;;
        *)
            echo "default (none of above)"
            break
        ;;
    esac
fi
