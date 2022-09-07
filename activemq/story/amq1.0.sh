#!/bin/bash
#version:1.0
#monitor:activemq/os
#update: 根据需求，将整体脚本做了切割，以独立产品做数据采集
#update: 增加activemq安全基线检查
#update-date:2022-05-31

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
    echo "----->>>---->>> amq process info"
    ps -ef | grep java | grep activemq | grep -v grep

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

#----------------------------------------activemq info------------------------------------------------
function activemq_inquiry_info() {
    init=0
    activemq_pid_member=$(ps -ef | grep java | grep activemq.jar | grep -v grep | awk -F " " '{print $2}' | wc -l)
    ip=$ipinfo

    for line in $(ps -ef | grep java | grep activemq.jar | grep -v grep | awk -F " " '{print $2}'); do

        echo "{"

        activemqBase=$(ps -ef | grep $line | grep -io "activemq.base=.*" | awk '{FS=" "; print $1}' | cut -d "=" -f2)

        echo "\"activemqBase\"":"\"$activemqBase\""","
        echo "获取当前activemq的运行目录为：$activemqBase" >"$filepath""$filename2"
        echo "获取当前activemq的配置文件目录，当前获取配置的节点为$ip-$line" >>"$filepath""$filename2"
        activemqConfig=$(ps -ef | grep $line | grep activemq.jar | grep -v grep | grep -io "activemq.conf=.*" | awk '{FS=" "; print $1}' | cut -d "=" -f2)
        echo "获取当前activemq的配置文件目录为：$activemqConfig" >>"$filepath""$filename2"

        echo "获取当前activemq数据文件目录，当前获取配置的节点为$ip-$line" >>"$filepath""$filename2"
        activemqData=$(ps -ef | grep $line | grep activemq.jar | grep -v grep | grep -io "activemq.data=.*" | awk '{FS=" "; print $1}' | cut -d "=" -f2)
        echo "获取当前activemq的配置数据文件目录为：$activemqData" >>"$filepath""$filename2"

        echo "\"activemqData\"":"\"$activemqData\""","

        #echo "获取activemq安装目录，当前获取配置节点为$ip-$line"
        activemqHome=$(ps -ef | grep $line | grep -io "activemq.home=.*" | awk '{FS=" "; print $1}' | cut -d "=" -f2)

        echo "获取activemq当前运行broker的配置文件,当前获取配置节点为$ip-$line" >>"$filepath""$filename2"
        echo "\"activemqHome\"":"\"$activemqHome\""","

        cusactivemqbrokerConfig=$(ps -ef | grep $line | grep -v grep  | grep xbean | wc -l)
        if [ x$cusactivemqbrokerConfig == x0 ]; then
            echo "采用默认的配置文件activemq.xml文件" >>"$filepath""$filename2"
            echo "当前activemq的broker配置文件内容如下：" >>"$filepath""$filename2"
            cat $activemqConfig/activemq.xml >>"$filepath""$filename2"
            cp $activemqConfig/activemq.xml $filepath/activemq.xml

            sed -i 's/<!--/\n<!--\n/' $filepath/activemq.xml
            sed -i 's/-->/\n-->\n/' $filepath/activemq.xml
            sed -i '/<!--/,/-->/ d' $filepath/activemq.xml
            sed -i '/-->/ d' $filepath/activemq.xml
            sed -i '/^\s*$/d' $filepath/activemq.xml
            amqconfiginfo=$(sed 's/\"//g' $filepath/activemq.xml)
            echo "\"activemqConfigfile\"":"\"$activemqConfig/activemq.xml\""","
            echo "\"amqconfiginfo\"":"\"$amqconfiginfo\""","
            echo "" >>"$filepath""$filename2"

            #启用消息后台认证访问控制
            simpleAuthenticationPlugincount=$(grep 'simpleAuthenticationPlugin' $activemqConfig/activemq.xml | wc -l)
            jaasAuthenticationPlugincount=$(grep 'jaasAuthenticationPlugincount' $activemqConfig/activemq.xml | wc -l)
            if [[ $simpleAuthenticationPlugincount -gt 0 || $jaasAuthenticationPlugincount -gt 0 ]]; then
                echo "\"securityplugin\"":"\"启用消息后台认证访问控制\""","
                echo "\"securitypluginresult\"":"\"PASS\""","
            else
                echo "\"securityplugin\"":"\"未启用消息后台认证访问控制\""","
                echo "\"securitypluginresult\"":"\"Failed\""","
            fi

        else

            echo "自定义配置文件" >>"$filepath""$filename2"
            configfile=$(ps -ef | grep $line  |grep -v grep  | awk -F ':' '{print $NF}' | awk -F '/' '{print $NF}' ) >>"$filepath""$filename2"
            echo "当前activemq的broker配置文件内容如下：" >>"$filepath""$filename2"
            activemqconfigfilepath=$(find $activemqConfig -name $configfile -type f -print | grep $configfile)

            cat $activemqconfigfilepath >>"$filepath""$filename2"

            cp $activemqconfigfilepath $filepath/$configfile
            sed -i 's/<!--/\n<!--\n/' $filepath/$configfile
            sed -i 's/-->/\n-->\n/' $filepath/$configfile
            sed -i '/<!--/,/-->/ d' $filepath/$configfile
            sed -i '/-->/ d' $filepath/$configfile
            sed -i '/^\s*$/d' $filepath/$configfile
            amqconfiginfo=$(sed 's/\"//g' $filepath/$configfile)
            echo "\"activemqConfigfile\"":"\"$activemqconfigfilepath\""","
            echo "\"amqconfiginfo\"":"\"$amqconfiginfo\""","
            echo "" >>"$filepath""$filename2"

            #启用消息后台认证访问控制
            simpleAuthenticationPlugincount=$(grep 'simpleAuthenticationPlugin' $activemqConfig/$configfile | wc -l)
            jaasAuthenticationPlugincount=$(grep 'jaasAuthenticationPlugincount' $activemqConfig/$configfile | wc -l)
            if [[ $simpleAuthenticationPlugincount -gt 0 || $jaasAuthenticationPlugincount -gt 0 ]]; then
                echo "\"securityplugin\"":"\"启用消息后台认证访问控制\""","
                echo "\"securitypluginresult\"":"\"PASS\""","
            else
                echo "\"securityplugin\"":"\"未启用消息后台认证访问控制\""","
                echo "\"securitypluginresult\"":"\"Failed\""","
            fi

        fi

        cd $activemqData
        echo "开始进行日志查询操作，当前查询节点为$ip-$line" >>"$filepath""$filename2" >>"$filepath""$filename2"
        for check_activemq_log in $(ls -lrt | grep activemq.log* | awk -F " " '{print $NF}'); do
            echo "开始检查$check_activemq_log 日志" >>"$filepath""$filename2"
            echo "查看activemq日志信息" >>"$filepath""$filename2"

            #filesize=$(ls -ltr $check_activemq_log | awk '{print $5}')
            #if [ $filesize > 52428800 ];then
            tail -n 5000 $check_activemq_log >>  "$filepath""$filename2"

            #less -mN $check_activemq_log | grep "WARN" >>"$filepath""$filename2"
            #echo "" >>"$filepath""$filename2"
            #echo "查看error日志信息" >>"$filepath""$filename2"
            #less -mN $check_activemq_log | grep "ERROR" >>"$filepath""$filename2"
            echo "END！！！" >>"$filepath""$filename2"
        done

        if [ x$activemqHome == x$activemqBase ]; then
            amqexec=activemq

            echo "" >>"$filepath""$filename2"
            echo "查看当前activemq的版本" >>"$filepath""$filename2"
            amqversion=$($activemqBase/bin/$amqexec --version | tail -3 | head -1)
            echo "amqversion=$amqversion" >>"$filepath""$filename2"

            echo "\"amqversion\"":"\"$amqversion\""","

            echo "" >>"$filepath""$filename2"
            echo "获取当前activemq的broker名字" >>"$filepath""$filename2"
            #$activemqBase/bin/$amqexec list |grep brokerName    >> "$filepath""$filename2"
            #echo ""  >> "$filepath""$filename2"
            brokerName=$($activemqBase/bin/$amqexec list | grep brokerName | awk -F '=' '{print $2}')
            echo "brokerName=$brokerName" >>"$filepath""$filename2"
            echo "\"brokerName\"":"\"$brokerName\""","

            echo "" >>"$filepath""$filename2"
            echo "获取当前activemq的broker的statistics信息，当前获取配置的节点为$ip-$line" >>"$filepath""$filename2"
            $activemqBase/bin/$amqexec bstat $brokerName | awk 'n==1{print} $0~/Connecting/{n=1}' >>"$filepath""$filename2"
            echo "" >>"$filepath""$filename2"
            echo "" >>"$filepath""$filename2"
            echo "获取当前broker中组件属性和统计信息,当前获取配置的节点为$ip-$line" >>"$filepath""$filename2"
            $activemqBase/bin/$amqexec query | awk 'n==1{print} $0~/Connecting/{n=1}' >>"$filepath""$filename2"
            echo "" >>"$filepath""$filename2"
            echo "" >>"$filepath""$filename2"
            echo "获取当前activemq的queues的统计信息" >>"$filepath""$filename2"

            queuestatus=$($activemqBase/bin/$amqexec dstat queues | awk 'n==1{print} $0~/Connecting/{n=1}')
            echo "队列统计信息：$queuestatus" >>"$filepath""$filename2"
            echo "\"queuestatus\"":"\"$queuestatus\""","

            #$activemqBase/bin/$amqexec dstat queues| awk 'n==1{print} $0~/Connecting/{n=1}' >> "$filepath""$filename2"
            echo "获取当前activemq的topics的统计信息" >>"$filepath""$filename2"
            topicstatus=$($activemqBase/bin/$amqexec dstat topics | awk 'n==1{print} $0~/Connecting/{n=1}')
            echo "主题统计信息：$topicstatus" >>"$filepath""$filename2"
            echo "\"topicstatus\"":"\"$topicstatus\""","
            #$activemqBase/bin/$amqexec dstat topics| awk 'n==1{print} $0~/Connecting/{n=1}'  >> "$filepath""$filename2"
            echo "" >>"$filepath""$filename2"

        else

            amqexec=${activemqBase##*/}

            echo "" >>"$filepath""$filename2"
            echo "查看当前activemq的版本" >>"$filepath""$filename2"
            amqversion=$($activemqBase/bin/$amqexec --version | tail -3 | head -1)
            echo "amqversion=$amqversion" >>"$filepath""$filename2"

            echo "\"amqversion\"":"\"$amqversion\""","

            echo "" >>"$filepath""$filename2"
            echo "获取当前activemq的broker名字" >>"$filepath""$filename2"
            #$activemqBase/bin/$amqexec list |grep brokerName    >> "$filepath""$filename2"
            #echo ""  >> "$filepath""$filename2"
            brokerName=$($activemqBase/bin/$amqexec list | grep brokerName | awk -F '=' '{print $2}')
            echo "brokerName=$brokerName" >>"$filepath""$filename2"
            echo "\"brokerName\"":"\"$brokerName\""","
            echo "" >>"$filepath""$filename2"
            echo "获取当前activemq的broker的statistics信息，当前获取配置的节点为$ip-$line" >>"$filepath""$filename2"
            $activemqBase/bin/$amqexec bstat $brokerName | awk 'n==1{print} $0~/Connecting/{n=1}' >>"$filepath""$filename2"
            echo "" >>"$filepath""$filename2"
            echo "" >>"$filepath""$filename2"
            echo "获取当前broker中组件属性和统计信息,当前获取配置的节点为$ip-$line" >>"$filepath""$filename2"
            $activemqBase/bin/$amqexec query | awk 'n==1{print} $0~/Connecting/{n=1}' >>"$filepath""$filename2"
            echo "" >>"$filepath""$filename2"
            echo "" >>"$filepath""$filename2"
            #echo "获取当前activemq的queues的统计信息"  >> "$filepath""$filename2"
            #$activemqBase/bin/$amqexec dstat queues| awk 'n==1{print} $0~/Connecting/{n=1}'  >> "$filepath""$filename2"
            #echo "获取当前activemq的topics的统计信息"  >> "$filepath""$filename2"
            #$activemqBase/bin/$amqexec dstat topics| awk 'n==1{print} $0~/Connecting/{n=1}'  >> "$filepath""$filename2"
            #echo ""  >> "$filepath""$filename2"
            echo "获取当前activemq的queues的统计信息" >>"$filepath""$filename2"

            queuestatus=$($activemqBase/bin/$amqexec dstat queues | awk 'n==1{print} $0~/Connecting/{n=1}')
            echo "队列统计信息：$queuestatus" >>"$filepath""$filename2"
            echo "\"queuestatus\"":"\"$queuestatus\""","

            #$activemqBase/bin/$amqexec dstat queues| awk 'n==1{print} $0~/Connecting/{n=1}' >> "$filepath""$filename2"
            echo "获取当前activemq的topics的统计信息" >>"$filepath""$filename2"
            topicstatus=$($activemqBase/bin/$amqexec dstat topics | awk 'n==1{print} $0~/Connecting/{n=1}')
            echo "主题统计信息：$topicstatus" >>"$filepath""$filename2"
            echo "\"topicstatus\"":"\"$topicstatus\""","
            #$activemqBase/bin/$amqexec dstat topics| awk 'n==1{print} $0~/Connecting/{n=1}'  >> "$filepath""$filename2"
            echo "" >>"$filepath""$filename2"

        fi

        #增加activemq安全基线检查,fileserver漏洞检测
        fileserverbugcount=$(grep '/fileserver' $activemqConfig/jetty.xml | wc -l)
        if [ $fileserverbugcount -eq 0 ]; then
            echo "\"fileserverbug\"":"\"不存在fileserver漏洞\""","
            echo "\"fileserverbugResult\"":"\"Pass\""","
        else
            echo "\"fileserverbug\"":"\"存在fileserver漏洞\""","
            echo "\"fileserverbugResult\"":"\"Failed\""","
        fi

        #默认账号密码身份鉴别,activemq存在默认的admin账号，且默认口令为admin。
        cat $activemqConfig/jetty-realm.properties | grep -v '#' | grep -v '^$' | grep -w 'admin' | while read line; do
            username=$(echo $line | awk -F "," '{print $1}' | awk -F ":" '{print $1}')
            password=$(echo $line | awk -F "," '{print $1}' | awk -F ":" '{print $2}' | sed 's/^[ \t]*//g')

            if [ x$username == x'admin' ]; then
                if [ x$password == x'admin' ]; then
                    echo "\"securityauth\"":"\"activemq存在默认的admin账号，且默认口令为admin\""","
                    echo  "\"securityauthresult\"":"\"Failed\""","
                else
                    echo "\"securityauth\"":"\"activemq存在默认的admin账号，且默认口令为$password\""","
                    echo  "\"securityauthresult\"":"\"Pass\""","
                fi
            fi
        done

        server_jvm_Xms=$(ps -feww | grep $line | grep -v grep | grep -io "\-Xms.*" | awk '{print $1}')
        server_jvm_Xmx=$(ps -feww | grep $line | grep -v grep | grep -io "\-Xmx.*" | awk '{print $1}')
        server_jvm_permsize=$(ps -feww | grep $line | grep -v grep | grep -io "\-XX:PermSize=.*" | awk '{print $1}')
        server_jvm_MAXpermsize=$(ps -feww | grep $line | grep -v grep | grep -io "\-XX:MaxPermSize=.*" | awk '{print $1}')
        server_jvm="$server_jvm_Xms $server_jvm_Xmx $server_jvm_permsize $server_jvm_MAXpermsize"


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
        [ $init -lt $activemq_pid_member ] && echo ","

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

function get_amq_jsondata() {

    echo \"amqinfo\": [ >>$new_document
    activemq_inquiry_info >>$new_document
    echo ] >>$new_document

}

function mwcheckr_result_jsondata() {
    new_document=$new_data/amq_$ipinfo.txt
    echo "{" >$new_document
    echo \"osinfo\": \{ >>$new_document
    get_os_jsondata
    echo "}," >>$new_document
    get_amq_jsondata
    echo "}" >>$new_document
}

function get_activemq_main() {

    ####check /tmp/tmpcheck Is empty
    tmpcheck_dir="/tmp/enmoResult/tmpcheck"
    if [ "$(ls -A $tmpcheck_dir)" ]; then
        echo "$tmpcheck_dir is not empty!!!"
        rm -rf $tmpcheck_dir/*
        echo "clean $tmpcheck_dir !!!"
    else
        echo "$tmpcheck_dir is empty!!!"
    fi

    ####get system info
    #filename1=$HOSTNAME"_"$name"_"wls"_"os_""$ipinfo"_"$qctime".txt"
    collect_sys_info >>"$filepath""$filename1"
    #filename2=$HOSTNAME"_"$name"_"amq"_"$ipinfo"_"$qctime".txt"
    qctime=$(date +'%Y%m%d%H%M%S')
    #activemq_inquiry_info >> "$filepath""$filename2"
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

activemq_pid_member=$(ps -ef | grep java | grep activemq.jar | grep -v grep | awk -F " " '{print $2}' | wc -l)
if [ $activemq_pid_member -eq 0 ]; then
    echo "没有activemq进程"
    exit 0
fi


new_data=/tmp/enmoResult/amq
if [ "$(ls -A $new_data)" ]; then
    echo "$new_data is not empty!!!"
    rm -rf $new_data/*
    echo "clean $new_data !!!"
else
    echo "$new_data is empty!!!"
fi
$excmkdir -p $new_data

####脚本基础数据收集
filename1=$HOSTNAME"_"amq"_"os_""$ipinfo"_"$qctime".txt"
filename2=$HOSTNAME"_"amq"_"$ipinfo"_"$qctime".txt"
get_activemq_main
