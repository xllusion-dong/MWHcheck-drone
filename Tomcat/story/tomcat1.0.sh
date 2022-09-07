#!/bin/bash
#version:v1.2

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

#----------------------------------------Tomcat info------------------------------------------------
# 检查服务器是否存在Tomcat进程
echo "############################################################"
tomcat_pid_member=`ps -eo ruser,pid,args|grep java|grep -v grep|grep "org.apache.catalina.startup.Bootstrap start"|awk '{ print $2}'|wc -l`
if [ ${tomcat_pid_member} == 0 ];then
	echo "There is no Tomcat process on the server!"
else
	echo "The Tomcat process is running on the server,Start Check!"
fi

function tomcat_info(){
	# Get Tomcat PID Info
	PID=`ps -eo ruser,pid,args|grep java|grep -v grep|grep "org.apache.catalina.startup.Bootstrap start"|awk '{ print $2}'`
	echo "###############Get Tomcat Process Info##################" 
	ps -ef |grep java|grep -v grep|grep "org.apache.catalina.startup.Bootstrap start"
	for OPID in $PID; do
		echo "##########Get Process $OPID Tomcat Install Info#########" 
		tomcat_path=`ps -ef|grep java|grep tomcat|grep 'org.apache.catalina.startup.Bootstrap'|grep -v grep|awk -F '-Dcatalina.home=' '{print $2}'|awk '{print $1}'`
		java_path=`ls -l /proc/$OPID/exe|awk -F "->" '{print $2}'| tr -d ' '`
		jdk_path=`ls -l /proc/$OPID/exe|awk -F "->" '{print $2}'| tr -d ' '|awk -F "/bin" '{print $1}'`
		sh $tomcat_path/bin/version.sh
		
		serverxml=$tomcat_path/conf/server.xml
		contextxml=$tomcat_path/conf/context.xml
		webxml=$tomcat_path/conf/web.xml
		userxml=$tomcat_path/conf/tomcat-users.xml
		# 去除配置文件中的注释内容
		sed 's/<!--.*-->//g' $serverxml|sed -n '/<!--/,/-->/!p' > /tmp/enmoResult/tmpcheck/temp.xml
		tempxml=/tmp/enmoResult/tmpcheck/temp.xml
		sed 's/<!--.*-->//g' $contextxml|sed -n '/<!--/,/-->/!p' >> $tempxml
		echo "################Process $OPID Tomcat Run User#################"
		run_user=`ps -ef|grep $OPID|grep -v grep|awk '{print $1}'`
		echo "Process $OPID Tomcat RunUser:"$run_user
		echo "################Process $OPID Tomcat Install Dir#################"
		echo "Process $OPID Tomcat Install Dir:"$tomcat_path
		echo "################Process $OPID Tomcat Run JDK Dir#################"
		echo "Process $OPID Tomcat JDK Dir:"$jdk_path
		echo "################Process $OPID Tomcat Port Info#################"
		shutdown_port=`cat $serverxml|grep "Server port="|awk -F "=" '{print $2}'|awk '{print $1}'|tr -d '"'`
		# 获取出HTTP Connector标签信息
		num_1=`cat -n $tempxml|grep -v AJP|grep "Connector port="|awk '{print $1}'`
		num_2=`cat -n $tempxml|grep -v AJP|grep "redirectPort="|awk '{print $1}'`
		http_connector=`sed -n ''"$num_1"','"$num_2"'p' $tempxml`
		httpport=`echo $http_connector|awk -F "port=" '{print $2}'|awk '{print $1}'|tr -d '"'`
		
		echo "Process $OPID Tomcat HttpPort:"$httpport
		echo "Process $OPID Tomcat ShutdownPort:"$shutdown_port
		echo "###############Process $OPID Tomcat JVM Options Info###############"
		jvm_opt=`ps -ef|grep $OPID|grep -v grep|awk -F "ClassLoaderLogManager" '{print $2}'|awk -F "-Djdk" '{print $1}'`
		if [ -z "$jvm_opt" ];then
			echo "Process $OPID Tomcat JVM Options Info:Null"
		else
			echo "Process $OPID Tomcat JVM Options Info:"$jvm_opt
		fi
		echo "###############Process $OPID Tomcat Threads Info###############"
		if [[ -z $(echo $http_connector|grep minSpareThreads) ]];then
			min_threads=10
		else		
			min_threads=`echo $http_connector|awk -F "minSpareThreads=" '{print $2}'|awk '{print $1}'|tr -d '"'`
		fi
		
		if [[ -z $(echo $http_connector|grep maxThreads) ]];then
			max_threads=200
		else		
			max_threads=`echo $http_connector|awk -F "maxThreads=" '{print $2}'|awk '{print $1}'|tr -d '"'`
		fi
		
		if [[ -z $(echo $http_connector|grep acceptCount) ]];then
			accept_count=100
		else		
			accept_count=`echo $http_connector|awk -F "acceptCount=" '{print $2}'|awk '{print $1}'|tr -d '"'`
		fi
		open_threads=`ps  -Lf $OPID |wc -l`
		echo "minSpareThreads:"$min_threads
		echo "maxThreads:"$max_threads
		echo "acceptCount:"$accept_count
		echo "openThreads:"$open_threads
		
		echo "#################Process $OPID Tomcat JDBC Info#################"
		row_num=`cat -n $tempxml|grep -v "UserDatabase"|grep "<Resource"|awk '{print $1}'`
		if [ -z "$row_num" ];then
			echo "Process $OPID Tomcat JDBC Info:Null"
		else
			for i in $row_num; do
				a=0
				while :
				do
					b=`expr $i + $a`
					row_data=`sed -n ${b}p $tempxml`
					if [[ $row_data =~ "/>" ]];then
						jdbcinfo=`sed -n ''${i}','${b}'p' $tempxml`
						echo "Process $OPID Tomcat JDBC Info:"$jdbcinfo
						break
					else
						let a+=1
					fi
				done
			done
		fi
		
		echo "#########View Process $OPID Tomcat Applications Info#########"
		appbase=`cat $tomcat_path/conf/server.xml|grep appBase|awk -F '=' '{print $NF}'|tr -d '"'`
		if [[ $appbase =~ ^/.* ]];then
			echo "Process $OPID Tomcat AppDir:"$appbase
			if [ -e "$appbase" ];then
				ls -l $appbase
				app_name=`ls -l $appbase |awk '/^d/ {print $NF}'`
			else
				echo "$appbase Dir Doesn't Exist!"
				app_name="Null"
			fi
		else
			echo "Process $OPID Tomcat AppDir:"$tomcat_path/$appbase
			if [ -e "$tomcat_path/$appbase" ];then
				ls -l $tomcat_path/$appbase
				app_name=`ls -l $tomcat_path/$appbase|awk '/^d/ {print $NF}'`
			else
				echo "$tomcat_path/$appbase Dir Doesn't Exist!"
				app_name="Null"
			fi
		fi
		
		m=0
		app_array=()
		for i in $app_name; do
			if [[ $i != "ROOT" ]];then
				app_array[$m]=$i
				let m+=1
			else
				continue
			fi
		done
		echo "Process $OPID Tomcat Applications:${app_array[*]}"
		
		#安全基线检查
		echo "#################Process $OPID Tomcat Security Check#################"
		# 版本安全检查
		if [[ -n "$java_path" ]]; then
          tomcatbb=$($java_path -classpath "$tomcat_path/lib/catalina.jar" org.apache.catalina.util.ServerInfo | awk -F':' '/number/{print $2}'|tr -d " ")
        fi
		
		if [ -n "$tomcatbb" ];then
			echo "Process $OPID Tomcat Version Check Result:$tomcatbb"
			tomcatbb_num=$(echo $tomcatbb|awk '{print substr($1,1,3)}')
			ver_num=$(echo $tomcatbb|awk '{print substr($1,1,1)}')
			num_a=`echo "$tomcatbb_num >= 8.5"|bc`
			num_b=`echo "$tomcatbb_num <= 10"|bc`
			num_c=`echo "$tomcatbb_num >= 5.0"|bc`
			num_d=`echo "$tomcatbb_num <= 8.0"|bc`
			# 判断版本在8.5到10之间为通过
			if [[ $num_a -eq 1 && $num_b -eq 1 ]];then
				echo "Process $OPID Tomcat Version Check Conclusion:Pass"
			# 判断版本在5到8.0之间为不通过
			elif [[ $num_c -eq 1 && $num_d -eq 1 ]];then
				echo "Process $OPID Tomcat Version Check Conclusion:Failed"
			# 判断版本在5以下视为设置了版本隐藏，为通过
			elif [[ $ver_num -lt 5 ]];then
				echo "Process $OPID Tomcat Version Check Conclusion:Pass"
			fi
		else
			echo "Process $OPID Tomcat Version Check Result:Hide"
			echo "Process $OPID Tomcat Version Check Conclusion:Pass"
		fi

		# 进程启动用户检查
		echo "Process $OPID Tomcat RunUser Check Result:$run_user"
		if [[ $run_user = "root" ]];then
			echo "Process $OPID Tomcat RunUser Check Conclusion:Failed"
		else
			echo "Process $OPID Tomcat RunUser Check Conclusion:Pass"
		fi
		# 自带应用检查
		echo "Process $OPID Tomcat App Check Result:${app_array[*]}"
		if [[ ${app_array[*]} =~ "docs" || ${app_array[*]} =~ "examples" || ${app_array[*]} =~ "host-manager" ||${app_array[*]} =~ "manager" ]];then
			echo "Process $OPID Tomcat App Check Conclusion:Failed"
		else
			echo "Process $OPID Tomcat App Check Conclusion:Pass"
		fi
		# AJP端口检查
		ajp_check=`cat $tempxml|grep "<Connector"|grep "AJP"|xargs`
		if [[ -n $ajp_check ]];then
			echo "Process $OPID Tomcat AJP Check Result:"$ajp_check
			echo "Process $OPID Tomcat AJP Check Conclusion:Failed"
		else
			echo "Process $OPID Tomcat AJP Check Result:Null"
			echo "Process $OPID Tomcat AJP Check Conclusion:Pass"
		fi
		
		# AccessLog完备性检查
		log_check=`cat $tempxml|grep "pattern="|xargs`
		if [[ -n $log_check ]];then
			echo "Process $OPID Tomcat Accesslog Check Result:"$log_check
		else
			echo "Process $OPID Tomcat Accesslog Check Result:Null"
		fi
		log_check1=`cat $tempxml|grep "User-Agent"`
		log_check2=`cat $tempxml|grep "Referer"`
		if [[ -z $log_check1 || -z $log_check2 ]];then
			echo "Process $OPID Tomcat Accesslog Check Conclusion:Failed"
		else
			echo "Process $OPID Tomcat Accesslog Check Conclusion:Pass"
		fi
		# 用户锁定检查
		if [ -e $userxml ];then
			user_check=`sed 's/<!--.*-->//g' $userxml|sed -n '/<!--/,/-->/!p'|grep "username="|xargs`
			if [[ -n $user_check ]];then
				echo "Process $OPID Tomcat Userxml Check Result:"$user_check
				echo "Process $OPID Tomcat Userxml Check Conclusion:Failed"
			else
				echo "Process $OPID Tomcat Userxml Check Result:Null"
				echo "Process $OPID Tomcat Userxml Check Conclusion:Pass"
			fi
		else
			echo "Process $OPID Tomcat Userxml Check Result:Null" 
			echo "Process $OPID Tomcat Userxml Check Conclusion:Pass"
		fi

		# 禁止目录浏览检查
		list_check=`cat $webxml|grep -A1 ">listings<"|grep -v ">listings<"|awk -F ">" '{print $2}'|awk -F "<" '{print $1}'`
		if [[ -n $list_check ]];then
			echo "Process $OPID Tomcat Listings Check Result:"$list_check
			if [[ $list_check = "false" ]];then
				echo "Process $OPID Tomcat Listings Check Conclusion:Pass"
			else
				echo "Process $OPID Tomcat Listings Check Conclusion:Failed"
			fi
		else
			echo "Process $OPID Tomcat Listings Check Result:Null"
			echo "Process $OPID Tomcat Listings Check Conclusion:Pass"
		fi
		# 文件上传漏洞防御检查
		put_check=`cat $webxml |grep -A1 ">readonly<"|grep -v ">readonly<"|awk -F ">" '{print $2}'|awk -F "<" '{print $1}'`
		if [[ -n $put_check ]];then
			echo "Process $OPID Tomcat FilePut Check Result:"$put_check
			if [[ $put_check = "false" ]];then
				echo "Process $OPID Tomcat FilePut Check Conclusion:Pass"
			else
				echo "Process $OPID Tomcat FilePut Check Conclusion:Failed"
			fi
		else
			echo "Process $OPID Tomcat FilePut Check Result:Null"
			echo "Process $OPID Tomcat FilePut Check Conclusion:Failed"
		fi
		
		# DDOS防御
		ddos_check=`cat $tempxml|grep connectionTimeout|xargs|awk -F " " '{for(i=1;i<=NF;i++){print $i}}'|awk '/connectionTimeout=/'`
		if [[ -n $ddos_check ]];then
			echo "Process $OPID Tomcat TimeOut Check Result:"$ddos_check
			outnum=`echo $ddos_check|awk -F "=" '{print $2}'`
			if [[ $outnum -ge 20000 ]];then
				echo "Process $OPID Tomcat TimeOut Check Conclusion:Failed"
			else
				echo "Process $OPID Tomcat TimeOut Check Conclusion:Pass"
			fi
		else
			echo "Process $OPID Tomcat TimeOut Check Result:Null"
			echo "Process $OPID Tomcat TimeOut Check Conclusion:Failed"
		fi
		
		# 删除临时生成文件
		rm -f $tempxml
		echo "#############View Process $OPID Tomcat ResourceUsage###########"
		top -bn1 -p $OPID
		echo "#############View Process $OPID Tomcat ResourceUsageEND########"
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
		echo "######View Process $OPID Tomcat logging.properties Info######"
		cat $tomcat_path/conf/logging.properties
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

function get_tomcat_main(){
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
filename1=$HOSTNAME"_"tomcat"_"os_""$ipinfo"_"$qctime".txt"
collect_sys_info >> "$filepath""$filename1"

####get tomcat info
filename2=$HOSTNAME"_"tomcat"_"$ipinfo"_"$qctime".txt"
tomcat_info >> "$filepath""$filename2"

#tar -czvf /tmp/tmpcheck/"$HOSTNAME"_"tomcat"_"$type"_"$ipinfo"_"$qctime".tar.gz /tmp/tmpcheck

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
echo "Start performing Tomcat patrols！！！"
get_tomcat_main

# get os json data
data_path=/tmp/enmoResult/tmpcheck
function get_os_jsondata(){
    mkdir -p /tmp/enmoResult/tomcat
    new_data=/tmp/enmoResult/tomcat
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
    new_document=$new_data/tomcat_$ip.json
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

# get tomcat json data
function get_tomcat_jsondata(){
	new_data=/tmp/enmoResult/tomcat
	cd $data_path
	file1=$filename2
    ip_1=`ls $file1|awk -F "_" '{print $3}'`
    new_document=$new_data/tomcat_$ip_1.json
    tomcat_version=`cat $file1 |grep "Version Check Result:"|awk -F ":" '{print $2}'` && echo "\"tomcat_version\"":"\"$tomcat_version\"""," >> $new_document
    tomcat_home=`cat $file1|grep "Tomcat Install Dir:"|awk -F ':' '{print $NF}'` && echo "\"tomcat_home\"":"\"$tomcat_home\"""," >> $new_document
    tomcat_user=`cat $file1|grep "Tomcat RunUser:"|awk -F ":" '{print $2}'` && echo "\"tomcat_user\"":"\"$tomcat_user\"""," >> $new_document
    http_port=`cat $file1|grep "Tomcat HttpPort:"|awk -F ":" '{print $2}'` && echo "\"http_port\"":"\"$http_port\"""," >> $new_document
	shutdown_port=`cat $file1|grep "Tomcat ShutdownPort:"|awk -F ":" '{print $2}'` && echo "\"shutdown_port\"":"\"$shutdown_port\"""," >> $new_document
	jdk_version=`cat $file1|grep "JVM Version:"|grep -v log|awk -F ":" '{print $2}'|tr -d " "` && echo "\"jdk_version\"":"\"$jdk_version\"""," >> $new_document
	jdk_path=`cat $file1|grep "Tomcat JDK Dir:"|awk -F ":" '{print $NF}'` && echo "\"jdk_path\"":"\"$jdk_path\"""," >> $new_document
	jvm_options=`cat $file1|grep "JVM Options Info:"` && echo "\"jvm_options\"":"\"$jvm_options\"""," >> $new_document
	tomcat_app=`cat $file1|grep "Tomcat Applications:"` && echo "\"tomcat_app\"":"\"$tomcat_app\"""," >> $new_document
	tomcat_threads=`cat $file1|grep -A4 "Tomcat Threads Info"` && echo "\"tomcat_threads\"":"\"$tomcat_threads\"""," >> $new_document
	tomcat_jdbc=`cat $file1|grep "Tomcat JDBC Info:"|sed 's/\"//g'` && echo "\"tomcat_jdbc\"":"\"$tomcat_jdbc\"""," >> $new_document
	resource_use=`cat $file1|sed -n /ResourceUsage/,/ResourceUsageEND/p|grep -v "ResourceUsage"|grep -v "ResourceUsageEND"` && echo "\"resource_use\"":"\"$resource_use\"""," >> $new_document
	version_check=`cat $file1 |grep "Version Check Result:"|awk -F ":" '{print $2}'` && echo "\"version_check\"":"\"$version_check\"""," >> $new_document
	version_check_con=`cat $file1 |grep "Version Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"version_check_con\"":"\"$version_check_con\"""," >> $new_document
	runuser_check=`cat $file1 |grep "RunUser Check Result:"|awk -F ":" '{print $2}'` && echo "\"runuser_check\"":"\"$runuser_check\"""," >> $new_document
	runuser_check_con=`cat $file1 |grep "RunUser Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"runuser_check_con\"":"\"$runuser_check_con\"""," >> $new_document
	apps_check=`cat $file1|grep "App Check Result:"|awk -F ":" '{print $2}'` && echo "\"apps_check\"":"\"$apps_check\"""," >> $new_document
	apps_check_con=`cat $file1|grep "App Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"apps_check_con\"":"\"$apps_check_con\"""," >> $new_document
	ajp_check=`cat $file1 |grep "AJP Check Result:"|awk -F ":" '{print $2}'` && echo "\"ajp_check\"":"\"$ajp_check\"""," >> $new_document
	ajp_check_con=`cat $file1 |grep "AJP Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"ajp_check_con\"":"\"$ajp_check_con\"""," >> $new_document
	accesslog_check=`cat $file1 |grep "Accesslog Check Result:"|awk -F ":" '{print $2}'` && echo "\"accesslog_check\"":"\"$accesslog_check\"""," >> $new_document
	accesslog_check_con=`cat $file1 |grep "Accesslog Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"accesslog_check_con\"":"\"$accesslog_check_con\"""," >> $new_document
	userxml_check=`cat $file1 |grep "Userxml Check Result:"|awk -F ":" '{print $2}'` && echo "\"userxml_check\"":"\"$userxml_check\"""," >> $new_document
	userxml_check_con=`cat $file1 |grep "Userxml Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"userxml_check_con\"":"\"$userxml_check_con\"""," >> $new_document
	list_check=`cat $file1 |grep "Listings Check Result:"|awk -F ":" '{print $2}'` && echo "\"list_check\"":"\"$list_check\"""," >> $new_document
	list_check_con=`cat $file1 |grep "Listings Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"list_check_con\"":"\"$list_check_con\"""," >> $new_document
	fileput_check=`cat $file1 |grep "FilePut Check Result:"|awk -F ":" '{print $2}'` && echo "\"fileput_check\"":"\"$fileput_check\"""," >> $new_document
	fileput_check_con=`cat $file1 |grep "FilePut Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"fileput_check_con\"":"\"$fileput_check_con\"""," >> $new_document
	timeout_check=`cat $file1 |grep "TimeOut Check Result:"|awk -F ":" '{print $2}'` && echo "\"timeout_check\"":"\"$timeout_check\"""," >> $new_document
	timeout_check_con=`cat $file1 |grep "TimeOut Check Conclusion:"|awk -F ":" '{print $2}'` && echo "\"timeout_check_con\"":"\"$timeout_check_con\"""," >> $new_document
	error1=`cat $file1|grep -A10 "OutOfMemoryError:"`
	error2=`cat $file1|grep -A10 "ERROR:"`
	error3=`cat $file1|grep -A10 "Caused by:"`
	error4=`cat $file1|grep -A10 "Too Many Open Files"`
	error5=`cat $file1|grep -A10 "java.lang.*Exception"`
	tomcat_log=`echo -e "${error2}\n${error3}\n${error5}\n${error4}\n${error1}"`
	if [[ -z ${tomcat_log} ]]
	then
		echo "\"tomcat_log\"":"\"日志无异常。\"" >> $new_document
	else
		echo "\"tomcat_log\"":"\"$tomcat_log\"" >> $new_document
	fi

}

echo "Start Tomcat Date Extraction!!!"
get_os_jsondata
get_tomcat_jsondata
tar -zcf /tmp/enmoResult/"$HOSTNAME"_"tomcat"_"$ipinfo"_"$qctime".tar.gz --exclude=/tmp/enmoResult/*.tar.gz /tmp/enmoResult/*  --format=ustar