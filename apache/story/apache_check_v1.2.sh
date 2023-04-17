#!/bin/bash
#version:v1.2
#time20230414
#each process data use alone table

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
        IO_User=$(iostat -x -k 2 1 | grep -1 avg | grep -v avg | grep -v ^$ | awk -F ' ' 'NR==1{print $1}')
        IO_System=$(iostat -x -k 2 1 | grep -1 avg | grep -v avg | grep -v ^$ | awk -F ' ' 'NR==1{print $4}')
        IO_Wait=$(iostat -x -k 2 1 | grep -1 avg | grep -v avg | grep -v ^$ | awk -F ' ' 'NR==1{print $4}')
        IO_Idle=$(iostat -x -k 2 1 | grep -1 avg | grep -v avg | grep -v ^$ | awk -F ' ' 'NR==1{print $NF}')
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
    #echo "----->>>---->>>  CPU usage"
    #sar 2 5
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
function convert_unit()
{
    result=$1
    if [ $result -ge  1048576 ]
    then
        value=1048576 #1024*1024    
        result_gb=$(awk 'BEGIN{printf"%.2f\n",'$result' / '$value'}') #将KB转换成GB，并保留2位小数
        echo $result_gb"GB"
    elif [ $result -ge  1024 ]
    then
        value=1024     
        result_mb=$(awk 'BEGIN{printf"%.2f\n",'$result' / '$value'}') #将KB转换成MB，并保留2位小数
        echo $result_mb"MB"
    else
        echo $result"KB"
    fi
}

# 检查服务器是否存在Apache进程
apache_pid_member=`ps -ef|grep httpd|grep -v grep|grep -v '.sh'|awk '$3==1{print $2}'|wc -l`
echo "############################################################"
if [ "$apache_pid_member" == 0 ];then
    echo "There is no Apache process on the server!"
    exit 0
else
    echo "The Apache process is running on the server,Start Check!"
    user_count=`ps -ef|grep httpd|grep -v grep|grep -v '.sh'|awk '$3==1{print $1}'|uniq|wc -l`
    run_user=`ps -ef|grep httpd|grep -v grep|grep -v '.sh'|awk '$3==1{print $1}'|uniq`
    if [ "$user_count" -gt "1" ];then
        if [ "$(whoami)" != "root" ];then
            echo "############################################################"
            echo "The Apache process startup user is: "$run_user
            echo "Please run this script with root user or sudo mode!"
            exit 0
        fi
    else
        if [ "$run_user" == "root"  ];then
            if [[ "$(whoami)" != "root" ]];then
                echo "############################################################"
                echo "The Apache process startup user is: "$run_user
                echo "Please run this script with root user or sudo mode!"
                exit 0
            fi                
        else
            if [[ "$(whoami)" != "root" && "$(whoami)" != "$run_user" ]];then
                echo "############################################################"
                echo "The Apache process startup user is: "$run_user
                echo "Please run this script with $run_user user!"
                echo "You can also use root user or sudo mode if you have permission."
                exit 0
            fi
        fi
    fi

fi

function apache_inquiry_info(){

    echo "###############Get Apache Process Info##################" 
    ps -ef|grep httpd|grep -v grep|grep -v '.sh'

    apids=`ps -ef|grep httpd|grep -v grep|grep -v '.sh'|awk '$3==1{print $2}'`

    for pid in $apids
    do

        apache_bin=`ls -l /proc/$pid/exe|awk '{print $(NF)}'`
        
        apache_home=`$apache_bin -V|grep "HTTPD_ROOT"|awk -F '=' '{print $2}'|tr -d '"'`
        apache_config=`$apache_bin -V |grep "SERVER_CONFIG_FILE"|awk -F '=' '{print $2}'| tr -d '"'`
        apache_log=`$apache_bin -V |grep "DEFAULT_ERRORLOG"| awk -F '=' '{print $2}'| tr -d '"'`

        #将apache所有配置内容输出到apache_temp.xml文件
        echo "######$apache_home/$apache_config Info:" > /tmp/enmoResult/tmpcheck/apache_temp.xml
        apache_temp=/tmp/enmoResult/tmpcheck/apache_temp.xml
        cat "$apache_home/$apache_config"|grep -vE '^#|^\s*#|^$' >> $apache_temp  2>/dev/null
        includes=`cat "$apache_home/$apache_config"|grep -v '#'|grep -i "include "`
        for include in $includes
        do
            if echo "$include"|grep -q -E '\.conf$'; then
                if [[ $include =~ ^/.* ]];then
                    echo "######$include Info:" >> $apache_temp
                    cat $include|grep -vE '^#|^\s*#|^$' >> $apache_temp 2>/dev/null
                else
                    echo "######$apache_home/$include Info:" >> $apache_temp
                    cat $apache_home/$include|grep -vE '^#|^\s*#|^$' >> $apache_temp 2>/dev/null
                fi
            fi
        done
        
        # 获取apache配置内容
        echo "###########Get Process $pid Apache Config Info###########"
        cat $apache_temp

        # 删除临时文件
        rm -f $apache_temp

        # 获取apache日志内容
        echo "############Get Process $pid Apache Log Info#############"
        cat "$apache_home/$apache_log"|tail -n 1000

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

function get_apache_jsondata(){

    init=0
    #获取apache pids
    hpids=`ps -ef|grep httpd|grep -v grep|grep -v '.sh'|awk '$3==1{print $2}'`

    for hpid in $hpids; do

        echo "{"

        #获取apache bin目录
        httpd_bin=`ls -l /proc/$hpid/exe|awk '{print $(NF)}'`

        #获取apache编译信息
        httpd_cinfo=`$httpd_bin -V|sed 's/\"//g'|sed 's/\\\//g'`
        echo "\"httpd_cinfo\"":"\"$httpd_cinfo\""","

        #获取apache安装目录
        httpd_home=`$httpd_bin -V|grep "HTTPD_ROOT"|awk -F '=' '{print $2}'|tr -d '"'`
        echo "\"httpd_home\"":"\"$httpd_home\""","

        #获取apache启动用户
        httpd_user=`ps -ef|grep $hpid|grep -v grep|grep -v '.sh'|awk '$3==1{print $1}'`
        echo "\"httpd_user\"":"\"$httpd_user\""","

        #获取apache版本信息
        httpd_version=`$httpd_bin -V|grep "Server version:"|awk -F "/" '{print $2}'|awk -F " " '{print $1}'`
        echo "\"httpd_version\"":"\"$httpd_version\""","

        #获取apache工作模式
        worker_mode=`$httpd_bin -V|grep "Server MPM:"|awk '{print $NF}'`
        echo "\"worker_mode\"":"\"$worker_mode\""","

        #获取apache配置文件目录
        httpd_confile=`ps -ef|grep $hpid|grep -v grep|grep -v '.sh'|awk '$3==1'|awk -F "-f" '{print $2}'|awk '{print $1}'`
        if [ -n "$httpd_confile" ];then
		    if [[ $httpd_confile =~ ^/.* ]];then
                httpd_conf="$httpd_confile"
            else
                httpd_conf="$httpd_home/$httpd_confile"
            fi
        else
            httpd_config=`$httpd_bin -V|grep "SERVER_CONFIG_FILE"|awk -F '=' '{print $2}'| tr -d '"'`
            httpd_conf="$httpd_home/$httpd_config"
        fi
        echo "\"httpd_conf\"":"\"$httpd_conf\""","

        httpd_errorlog=`$httpd_bin -V|grep "DEFAULT_ERRORLOG"| awk -F '=' '{print $2}'| tr -d '"'`
   
        httpd_num=`ps -ef|grep "$hpid"|grep -v grep|grep -v '.sh'|wc -l`
        echo "\"httpd_num\"":"\"$httpd_num\""","

        #将httpd所有配置内容输出到httpd_tp.xml文件
        echo "######$httpd_conf Info:" > /tmp/enmoResult/tmpcheck/httpd_tp.xml
        httpd_tp=/tmp/enmoResult/tmpcheck/httpd_tp.xml
        cat "$httpd_conf"|grep -vE '^#|^\s*#|^$' >> $httpd_tp
        httpd_includes=`cat $httpd_conf|grep -v '#'|grep -i "include "`
        for include in $httpd_includes
        do
            if echo "$include"|grep -q -E '\.conf$'; then
                if [[ $include =~ ^/.* ]];then
                    echo "######$include Info:" >> $httpd_tp
                    cat "$include"|grep -vE '^#|^\s*#|^$' >> $httpd_tp 2>/dev/null
                else
                    echo "######$httpd_home/$include Info:" >> $httpd_tp
                    cat "$httpd_home/$include"|grep -vE '^#|^\s*#|^$' >> $httpd_tp 2>/dev/null
                fi
            fi
        done

        # 获取httpd监听端口
        httpd_listen=`cat $httpd_tp|grep -i "Listen "`
        a=":"
        if [[ "$httpd_listen" =~ "$a" ]];then
            httpd_port=`echo $httpd_listen|awk -F ":" '{print $NF}'`
        else
            httpd_port="$httpd_listen"
        fi
        echo "\"httpd_port\"":"\"$httpd_port\""","

        # 安全基线检查
        # 版本检查
        echo "\"version_check\"":"\"$httpd_version\""","

        # 进程启动用户检查
        echo "\"runuser_check\"":"\"$httpd_user\""","
        if [[ $httpd_user = "root" ]];then
            echo "\"runuser_check_con\"":"\"Failed\""","
        else
            echo "\"runuser_check_con\"":"\"Pass\""","
        fi

        # 版本隐藏配置
        server_token=`cat "$httpd_tp"|grep -i "ServerTokens"`
        if [ -n "$server_token" ];then
            echo "\"token_check\"":"\"$server_token\""","
            typeset -l token_value
            token_value=`echo $server_token|awk '{print $NF}'`
            if [ "$token_value" = "prod" ];then
                echo "\"token_check_con\"":"\"Pass\""","
            else
                echo "\"token_check_con\"":"\"Failed\""","
            fi
        else
            echo "\"token_check\"":"\"NullConfig\""","
            echo "\"token_check_con\"":"\"Failed\""","
        fi

        # 禁止目录浏览
        indexes=`cat "$httpd_tp"|grep -v IndexOptions|grep Options`
        indexes_1=`cat $httpd_tp|grep -v IndexOptions|grep Options|grep " Indexes"`
        indexes_2=`cat $httpd_tp|grep -v IndexOptions|grep Options|grep "+Indexes"`
        if [ -n "$indexes" ];then
            echo "\"dir_check\"":"\"$indexes\""","
            if [[ -n $indexes_1 || -n $indexes_2 ]];then
                echo "\"dir_check_con\"":"\"Failed\""","
            else
                echo "\"dir_check_con\"":"\"Pass\""","
            fi
        else
            echo "\"dir_check\"":"\"NullConfig\""","
            echo "\"dir_check_con\"":"\"Failed\""","
        fi


        # 自定义错误页面检查
        error_page=`cat $httpd_tp|grep "ErrorDocument "`
        if [ -n "$error_page" ];then
            echo "\"errorpage_check\"":"\"$error_page\""","
            echo "\"errorpage_check_con\"":"\"Pass\""","
        else
            echo "\"errorpage_check\"":"\"NullConfig\""","
            echo "\"errorpage_check_con\"":"\"Failed\""","
        fi
        
        # 获取httpd配置内容
        httpd_confinfo=`cat "$httpd_conf"|grep -vE '^#|^\s*#|^$'|sed 's/\"//g'|sed 's/\\\//g'`
        echo "\"httpd_confinfo\"":"\"$httpd_confinfo\""

        # 删除缓存文件
        rm -f $httpd_tp

        let init+=1
        echo "}"
        if [ "$init" -lt "$apache_pid_member" ];then
            echo ","
        fi

    done

}

function get_jsondata(){

    new_document=$new_data/apache_$ipinfo.json
    echo "{" > $new_document
    
    echo "\"os_info\": {" >> $new_document
    get_os_jsondata
    echo "}," >>$new_document
    
    echo "\"httpd_info\": [" >> $new_document
    get_apache_jsondata >> $new_document
    echo "]" >> $new_document
    
    echo "}" >> $new_document
}

function get_apache_main() {

####check /tmp/tmpcheck Is empty
if [ "$(ls -A $filepath)" ];then  
    echo "$filepath is not empty!!!"
    rm -rf $filepath/*
    echo "clean $filepath !!!"
else    
    echo "$filepath is empty!!!"
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
filename1=$HOSTNAME"_"apache"_"os_""$ipinfo"_"$qctime".txt"
collect_sys_info >> "$filepath""$filename1"

####get apache info
filename2=$HOSTNAME"_"apache"_"$ipinfo"_"$qctime".txt"
apache_inquiry_info >> "$filepath""$filename2"

###get json data
get_jsondata

tar -zcf /tmp/enmoResult/"$HOSTNAME"_"apache"_"$ipinfo"_"$qctime".tar.gz --exclude=/tmp/enmoResult/*.tar.gz /tmp/enmoResult/* --format=ustar

echo -e "___________________"
echo -e "Collection info Finished."
echo -e "Result File Path:" $filepath
echo -e "\n"
}
    
######################Main##########################
filepath="/tmp/enmoResult/tmpcheck/"
excmkdir=$(which mkdir | awk 'NR==1{print}'  )
$excmkdir -p $filepath
new_data="/tmp/enmoResult/apache"
$excmkdir -p $new_data
qctime=$(date +'%Y%m%d%H%M%S')
ipinfo=`ip addr show |grep 'state UP' -A 2| grep "inet " |grep -v 127.0.0. |head -1|cut -d" " -f6|cut -d/ -f1`

echo "############################################################"
echo "Start performing apache patrols！！！"
get_apache_main
