#!/bin/bash
#version:1.0

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

#----------------------------------------nginx info------------------------------------------------

function nginx_inquiry_info(){

	nginx_pid_member=`ps -ef|grep nginx|grep -v grep|wc -l`
	echo "############################################################"
	if [ "$nginx_pid_member" == 0 ];then
		echo "There is no Nginx process on the server!"
	else
		echo "The Nginx process is running on the server,Start Check!"
	fi
	echo "#################Get Nginx Process Info####################" 
	ps -ef|grep nginx|grep -v grep
	
	nginx_pid=`ps -ef|grep nginx|grep master|grep -v grep |awk '{print $2}'`
	
	for NPID in $nginx_pid
	do
		echo "###############Get Process $NPID NginxInfo###############"
		nginx_bin=`ls -l /proc/$NPID/exe|awk '{print $(NF)}'`
		$nginx_bin -V 2>&1
		echo "##############Get Process $NPID NginxInfoEND#############"
		
		nginx_prefix=`$nginx_bin -V 2>&1|grep "prefix="|awk -F "prefix=" '{print $2}'|awk '{print $1}'`
		nginx_dir=${nginx_prefix%*/}
		nginx_conf=`ps -ef|grep nginx|grep master|grep -v grep|awk -F "-c" '{print $2}'|tr -d " "`
		if [ ! -n "$nginx_conf" ];then
			nginx_conf=`$nginx_bin -t 2>&1|grep syntax|awk '{print $(NF-3)}'`
		fi
		# 获取nginx用户 版本 端口 进程 日志信息
		runuser=`ps -ef|grep nginx|grep master|grep -v grep |awk '{print $1}'`
		nginx_ver=`$nginx_bin -v 2>&1|grep version|awk -F "/" '{print $NF}'`
		port=`cat $nginx_conf|grep listen|grep -v "#"|awk '{print $2}'|tr -d ";"`
		pro_num=`ps -ef|grep $NPID|grep -v grep|wc -l`
		accesslog=`cat $nginx_conf|grep access_log|grep -v "#"|grep -v off|awk '{print $2}'|tr -d ";"`
		errorlog=`cat $nginx_conf|grep error_log|grep -v "#"|grep -v off|awk '{print $2}'|tr -d ";"`
		if [ -n "$errorlog" ];then
			if [[ $errorlog =~ ^/.* ]];then
				error_log=$errorlog
			else
				error_log=$nginx_dir$errorlog
			fi
		else
			error_log=$nginx_dir"/logs/error.log"
		fi
		
		echo "############Get Process $NPID Nginx Install Dir###########"
		echo "Process $NPID Nginx Install Dir:"$nginx_dir
		
		echo "############Get Process $NPID Nginx Version Info##########"
		echo "Process $NPID Nginx Version Info:"$nginx_ver
		
		echo "############Get Process $NPID Nginx Run User##############"
		echo "Process $NPID Nginx Run User:"$runuser
		
		echo "##############Process $NPID Nginx Port Info###############"
		echo "Process $NPID Nginx Listen Port:"$port
		
		echo "#########Get Process $NPID Nginx Processes Number#########"
		echo "Process $NPID Nginx Processes Number:"$pro_num
		
		echo "#########Get Process $NPID Nginx Config File Dir##########"
		echo "Process $NPID Nginx Config File Dir:"$nginx_conf
		
		
		# 安全基线检查
		echo "##########Get Process $NPID Nginx Security Check##########"
		# 版本检查
		echo "Process $NPID Nginx Version Check Result:"$nginx_ver
		ver_num=$(echo $nginx_ver|awk '{print substr($1,1,3)}')
		num_a=`echo "$ver_num >= 1.21"|bc`
		if [ "$num_a" -eq 1 ];then
			echo "Process $NPID Nginx Version Check Conclusion:Pass"
		else
			echo "Process $NPID Nginx Version Check Conclusion:Failed"
		fi
		
		# 进程启动用户检查
		echo "Process $NPID Nginx RunUser Check Result:"$runuser
		if [[ $runuser = "root" ]];then
			echo "Process $NPID Nginx RunUser Check Conclusion:Failed"
		else
			echo "Process $NPID Nginx RunUser Check Conclusion:Pass"
		fi
		# 版本隐藏配置
		server_token=`cat $nginx_conf|grep "server_tokens"|grep -v "#"|xargs`
		if [ -n "$server_token" ];then
			echo "Process $NPID Nginx ServerToken Check Result:"$server_token
			typeset -l token_value
			token_value=`echo $server_token|awk '{print $NF}'|tr -d ';'`
			if [ "$token_value" = "off" ];then
				echo "Process $NPID Nginx ServerToken Check Conclusion:Pass"
			else
				echo "Process $NPID Nginx ServerToken Check Conclusion:Failed"
			fi
		else
			echo "Process $NPID Nginx ServerToken Check Result:Null"
			echo "Process $NPID Nginx ServerToken Check Conclusion:Failed"
		fi
		
		# 禁止目录浏览
		dir_brow=`cat $nginx_conf|grep autoindex|grep -v "#"|xargs`
		if [ -n "$dir_brow" ];then
			echo "Process $NPID Nginx Directory Check Result:"$dir_brow
			typeset -l brow_value
			brow_value=`echo $dir_brow|awk '{print $NF}'|tr -d ';'`
			if [ "$brow_value" = "off" ];then
				echo "Process $NPID Nginx Directory Check Conclusion:Pass"
			else
				echo "Process $NPID Nginx Directory Check Conclusion:Failed"
			fi
		else
			echo "Process $NPID Nginx Directory Check Result:Null"
			echo "Process $NPID Nginx Directory Check Conclusion:Pass"
		fi
		
		# 连接超时设置
		time_out=`cat $nginx_conf|grep timeout|grep -v "#"|xargs`
		if [ -n "$time_out" ];then
			echo "Process $NPID Nginx TimeOut Check Result:"$time_out
			echo "Process $NPID Nginx TimeOut Check Conclusion:Pass"
		else
			echo "Process $NPID Nginx TimeOut Check Result:Null"
			echo "Process $NPID Nginx TimeOut Check Conclusion:Failed"
		fi
		
		# 自定义错误页面
		error_page=`cat $nginx_conf|grep -v "#"|grep "fastcgi_intercept_errors"|xargs`
		if [ -n "$error_page" ];then
			echo "Process $NPID Nginx Error Pages Check Result:"$error_page
			typeset -l page_value
			page_value=`echo error_page|awk '{print $NF}'|tr -d ';'`
			if [ "$page_value" = "on" ];then
				echo "Process $NPID Nginx Error Pages Check Conclusion:Pass"
			else
				echo "Process $NPID Nginx Error Pages Check Conclusion:Failed"
			fi
		else
			echo "Process $NPID Nginx Error Pages Check Result:Null"
			echo "Process $NPID Nginx Error Pages Check Conclusion:Failed"
		fi
		
		
		echo "###########Get Process $NPID NginxConfigInfo#############"
	  	echo "Process $NPID Nginx Config Info:" && cat $nginx_conf|grep -v "#"|sed '/^$/d'
		echo "###########Get Process $NPID NginxConfigInfoEND##########"
		
		echo "############Get Process $NPID Nginx Log Info#############"
		if [ -e "$error_log" ];then
			cat $error_log|tail -n 5000
		else
			echo "No Error_Log File!"
		fi
		echo "Nginx Log END!"
	done
	
}

function get_nginx_main() {
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
filename1=$HOSTNAME"_"nginx"_"os_""$ipinfo"_"$qctime".txt"
collect_sys_info >> "$filepath""$filename1"

####get nginx info
filename2=$HOSTNAME"_"nginx"_"$ipinfo"_"$qctime".txt"
nginx_inquiry_info >> "$filepath""$filename2"


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
echo "Start performing Nginx patrols！！！"
get_nginx_main

# get os json data
data_path=/tmp/enmoResult/tmpcheck
function get_os_jsondata(){
    mkdir -p /tmp/enmoResult/nginx
    new_data=/tmp/enmoResult/nginx
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
    new_document=$new_data/nginx_$ip.json
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

function get_nginx_data(){
    new_data=/tmp/enmoResult/nginx
    cd $data_path
	file1=$filename2
	ip_1=`ls $file1|awk -F "_" '{print $3}'`
    new_document=$new_data/nginx_$ip_1.json
	nginx_info=`cat $file1|sed -n /NginxInfo/,/NginxInfoEND/p|grep -v "NginxInfo"|grep -v "NginxInfoEND"|sed 's/\"//g'` && echo "\"nginx_info\"":"\"$nginx_info\"""," >> $new_document
    nginx_version=`cat $file1 |grep "Nginx Version Info:"|awk -F ":" '{print $2}'` && echo "\"nginx_version\"":"\"$nginx_version\"""," >> $new_document
	nginx_home=`cat $file1 |grep "Nginx Install Dir:"|awk -F ":" '{print $2}'` && echo "\"nginx_home\"":"\"$nginx_home\"""," >> $new_document
	nginx_user=`cat $file1 |grep "Nginx Run User:"|awk -F ":" '{print $2}'` && echo "\"nginx_user\"":"\"$nginx_user\"""," >> $new_document
	nginx_port=`cat $file1 |grep "Nginx Listen Port:"|awk -F ":" '{print $2}'` && echo "\"nginx_port\"":"\"$nginx_port\"""," >> $new_document
	nginx_num=`cat $file1 |grep "Nginx Processes Number:"|awk -F ":" '{print $2}'` && echo "\"nginx_num\"":"\"$nginx_num\"""," >> $new_document
	config_dir=`cat $file1 |grep "Nginx Config File Dir:"|awk -F ":" '{print $2}'` && echo "\"config_dir\"":"\"$config_dir\"""," >> $new_document
	version_check=`cat $file1 |grep "Nginx Version Check Result:"|awk -F ":" '{print $2}'` && echo "\"version_check\"":"\"$version_check\"""," >> $new_document
	version_check_con=`cat $file1 |grep "Nginx Version Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"version_check_con\"":"\"$version_check_con\"""," >> $new_document
	runuser_check=`cat $file1 |grep "Nginx RunUser Check Result:"|awk -F ":" '{print $2}'` && echo "\"runuser_check\"":"\"$runuser_check\"""," >> $new_document
	runuser_check_con=`cat $file1 |grep "Nginx RunUser Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"runuser_check_con\"":"\"$runuser_check_con\"""," >> $new_document
	token_check=`cat $file1 |grep "Nginx ServerToken Check Result:"|awk -F ":" '{print $2}'` && echo "\"token_check\"":"\"$token_check\"""," >> $new_document
	token_check_con=`cat $file1 |grep "Nginx ServerToken Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"token_check_con\"":"\"$token_check_con\"""," >> $new_document
	directory_check=`cat $file1 |grep "Nginx Directory Check Result:"|awk -F ":" '{print $2}'` && echo "\"directory_check\"":"\"$directory_check\"""," >> $new_document
	directory_check_con=`cat $file1 |grep "Nginx Directory Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"directory_check_con\"":"\"$directory_check_con\"""," >> $new_document
	errorpage_check=`cat $file1 |grep "Nginx Error Pages Check Result:"|awk -F ":" '{print $2}'` && echo "\"errorpage_check\"":"\"$errorpage_check\"""," >> $new_document
	errorpage_check_con=`cat $file1 |grep "Nginx Error Pages Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"errorpage_check_con\"":"\"$errorpage_check_con\"""," >> $new_document
	timeout_check=`cat $file1 |grep "Nginx TimeOut Check Result:"|awk -F ":" '{print $2}'` && echo "\"timeout_check\"":"\"$timeout_check\"""," >> $new_document
	timeout_check_con=`cat $file1 |grep "Nginx TimeOut Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"timeout_check_con\"":"\"$timeout_check_con\"""," >> $new_document
	nginx_config=`cat $file1|sed -n /NginxConfigInfo/,/NginxConfigInfoEND/p|grep -v "NginxConfigInfo"|grep -v "NginxConfigInfoEND"|sed 's/\"//g'|sed 's/\\\//g'` && echo "\"nginx_config\"":"\"$nginx_config\"""," >> $new_document
	
	nginx_warn_log=`cat $file1|grep "\[warn]"|sed 's/\"//g'`
	nginx_error_log=`cat $file1|grep "\[error]"|sed 's/\"//g'`
	nginx_crit_log=`cat $file1|grep "\[crit]"|sed 's/\"//g'`
	nginx_alert_log=`cat $file1|grep "\[alert]"|sed 's/\"//g'`
	nginx_emerg_log=`cat $file1|grep "\[emerg]"|sed 's/\"//g'`
	nginx_errorlog=`echo -e "${nginx_warn_log}\n${nginx_error_log}\n${nginx_crit_log}\n${nginx_alert_log}\n${nginx_emerg_log}"`
	
	if [[ -z ${nginx_errorlog} ]]
	then
		echo "\"nginx_log\"":"\"日志无异常。\"" >> $new_document
	else
		echo "\"nginx_log\"":"\"$nginx_errorlog\"" >> $new_document
	fi

}

echo "Start Nginx Date Extraction!!!"
get_os_jsondata
get_nginx_data
tar -zcf /tmp/enmoResult/"$HOSTNAME"_"nginx"_"$ipinfo"_"$qctime".tar.gz --exclude=/tmp/enmoResult/*.tar.gz /tmp/enmoResult/* --format=ustar