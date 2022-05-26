#!/bin/bash
#version:1.7
#monitor:kafka/zk/rabbitmq/rocketmq/redis/es/os
#update：tomcat
#update: weblogic
#update: 1、zookeeper巡检，没有做日志检查，需要对日志做一些类似“error”等关键字检查
#        2、新增对redis启动运行日志中的error关键字进行检索
#        3、rabbitmq不允许拷贝所有日志，建议根据关键字筛选并输出到指定文件
#        4、nginx
#update：apache、keepalive、activemq
#update-date:2022-03-04

#----------------------------------------OS层数据采集------------------------------------------------
function collect_sys_info(){

    echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
	echo "|                      os info                            |"
	echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
	echo ""

	echo "----->>>---->>>  hostname"
	hostname -s
	echo ""
	echo "----->>>---->>>  os kernal"
	uname -a
	echo ""
	echo "----->>>---->>>  ip info"
	ifconfig
	echo ""
	echo "----->>>---->>>  mem info"
	cat /proc/meminfo
	echo "the value:"
	awk '($1 == "MemTotal:"){printf ("%.2f",$2/1024/1024)}' /proc/meminfo
	echo ""
	echo "----->>>---->>>  mem usage: "
	free -m
	echo ""
	vmstat 2 10
	echo ""
	echo "----->>>---->>>  CPU cores"
	cat /proc/cpuinfo| grep "processor"| wc -l
	echo ""
	echo "----->>>---->>>  CPU usage: "
	sar 2 10
	echo ""
	echo "----->>>---->>>  resource limit"
	ulimit -a
	echo ""
	cat /etc/security/limits.conf
	echo ""
	echo "----->>>---->>>  swap method"
	cat /proc/sys/vm/swappiness
	echo ""
	echo "----->>>---->>>  io scheduler"
	dmesg | grep -i scheduler
	echo ""

	echo "----->>>---->>>  io usage"
	iostat -x -k 5 3
	echo ""

	echo "----->>>---->>>  disk mount "
	df -HT
	echo ""
	echo "----->>>---->>>  dist type "
	lsblk -d -o name,rota
	echo ""
	echo -e "\n"

	echo "----->>>---->>>  ps detail "
	ps -ef | grep redis
	echo ""
	echo -e "\n"
	ps -ef | grep java|grep kafka
	echo ""
	echo -e "\n"
	ps -ef | grep java|grep zookeeper
	echo ""
	echo -e "\n"
	ps -ef | grep java|grep tomcat
	echo ""
	echo -e "\n"
	ps -ef | grep rabbitmq
	echo ""
	echo -e "\n"
	ps -ef | grep rocketmq
	echo ""
	echo -e "\n"
	ps -ef | grep elasticsearch
	echo ""
	echo -e "\n"
	ps -ef | grep java |grep weblogic.Server
	echo ""
	echo -e "\n"
	ps -ef |grep httpd
	echo ""
	echo -e "\n"
	ps -ef |grep nginx
	echo ""
	echo -e "\n"
	ps -ef |grep java |grep activemq.jar
	echo ""
	echo -e "\n"
	ps -ef | grep java |grep Dwas.install.root
	echo ""
	echo -e "\n"

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



#获取内核参数
function getkernel()
{
    	shmall=`cat /proc/sys/kernel/shmall`
    	shmmni=`cat /proc/sys/kernel/shmmni`
    	shmmax=`cat /proc/sys/kernel/shmmax`
    	msgmax=`cat /proc/sys/kernel/msgmax`
    	msgmni=`cat /proc/sys/kernel/msgmni`               
    	msgmnb=`cat /proc/sys/kernel/msgmnb`

    	echo \""shmall\":\"$shmall"\",	    	
    	echo \""shmmni\":\"$shmmni"\",	    	
    	echo \""shmmax\":\"$shmmax"\",	    	
    	echo \""msgmax\":\"$msgmax"\",	    	
    	echo \""msgmni\":\"$msgmni"\",	    	
    	echo \""msgmnb\":\"$msgmnb"\",	    	
    	
    	
    	sysctl -a |grep 'kernel.sem '  >./tmp.txt
	    semmsl=`cat tmp.txt |grep kernel.sem |awk {'print $3'}`
    	echo \""semmsl\":\"$semmsl"\",	    	
	    semmns=`cat tmp.txt |grep kernel.sem |awk {'print $4'}`
    	echo \""semmns\":\"$semmns"\",	    	
	    semopm=`cat tmp.txt |grep kernel.sem |awk {'print $5'}`
    	echo \""semopm\":\"$semopm"\",	    	
	    semmni=`cat tmp.txt |grep kernel.sem |awk {'print $6'}`
    	echo \""semmni\":\"$semmni"\",	
}


#----------------------------------------tuxedo info------------------------------------------------
function tuxedo_info(){
  #format
  #{
  #"yjt": "boy",
  #"age": 20
  #}  
  #echo \""ip\":\"$ipinfo"\",
  #echo -e \""ip\":\"$ipinfo"\",
	echo "{"
	#ps -ef | grep java |grep Dwas.install.root

  #get os json
  #get os json
  # Check OS Type
    IP_Address=$(ip addr show |grep 'state UP' -A 2| grep "inet " |grep -v 127.0.0. |head -1|cut -d" " -f6|cut -d/ -f1)
    echo -e \""IP\":\"$IP_Address"\",
    Hostname=$(hostname -s)
    echo -e \""Hostname\":\"$Hostname"\",
    
    Architecture=$(getconf LONG_BIT)
    echo -e \""Architecture\":\"$Architecture"\",
    
    Kernel_Release=$(uname -r)
    echo -e \""Kernel_Release\":\"$Kernel_Release"\",
    
    Physical_Memory=$(sudo dmidecode | grep "^[[:space:]]*Size.*MB$" | uniq -c | sed 's/ \t*Size: /\*/g' | sed 's/^ *//g')
    echo -e \""Physical_Memory\":\"$Physical_Memory"\",
    
    Cpu_Cores=$(cat /proc/cpuinfo | grep "cpu cores" | uniq | awk -F ': ' '{print $2}')
    echo -e \""Cpu_Cores\":\"$Cpu_Cores"\",
    
    Cpu_Proc_Num=$(cat /proc/cpuinfo | grep "processor" | uniq | wc -l)
    echo -e \""Cpu_Proc_Num\":\"$Cpu_Proc_Num"\",
    
    LastReboot=$(who -b | awk '{print $3,$4}')
    echo -e \""LastReboot\":\"$LastReboot"\",
    
    Uptime=$(uptime | sed 's/.*up \([^,]*\), .*/\1/')
    echo -e \""Uptime\":\"$Uptime"\",
    
    Load=$(uptime |awk -F ":" '{print $NF}')
    echo -e \""Load\":\"$Load"\",
    
    MemTotal=$(cat /proc/meminfo | awk '/^MemTotal/{print $2}') #内存总量
    echo -e \""MemTotal\":\"$(convert_unit $MemTotal)"\",
    
    MemFree=$(cat /proc/meminfo | awk '/^MemFree/{print $2}')   #空闲内存
    echo -e \""MemFree\":\"$(convert_unit $MemFree)"\",
    
    MemBuffers=$(cat /proc/meminfo | awk '/^Buffers/{print $2}')   #Buffers
    MemCached=$(cat /proc/meminfo | awk '/^Cached/{print $2}')   #Cached
    MemUsed=$(expr $MemTotal - $MemFree - $MemBuffers - $MemCached)  #已用内存
    echo -e \""MemUsed\":\"$(convert_unit $MemUsed)"\",
    
    Mem_Rate=$(awk 'BEGIN{printf"%.2f\n",'$MemUsed' / '$MemTotal' *100}') #保留小数点后2位
    echo -e \""Mem_Rate\":\"$Mem_Rate"\",
    
    Swap_Method=$(cat /proc/sys/vm/swappiness)
    Openfile=$(ulimit -a|grep "open files"|awk '{print $NF}')
    echo -e \""Openfile\":\"$Openfile"\",
    
    echo -e \""Swap_Method\":\"$Swap_Method"\",
    
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
     echo -e \""Totalsum\":\"$Totalsum K"\",

    elif [ $Totalsum -gt 1024 -a  $Totalsum -lt 1048576 ];then  
	   Totalsum=$(awk 'BEGIN{printf"%.2f\n",'$Totalsum' / 1024}')
     echo -e \""Totalsum\":\"$Totalsum M"\",

    elif [ $Totalsum -gt 1048576 ];then 
	   Totalsum=$(awk 'BEGIN{printf"%.2f\n",'$Totalsum' / 1048576}')
     echo -e \""Totalsum\":\"$Totalsum G"\",

    fi

    #磁盘已使用总量
    if [ $Usesum -ge 0 -a $Usesum -lt 1024 ];then
    echo -e \""Usesum\":\"$Usesum K"\",

    elif [ $Usesum -gt 1024 -a  $Usesum -lt 1048576 ];then  
	   Usesum=$(awk 'BEGIN{printf"%.2f\n",'$Usesum' / 1024}')
     echo -e \""Usesum\":\"$Usesum M"\",

    elif [ $Usesum -gt 1048576 ];then   
	   Usesum=$(awk 'BEGIN{printf"%.2f\n",'$Usesum' / 1048576}')
     echo -e \""Usesum\":\"$Usesum G"\",

    fi  

    #磁盘未使用总量
    if [ $Freesum -ge 0 -a $Freesum -lt 1024 ];then
    echo -e \""Freesum\":\"$Freesum K"\",

    elif [ $Freesum -gt 1024 -a  $Freesum -lt 1048576 ];then    
	   Freesum=$(awk 'BEGIN{printf"%.2f\n",'$Freesum' / 1024}')
     echo -e \""Freesum\":\"$Freesum M"\",

    elif [ $Freesum -gt 1048576 ];then  
	   Freesum=$(awk 'BEGIN{printf"%.2f\n",'$Freesum' / 1048576}')
     echo -e \""Freesum\":\"$Freesum G"\",
    
    fi  
    #磁盘占用率
    echo -e \""Diskutil\":\"$Diskutil%"\",

    #磁盘空闲率
    echo -e \""Freeutil\":\"$Freeutil%"\",

    #
    IO_User=$(iostat -x -k 2 1 |tail -6|grep -v Device:|grep -v vda|grep -v avg|awk -F " " '{print $2}')
    IO_System=$(iostat -x -k 2 1 |tail -6|grep -v Device:|grep -v vda|grep -v avg|awk -F " " '{print $4}')
    IO_Wait=$(iostat -x -k 2 1 |tail -6|grep -v Device:|grep -v vda|grep -v avg|awk -F " " '{print $5}')
    IO_Idle=$(iostat -x -k 2 1 |tail -6|grep -v Device:|grep -v vda|grep -v avg|awk -F " " '{print $NF}')

    
    echo -e \""IO_User\":\"$IO_User%"\",
    echo -e \""IO_System\":\"$IO_System%"\",
    echo -e \""IO_Wait\":\"$IO_Wait%"\",
    echo -e \""IO_Idle\":\"$IO_Idle%"\",
    
    #TCP参数获取
    #Tcp_Tw_Recycle=$(sysctl net.ipv4.tcp_tw_recycle |awk -F "=" '{print $2}')
    #Linux 从4.12内核版本开始移除了 tcp_tw_recycle 配置
    if [[ ! -f "/proc/sys/net/ipv4/tcp_tw_recycle" ]]; then
     Tcp_Tw_Recycle="-"
    else
     Tcp_Tw_Recycle=`cat /proc/sys/net/ipv4/tcp_tw_recycle`
    fi


    #该参数的作用是快速回收timewait状态的连接。上面虽然提到系统会自动删除掉timewait状态的连接，但如果把这样的连接重新利用起来岂不是更好。
    #所以该参数设置为1就可以让timewait状态的连接快速回收，它需要和下面的参数配合一起使用
    Tcp_Tw_Reuse=$(sysctl net.ipv4.tcp_tw_reuse|awk -F "=" '{print $2}')
    #该参数设置为1，将timewait状态的连接重新用于新的TCP连接，要结合上面的参数一起使用。
    Tcp_Fin_Timeout=$(sysctl net.ipv4.tcp_fin_timeout|awk -F "=" '{print $2}')
    #tcp连接的状态中，客户端上有一个是FIN-WAIT-2状态，它是状态变迁为timewait前一个状态。
    #该参数定义不属于任何进程该连接状态的超时时间，默认值为60，建议调整为6。
    Tcp_Keepalive_Time=$(sysctl net.ipv4.tcp_keepalive_time|awk -F "=" '{print $2}')
    #表示当keepalive起用的时候，TCP发送keepalive消息的频度。缺省是2小时，改为30分钟。
    Tcp_Keepalive_Probes=$(sysctl net.ipv4.tcp_keepalive_probes|awk -F "=" '{print $2}')
    #如果对方不予应答，探测包的发送次数
    Tcp_Keepalive_Intvl=$(sysctl net.ipv4.tcp_keepalive_intvl|awk -F "=" '{print $2}')
    #keepalive探测包的发送间隔
    
    echo -e \""Tcp_Tw_Recycle\":\"$Tcp_Tw_Recycle"\",
    echo -e \""Tcp_Tw_Reuse\":\"$Tcp_Tw_Reuse"\",
    echo -e \""Tcp_Fin_Timeout\":\"$Tcp_Fin_Timeout"\",
    echo -e \""Tcp_Keepalive_Time\":\"$Tcp_Keepalive_Time"\",
    echo -e \""Tcp_Keepalive_Probes\":\"$Tcp_Keepalive_Probes"\",
    echo -e \""Tcp_Keepalive_Intvl\":\"$Tcp_Keepalive_Intvl"\",
    echo -e \""Disk_Usages\":\n\"`df -h`"\",  
	

	PIDCOUNT=`ps -ef |grep BBL |grep -v grep| awk ' { print $2 }' |wc -l `

	PID=`ps -ef |grep BBL |grep -v grep| awk ' { print $2 }' `
	init=0
	#"tuxedopid": [
	#echo \"ip\": [
	echo \"tuxedopid\": [
	for OPID in $PID; 
	do
	    echo "{"
	    echo \""ip\":\"$ipinfo"\",
	    
	    
	    version=`tmadmin -v 2>&1 |grep Tuxedo`
    	echo \""version\":\"$version"\",
      startuser=`ps -ef |grep BBL |grep -v grep |awk '{print $1}'` 
      echo \""startuser\":\"$startuser"\",		
	    TUX_CONFIG=`tmunloadcf |grep  TUXCONFIG  |awk -F '=' '{print $NF}'`
    	echo \""TUX_CONFIG\":$TUX_CONFIG",
	    TUX_DIR=`tmunloadcf |grep  TUXDIR  |awk -F '=' '{print $NF}'`
    	echo \""TUX_DIR\":$TUX_DIR",
	    APP_DIR=`tmunloadcf |grep  APPDIR  |awk -F '=' '{print $NF}'`
    	echo \""APP_DIR\":$APP_DIR",
	    MASTER=`tmunloadcf |grep  MASTER |awk '{print $NF}'`
    	echo \""MASTER\":$MASTER",
    	
    	
	    MODEL=`tmunloadcf |grep  MODEL |awk  '{print $NF}'`
    	echo \""MODEL\":\"$MODEL"\",
    	
    	
	    MAXACCESSERS=`tmunloadcf |grep  MAXACCESSERS |awk  '{print $NF}'`
    	echo \""MAXACCESSERS\":\"$MAXACCESSERS"\",
	    MAXQUEUES=`tmunloadcf |grep  MAXQUEUES |awk  '{print $NF}'`
    	echo \""MAXQUEUES\":\"$MAXQUEUES"\",
	    MAXSERVERS=`tmunloadcf |grep  MAXSERVERS |awk  '{print $NF}'`
    	echo \""MAXSERVERS\":\"$MAXSERVERS"\",
	    MAXSERVICES=`tmunloadcf |grep  MAXSERVICES |awk  '{print $NF}'`
    	echo \""MAXSERVICES\":\"$MAXSERVICES"\",
	    BLOCKTIME=`tmunloadcf |grep  BLOCKTIME |awk  '{print $NF}'`
    	echo \""BLOCKTIME\":\"$BLOCKTIME"\",
	    SCANUNIT=`tmunloadcf |grep  SCANUNIT |awk  '{print $NF}'`
    	echo \""SCANUNIT\":\"$SCANUNIT"\",
	    MAXWSCLIENTS=`tmunloadcf |grep  MAXWSCLIENTS|awk -F '='  '{print $NF}'`
    	echo \""MAXWSCLIENTS\":\"$MAXWSCLIENTS"\",    	
    	 


      getkernel
      
      #是否启动jolt
      jolt=`ps -ef |grep JREPSVR  |grep -v grep |wc -l`
      if [ $jolt -eq 1 ]; then
      	jolt='启用'
      else
        jolt='没启用'	
      fi
    	echo \""jolt\":\"$jolt"\",
    	
    	      
      echo psr | tmadmin >./tmp
      #去除前面3行
      cat tmp |tail -n +4 >tmp1
 
      #按第5列降序,显示前10行
      sort -n -k5  -r tmp1  | head -n 10 > tmp
      #前面插入3行,第一行空行
      sed -i '1s/^/---------      ----------  --------      -- ------ --------- ---------------\n/' tmp
      sed -i '1s/^/> Prog Name      Queue Name  Grp Name      ID RqDone Load Done Current Service\n/' tmp
      sed -i '1s/^/\n/' tmp
      
      #replace : >  = 出错
      #replace : >  -
	    psr=`cat tmp|tr ":" "-"`
    	echo \""psr\":\"$psr"\",                
    
    
      echo psc | tmadmin >./tmp       
	    psc=`cat tmp|tr ":" "-"`
    	echo \""psc\":\"$psc"\",                
      #>0的队列  
      echo pq |tmadmin |awk '$5!="0"' >./tmp      
       
	    pq=`cat tmp|tr ":" "-"`
    	echo \""pq\":\"$pq"\",                


      echo bbs | tmadmin >./tmp       
	    bbs=`cat tmp|tr ":" "-"`
    	echo \""bbs\":\"$bbs"\",                


      echo printclient | tmadmin >./tmp       
	    printclient=`cat tmp |tr ":" "-"`
    	echo \""printclient\":\"$printclient"\",



      ULOGPFX=`ps -ef |grep BBL |grep -v grep | sed 's/.*-U//g' | awk '{print $1}' | sed 's/ULOG//g'`
      cd $ULOGPFX
      
      #count column 
      # get first line
      column=`ls -lt |grep ULOG|head -1 |awk '{print NF}'`
       

      #\ really . 
      if [ $column -eq 9 ]; then
       filelist=`ls -lt ./ |grep ULOG|awk '{print $9}'`
      fi
      
      if [ $column -eq 8 ]; then
       filelist=`ls -lt ./ |grep ULOG|awk '{print $8}'`
      fi
      
      

      
      count=0
      for file in $filelist
      do 
        errorlog=`cat $file |grep -i error |tr ":" "-" |tr "\"" "&"` 
        echo \""errorlog\":\"$errorlog"\"      
       ((count +=1))
       break
      
      done



	    init=`expr $init + 1`;
	    #lt <
      echo "}"
	    [ $init -lt $PIDCOUNT ] && echo ","

	done
  echo "]"
  echo "}"

}

#was主函数
function get_tuxedo_main() {

####check /tmp/tmpcheck Is empty
tmpcheck_dir="/tmp/tmpcheck"
if [ "$(ls -A $tmpcheck_dir)" ];then  
    echo "$tmpcheck_dir is not empty!!!"
    rm -rf $tmpcheck_dir/*
    echo "clean $tmpcheck_dir !!!"
else    
    echo "$tmpcheck_dir is empty!!!"
fi

####get system info
filename1=$HOSTNAME"_"$name"_"$type"_"os_""$ipinfo"_"$qctime".txt"
#collect_sys_info >> "$filepath""$filename1"

####get tuxedo info
filename2=$HOSTNAME"_"$name"_"$type"_"$ipinfo"_"$qctime".txt"
qctime=$(date +'%Y%m%d%H%M%S')
tuxedo_info >> "$filepath""$filename2"
tar -czvf /tmp/tmpcheck/"$HOSTNAME"_"$name"_"$type"_"$ipinfo"_"$qctime".tar.gz /tmp/tmpcheck

echo -e "___________________"
echo -e "Collection info Finished."
echo -e "Result File Path:" $filepath
echo -e "\n"
cd /tmp/tmpcheck
}
#----------------------------------------END------------------------------------------------
######################Main##########################
filepath="/tmp/tmpcheck/"
excmkdir=$(which mkdir  | awk 'NR==1{print}'  )

$excmkdir -p   $filepath

qctime=$(date +'%Y%m%d%H%M%S')
ipinfo=`ip addr show |grep 'state UP' -A 2| grep "inet " |grep -v 127.0.0. |head -1|cut -d" " -f6|cut -d/ -f1`

echo "###########################################"
cat <<EOF
    Example System name:
    oa
    pmp
    ..
EOF
echo "###########################################"

read -p "Please input your check system name:"  name

echo "###########################################"
cat <<EOF
    Script support Middleware type:
        kafka
        zookeeper
        tuxedo
        rabbitmq
        rocketmq
        redis
        es
        tomcat
        wls
        was
        nginx
	    apache
	    keepalived
	    activemq
        quit
EOF
echo "###########################################"
read -p "Please input your check middleware type:" type

echo "当前服务器IP地址为\(供参考\)："$ipinfo
echo "当前服务器Listener端口为\(供参考\):" 
netstat -anpt|grep LISTEN|grep  :::*
echo "当前服务器进程\（供参考\）："
ps -aux
echo "###########################################"
case "${type}" in
    kafka)
        echo "Start performing kafka patrols！！！"
        get_kafka_main
    ;;
    zookeeper)
        echo "Start performing zookeeper patrols！！！"
        get_zookeeper_main
    ;;
    rabbitmq)
        echo "Start performing rabbitmq patrols！！！"
        get_rabbitmq_main
    ;;
    was)
        echo "Start performing was patrols！！！"
        get_tuxedo_main    
    ;;    
    rocketmq)
        echo "Start performing rocketmq patrols！！！"
        get_rocketmq_main
    ;;
    redis)
        echo "Start performing redis patrols！！！"
        get_redis_main
    ;;
    es)
        echo "Start performing es patrols！！！"
        get_es_main
    ;;
    tomcat)
        echo "Start performing tomcat patrols！！！"
        get_tomcat_main
    ;;
    wls)
        echo "Start performing tomcat patrols！！！"
        get_weblogic_main
    ;;
    nginx)
        echo "Start performing nginx patrols！！！"
        get_nginx_main
    ;;
	apache)
        echo "Start performing apache patrols！！！"
        get_apache_main
    ;;
	tuxedo)
        echo "Start performing tuxedo patrols！！！"
        get_tuxedo_main
    ;;    
	keepalived)
        echo "Start performing apache patrols！！！"
        get_keepalived_main
    ;;
	activemq)
    	echo "Start performing activemq patrols！！！"
    	get_activemq_main
    ;;
    quit)
        echo "Quit！！！"
        break
    ;;
    *)
        echo "default \(none of above\)"
        break
    ;;
esac
