#!/bin/bash
#version:1.0
#monitor:rocketmq/os
#update: 根据需求，将整体脚本做了切割，以独立产品做数据采集
#update-date:2022-06-6

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
    if [ $MemTotal -ge "1048576" ]; then
        memTotalReal01=$(convert_unit $MemTotal)
        echo "MemTotal:$memTotalReal01"
        memTotalReal=$((${memTotalReal01//.*/+1}))
        ###根据memTotalReal确定Physical_Memory物理内存
        Physical_Memory=$(expr $memTotalReal \* 1024)M
        echo "Physical_Memory:$Physical_Memory"
    fi

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
        IO_System=$(iostat -x -k 2 1 | grep -1 avg | grep -v avg | grep -v ^$ | awk -F ' ' '{print $4}')
        IO_Wait=$(iostat -x -k 2 1 | grep -1 avg | grep -v avg | grep -v ^$ | awk -F ' ' '{print $4}')
        IO_Idle=$(iostat -x -k 2 1 | grep -1 avg | grep -v avg | grep -v ^$ | awk -F ' ' '{print $NF}')
        echo "IO_User:$IO_User%"
        echo "IO_System:$IO_System%"
        echo "IO_Wait:$IO_Wait%"
        echo "IO_Idle:$IO_Idle%"
    else
        IO_User=$(top -n1 | fgrep "Cpu(s)" | tail -1 | awk -F ' ' '{print $2}')
        IO_System=$(top -n1 | fgrep "Cpu(s)" | tail -1 | awk -F ' ' '{print $4}')
        IO_Wait=$(top -n1 | fgrep "Cpu(s)" | tail -1 | awk -F ' ' '{print $10}')
        IO_Idle=$(top -n1 | fgrep "Cpu(s)" | tail -1 | awk -F ' ' '{print $8}')
        echo "IO_User:$IO_User%"
        echo "IO_System:$IO_System%"
        echo "IO_Wait:$IO_Wait%"
        echo "IO_Idle:$IO_Idle%"
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
    #echo "----->>>---->>>  io scheduler"
    #dmesg | grep -i scheduler
    echo ""
    echo "----->>>---->>>  disk mount "
    df -h
    echo "----->>>---->>> rocketmq process info"    
    ps -ef | grep java |grep org.apache.rocketmq.namesrv.NamesrvStartup  | grep -v grep
    ps -ef | grep java |grep org.apache.rocketmq.broker.BrokerStartup | grep -v grep 



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

#----------------------------------------rocketmq info------------------------------------------------

function rocketmq_status_info(){
    rocketmqbase=$1
    namesrvAddr=$2
    brokeraddress=$3

    #查看当前broker集群信息
    echo "查看当前broker集群信息" >> "$filepath""$filename2"
    #$rocketmqbase/bin/mqadmin clusterList -n $namesrvAddr >> "$filepath""$filename2"
    rocketmqclusterinfo=$($rocketmqbase/bin/mqadmin clusterList -n $namesrvAddr)
    echo -e "$rocketmqclusterinfo" >> "$filepath""$filename2"
    echo  -e "\"rocketmqclusterinfo\"":"\"$rocketmqclusterinfo\""","

    echo "" >>  "$filepath""$filename2"
    #查看当前broker的配置信息
    echo "当前broker的配置信息" >>  "$filepath""$filename2"
    rocketmqbrokerconfig=$($rocketmqbase/bin/mqadmin getBrokerConfig -n $namesrvAddr -b $brokeraddress )
    echo -e "$rocketmqbrokerconfig" >> "$filepath""$filename2"
    echo "" >>  "$filepath""$filename2"
    #查看当前broker的状态信息
    echo "查看当前broker的状态信息" >>  "$filepath""$filename2"
    echo "" >>  "$filepath""$filename2"
    rocketmqbrokerstatus=$($rocketmqbase/bin/mqadmin brokerStatus -n $namesrvAddr -b $brokeraddress )
    echo -e "$rocketmqbrokerstatus" >>  "$filepath""$filename2"
    echo "" >>  "$filepath""$filename2"
    echo -e "\"rocketmqbrokerstatus\"":"\"$rocketmqbrokerstatus\""","
    echo "查看当前broker中所有的消费者组"  >> "$filepath""$filename2"
    rocketmqconsumergroup=$($rocketmqbase/bin/mqadmin consumerProgress -n $namesrvAddr)
    echo -e "$rocketmqconsumergroup" >>  "$filepath""$filename2"
    echo -e "\"rocketmqconsumergroup\"":"\"$rocketmqconsumergroup\""","
    echo "" >>  "$filepath""$filename2"

    rocketmqconsumergroupInfo=$($rocketmqbase/bin/mqadmin consumerProgress -n $namesrvAddr | grep -v '#Group' |awk '{print $1}')
    for consumergroup in $rocketmqconsumergroupInfo;do
        echo "查看指定消费组下的所有topic数据堆积情况" >> "$filepath""$filename2"
        consumergroupinfo=$($rocketmqbase/bin/mqadmin consumerProgress -n $namesrvAddr -g $consumergroup )
        echo -e "$consumergroupinfo" >>  "$filepath""$filename2"
        #echo -e "\"rocketmqconsumergroup\"":"\"$rocketmqconsumergroup\""","
        echo "" >>  "$filepath""$filename2"
    done



    echo "查看broker中各个消费者的消费情况，消息是否有积压" >> "$filepath""$filename2"
    #判断 diff不为0，./mqadmin brokerConsumeStats -n 192.168.3.138:9876 -b 192.168.3.64:10911 | awk 'n==1{print} $0~/#Topic/{n=1}' | awk '(NR>=1) {if($7>0) print}'
    rocketmqconsumerinfo=$($rocketmqbase/bin/mqadmin brokerConsumeStats -n $namesrvAddr -b $brokeraddress)
    echo -e "$rocketmqconsumerinfo" >>  "$filepath""$filename2"
    echo -e "\"rocketmqconsumerinfo\"":"\"$rocketmqconsumerinfo\""","
    echo "" >>  "$filepath""$filename2"

    echo "查看当前broker中存在的主题" >> "$filepath""$filename2"
    rocketmqtopic=$($rocketmqbase/bin/mqadmin topicList -n $namesrvAddr -c)
    echo -e "$rocketmqtopic" >>  "$filepath""$filename2"
    echo -e "\"rocketmqtopic\"":"\"$rocketmqtopic\""","
    echo "" >>  "$filepath""$filename2"


    echo "收集Topic订阅关系、TPS、积累量、24h读写总量等信息" >> "$filepath""$filename2"
    rocketmqtopic24info=$($rocketmqbase/bin/mqadmin statsAll -n $namesrvAddr)
    echo -e "$rocketmqtopic24info" >>  "$filepath""$filename2"
    echo -e "\"rocketmqtopic24info\"":"\"$rocketmqtopic24info\""","
    echo "" >>  "$filepath""$filename2"

}


function  rocketmq_broker_log(){
    rocketmqBase=$1
    rocketmqlogpath=$2

    echo "" >>  "$filepath""$filename2"
    echo "查看broker日志" >> "$filepath""$filename2"
    tail -n 5000 $rocketmqlogpath/broker.log >>  "$filepath""$filename2"
    echo "" >>  "$filepath""$filename2"

    echo "" >>  "$filepath""$filename2"
    echo "查看store日志" >> "$filepath""$filename2"
    tail -n 5000 $rocketmqlogpath/store.log >>  "$filepath""$filename2"
    echo "" >>  "$filepath""$filename2"

    echo "" >>  "$filepath""$filename2"
    echo "查看storeerror日志" >> "$filepath""$filename2"
    tail -n 5000 $rocketmqlogpath/storeerror.log >>  "$filepath""$filename2"
    echo "" >>  "$filepath""$filename2"


    echo "" >>  "$filepath""$filename2"
    echo "查看remoting日志" >> "$filepath""$filename2"
    tail -n 5000 $rocketmqlogpath/remoting.log >>  "$filepath""$filename2"
    echo "" >>  "$filepath""$filename2"


    echo "" >>  "$filepath""$filename2"
    echo "查看stats日志" >> "$filepath""$filename2"
    tail -n 5000 $rocketmqlogpath/stats.log >>  "$filepath""$filename2"
    echo "" >>  "$filepath""$filename2"

    if [ $rocketmq_namesvr_member -gt 0 ];then
        namesvrlogpath=$(ps -feww | grep org.apache.rocketmq.namesrv.NamesrvStartup  | grep -v grep | grep -io "rocketmq.client.logRoot=.*" | awk '{FS=" "; print $1}' | cut -d "=" -f2)
        echo "收集namesvr服务日志" >>  "$filepath""$filename2"
        tail -n 5000 $namesvrlogpath/namesrv.log >> "$filepath""$filename2"
        echo "" >>  "$filepath""$filename2"
    fi

}


function rocketmq_inquiry_info() {
    init=0
    rocketmq_pid_member=$(ps -ef | grep java | grep org.apache.rocketmq.broker.BrokerStartup | grep -v grep | awk -F " " '{print $2}' | wc -l)
    ip=$ipinfo

    

    for line in $(ps -ef | grep java | grep org.apache.rocketmq.broker.BrokerStartup | grep -v grep | awk -F " " '{print $2}'); do
        echo "{"
        
        rocketmqBase=$(pwdx $line | awk -F ':' '{print $2}' | awk -F '/bin' '{print $1}' | awk '{print $1}')
        echo "\"rocketmqBase\"":"\"$rocketmqBase\""","

        rocketmqversion=$(ls -lt $rocketmqBase/lib| grep rocketmq-broker | awk '{print $NF}' | awk -F '-' '{print $3}')
        echo "\"rocketmqversion\"":"\"$rocketmqversion\""","

        
        #获取当前rocketmq的配置文件，对服务进程进行判断是否存在-c参数
        ppid=$(ps -ef|grep $line |grep -v grep | awk '{print $3}')
        cparameter=$(ps -ef|grep $ppid |grep runbroker.sh | grep -io '\-c')
        if [ x$cparameter = x ];then
            rocketmqconfigfilepath=$rocketmqBase/conf/broker.conf
        else
            rocketmqconfigfile=$(ps -ef|grep $line |grep -v grep| grep  org.apache.rocketmq.broker.BrokerStartup  | awk -F '-c' '{print $NF}' | awk '{print $1}')
            rocketmqconfigfile01=$(echo $rocketmqconfigfile  | awk -F '/' '{print $NF}')
            rocketmqconfigfilepath=$(find $rocketmqBase -name $rocketmqconfigfile01 -type f -print | grep $rocketmqconfigfile)
        fi 
      

        echo "获取当前rocketmq的配置文件为：$rocketmqconfigfilepath" >"$filepath""$filename2" 
        cat $rocketmqconfigfilepath >> "$filepath""$filename2"

        echo "\"rocketmqconfigfilepath\"":"\"$rocketmqconfigfilepath\""","
        namesrvAddr=$(ps -ef|grep $line |grep -v grep| grep  org.apache.rocketmq.broker.BrokerStartup |grep "\-n" | awk -F '-n' '{print $NF}' | awk '{print $1}')
        
        brokerClusterName=$(grep 'brokerClusterName' $rocketmqconfigfilepath | awk -F '=' '{print $2}')
        echo "\"brokerClusterName\"":"\"$brokerClusterName\""","
        brokerRole=$(grep 'brokerRole' $rocketmqconfigfilepath | awk -F '=' '{print $2}')
        echo "\"brokerRole\"":"\"$brokerRole\""","
        brokerId=$(grep 'brokerId' $rocketmqconfigfilepath | awk -F '=' '{print $2}')
        echo "\"brokerId\"":"\"$brokerId\""","
        listenPort=$(grep 'listenPort' $rocketmqconfigfilepath | awk -F '=' '{print $2}')
        if [ x$listenPort = x ];then
            listenPort=10911
            echo "\"listenPort\"":"\"$listenPort\""","
        else
            echo "\"listenPort\"":"\"$listenPort\""","
        fi
        
        brokerIP1=$(grep 'brokerIP1' $rocketmqconfigfilepath | awk -F '=' '{print $2}')
        if [ x$brokerIP1 = x ];then
            brokerIP1=$ip
            echo "\"brokerIP1\"":"\"$brokerIP1\""","
        else
            echo "\"brokerIP1\"":"\"$brokerIP1\""","
        fi 

        brokeraddress=$brokerIP1:$listenPort\($brokerId\)
        echo "\"brokeraddress\"":"\"$brokeraddress\""","  

        brokeraddress01=$brokerIP1:$listenPort        

        if [ x$namesrvAddr = x ];then
            #get namesrvAddr from broker.conf 
            namesrvAddr=$(grep 'namesrvAddr' $rocketmqconfigfilepath | awk -F '=' '{print $2}')
            namesrvAddr01=$(echo $namesrvAddr | awk -F ';' '{print $1}')
            echo "\"namesrvAddr\"":"\"$namesrvAddr\""","
            rocketmq_status_info $rocketmqBase $namesrvAddr01 $brokeraddress01
            
        else
            echo "\"namesrvAddr\"":"\"$namesrvAddr\""","
            rocketmq_status_info $rocketmqBase $namesrvAddr $brokeraddress01
        fi


        rocketmqlogpath=$(ps -feww | grep $line | grep -v grep | grep -io "rocketmq.client.logRoot=.*" | awk '{FS=" "; print $1}' | cut -d "=" -f2)
        rocketmq_broker_log $rocketmqBase $rocketmqlogpath

        #jdk安装路径
        javapath=$(ps -ef|grep $line|grep -v grep | awk '{print $8}')
        #判断是否openjdk或者oracle jdk
        if [ x$javapath = x'/usr/bin/java' ];then
            javarealpath=$(ls -lt /usr/bin/java  | awk '{print $NF}')
            javarealpath=$(ls -lt $javarealpath | awk '{print $NF}' | awk -F "/jre" '{print $1}')
            echo "\"javapath\"":"\"$javarealpath\""","

            javaversion=$($javapath -version 2>&1 |awk 'NR==1 {gsub(/"/,""); print $3}')
            echo "\"javaversion\"":"\"$javaversion\""","
            
        else 
            javarealpath=$(echo $javapath  | awk -F "/bin" '{print $1}')
            echo "\"javapath\"":"\"$javarealpath\""","
            javaversion=$($javapath -version 2>&1 |awk 'NR==1 {gsub(/"/,""); print $3}')
            echo "\"javaversion\"":"\"$javaversion\""","
        fi

        server_jvm_Xms=$(ps -feww | grep $line | grep -v grep | grep -io "\-Xms.*" | awk '{print $1}')
        server_jvm_Xmx=$(ps -feww | grep $line | grep -v grep | grep -io "\-Xmx.*" | awk '{print $1}')
        server_jvm="$server_jvm_Xms $server_jvm_Xmx"

        echo "\"server_jvm\"":"\"$server_jvm\""","
        runUser=$(ps -eo ruser,pid | grep $line | awk '{print $1}')
        echo "\"runUser\"":"\"$runUser\""","
        if [ x$runUser == x'root' ]; then
            echo "\"runUserResult\"":"\"Failed\""

        else
            echo "\"runUserResult\"":"\"Pass\""

        fi

        init=$(expr $init + 1)
        echo "}"
        [ $init -lt $rocketmq_pid_member ] && echo ","
    done
    
}

function get_os_jsondata() {

    #for file in  $data_path/tmp/tmpcheck/*_os_*.txt ;

    file="$filepath""$filename1"

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
		diskinfo=$(df -h |grep -v 'tmpfs'|grep -v 'boot' |grep -v 'overlay' |grep -v 'iso'|grep -v 'shm') && echo "\"diskinfo\"":"\"$diskinfo\"""," >>$new_document
    IO_User=$(cat $file | grep IO_User | awk -F ":" '{print $2}') && echo "\"IO_User\"":"\"$IO_User\"""," >>$new_document
    IO_System=$(cat $file | grep IO_System | awk -F ":" '{print $2}') && echo "\"IO_System\"":"\"$IO_System\"""," >>$new_document
    IO_Wait=$(cat $file | grep IO_Wait | awk -F ":" '{print $2}') && echo "\"IO_Wait\"":"\"$IO_Wait\"""," >>$new_document
    IO_Idle=$(cat $file | grep IO_Idle | awk -F ":" '{print $2}') && echo "\"IO_Idle\"":"\"$IO_Idle\"""," >>$new_document
    Tcp_Tw_Recycle=$(cat $file | grep Tcp_Tw_Recycle | awk -F ":" '{print $2}') && echo "\"Tcp_Tw_Recycle\"":"\"$Tcp_Tw_Recycle\"""," >>$new_document
    Tcp_Tw_Reuse=$(cat $file | grep Tcp_Tw_Reuse | awk -F ":" '{print $2}') && echo "\"Tcp_Tw_Reuse\"":"\"$Tcp_Tw_Reuse\"""," >>$new_document
    Tcp_Fin_Timeout=$(cat $file | grep Tcp_Fin_Timeout | awk -F ":" '{print $2}') && echo "\"Tcp_Fin_Timeout\"":"\"$Tcp_Fin_Timeout\"""," >>$new_document
    Tcp_Keepalive_Time=$(cat $file | grep Tcp_Keepalive_Time | awk -F ":" '{print $2}') && echo "\"Tcp_Keepalive_Time\"":"\"$Tcp_Keepalive_Time\"""," >>$new_document
    Tcp_Keepalive_Probes=$(cat $file | grep Tcp_Keepalive_Probes | awk -F ":" '{print $2}') && echo "\"Tcp_Keepalive_Probes\"":"\"$Tcp_Keepalive_Probes\"""," >>$new_document
    Tcp_Keepalive_Intvl=$(cat $file | grep Tcp_Keepalive_Intvl | awk -F ":" '{print $2}') && echo "\"Tcp_Keepalive_Intvl\"":"\"$Tcp_Keepalive_Intvl\"" >>$new_document

}

function get_rocketmq_jsondata() {

    echo \"rocketmqinfo\": [ >>$new_document
    rocketmq_inquiry_info >>$new_document
    echo ] >>$new_document

}

function mwcheckr_result_jsondata() {
    new_document=$new_data/rocketmq_$ipinfo.txt
    echo "{" >$new_document
    echo \"osinfo\": \{ >>$new_document
    get_os_jsondata
    echo "}," >>$new_document
    get_rocketmq_jsondata
    echo "}" >>$new_document
}

function get_rocketmq_main() {
    ####get system info
    #filename1=$HOSTNAME"_"$name"_"wls"_"os_""$ipinfo"_"$qctime".txt"
    collect_sys_info >>"$filepath""$filename1"
    #filename2=$HOSTNAME"_"$name"_"rocketmq"_"$ipinfo"_"$qctime".txt"
    qctime=$(date +'%Y%m%d%H%M%S')
    mwcheckr_result_jsondata
    #tar -czvf /tmp/enmoResult/"$HOSTNAME"_"$ipinfo"_"$qctime".tar.gz /tmp/enmoResult
    tar -czf /tmp/enmoResult/"$HOSTNAME"_"$ipinfo"_"$qctime".tar.gz --exclude=/tmp/enmoResult/*.tar.gz --format=ustar /tmp/enmoResult/*

    echo -e "___________________"
    echo -e "Collection info Finished."
    echo -e "Result File Path:" $filepath
    echo -e "\n"
    cd /tmp/enmoResult/tmpcheck
}

######################Main##########################
filepath="/tmp/enmoResult/tmpcheck/"
excmkdir=$(which mkdir | awk 'NR==1{print}')
$excmkdir -p $filepath
qctime=$(date +'%Y%m%d%H%M%S')
ipinfo=$(ip addr show | grep 'state UP' -A 2 | grep "inet " | grep -v 127.0.0. | head -1 | cut -d" " -f6 | cut -d/ -f1)





new_data=/tmp/enmoResult/rocketmq
if [ "$(ls -A $new_data)" ]; then
    echo "$new_data is not empty!!!"
    rm -rf $new_data/*
    echo "clean $new_data !!!"
else
    echo "$new_data is empty!!!"
fi
$excmkdir -p $new_data


####check /tmp/tmpcheck Is empty
tmpcheck_dir="/tmp/enmoResult/tmpcheck"
if [ "$(ls -A $tmpcheck_dir)" ]; then
    echo "$tmpcheck_dir is not empty!!!"
    rm -rf $tmpcheck_dir/*
    echo "clean $tmpcheck_dir !!!"
else
    echo "$tmpcheck_dir is empty!!!"
fi


rocketmq_namesvr_member=$(ps -ef | grep java |grep org.apache.rocketmq.namesrv.NamesrvStartup  | grep -v grep |awk -F " " '{print $2}' | wc -l)
rocketmq_pid_member=$(ps -ef | grep java | grep org.apache.rocketmq.broker.BrokerStartup | grep -v grep | awk -F " " '{print $2}' | wc -l)

filename1=$HOSTNAME"_"rocketmq"_"os_""$ipinfo"_"$qctime".txt"
filename2=$HOSTNAME"_"rocketmq"_"$ipinfo"_"$qctime".txt"

if [ $rocketmq_pid_member -eq 0 ]; then
    if [ $rocketmq_namesvr_member -eq 0 ]; then
        echo "没有rocketmq服务进程"
        exit 0
    else 
        echo "只存在namesvr服务，服务进程为" >> "$filepath""$filename2"
        ps -ef | grep java |grep org.apache.rocketmq.namesrv.NamesrvStartup  | grep -v grep >> "$filepath""$filename2"
        namesvrlogpath=$(ps -feww | grep org.apache.rocketmq.namesrv.NamesrvStartup  | grep -v grep | grep -io "rocketmq.client.logRoot=.*" | awk '{FS=" "; print $1}' | cut -d "=" -f2)
        echo "收集namesvr服务日志" >>  "$filepath""$filename2"
        tail -n 5000 $namesvrlogpath/namesrv.log >> "$filepath""$filename2"
        collect_sys_info >>"$filepath""$filename1"
            echo "" >>  "$filepath""$filename2"
        tar -czf /tmp/enmoResult/"$HOSTNAME"_"$ipinfo"_"$qctime".tar.gz --exclude=/tmp/enmoResult/*.tar.gz --format=ustar /tmp/enmoResult/*

        echo -e "___________________"
        echo -e "Collection info Finished."
        echo -e "Result File Path:" $filepath
        echo -e "\n"
        exit 0 
    fi
fi


####脚本基础数据收集
get_rocketmq_main
