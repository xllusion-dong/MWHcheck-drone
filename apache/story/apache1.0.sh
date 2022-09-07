#!/bin/bash
#version:v1.0

#----------------------------------------OS层数据采集------------------------------------------------
function collect_sys_info(){

	echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
	echo "|                      os info                            |"
	echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
	echo ""

	echo "--------------系统检查--------------"
    IP_Address=$(ip addr show |grep 'state UP' -A 2| grep "inet " |grep -v 127.0.0. |head -1|cut -d" " -f6|cut -d/ -f1)
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
    Load=$(uptime |awk -F ":" '{print $NF}')
    echo "Load:$Load"
    MemTotal=$(cat /proc/meminfo | awk '/^MemTotal/{print $2}') #内存总量
    echo "MemTotal:$(convert_unit $MemTotal)"
    MemFree=$(cat /proc/meminfo | awk '/^MemFree/{print $2}')   #空闲内存
    echo "MemFree:$(convert_unit $MemFree)"
    MemBuffers=$(cat /proc/meminfo | awk '/^Buffers/{print $2}')   #Buffers
    MemCached=$(cat /proc/meminfo | awk '/^Cached/{print $2}')   #Cached
    MemUsed=$(expr $MemTotal - $MemFree - $MemBuffers - $MemCached)  #已用内存
    echo "MemUsed:$(convert_unit $MemUsed)"
    Mem_Rate=$(awk 'BEGIN{printf"%.2f\n",'$MemUsed' / '$MemTotal' *100}') #保留小数点后2位
    echo "Mem_Rate:$Mem_Rate%"
    Swap_Method=$(cat /proc/sys/vm/swappiness)
    Openfile=$(ulimit -a|grep "open files"|awk '{print $NF}')
    echo "Openfile:$Openfile"
    echo "Swap_Method:$Swap_Method"
    Usesum=0
    Totalsum=0
    disknum=`df -hlT |wc -l `
    for((n=2;n<=$disknum;n++))
    do  
	use=$(df -k |awk NR==$n'{print int($3)}')   
	pertotal=$(df -k |awk NR==$n'{print int($2)}')  
	Usesum=$[$Usesum+$use]		#计算已使用的总量   
	Totalsum=$[$Totalsum+$pertotal]	#计算总量
    done
    Freesum=$[$Totalsum-$Usesum]
    Diskutil=$(awk 'BEGIN{printf"%.2f\n",'$Usesum' / '$Totalsum'*100}')
    Freeutil=$(awk 'BEGIN{printf"%.2f\n",100 - '$Diskutil'}')   

    #磁盘总量
    if [ $Totalsum -ge 0 -a $Totalsum -lt 1024 ];then
    echo "Totalsum:$To'ta'l'su'm K"  

    elif [ $Totalsum -gt 1024 -a  $Totalsum -lt 1048576 ];then  
	Totalsum=$(awk 'BEGIN{printf"%.2f\n",'$Totalsum' / 1024}')
    echo "Totalsum:$Totalsum M"  

    elif [ $Totalsum -gt 1048576 ];then 
	Totalsum=$(awk 'BEGIN{printf"%.2f\n",'$Totalsum' / 1048576}')
    echo "Totalsum:$Totalsum G"  

    fi

    #磁盘已使用总量
    if [ $Usesum -ge 0 -a $Usesum -lt 1024 ];then
    echo "Usesum:$Usesum K"    

    elif [ $Usesum -gt 1024 -a  $Usesum -lt 1048576 ];then  
	Usesum=$(awk 'BEGIN{printf"%.2f\n",'$Usesum' / 1024}')
    echo "Usesum:$Usesum M"    

    elif [ $Usesum -gt 1048576 ];then   
	Usesum=$(awk 'BEGIN{printf"%.2f\n",'$Usesum' / 1048576}')
    echo "Usesum:$Usesum G"    

    fi  

    #磁盘未使用总量
    if [ $Freesum -ge 0 -a $Freesum -lt 1024 ];then
    echo "Freesum:$Freesum K"   

    elif [ $Freesum -gt 1024 -a  $Freesum -lt 1048576 ];then    
	Freesum=$(awk 'BEGIN{printf"%.2f\n",'$Freesum' / 1024}')
    echo "Freesum:$Freesum M"   

    elif [ $Freesum -gt 1048576 ];then  
	Freesum=$(awk 'BEGIN{printf"%.2f\n",'$Freesum' / 1048576}')
    echo "Freesum:$Freesum G"
    fi  
    #磁盘占用率
    echo "Diskutil:$Diskutil%"   

    #磁盘空闲率
    echo "Freeutil:$Freeutil%"   

    #
    IO_User=$(iostat -x -k 2 1 |tail -6|grep -v Device:|grep -v vda|grep -v avg|awk -F " " '{print $2}')
    IO_System=$(iostat -x -k 2 1 |tail -6|grep -v Device:|grep -v vda|grep -v avg|awk -F " " '{print $4}')
    IO_Wait=$(iostat -x -k 2 1 |tail -6|grep -v Device:|grep -v vda|grep -v avg|awk -F " " '{print $5}')
    IO_Idle=$(iostat -x -k 2 1 |tail -6|grep -v Device:|grep -v vda|grep -v avg|awk -F " " '{print $NF}')
    echo "IO_User:$IO_User%"
    echo "IO_System:$IO_System%"
    echo "IO_Wait:$IO_Wait%"
    echo "IO_Idle:$IO_Idle%"
    #TCP参数获取
    Tcp_Tw_Recycle=$(sysctl net.ipv4.tcp_tw_recycle |awk -F "=" '{print $2}')
    echo "Tcp_Tw_Recycle:$Tcp_Tw_Recycle"
    #该参数的作用是快速回收timewait状态的连接。上面虽然提到系统会自动删除掉timewait状态的连接，但如果把这样的连接重新利用起来岂不是更好。
    #所以该参数设置为1就可以让timewait状态的连接快速回收，它需要和下面的参数配合一起使用
    Tcp_Tw_Reuse=$(sysctl net.ipv4.tcp_tw_reuse|awk -F "=" '{print $2}')
    echo "Tcp_Tw_Reuse:$Tcp_Tw_Reuse"
    #该参数设置为1，将timewait状态的连接重新用于新的TCP连接，要结合上面的参数一起使用。
    Tcp_Fin_Timeout=$(sysctl net.ipv4.tcp_fin_timeout|awk -F "=" '{print $2}')
    echo "Tcp_Fin_Timeout:$Tcp_Fin_Timeout"
    #tcp连接的状态中，客户端上有一个是FIN-WAIT-2状态，它是状态变迁为timewait前一个状态。
    #该参数定义不属于任何进程该连接状态的超时时间，默认值为60，建议调整为6。
    Tcp_Keepalive_Time=$(sysctl net.ipv4.tcp_keepalive_time|awk -F "=" '{print $2}')
    echo "Tcp_Keepalive_Time:$Tcp_Keepalive_Time"
    #表示当keepalive起用的时候，TCP发送keepalive消息的频度。缺省是2小时，改为30分钟。
    Tcp_Keepalive_Probes=$(sysctl net.ipv4.tcp_keepalive_probes|awk -F "=" '{print $2}')
    echo "Tcp_Keepalive_Probes:$Tcp_Keepalive_Probes"
    #如果对方不予应答，探测包的发送次数
    Tcp_Keepalive_Intvl=$(sysctl net.ipv4.tcp_keepalive_intvl|awk -F "=" '{print $2}')
    echo "Tcp_Keepalive_Intvl:$Tcp_Keepalive_Intvl"
    #keepalive探测包的发送间隔
    
    echo "--------------原始数据采集_补充--------------"
	echo "----->>>---->>>  CPU usage"
	sar 2 5
	echo ""
	echo "----->>>---->>>  resource limit"
	cat /etc/security/limits.conf |grep -v '^#' |grep -v '^$'
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

#----------------------------------------apache info------------------------------------------------

function apache_inquiry_info(){
	apache_pid_member=`ps -ef|grep httpd|grep -v grep|wc -l`
	echo "############################################################"
	if [ $apache_pid_member == 0 ];then
		echo "There is no Apache process on the server!"
	else
		echo "The Apache process is running on the server,Start Check!"
	fi
	echo "###############Get Apache Process Info##################" 
	ps -ef |grep httpd|grep -v grep
	apachepros=`ps -ef|grep httpd|grep -v grep|awk '{print $3}'|sort|uniq`
	j=0
	for i in $apachepros
	do
		if [ $i -ne 1 ];then
			apache_pids[$j]=$i
			let j++
		fi
	done
	for pid in ${apache_pids[@]}
	do
		echo "###############Get Process $pid ApacheInfo###############"
		apache_bin=`ls -l /proc/$pid/exe|awk '{print $(NF)}'`
		$apache_bin -V
		echo "##############Get Process $pid ApacheInfoEND#############"
		
		apache_home=`$apache_bin -V|grep "HTTPD_ROOT"|awk -F '=' '{print $2}'|tr -d '"'`
		apache_config=`$apache_bin -V |grep "SERVER_CONFIG_FILE"|awk -F '=' '{print $2}'| tr -d '"'`
		apache_log=`$apache_bin -V |grep "DEFAULT_ERRORLOG"| awk -F '=' '{print $2}'| tr -d '"'`
		run_user=`ps -ef|grep $pid|grep -v grep|awk '$3==1{print $1}'`
		apache_ver=`$apache_bin -V|grep "Server version:"|awk -F "/" '{print $2}'|awk -F " " '{print $1}'`
		
		echo "############Get Process $pid Apache Install Dir###########"
		echo "Process $pid Apache Install Dir:"$apache_home
		
		echo "############Get Process $pid Apache Version Info##########"
		echo "Process $pid Apache Version Info:"$apache_ver
		
		echo "#############Get Process $pid Apache Run User#############"
		echo "Process $pid Apache Run User:"$run_user
		
		echo "##############Process $pid Apache Port Info###############"
		apache_listen=`cat $apache_home/$apache_config|grep "Listen"|grep -v "#"`
		a=":"
		if [[ $apache_listen =~ $a ]]
		then
			listen_port=`echo $apache_listen|awk -F ":" '{print $2}'`
		else
			listen_port=`echo $apache_listen|awk -F " " '{print $2}'`
		fi
		echo "Process $pid Apache Listen Port:"$listen_port
		
		echo "############Get Process $pid Apache Work Mode#############"
		worker_mode=`$apache_bin -V|grep "Server MPM:"|awk '{print $NF}'`
		echo "Process $pid Apache Work Mode:"$worker_mode
		
		echo "#########Get Process $pid Apache Processes Number#########"
		pro_num=`ps -ef|grep $pid|grep -v grep|wc -l`
		echo "Process $pid Apache Processes Number:"$pro_num
		
		# 安全基线检查
		echo "##########Get Process $pid Apache Security Check##########"
		# 版本检查
		echo "Process $pid Apache Version Check Result:"$apache_ver
		ver_num=$(echo $apache_ver|awk '{print substr($1,1,3)}')
		num_a=`echo "$ver_num >= 2.4"|bc`
		if [ "$num_a" -eq 1 ];then
			echo "Process $pid Apache Version Check Conclusion:Pass"
		else
			echo "Process $pid Apache Version Check Conclusion:Failed"
		fi
		# 进程启动用户检查
		echo "Process $pid Apache RunUser Check Result:"$run_user
		if [[ $run_user = "root" ]];then
			echo "Process $pid Apache RunUser Check Conclusion:Failed"
		else
			echo "Process $pid Apache RunUser Check Conclusion:Pass"
		fi
		# 版本隐藏配置
		server_token=`cat $apache_home/$apache_config|grep -v "#"|grep "ServerTokens"|awk '{print $NF}'`
		if [ -n "$server_token" ];then
			echo "Process $pid Apache ServerToken Check Result:"$server_token
			if [ "$server_token" = "Prod" ];then
				echo "Process $pid Apache ServerToken Check Conclusion:Pass"
			else
				echo "Process $pid Apache ServerToken Check Conclusion:Failed"
			fi
		else
			echo "Process $pid Apache ServerToken Check Result:Null"
			echo "Process $pid Apache ServerToken Check Conclusion:Failed"
		fi
		
		# 禁止目录浏览
		dir_options=`cat $apache_home/$apache_config|grep -v "#"|grep "FollowSymLinks"|xargs`
		if [ -n "$dir_options" ];then
			echo "Process $pid Apache Directory Check Result:"$dir_options
			if [[ $dir_options =~ "Indexes" ]];then
				echo "Process $pid Apache Directory Check Conclusion:Failed"
			else
				echo "Process $pid Apache Directory Check Conclusion:Pass"
			fi
		else
			echo "Process $pid Apache Directory Check Result:Null"
			echo "Process $pid Apache Directory Check Conclusion:Failed"
		fi
		# 自定义错误页面
		error_page=`cat $apache_home/$apache_config|grep -v "#"|grep "ErrorDocument"|xargs|sed '/^$/d'`
		if [ -n "$error_page" ];then
			echo "Process $pid Apache Error Pages Check Result:"$error_page
			echo "Process $pid Apache Error Pages Check Conclusion:Pass"
		else
			echo "Process $pid Apache Error Pages Check Result:Null"
			echo "Process $pid Apache Error Pages Check Conclusion:Failed"
		fi
		
		echo "###########Get Process $pid ApacheConfigInfo###########"
		echo "Process $pid Apache Config Info:" && cat $apache_home/$apache_config|grep -v "#"
		echo "###########Get Process $pid ApacheConfigInfoEND###########"
		
		echo "###########Get Process $pid Apache Limits Info###########"
		cat /proc/$pid/limits
		
		echo "############Get Process $pid Apache Log Info#############"
		cat $apache_home/$apache_log|tail -n 5000
		echo "Apache Log END!"
		
	done
	
}

function get_apache_main() {
####check /tmp/tmpcheck Is empty
tmpcheck_dir="/tmp/enmoResult/tmpcheck/"
if [ "$(ls -A $tmpcheck_dir)" ];then  
    echo "$tmpcheck_dir is not empty!!!"
    rm -rf $tmpcheck_dir/*
    echo "clean $tmpcheck_dir !!!"
else    
    echo "$tmpcheck_dir is empty!!!"
fi

####get system info
filename1=$HOSTNAME"_"apache"_"os_""$ipinfo"_"$qctime".txt"
collect_sys_info >> "$filepath""$filename1"

####get apache info
filename2=$HOSTNAME"_"apache"_"$ipinfo"_"$qctime".txt"
apache_inquiry_info >> "$filepath""$filename2"


echo -e "___________________"
echo -e "Collection info Finished."
echo -e "Result File Path:" $filepath
echo -e "\n"
}

#----------------------------------------END------------------------------------------------
######################Main##########################
filepath="/tmp/enmoResult/tmpcheck/"
excmkdir=$(which mkdir | awk 'NR==1{print}'  )
$excmkdir -p $filepath
qctime=$(date +'%Y%m%d%H%M%S')
ipinfo=`ip addr show |grep 'state UP' -A 2| grep "inet " |grep -v 127.0.0. |head -1|cut -d" " -f6|cut -d/ -f1`

echo "############################################################"
echo "Start performing Apache patrols！！！"
get_apache_main

# get os json data
data_path=/tmp/enmoResult/tmpcheck
function get_os_jsondata(){
    mkdir -p /tmp/enmoResult/apache
    new_data=/tmp/enmoResult/apache
    if [ "$(ls -A $new_data)" ];then  
        echo "$new_data is not empty!!!"
        rm -rf $new_data/*
        echo "clean $new_data !!!"
    else    
        echo "$new_data is empty!!!"
    fi    
    cd $data_path
    file=$filename1
    ip=`ls $file|awk -F "_" '{print $4}'`
    result=$(echo $ip | grep "addr")
    if [[ "$result" != "" ]];
    then 
        ip=${ip#*:} 
    fi
    new_document=$new_data/apache_$ip.json
    #echo "=====================OS基础信息=====================" >> $new_document
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
    Totalsum=`cat $file |grep Totalsum|awk -F ":" '{print $2}'`&& echo "\"Totalsum\"":"\"$Totalsum\"""," >> $new_document
    Usesum=`cat $file |grep Usesum|awk -F ":" '{print $2}'`&& echo "\"Usesum\"":"\"$Usesum\"""," >> $new_document
    Freesum=`cat $file |grep Freesum|awk -F ":" '{print $2}'`&& echo "\"Freesum\"":"\"$Freesum\"""," >> $new_document
    Diskutil=`cat $file |grep Diskutil|awk -F ":" '{print $2}'`&& echo "\"Diskutil\"":"\"$Diskutil\"""," >> $new_document
    Freeutil=`cat $file |grep Freeutil|awk -F ":" '{print $2}'`&& echo "\"Freeutil\"":"\"$Freeutil\"""," >> $new_document
    IO_User=`cat $file|grep IO_User|awk -F ":" '{print $2}'`&& echo "\"IO_User\"":"\"$IO_User\"""," >> $new_document
    IO_System=`cat $file |grep IO_System|awk -F ":" '{print $2}'`&& echo "\"IO_System\"":"\"$IO_System\"""," >> $new_document
    IO_Wait=`cat $file |grep IO_Wait|awk -F ":" '{print $2}'`&& echo "\"IO_Wait\"":"\"$IO_Wait\"""," >> $new_document
    IO_Idle=`cat $file |grep IO_Idle|awk -F ":" '{print $2}'`&& echo "\"IO_Idle\"":"\"$IO_Idle\"""," >> $new_document
    Tcp_Tw_Recycle=`cat $file |grep Tcp_Tw_Recycle|awk -F ":" '{print $2}'`&& echo "\"Tcp_Tw_Recycle\"":"\"$Tcp_Tw_Recycle\"""," >> $new_document
    Tcp_Tw_Reuse=`cat $file |grep Tcp_Tw_Reuse|awk -F ":" '{print $2}'`&& echo "\"Tcp_Tw_Reuse\"":"\"$Tcp_Tw_Reuse\"""," >> $new_document
    Tcp_Fin_Timeout=`cat $file |grep Tcp_Fin_Timeout|awk -F ":" '{print $2}'`&& echo "\"Tcp_Fin_Timeout\"":"\"$Tcp_Fin_Timeout\"""," >> $new_document
    Tcp_Keepalive_Time=`cat $file |grep Tcp_Keepalive_Time|awk -F ":" '{print $2}'`&& echo "\"Tcp_Keepalive_Time\"":"\"$Tcp_Keepalive_Time\"""," >> $new_document
    Tcp_Keepalive_Probes=`cat $file |grep Tcp_Keepalive_Probes|awk -F ":" '{print $2}'`&& echo "\"Tcp_Keepalive_Probes\"":"\"$Tcp_Keepalive_Probes\"""," >> $new_document
    Tcp_Keepalive_Intvl=`cat $file |grep Tcp_Keepalive_Intvl|awk -F ":" '{print $2}'`&& echo "\"Tcp_Keepalive_Intvl\"":"\"$Tcp_Keepalive_Intvl\"""," >> $new_document

}


function get_apache_data(){
	new_data=/tmp/enmoResult/apache
	cd $data_path
	file1=$filename2
    ip_1=`ls $file1|awk -F "_" '{print $3}'`
    new_document=$new_data/"apache_"$ip_1.json
	apache_info=`cat $file1|sed -n /ApacheInfo/,/ApacheInfoEND/p|grep -v "ApacheInfo"|grep -v "ApacheInfoEND"|sed 's/\"//g'` && echo "\"apache_info\"":"\"$apache_info\"""," >> $new_document
    apache_version=`cat $file1|grep "Apache Version Info:"|awk -F ":" '{print $2}'` && echo "\"apache_version\"":"\"$apache_version\"""," >> $new_document
    apache_dir=`cat $file1|grep "Apache Install Dir:"|awk -F ":" '{print $2}'` && echo "\"apache_dir\"":"\"$apache_dir\"""," >> $new_document
	apache_user=`cat $file1|grep "Apache Run User:"|awk -F ":" '{print $2}'` && echo "\"apache_user\"":"\"$apache_user\"""," >> $new_document
	apache_listen=`cat $file1|grep "Apache Listen Port:"|awk -F ":" '{print $2}'` && echo "\"apache_listen\"":"\"$apache_listen\"""," >> $new_document
	apache_mode=`cat $file1|grep "Apache Work Mode:"|awk -F ":" '{print $2}'` && echo "\"apache_mode\"":"\"$apache_mode\"""," >> $new_document
	apache_num=`cat $file1|grep "Apache Processes Number:"|awk -F ":" '{print $2}'` && echo "\"apache_num\"":"\"$apache_num\"""," >> $new_document
	version_check=`cat $file1|grep "Apache Version Check Result:"|awk -F ":" '{print $2}'` && echo "\"version_check\"":"\"$version_check\"""," >> $new_document
	version_check_con=`cat $file1|grep "Apache Version Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"version_check_con\"":"\"$version_check_con\"""," >> $new_document
	runuser_check=`cat $file1|grep "Apache RunUser Check Result:"|awk -F ":" '{print $2}'` && echo "\"runuser_check\"":"\"$runuser_check\"""," >> $new_document
	runuser_check_con=`cat $file1|grep "Apache RunUser Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"runuser_check_con\"":"\"$runuser_check_con\"""," >> $new_document
	token_check=`cat $file1|grep "Apache ServerToken Check Result:"|awk -F ":" '{print $2}'` && echo "\"token_check\"":"\"$token_check\"""," >> $new_document
	token_check_con=`cat $file1|grep "Apache ServerToken Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"token_check_con\"":"\"$token_check_con\"""," >> $new_document
	directory_check=`cat $file1|grep "Apache Directory Check Result:"|awk -F ":" '{print $2}'` && echo "\"directory_check\"":"\"$directory_check\"""," >> $new_document
	directory_check_con=`cat $file1|grep "Apache Directory Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"directory_check_con\"":"\"$directory_check_con\"""," >> $new_document
	errorpage_check=`cat $file1|grep "Apache Error Pages Check Result:"|awk -F ":" '{print $2}'` && echo "\"errorpage_check\"":"\"$errorpage_check\"""," >> $new_document
	errorpage_check_con=`cat $file1|grep "Apache Error Pages Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"errorpage_check_con\"":"\"$errorpage_check_con\"""," >> $new_document
	apache_config=`cat $file1|sed -n /ApacheConfigInfo/,/ApacheConfigInfoEND/p|grep -v "ApacheConfigInfo"|grep -v "ApacheConfigInfoEND"|sed 's/\"//g'|sed 's/\\\//g'|sed '/^$/d'` && echo "\"apache_config\"":"\"$apache_config\"""," >> $new_document
	
	apache_warn_log=`cat $file1|grep ":warn]"`
	apache_error_log=`cat $file1|grep ":error]"`
	apache_crit_log=`cat $file1|grep ":crit]"`
	apache_alert_log=`cat $file1|grep ":alert]"`
	apache_emerg_log=`cat $file1|grep ":emerg]"`
	apache_errorlog=`echo -e "${apache_warn_log}${apache_error_log}\n${apache_crit_log}\n${apache_alert_log}\n${apache_emerg_log}"`
	
	#echo "\"错误日志\"":"\"$apache_emerg_log\n$apache_alert_log\n$apache_crit_log\n$apache_error_log\"""," >> $new_document
	if [[ -z ${apache_errorlog} ]]
	then
		echo "\"apache_log\"":"\"日志无异常。\"" >> $new_document
	else
		echo "\"apache_log\"":"\"$apache_errorlog\"" >> $new_document
	fi

}

echo "Start Apache Date Extraction!!!"
get_os_jsondata
get_apache_data
tar -zcf /tmp/enmoResult/"$HOSTNAME"_"apache"_"$ipinfo"_"$qctime".tar.gz --exclude=/tmp/enmoResult/*.tar.gz /tmp/enmoResult/* --format=ustar
