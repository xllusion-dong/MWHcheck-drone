#!/bin/bash
#version:1.0
#monitor:elasticsearch/os
#update:新增日志检查，针对初始堆、内存使用情况、内存锁定、查询条件情况、磁盘容量进行检查
#update-date:2022-07-01

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
    
    #for file in  $data_path/tmp/tmpcheck/*_os_*.txt ;

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
#----------------------------------------es info------------------------------------------------
function es_inquiry_info(){
    echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|" >> "$filepath""$filename2"
    echo "|                 info   Elasticsearch  cluster           |"  >> "$filepath""$filename2"
    echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|" >> "$filepath""$filename2"

    #echo "++++++++++ ES info information ++++++++++"

    init=0
    es_pid_member=`ps -ef|grep java|grep elasticsearch |grep -v grep |awk -F " " '{print $2}'|wc -l`
    
    if [ $es_pid_member == 0 ];then
	exit 0;
    else
	pids=`ps -ef|grep java|grep elasticsearch |grep -v grep |awk -F " " '{print $2}'`
	#pid=`ps -ef|grep java|grep elasticsearch |grep -v grep |awk -F " " '{print $2}'`
	for pid in $pids
        do
	   echo "{"
	   echo "[" >> "$filepath""$filename2"
	   excelastic=`ps -ef | grep $pid | grep -v grep |awk -F "-Des.path.conf=" '{print $2}' | awk '{print $1}'`
	   elasticPath=`ps -ef | grep $pid | grep -v grep | grep -o "Des.path.home=.*" | awk -F' ' '{print $1}'| awk -F'=' '{print $NF}'`	   
           #httpPort=`grep -r http.port $excelastic |awk 'NR==1{print $NF}'`
	   echo "当前Elasticsearch服务进程: $pid" >> "$filepath""$filename2"
	   #当前Elasticsearch服务启动用户"
	   start_User=`ps -ef|grep elasticsearch|grep -v grep | awk 'NR==1{print $1}'`
	   echo "当前Elasticsearch服务启动用户: $start_User" >> "$filepath""$filename2"   
           echo "\"startUser\":\"$start_User\""","
	   if [ "$start_User"x == 'root'x ];then
		echo "\"runUserResult\":\"Failed\""","
	   else
		echo "\"runUserResult\":\"Pass\""","
	   fi
	   #Elasticsearch安装路径
	   echo "\"elasticPath\":\"$elasticPath\""","
	   echo "Elasticsearch的安装路径: $elasticPath" >> "$filepath""$filename2"
	   #Elasticsearch版本信息
	   version=`cd $elasticPath && ls lib/ | grep -P 'elasticsearch-\d\.\d\.\d\.jar'|awk -F '-' '{print $2}'|awk -F '.jar' '{print $(NF-1)}'`
	   echo "Elasticsearch版本信息: $version" >> "$filepath""$filename2"
	   echo "\"version\":\"$version\""","
           #Elasticsearch配置文件路径
	   echo "\"excelastic\":\"$excelastic\""","
	   echo "Elasticsearch配置文件路径: $excelastic" >> "$filepath""$filename2"
           #当前Elasticsearch提供服务端口
           httpPort=`grep -r http.port "$excelastic/elasticsearch.yml" | awk 'NR==1{print $NF}'`
           echo "\"http_port\":\"$httpPort\""","
           echo "当前Elasticsearch对外提供服务端口：$httpPort" >> "$filepath""$filename2"
	   es_host=$ipinfo:$httpPort 
	   #Elasticsearch 使用java版本信息
	   elastic_java_path=`ps -ef | grep $pid | grep -v grep | awk 'NR==1{print $8}'`
	   #判断使用的jdk类型（oracle_jdk、openjdk）
           if [ x"$elastic_java_path"x == x'/usr/bin/java' ];then
                java_real_path=`ls -lt /usr/bin/java | awk '{print $NF}'`
                java_real_path=`ls -lt $java_real_path | awk '{print $NF}' | awk -F "/jre" '{print $1}'`
                echo "\"java_path\"":"\"$java_real_path\""","
		echo "Java安装路径: $java_real_path" >> "$filepath""$filename2"
                java_version=`$java_path -version 2>&1 |awk 'NR==1 {gsub(/"/,""); print $3}'`
                echo "\"java_version\"":"\"$java_version\""","
		echo "Java使用版本：$java_version " >> "$filepath""$filename2"
           else
                java_real_path=`echo $elastic_java_path | awk -F "/bin" '{print $(NF-1)}'`
                echo "\"java_path\"":"\"$java_real_path\""","
		echo "Java安装路径: $java_real_path" >> "$filepath""$filename2"
                java_version=`$elastic_java_path -version 2>&1 |awk 'NR==1 {gsub(/"/,""); print $3}'`
                echo "\"java_version\"":"\"$java_version\""","
		echo "Java使用版本：$java_version " >> "$filepath""$filename2"
           fi
	   #Elasticsearch配置jvm大小
	   jvm_size=`cd $excelastic && grep -v ^# ./jvm.options|grep 'Xm' 2>&1 | awk '{printf "%s",$0}'`
           echo "\"jvm\":\"$jvm_size\""","
	   echo "java配置的jvm大小：$jvm_size" >> "$filepath""$filename2"
	   #Elasticsearch中cluster名字
	   cluster_name=`cd $excelastic && grep -v ^# ./elasticsearch.yml | grep 'cluster.name' | awk '{print $NF}'`
	   echo "\"cluster_name\":\"$cluster_name\""","
	   echo "当前Elasticsearch配置集群名称：$cluster_name" >> "$filepath""$filename2"
	   #Elasticsearch中master节点
	   masterIP=`curl http://$es_host/_cat/master 2>&1 | awk 'END{print $(NF-2)}'`
	   echo "\"master\":\"$masterIP\""","
	   echo "当前Elasticsearch集群中master节点ip：$masterIP" >> "$filepath""$filename2"
	   #当前Elasticsearch节点类型
       	   if [ $ipinfo == $masterIP ];then
		echo "\"node_type\":\"Master node\""","
		echo "node_type:当前Elasticsearch节点为master节点" >> "$filepath""$filename2"
	   else
		echo "\"node_type\":\"Slave node\""","
		echo "node_type:当前Elasticsearch节点为slave节点" >> "$filepath""$filename2"
	   fi	   
	   #当前Elasticsearch节点是否为数据节点
	   node_data=`cd $excelastic && grep -v ^# ./elasticsearch.yml|grep 'node.data' | awk '{print $NF}'`
	   echo "\"node_data\":\"$node_data\""","
	   echo "当前节点是否为数据节点：$node_data" >> "$filepath""$filename2"
	   #Elasticsearch中索引数据存储路径
	   path_data=`cd $excelastic && grep -v ^# ./elasticsearch.yml|grep 'path.data' | awk '{print $NF}'`
	   echo "\"path_data\":\"$path_data\""","
	   echo "当前Elasticsearch节点的索引数据存储路径：$path_data" >> "$filepath""$filename2"
	   #当前Elasticsearch服务日志文件路径
	   path_logs=`cd $excelastic && grep -v ^# ./elasticsearch.yml|grep 'path.logs' | awk '{print $NF}'`
	   echo "\"path_logs\":\"$path_logs\""","
	   echo "当前Elasticsearch节点日志文件路径：$path_logs" >> "$filepath""$filename2"
	   #当前Elasticsearch传输最大容量
	   content_length=`cd $excelastic && grep -v ^# ./elasticsearch.yml|grep 'http.max_content_length'`
	   if [ ! $content_length ];then
		echo "\"http_max_content_length\":\"100mb\""","
		echo "当前Elasticsearch传输最大容量http_max_content_length: 100mb" >> "$filepath""$filename2"
	   else
		echo "\"http_max_content_length\":\"`echo $content_length | awk '{print $NF}'`\""","
		echo "当前Elasticsearch传输最大容量http_max_content_length: $http_max_content_length" >> "$filepath""$filename2"
	   fi
	   #当前Elasticsearch服务是否锁定内存
	   memory_lock=`cd $excelastic && grep -v ^# ./elasticsearch.yml|grep 'bootstrap.memory_lock'`
	   if [ ! ${#memory_lock} ];then
		echo "\"bootstrap_memory_lock\":\"false\""","
		echo "当前Elasticserach节点是否锁定内存：false" >> "$filepath""$filename2"
	   else
		echo "\"bootstrap_memory_lock\":\"`echo $memory_lock | awk '{print $NF}'`\""","
		echo "当前Elasticserach节点是否锁定内存：true" >> "$filepath""$filename2"
	   fi
	   #当前Elasticsearch服务健康状态
	   health=`curl http://$es_host/_cat/health 2>&1 | awk 'END{print $4}'`
	   echo "\"health\":\"$health\""","
	   echo "当前Elasticsearch服务健康状态: $health" >> "$filepath""$filename2"
	   #当前Elasticsearch中shards分片总数
	   shards_count=`curl -XGET  http://$es_host/_cat/health?v 2>&1|awk 'END{print $7}'`
	   echo "\"shards_count\":\"$shards_count\""","
	   echo "当前Elasticsearch中shards分片总数: $shards_count" >> "$filepath""$filename2"
	   #当前Elasticsearch服务索引监控状态
	   indexes_status=`curl -XGET  http://$es_host/_cat/indices?v 2>&1 |grep -E "yellow|red"`
	   if [ ! ${#indexes_status} ];then
		echo "\"indexes_status\":\"$indexes_status\""","
		echo "当前Elasticsearch服务索引监控状态: $indexes_status" >> "$filepath""$filename2"
	   else
		echo "\"indexes_status\":\"Index in good condition\""","
		echo "当前Elasticsearch服务索引监控状态: 运行良好" >> "$filepath""$filename2"
	   fi
	   #当前Elasticsearch配置的初始分片数量
	   init_count=`curl -s -XGET  http://$es_host/_cat/health?v 2>&1|awk 'END{print $10}'`
	   echo "\"init_count\":\"$init_count\""","
	   echo "当前Elasticsearch配置的初始分片数量: $init_count" >> "$filepath""$filename2"
	   #当前Elasticsearch集群中未分配的分片数量
	   unassign=`curl -s -XGET  http://$es_host/_cat/health?v 2>&1|awk 'END{print $11}'`
	   echo "\"unassign\":\"$unassign\""","
	   echo "当前Elasticsearch集群中未分配的分片数量: $unassign" >> "$filepath""$filename2"
	   #当前Elasticsearch中准备执行的任务数量
	   pending_tasks=`curl -s -XGET  http://$es_host/_cat/health?v 2>&1|awk 'END{print $12}'`
	   echo "\"pending_tasks\":\"$pending_tasks\""","
	   echo "当前Elasticsearch中准备执行的任务数量: $pending_tasks" >> "$filepath""$filename2"
	   #当前节点Elasticsearch中是否存在Shard分片大于50G的索引
	   a_store=`curl -s -XGET  http://$es_host/_cat/shards?v | grep "$node_name" | awk '{if (NR > 1){print $6}}'`
	   for b_store in $a_store
	   do
	       result=$(echo $b_store | grep -i "gb")
	       if [  $result ];then
		     #c_store=`echo ${b_store%??}`
		     c_store=`echo ${b_store%??} | awk -F '.' '{print $1}'`
      		     d_store=50 #50G
      		     compare
     	       else
      		     result=$(echo $b_store | grep -i "mb")
      	       	     if [  $result ];then
			   c_store=`echo ${b_store%??} | awk -F '.' '{print $1}'`
         		   d_store=51200 #1024*50G
         		   compare
      		     else
         		   result=$(echo $b_store | grep -i "kb")
         		   if [  $result ];then
				 c_store=`echo ${b_store%??} | awk -F '.' '{print $1}'`
            			 d_store=52428800
            			 compare
         		   else
            			 result=$(echo $b_store | grep -i "b")
            			 c_store=`echo ${b_store%?} | awk -F '.' '{print $1}'`
            			 d_store=53687091200
            			 compare
         		   fi
      		     fi
   	       fi
	   done
	   #compare
           if [ -e $store_data ];then
              if [ -s $store_data ];then
		   removal_data=$new_data/es_removal.txt
		   echo $(awk '!a[$0]++' $store_data) >> $removal_data
		   store_count=`grep store $removal_data | wc -l`
		   if [ $store_count -gt 1 ];then
		   	store=$(grep store $removal_data | grep -v '单个分片没有大于50G的分片' | awk -F ':' '{print $NF}')
		   else
                   	store=$(grep store $removal_data |awk -F ':' '{print $NF}')
		   fi
                   echo "\"store\":\"$store\""","
		   echo "当前Elasticsearch集群中所有Shard分片及索引信息" >> "$filepath""$filename2"
		   echo "$(curl -s -XGET  http://$es_host/_cat/shards?v)" >> "$filepath""$filename2"
		   rm -f $store_data && rm -f $removal_data
              fi
           fi
	   #当前节点在Elasticsearch集群中节点名称
	   node_name=`cd $excelastic && grep -v ^# ./elasticsearch.yml|grep 'node.name' | awk '{print $NF}'`
           echo "\"node_name\":\"$node_name\""","
	   echo "当前节点在Elasticsearch集群中节点名称: $node_name" >> "$filepath""$filename2"
           #当前节点Elasticsearch中线程池信息，判断条件queue>1000且rejected>500时输出，否则输出线程池正常
	   get_es_thread

	   #查看当前elasticsearch集群分片是否正常
	   count=`curl -s -XGET http://$es_host/_cat/shards?v | grep -v STARTED|awk '{if (NR > 1){print $(NF-1)}}'`
	   if [[ ! $count ]];then
		echo "\"cluster_shards\":\"当前集群分片正常\""","
           else
                echo "\"cluster_shards\":\"当前集群分片存在异常\""","

	   fi
	   #当前节点Elasticsearch中磁盘使用情况
	   ram_percent=`curl -s -XGET  http://$es_host/_cat/nodes?v | grep "$ipinfo"|awk '{print $3}'`
	   echo "\"ram_percent\":\"$ram_percent\""","
	   echo "当前节点Elasticsearch中磁盘使用情况: $ram_percent" >> "$filepath""$filename2"
	   #当前节点Elasticsearch监听地址
	   networkHost=`cd $excelastic && grep -v ^# ./elasticsearch.yml|grep 'network.host' | awk '{print $NF}'`
	   echo "\"network_host\":\"$networkHost\""","
	   echo "当前节点Elasticsearch监听地址: $networkHost" >> "$filepath""$filename2"
	   if [ "$networkHost" = '0.0.0.0' ];then
		echo "\"networkHostResult\":\"Failed\""","
	  else
		echo "\"networkHostResult\":\"Pass\""","
	  fi

	   #当前Elasticsearch是否配置禁止批量删除查询
	   action=`cd $excelastic && grep -v ^# ./elasticsearch.yml|grep 'action.destructive_requires_name' | awk '{print $NF}'`
	   if [ ! $action ] || [ "$action" = 'false' ];then
            	echo "\"action_destructive_requires_name\":\"false\""","
		echo "当前Elasticsearch是否配置禁止批量删除查询: false" >> "$filepath""$filename2"
		echo "\"requires_Result\":\"Failed\""","
	   else
	   	echo "\"action_destructive_requires_name\":\"$action\""","
		echo "当前Elasticsearch集群中配置缓存field的过期时间: $field_expire" >> "$filepath""$filename2"
		echo "\"requires_Result\":\"Pass\""","
	   fi
	   #当前Elasticsearch集群中配置缓存field的过期时间
	   field_expire=`cd $excelastic &&  grep -v ^# ./elasticsearch.yml|grep 'index.cache.field.expire' | awk '{print $NF}'`
	   if [ ! $field_expire ];then
	 	echo "\"index_cache_field_expire\":\"unlimited\""","
		echo "当前Elasticsearch集群中配置缓存field的过期时间: unlimited" >> "$filepath""$filename2"
		echo "\"index_expire_Result\":\"Failed\""","
	   else
		echo "\"index_cache_field_expire\":\"$field_expire\""","
		echo "当前Elasticsearch集群中配置缓存field的过期时间: $field_expire" >> "$filepath""$filename2"
		echo "\"index_expire_Result\":\"Pass\""","
	   fi
	   #当前Elasticsearch集群中配置缓存field的最大文件数
	   field_max_size=`cd $excelastic &&  grep -v ^# ./elasticsearch.yml|grep 'index.cache.field.max_size' | awk '{print $NF}'`
	   if [ ! $field_max_size ];then
		echo "\"index_cache_field_max_size\":\"unlimited\""","
		echo "当前Elasticsearch集群中配置缓存field的最大文件数: unlimited" >> "$filepath""$filename2"
		echo "\"index_max_size_Result\":\"Failed\""","
	   else
		echo "\"index_cache_field_max_size\":\"$field_max_size\""","
		echo "当前Elasticsearch集群中配置缓存field的最大文件数: $field_max_size" >> "$filepath""$filename2"
		echo "\"index_max_size_Result\":\"Pass\""","
           fi
		
	   #echo 当前Elasticsearch集群初始化数据恢复进程的超时时间
	   #recover_after_time=`cd $excelastic &&  grep -v ^# ./elasticsearch.yml|grep 'gateway.recover_after_time' | awk '{print $NF}'`
           #if [ ! $recover_after_time ];then
           #     echo "\"gateway_recover_after_time\":\"5m\""
           #else
           #     echo "\"gateway_recover_after_time\":\"$recover_after_time\""
           #fi
	   #echo 当前Elasticsearch集群中N个节点启动时进行数据恢复
	   #recover_after_nodes=`cd $excelastic &&  grep -v ^# ./elasticsearch.yml|grep 'gateway.recover_after_nodes' | awk '{print $NF}'`
           #if [ ! $recover_after_nodes ];then
           #     echo "\"gateway_recover_after_nodes\":\"1\""
           #else
           #     echo "\"gateway_recover_after_nodes\":\"$recover_after_nodes\""
           #fi
	   #echo 当前Elasticsearch集群是否配置压缩tcp传输时的数据
	   transport_tcp_compress=`cd $excelastic &&  grep -v ^# ./elasticsearch.yml|grep 'transport.tcp.compress' | awk '{print $NF}'`
           if [ ! $transport_tcp_compress ];then
                echo "\"transport_tcp_compress\":\"false\""","
		echo "当前Elasticsearch集群是否配置压缩tcp传输时的数据: false" >> "$filepath""$filename2"
		echo "\"transport_tcp_Result\":\"Failed\""","
           else
                echo "\"transport_tcp_compress\":\"$transport_tcp_compress\""","
		echo "当前Elasticsearch集群是否配置压缩tcp传输时的数据: $transport_tcp_compress" >> "$filepath""$filename2"
		echo "\"transport_tcp_Result\":\"Pass\""","
           fi
	   log_check
	   #当前Elasticsearch集群所有配置文件"
           #cd  $excelastic && ls -l
	   init=`expr $init + 1`
           echo "}"
	   echo "]" >> "$filepath""$filename2"
           [ $init -lt $es_pid_member ] && echo ","

	done
    fi
}
#获取elasticsearch分片状态
function compare(){
	store_data=$new_data/es_store.txt
   	if [[ $c_store -gt $d_store ]];then
        	#result=$result
        	store=`curl -s -XGET  http://$es_host/_cat/shards?v|grep $result`
        	echo "store:$store" >> $store_data
   	else
        	echo "store:单个分片没有大于50G的分片" >> $store_data
   	fi
}
#获取elasticsearch线程状态
function get_es_thread(){

	thread_data=$new_data/es_thread.txt	
	#queue=(`curl -s -XGET  http://$es_host/_cat/thread_pool?v | grep $node_name | awk '{if (NR > 1){print $(NF-1)}}'`)
        queue=(`curl -s -XGET  http://$es_host/_cat/thread_pool?v | grep $node_name | awk '{print $(NF-1)}'`)
        #rejected=(`curl -s -XGET  http://$es_host/_cat/thread_pool?v | grep $node_name |awk '{if (NR > 1){print $(NF)}}'`)
        rejected=(`curl -s -XGET  http://$es_host/_cat/thread_pool?v | grep $node_name |awk '{print $(NF)}'`)
        #echo $queue
        #echo $rejected
        for (( i=0;i<${#queue[@]};i++)) do
             result=(${queue[i]}:${rejected[i]})
             #echo $result
             a_result=${result%%:*}
             #echo $a_result
             b_result=${result##*:}
             #echo $b_result
             #echo "a_result=$a_result" 
             if [[ $a_result -gt '1000' ]] && [[ $b_result -gt '500' ]];then
                   thread_result=`curl -s -XGET  http://$es_host/_cat/thread_pool?v|grep $node_name|awk '(NR>1) {if($(NF-1)>=1000) print}'|awk ' {if($NF>=500) print}'`
                   echo "thread:$thread_result" >> $thread_data
             else
                   echo "thread:线程池运行正常，当前队列中无过多任务数（大于1000）并且连接被拒绝的任务数小于500" >> $thread_data
             fi
        done
	if [ -e $thread_data ];then
	     if [ -s $thread_data ];then
		removal_data=$new_data/es_removal.txt
		echo $(awk '!a[$0]++' $thread_data) >> $removal_data
		thread_count=`grep thread $removal_data |wc -l`
		if [ $thread_count -gt 1 ];then
		     thread=$(grep thread $removal_data | grep -v '线程池运行正常' | awk -F ':' '{print $NF}')
		else
             	     thread=$(grep thread $removal_data |awk -F ':' '{print $NF}')
		fi
	     	echo "\"thread\":\"$thread\""","
                echo "当前Elasticsearch集群线程状态" >> "$filepath""$filename2"
                echo "$(curl -s -XGET  http://$es_host/_cat/thread_pool?v)" >> "$filepath""$filename2"
		rm -f $thread_data && rm -f $removal_data
	     fi
	fi
}
function log_check(){
	#awk '!a[$0]++' "$filepath""$filename2" >> "$filepath""$filename2"
	#获取日志提取备份
	checktime=$(date +'%Y-%m-%d')
	#获取运行日志
	logfile="$cluster_name"_deprecation.log
	newlogfile="$filepath""$logfile-$checktime"
	tail -n5000 $path_logs/$logfile >> $newlogfile
	#获取节点日志
	nodelogfile="$cluster_name".log
	newNodefile="$filepath""$nodelogfile-$checktime"
	tail -n5000 $path_logs/$logfile >> $newNodefile
	#获取索引写入的慢日志
	indexing_slowlog="$cluster_name"_index_indexing_slowlog.log
	newIndexlog="$filepath""$indexing_slowlog-$checktime"
	index_data=$path_logs/$indexing_slowlog
	if [[ -f $index_data && -s $index_data ]];then
	      tail -n5000 $index_data >> $newIndexlog
	fi
	#获取索引读取的慢日志
	search_slowlog="$cluster_name"_index_search_slowlog.log
	newSearchlog="$filepath""$search_slowlog-$checktime"
	search_date=$path_logs/$search_slowlog
	if [[ -f $search_date && -s $search_date ]];then
	      tail -n5000 $search_date >> $newSearchlog
	fi
	#核查jvm初始堆配置
	headp_size=`grep 'initial heap size' -C 10 $newlogfile | tail -n 5`
	if [ ${#headp_size} -ne 0 ];then
        	echo "\"headp_size\":\"$headp_size\""","
        	echo "\"headp_size_result\":\"初始化堆内存和最大堆内存设置不一致,可能导致调整大小暂停，并阻止mlockall锁定整个堆。建议将jvm的初始堆的最小值（xms）和最大值（xmx）设置为同样大小，且不>大于物理内存的1/2\""","
	#else
        #	echo "\"headp_size_result\":\"当前初始堆配置合理，在对initial heap size排查时未发现异常\""","
	fi
	#核查内存使用情况
	memory_error=`grep 'Java heap space' -C 10 $newlogfile | tail -n 20`
	if [ ${#memory_error} -ne 0 ];then
	        echo "\"memory_error\":\"$memory_error\""","
        	echo "\"memory_error_result\":\"当前elasticsearch集群节点出现过jvm内存溢出现象，建议对该elasticsearch集群进一步深入检查，排查内存溢出的原因。\""","
	else
        	echo "\"memory_error\":\"检查当前集群是否出现过内存溢出时，发现系统运行良好，未发现异常信息\""","
	fi
	#核查bool查询条件，是否index.query.bool.max_clause_count配置不合理
	toomany_clauses=`grep 'too_many_clauses' -C 10 $newlogfile | tail -n 20`
	if [ ${#toomany_clauses} -ne 0 ];then
        	echo "\"toomany_clauses\":\"$too_many_clauses\""","
        	echo "\"toomany_clauses_result\":\" bool查询的查询条件过多,需要调整index.query.bool.max_clause_count\""","
	else
        	echo "\"toomany_clauses\":\"当前查询正常，未发现明显异常\""","
	fi
	#核查内存是否可以锁定
	lock_type=`grep 'memory locking requested for elasticsearch process but memory is not locked' -C 10 $newlogfile | tail -n 5`
	if [ ${#lock_type} -ne 0 ];then
        	echo "\"lock_type\":\"$lock_type\""","
        	echo "\"lock_type_result\":\"进程内存锁定失败,建议对当前es进一步检查\""","
	else
        	echo "\"lock_type\":\"当前查询正常，未发现明显异常\""","
	fi
	#对当前节点磁盘空间进行排查
	transport_error=`grep 'TransportError' -C 10 $newlogfile | tail -n 20`
	if [ ${#transport_error} -ne 0 ];then
        	echo "\"transport_error\":\"$transport_error\""","
        	echo "\"transport_error_result\":\"当前节点磁盘空间不足，建议扩充储存空间或对磁盘使用进行清理\""
	else
        	echo "\"transport_error\":\"当前节点磁盘空间正常\""
	fi
}
#----------------------------------------es info-JSON------------------------------------------------
function get_es_jsondata(){

	echo \"esinfo\": [ >> $new_document
	es_inquiry_info >> $new_document
	echo ] >> $new_document

}

function mwcheck_result_jsondata(){
	new_data=/tmp/enmoResult/es
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
	new_document=$new_data/es_$ipinfo.json
	#echo "{" > $new_document
	echo \"osinfo\": \{ >> $new_document
	#获取os的json文件
	get_os_jsondata
	echo "}," >> $new_document
	#获取es的json文件
	get_es_jsondata
	#echo "}" >> $new_document
	#将本次巡检结果打包
	echo "Patrol data packaging process !!!"
	tar -czvf /tmp/enmoResult/"$HOSTNAME"_"es"_"$ipinfo"_"$qctime".tar.gz --exclude=/tmp/enmoResult/*tar* /tmp/enmoResult/ 2> /dev/null
        echo "Patrol data for successful collection !!!" 
}

######################Main##########################
#指定控制台语音为UTF-8
export LANG=zh_CN.UTF-8
#原始巡检数据存放位置
filepath="/tmp/enmoResult/tmpcheck/"
#当前系统时间
qctime=$(date +'%Y%m%d%H%M%S')
#IP地址
ipinfo=`ip addr show |grep 'state UP' -A 2| grep "inet " |grep -v 127.0.0. |head -1|cut -d" " -f6|cut -d/ -f1`
excmkdir=$(which mkdir | awk 'NR==1{print}' )
#节点分片所需参数
b_store=$b_store
c_store=$c_store
d_store=$d_store
result=$result
if [ ! -d $filepath  ];then
   #excmkdir=$(which mkdir  | awk 'NR==1{print}'  )
   $excmkdir -p   $filepath
else
   rm -rf $filepath/*   
fi
####脚本基础数据收集
filename1=$HOSTNAME"_"es"_"os_""$ipinfo"_"$qctime".txt"
filename2=$HOSTNAME"_"es"_"$ipinfo"_"$qctime".txt"
collect_sys_info >> "$filepath""$filename1"
mwcheck_result_jsondata
