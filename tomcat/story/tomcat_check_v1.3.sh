#!/bin/bash
#version:v1.3
#update time 2022-11-01
#tomcat巡检数据直接生成json文件
#巡检报告实现每个进程生成单独的表格

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
    disknum=$(df -hlT|grep -v tmpfs|grep -v boot| grep -v overlay | wc -l)
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
    echo "----->>>---->>>  io scheduler"
    dmesg | grep -i scheduler
    echo ""
    echo "----->>>---->>>  disk mount "
    df -h

}

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

#----------------------------------------Tomcat info------------------------------------------------
# 检查服务器是否存在Tomcat进程
echo "############################################################"
tomcat_pid_member=`ps -eo ruser,pid,args|grep java|grep -v grep|grep "org.apache.catalina.startup.Bootstrap start"|awk '{ print $2}'|wc -l`
if [ ${tomcat_pid_member} == 0 ];then
    echo "There is no Tomcat process on the server!"
    exit 0
else
    echo "The Tomcat process is running on the server,Start Check!"
fi

function tomcat_info(){
    # Get Tomcat PID Info
    PID=`ps -eo ruser,pid,args|grep java|grep -v grep|grep "org.apache.catalina.startup.Bootstrap start"|awk '{ print $2}'`
    echo "###############Get All Tomcat Process Info##################" 
    ps -ef |grep java|grep -v grep|grep "org.apache.catalina.startup.Bootstrap start"
    for OPID in $PID; do
        echo "##########Get Process $OPID Tomcat Install Info#########" 
        tomcat_path=`ps -ef|grep $OPID|grep 'org.apache.catalina.startup.Bootstrap'|grep -v grep|awk -F '-Dcatalina.home=' '{print $2}'|awk '{print $1}'`
        sh $tomcat_path/bin/version.sh

        echo "###############Process $OPID Tomcat Process Info###############"
        ps -ef|grep $OPID|grep -v grep

        echo "#############View Process $OPID Tomcat ResourceUsage###########"
        top -bn1 -p $OPID

        echo "#############View Process $OPID Tomcat Use Ports###############" 
        netstat -nutlp|grep $OPID

        echo "#########View Process $OPID Tomcat catalina.sh Info#########"
        cat $tomcat_path/bin/catalina.sh
        echo "#########View Process $OPID Tomcat startup.sh Info##########"
        cat $tomcat_path/bin/startup.sh
        echo "#########View Process $OPID Tomcat server.xml Info##########"
        cat $tomcat_path/conf/server.xml
        echo "#########View Process $OPID Tomcat context.xml Info#########"
        cat $tomcat_path/conf/context.xml

        echo "#############View Process $OPID Tomcat Log Info##############"
        out_num=`grep "CATALINA_OUT=" $tomcat_path/bin/catalina.sh|grep -v '#'|wc -l`
        if [ $out_num -eq 1 ]; then
            outstr="\"\$CATALINA_BASE\"/logs/catalina.out"
            outconfig=`grep "CATALINA_OUT=" $tomcat_path/bin/catalina.sh|grep -v '#'|awk -F '=' '{print $2}'`
            if [ $outconfig = $outstr ]; then
                out_log=$tomcat_path/logs/catalina.out
            else
                out_log=`grep "CATALINA_OUT="  $tomcat_path/bin/catalina.sh|grep -v '#'|awk -F '=' '{print $2}'|tr -d "\""`
            fi
        elif [ $out_num -gt 1 ]; then
            outstr="\"\$CATALINA_BASE\"\/logs\/catalina.out"
            out_log=`grep "CATALINA_OUT="  $tomcat_path/bin/catalina.sh|grep -v '#'|awk -F '=' '{print $2}'|sed "/$outstr/d"|tr -d "\""`
        else
            if [ -s $tomcat_path/logs/catalina.out ]; then
                out_log=$tomcat_path/logs/catalina.out
            else
                out_log="notfind"
            fi
        fi
        echo "Process $OPID Tomcat LogDir:"$out_log
        tail -n 5000 $out_log
    done

}

# get os json data
function get_os_jsondata(){

    file="$filepath$filename1"
    IP_Address=`cat $file |grep IP:|awk -F ":" '{print $2}'`&& echo "\"IP_Address\"":"\"$IP_Address\"""," >> $new_document
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
    diskinfo=$(df -h |grep -v 'tmpfs'|grep -v 'boot' |grep -v 'overlay' |grep -v 'iso'|grep -v 'shm') && echo "\"diskinfo\"":"\"$diskinfo\"""," >>$new_document
    IO_User=`cat $file|grep IO_User|awk -F ":" '{print $2}'`&& echo "\"IO_User\"":"\"$IO_User\"""," >> $new_document
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

# get tomcat json data
function get_tomcat_jsondata(){
    
    init=0
    PIDS=`ps -eo ruser,pid,args|grep java|grep -v grep|grep "org.apache.catalina.startup.Bootstrap start"|awk '{ print $2}'`
    for OPID in $PIDS; do
        
        echo "{"
        # 获取tomcat目录
        tomcat_path=`ps -ef|grep $OPID|grep 'org.apache.catalina.startup.Bootstrap'|grep -v grep|awk -F '-Dcatalina.home=' '{print $2}'|awk '{print $1}'`
        
        echo "\"tomcat_home\"":"\"$tomcat_path\""","
        
        # 获取tomcat使用的JDK目录及版本
        java_path=`ls -l /proc/$OPID/exe 2>/dev/null|awk '{print $NF}'`
        if [ "$java_path" = "/proc/$OPID/exe" ];then
            java_path=`ps -ef|grep $OPID|grep 'org.apache.catalina.startup.Bootstrap'|grep -v grep |awk '{print $8}'`
        fi
        if [[ "$java_path" =~ "/jre" ]];then
            jdk_path=`echo $java_path|awk -F "/jre" '{print $1}'`
        else
            jdk_path=`echo $java_path|awk -F "/bin" '{print $1}'`
        fi

        jdk_version=`$java_path -version 2>&1|grep version|awk '{print $NF}'|tr -d '"'`
        
        echo "\"jdk_path\"":"\"$jdk_path\""","
        echo "\"jdk_version\"":"\"$jdk_version\""","

        #获取tomcat版本信息
        if [ -n "$java_path" ]; then
          tomcatbb=$($java_path -classpath "$tomcat_path/lib/catalina.jar" org.apache.catalina.util.ServerInfo | awk -F':' '/number/{print $2}'|tr -d " ")
        fi
    
        echo "\"tomcat_version\"":"\"$tomcatbb\""","
        
        # 获取tomcat启动用户
        run_user=`ps -ef|grep $OPID|grep -v grep|awk '{print $1}'`
        echo "\"tomcat_user\"":"\"$run_user\""","

        # 获取JVM内存参数
        jvm_xms=$(ps -feww|grep $OPID|grep -v grep|grep -o "\-Xms.*"|awk '{print $1}')
        jvm_xmx=$(ps -feww|grep $OPID|grep -v grep|grep -o "\-Xmx.*"|awk '{print $1}')
        jvm_xmn=$(ps -feww|grep $OPID|grep -v grep|grep -o "\-Xmn.*"|awk '{print $1}')
        jvm_permsize=$(ps -feww|grep $OPID|grep -v grep|grep -o "\-XX:PermSize=.*"|awk '{print $1}')
        jvm_maxpermsize=$(ps -feww|grep $OPID|grep -v grep|grep -o "\-XX:MaxPermSize=.*"|awk '{print $1}')
        jvm_metasize=$(ps -feww|grep $OPID|grep -v grep|grep -o "\-XX:MetaspaceSize=.*"|awk '{print $1}')
        jvm_maxmetasize=$(ps -feww|grep $OPID|grep -v grep|grep -o "\-XX:MaxMetaspaceSize=.*"|awk '{print $1}')
        jvm_memory="$jvm_xms $jvm_xmx $jvm_xmn $jvm_permsize $jvm_maxpermsize $jvm_metasize $jvm_maxmetasize"
        jvm_mem=`echo "$jvm_memory"|tr -d ' '`
        if [ -z "$jvm_mem" ];then
            jvm_memory="-Xms256m -Xmx512m"
        fi

        echo "\"jvm_memory\"":\"$jvm_memory\"","
        
        # 定义tomcat配置文件
        serverxml=$tomcat_path/conf/server.xml
        contextxml=$tomcat_path/conf/context.xml
        webxml=$tomcat_path/conf/web.xml
        userxml=$tomcat_path/conf/tomcat-users.xml
        # 去除配置文件中的注释内容
        sed 's/<!--.*-->//g' $serverxml|sed -n '/<!--/,/-->/!p' > /tmp/enmoResult/tmpcheck/temp.xml
        tempxml=/tmp/enmoResult/tmpcheck/temp.xml
        sed 's/<!--.*-->//g' $contextxml|sed -n '/<!--/,/-->/!p' >> $tempxml
        
        # 获取tomcat端口信息
        shutdown_port=`cat $tempxml|grep "Server port="|awk -F "=" '{print $2}'|awk '{print $1}'|tr -d '"'`
        httpport=`cat $tempxml|grep -v AJP|grep -A5 "<Connector"|grep "port="|grep -v 8009|grep -v 8443|awk -F "port=" '{print $2}'|awk '{print $1}'|tr -d '"'`
        if [ -z "$httpport" ];then
            httpport=`cat $tempxml|grep -v AJP|grep -A10 "<Connector"|grep "port="|grep -v 8009|grep -v 8443|awk -F "port=" '{print $2}'|awk '{print $1}'|tr -d '"'`
        fi

        echo "\"http_port\"":"\"$httpport\""","
        echo "\"shutdown_port\"":"\"$shutdown_port\""","

        # 获取tomcat线程池信息
        min_threads=`cat $tempxml|grep minSpareThreads|awk -F "minSpareThreads=" '{print $2}'|awk '{print $1}'|tr -d '"'`
        if [ -z "$min_threads" ];then
            min_threads=10
        fi
        
        max_threads=`cat $tempxml|grep maxThreads|awk -F "maxThreads=" '{print $2}'|awk '{print $1}'|tr -d '"'`
        if [ -z "$max_threads" ];then
            max_threads=200
        fi
        
        accept_count=`cat $tempxml|grep acceptCount|awk -F "acceptCount=" '{print $2}'|awk '{print $1}'|tr -d '"'`
        if [ -z "$accept_count" ];then
            accept_count=100
        fi
        
        tomcat_threads="minSpareThreads=$min_threads maxThreads=$max_threads acceptCount=$accept_count"
        echo "\"tomcat_threads\"":"\"$tomcat_threads\""","
        
        
        # 获取tomcat数据源信息
        row_num=`cat -n $tempxml|grep -v "UserDatabase"|grep "<Resource"|awk '{print $1}'`
        if [ -z "$row_num" ];then
            echo "\"tomcat_jdbc\"":"\"Null-未配置数据源\""","
        else
            jdbc_array=()
            j=0
            for i in $row_num; do
                a=0
                while :
                do
                    b=`expr $i + $a`
                    row_data=`sed -n ${b}p $tempxml`
                    if [[ $row_data =~ "/>" ]];then
                        jdbcinfo=`sed -n ''${i}','${b}'p' $tempxml|sed '/password/Id'|sed '/username/Id'`
                        break
                    else
                        let a+=1
                    fi
                done
                jdbc_array[$j]=`echo $jdbcinfo|sed 's/^[ \t]*//g'|sed 's/\"//g'`
                let j+=1
            done
            echo -e "\"tomcat_jdbc\"":"\n\"${jdbc_array[*]}\""","
        fi
        
        # 获取tomcat应用信息
        appbase=`cat $tempxml|grep appBase|awk -F "appBase=" '{print $2}'|awk '{print $1}'|tr -d '"'`
        if [[ $appbase =~ ^/.* ]];then
            if [ -e "$appbase" ];then
                app_name=`ls -l $appbase |awk '/^d/ {print $NF}'`
            else
                app_name="app not found"
            fi
        else
            if [ -e "$tomcat_path/$appbase" ];then
                app_name=`ls -l $tomcat_path/$appbase|awk '/^d/ {print $NF}'`
            else
                app_name="app not found"
            fi
        fi
        echo "\"tomcat_app\"":"\"$app_name\""","
        
        #tomcat资源占用
        resource_use=`top -bn1 -p $OPID|grep -B1 $OPID`
        echo "\"resource_use\"":"\"$resource_use\""","
        
        # 安全基线检查
        # 版本安全检查
        if [ -n "$tomcatbb" ];then
            echo "\"version_check\"":"\"$tomcatbb\""","
            tomcatbb_num=$(echo $tomcatbb|awk '{print substr($1,1,3)}')
            ver_num=$(echo $tomcatbb|awk '{print substr($1,1,1)}')
            num_a=`echo "$tomcatbb_num >= 8.5"|bc`
            num_b=`echo "$tomcatbb_num <= 10"|bc`
            num_c=`echo "$tomcatbb_num >= 5.0"|bc`
            num_d=`echo "$tomcatbb_num <= 8.0"|bc`
            # 判断版本在8.5到10之间为通过
            if [[ $num_a -eq 1 && $num_b -eq 1 ]];then
                echo "\"version_check_con\"":"\"Pass\""","
            # 判断版本在5到8.0之间为不通过
            elif [[ $num_c -eq 1 && $num_d -eq 1 ]];then
                echo "\"version_check_con\"":"\"Failed\""","
            # 判断版本在5以下视为设置了版本隐藏，为通过
            elif [[ $ver_num -lt 5 ]];then
                echo "\"version_check_con\"":"\"Pass\""","
            fi
        else
            echo "Process $OPID Tomcat Version Check Result:Version Hide"
            echo "Process $OPID Tomcat Version Check Conclusion:Pass"
        fi

        # 进程启动用户检查
        echo "\"runuser_check\"":"\"$run_user\""","
        if [[ $run_user = "root" ]];then
            echo "\"runuser_check_con\"":"\"Failed\""","
        else
            echo "\"runuser_check_con\"":"\"Pass\""","
        fi
        
        # 自带应用检查
        echo "\"apps_check\"":"\"$app_name\""","

        if [[ $app_name =~ "docs" || $app_name =~ "examples" || $app_name =~ "host-manager" ||$app_name =~ "manager" ]];then
            echo "\"apps_check_con\"":"\"Failed\""","
        else
            echo "\"apps_check_con\"":"\"Pass\""","
        fi
        
        # AJP端口检查
        ajp_check=`cat $tempxml|grep "<Connector"|grep "AJP"|xargs`
        if [[ -n $ajp_check ]];then
            echo "\"ajp_check\"":"\"$ajp_check\""","
            echo "\"ajp_check_con\"":"\"Failed\""","
        else
            echo "\"ajp_check\"":"\"No AJP\""","
            echo "\"ajp_check_con\"":"\"Pass\""","
        fi
        
        # AccessLog完备性检查
        log_check=`cat $tempxml|grep "pattern="|xargs`
        if [[ -n $log_check ]];then
            echo "\"accesslog_check\"":"\"$log_check\""","
            log_check1=`cat $tempxml|grep "User-Agent"`
            log_check2=`cat $tempxml|grep "Referer"`
            if [[ -z $log_check1 || -z $log_check2 ]];then
                echo "\"accesslog_check_con\"":"\"Failed\""","
            else
                echo "\"accesslog_check_con\"":"\"Pass\""","
            fi
        else
            echo "\"accesslog_check\"":"\"Null-未配置access日志\""","
            echo "\"accesslog_check_con\"":"\"Failed\""","
        fi

        # 用户锁定检查
        if [ -e $userxml ];then
            user_check=`sed 's/<!--.*-->//g' $userxml|sed -n '/<!--/,/-->/!p'|grep "username="|xargs`
            if [[ -n $user_check ]];then
                echo "\"userxml_check\"":"\"$user_check\""","
                echo "\"userxml_check_con\"":"\"Failed\""","
            else
                echo "\"userxml_check\"":"\"Null-未使用控制台用户\""","
                echo "\"userxml_check_con\"":"\"Pass\""","
            fi
        else
            echo "\"userxml_check\"":"\"Null-未使用控制台用户\""","
            echo "\"userxml_check_con\"":"\"Pass\""","
        fi

        # 禁止目录浏览检查
        list_check=`cat $webxml|grep -A1 ">listings<"|grep -v ">listings<"|awk -F ">" '{print $2}'|awk -F "<" '{print $1}'`
        if [[ -n $list_check ]];then
            echo "\"list_check\"":"\"$list_check\""","
            if [[ $list_check = "false" ]];then
                echo "\"list_check_con\"":"\"Pass\""","
            else
                echo "\"list_check_con\"":"\"Failed\""","
            fi
        else
            echo "\"list_check\"":"\"false\""","
            echo "\"list_check_con\"":"\"Pass\""","
        fi
        
        # 文件上传漏洞防御检查
        put_check=`cat $webxml|grep -A1 ">readonly<"|grep -v ">readonly<"|awk -F ">" '{print $2}'|awk -F "<" '{print $1}'`
        if [[ -n $put_check ]];then
            echo "\"fileput_check\"":"\"$put_check\""","
            if [[ $put_check = "false" ]];then
                echo "\"fileput_check_con\"":"\"Pass\""","
            else
                echo "\"fileput_check_con\"":"\"Failed\""","
            fi
        else
            echo "\"fileput_check\"":"\"true\""","
            echo "\"fileput_check_con\"":"\"Failed\""","
        fi
        
        # DDOS防御
        ddos_check=`cat $tempxml|grep connectionTimeout|xargs|awk -F " " '{for(i=1;i<=NF;i++){print $i}}'|awk '/connectionTimeout=/'`
        if [[ -n $ddos_check ]];then
            echo "\"timeout_check\"":"\"$ddos_check\""","
            outnum=`echo $ddos_check|awk -F "=" '{print $2}'`
            if [[ $outnum -ge 20000 ]];then
                echo "\"timeout_check_con\"":"\"Pass\""
            else
                echo "\"timeout_check_con\"":"\"Failed\""
            fi
        else
            echo "\"timeout_check\"":"\"connectionTimeout=20000\""","
            echo "\"timeout_check_con\"":"\"Failed\""
        fi
        
        # 删除临时生成文件
        rm -f $tempxml
        
        let init+=1
        echo "}"
        if [ $init -lt $tomcat_pid_member ];then
            echo ","
        fi

    done

}

function get_jsondata(){

    new_document=$new_data/tomcat_$ipinfo.json
    echo "{" > $new_document
    
    echo "\"os_info\": {" >> $new_document
    get_os_jsondata
    echo "}," >>$new_document
    
    echo "\"tomcat_info\": [" >> $new_document
    get_tomcat_jsondata >> $new_document
    echo "]" >> $new_document
    
    echo "}" >> $new_document
}

function get_tomcat_main(){
####check /tmp/tmpcheck Is empty
tmpcheck_dir="/tmp/enmoResult/tmpcheck/"
echo ""
if [ "$(ls -A $tmpcheck_dir)" ];then
    echo "$tmpcheck_dir is not empty!!!"
    rm -rf $tmpcheck_dir/*
    echo "clean $tmpcheck_dir !!!"
else    
    echo "$tmpcheck_dir is empty!!!"
fi
echo ""
if [ "$(ls -A $new_data)" ];then  
    echo "$new_data is not empty!!!"
    rm -rf $new_data/*
    echo "clean $new_data !!!"
else    
    echo "$new_data is empty!!!"
fi

####get system info
collect_sys_info >> "$filepath""$filename1"

####get tomcat info
tomcat_info >> "$filepath""$filename2"

###get json data
get_jsondata

tar -zcf /tmp/enmoResult/"$HOSTNAME"_"tomcat"_"$ipinfo"_"$qctime".tar.gz --exclude=/tmp/enmoResult/*.tar.gz /tmp/enmoResult/*  --format=ustar

echo -e "___________________"
echo -e "Collection info Finished."
echo -e "Result File Path:" $filepath
echo -e "\n"

}

######################Main##########################
filepath="/tmp/enmoResult/tmpcheck/"
excmkdir=$(which mkdir | awk 'NR==1{print}'  )
$excmkdir -p $filepath
new_data="/tmp/enmoResult/tomcat"
$excmkdir -p $new_data
qctime=$(date +'%Y%m%d%H%M%S')
ipinfo=`ip addr show |grep 'state UP' -A 2| grep "inet " |grep -v 127.0.0. |head -1|cut -d" " -f6|cut -d/ -f1`
filename1=$HOSTNAME"_"tomcat"_"os_""$ipinfo"_"$qctime".txt"
filename2=$HOSTNAME"_"tomcat"_"$ipinfo"_"$qctime".txt"

echo "############################################################"
echo "Start performing Tomcat patrols！！！"
get_tomcat_main
