#!/bin/bash
#version:2.3
#monitor:websphere/os
#update:1、Physical_Memory值的获取方式；2、新增SystemOut.log位置展示；3、对平台数据异常进行修正
#update-date:2022-11-02

#用于获取os信息
function collect_sys_info() {
    IP_Address=$(ip addr show | grep 'state UP' -A 2 | grep "inet " | grep -v 127.0.0. | head -1 | cut -d" " -f6 | cut -d/ -f1)
    echo -e \""IP\":\"$IP_Address"\",
    Hostname=$(hostname -s)
    echo -e \""Hostname\":\"$Hostname"\",
    Architecture=$(getconf LONG_BIT)
    echo -e \""Architecture\":\"$Architecture"\",
    Kernel_Release=$(uname -r)
    echo -e \""Kernel_Release\":\"$Kernel_Release"\",
    Cpu_Cores=$(cat /proc/cpuinfo | grep "cpu cores" | uniq | awk -F ': ' '{print $2}')
    echo -e \""Cpu_Cores\":\"$Cpu_Cores"\",
    Cpu_Proc_Num=$(cat /proc/cpuinfo | grep "processor" | uniq | wc -l)
    echo -e \""Cpu_Proc_Num\":\"$Cpu_Proc_Num"\",
    LastReboot=$(who -b | awk '{print $3,$4}')
    echo -e \""LastReboot\":\"$LastReboot"\",
    Uptime=$(uptime | sed 's/.*up \([^,]*\), .*/\1/'|sed 's/^[ ]*//g')
    echo -e \""Uptime\":\"$Uptime"\",
    Load=$(uptime | awk -F ":" '{print $NF}')
    echo -e \""Load\":\"$Load"\",
    MemTotal=$(cat /proc/meminfo | awk '/^MemTotal/{print $2}') #内存总量
    if [ $MemTotal -ge "1048576" ]; then
        memTotalReal01=$(convert_unit $MemTotal)
        echo -e \""MemTotal\":\"$memTotalReal01"\",
        memTotalReal=$((${memTotalReal01//.*/+1}))
        ###根据memTotalReal确定Physical_Memory物理内存
        Physical_Memory=$(expr $memTotalReal \* 1024)M
        echo -e \""Physical_Memory\":\"$Physical_Memory"\",
    fi

    MemFree=$(cat /proc/meminfo | awk '/^MemFree/{print $2}') #空闲内存
    echo -e \""MemFree\":\"$(convert_unit $MemFree)"\",
    MemBuffers=$(cat /proc/meminfo | awk '/^Buffers/{print $2}')    #Buffers
    MemCached=$(cat /proc/meminfo | awk '/^Cached/{print $2}')      #Cached
    MemUsed=$(expr $MemTotal - $MemFree - $MemBuffers - $MemCached) #已用内存
    echo -e \""MemUsed\":\"$(convert_unit $MemUsed)"\",
    Mem_Rate=$(awk 'BEGIN{printf"%.2f\n",'$MemUsed' / '$MemTotal' *100}') #保留小数点后2位
    echo -e \""Mem_Rate\":\"$Mem_Rate"\",
    Swap_Method=$(cat /proc/sys/vm/swappiness)
    Openfile=$(ulimit -a | grep "open files" | awk '{print $NF}')
    echo -e \""Openfile\":\"$Openfile"\",
    
    echo -e \""Swap_Method\":\"$Swap_Method"\",    

    #磁盘空间，过滤tmpfs，boot，overlay(docker文件系统)，iso（挂载的iso镜像文件）
    diskinfo=$(df -h |grep -v 'tmpfs'|grep -v 'boot' |grep -v 'overlay' |grep -v 'iso')
    echo -e \""diskinfo\":\"$diskinfo%"\",
    #
    iostat=$(which iostat)
    iostat_status=$(echo $?)
    if [ $iostat_status -eq 0 ]; then
        IO_User=$(iostat -x -k 2 1 | grep -1 avg | grep -v avg | grep -v ^$ | awk -F ' ' 'NR==1{print $1}')
        IO_System=$(iostat -x -k 2 1 | grep -1 avg | grep -v avg | grep -v ^$ | awk -F ' ' 'NR==1{print $4}')
        IO_Wait=$(iostat -x -k 2 1 | grep -1 avg | grep -v avg | grep -v ^$ | awk -F ' ' 'NR==1{print $4}')
        IO_Idle=$(iostat -x -k 2 1 | grep -1 avg | grep -v avg | grep -v ^$ | awk -F ' ' 'NR==1{print $NF}')
        echo -e \""IO_User\":\"$IO_User%"\",
        echo -e \""IO_System\":\"$IO_System%"\",
        echo -e \""IO_Wait\":\"$IO_Wait%"\",
        echo -e \""IO_Idle\":\"$IO_Idle%"\",
    else
        IO_User=$(top -n1 | fgrep "Cpu(s)" | tail -1 | awk -F ' ' '{print $2}')
        IO_System=$(top -n1 | fgrep "Cpu(s)" | tail -1 | awk -F ' ' '{print $4}')
        IO_Wait=$(top -n1 | fgrep "Cpu(s)" | tail -1 | awk -F ' ' '{print $10}')
        IO_Idle=$(top -n1 | fgrep "Cpu(s)" | tail -1 | awk -F ' ' '{print $8}')
        echo -e \""IO_User\":\"$IO_User%"\",
        echo -e \""IO_System\":\"$IO_System%"\",
        echo -e \""IO_Wait\":\"$IO_Wait%"\",
        echo -e \""IO_Idle\":\"$IO_Idle%"\",
    fi
    #TCP参数获取
    #Tcp_Tw_Recycle=$(sysctl net.ipv4.tcp_tw_recycle |awk -F "=" '{print $2}')
    #Linux 从4.12内核版本开始移除了 tcp_tw_recycle 配置
    if [[ ! -f "/proc/sys/net/ipv4/tcp_tw_recycle" ]]; then
     Tcp_Tw_Recycle="-"
    else
     Tcp_Tw_Recycle=`cat /proc/sys/net/ipv4/tcp_tw_recycle`
    fi
    sysctlconf="/etc/sysctl.conf"
    if [ ! -e $sysctlconf ];then
       #该参数的作用是快速回收timewait状态的连接。上面虽然提到系统会自动删除掉timewait状态的连接，但如果把这样的连接重新利用起来岂不是更好。
       #所以该参数设置为1就可以让timewait状态的连接快速回收，它需要和下面的参数配合一起使用
       Tcp_Tw_Reuse=$(sysctl net.ipv4.tcp_tw_reuse | awk -F "=" '{print $2}')
       #该参数设置为1，将timewait状态的连接重新用于新的TCP连接，要结合上面的参数一起使用。
       Tcp_Fin_Timeout=$(sysctl net.ipv4.tcp_fin_timeout | awk -F "=" '{print $2}')
       #tcp连接的状态中，客户端上有一个是FIN-WAIT-2状态，它是状态变迁为timewait前一个状态。
       #该参数定义不属于任何进程该连接状态的超时时间，默认值为60，建议调整为6。
       Tcp_Keepalive_Time=$(sysctl net.ipv4.tcp_keepalive_time | awk -F "=" '{print $2}')
       #表示当keepalive起用的时候，TCP发送keepalive消息的频度。缺省是2小时，改为30分钟。
       Tcp_Keepalive_Probes=$(sysctl net.ipv4.tcp_keepalive_probes | awk -F "=" '{print $2}')
       #如果对方不予应答，探测包的发送次数
       Tcp_Keepalive_Intvl=$(sysctl net.ipv4.tcp_keepalive_intvl | awk -F "=" '{print $2}')
       #keepalive探测包的发送间隔
       echo -e \""Tcp_Tw_Recycle\":\"$Tcp_Tw_Recycle"\",
       echo -e \""Tcp_Tw_Reuse\":\"$Tcp_Tw_Reuse"\",
       echo -e \""Tcp_Fin_Timeout\":\"$Tcp_Fin_Timeout"\",
       echo -e \""Tcp_Keepalive_Time\":\"$Tcp_Keepalive_Time"\",
       echo -e \""Tcp_Keepalive_Probes\":\"$Tcp_Keepalive_Probes"\",
       echo -e \""Tcp_Keepalive_Intvl\":\"$Tcp_Keepalive_Intvl"\",
       echo -e \""Disk_Usages\":\n\"`df -h`"\",  
    else 
       #该参数的作用是快速回收timewait状态的连接。上面虽然提到系统会自动删除掉timewait状态的连接，但如果把这样的连接重新利用起来岂不是更好。
       #所以该参数设置为1就可以让timewait状态的连接快速回收，它需要和下面的参数配合一起使用
       Tcp_Tw_Reuse1=$(grep -v ^# $sysctlconf|grep 'net.ipv4.tcp_tw_reuse' | awk -F "=" '{print $2}')
       if [ ${#Tcp_Tw_Reuse1} -eq 0 ];then
	  echo -e \""Tcp_Tw_Reuse\":\"0"\",
       else
          echo -e \""Tcp_Tw_Reuse\":\"$Tcp_Tw_Reuse1"\",
       fi
       #该参数设置为1，将timewait状态的连接重新用于新的TCP连接，要结合上面的参数一起使用。
       Tcp_Fin_Timeout1=$(grep -v ^# $sysctlconf|grep 'net.ipv4.tcp_fin_timeout' | awk -F "=" '{print $2}')

       if [ ${#Tcp_Fin_Timeout1} -eq 0 ];then
          echo -e \""Tcp_Fin_Timeout\":\"60"\",
       else
          echo -e \""Tcp_Fin_Timeout\":\"$Tcp_Fin_Timeout1"\",
       fi
       #tcp连接的状态中，客户端上有一个是FIN-WAIT-2状态，它是状态变迁为timewait前一个状态。
       #该参数定义不属于任何进程该连接状态的超时时间，默认值为60，建议调整为6。
       Tcp_Keepalive_Time1=$(grep -v ^# $sysctlconf|grep 'net.ipv4.tcp_keepalive_time' | awk -F "=" '{print $2}')

       if [ ${#Tcp_Keepalive_Time1} -eq 0 ];then
          echo -e \""Tcp_Keepalive_Time\":\"7200"\",
       else
          echo -e \""Tcp_Keepalive_Time\":\"$Tcp_Keepalive_Time1"\",
       fi
       #表示当keepalive起用的时候，TCP发送keepalive消息的频度。缺省是2小时，改为30分钟。
       Tcp_Keepalive_Probes1=$(grep -v ^# $sysctlconf|grep 'net.ipv4.tcp_keepalive_probes' | awk -F "=" '{print $2}')

       if [ ${#Tcp_Keepalive_Probes1} -eq 0 ];then
          echo -e \""Tcp_Keepalive_Probes\":\"9"\",
       else
          echo -e \""Tcp_Keepalive_Probes\":\"$Tcp_Keepalive_Probes1"\",
       fi
       #如果对方不予应答，探测包的发送次数
       Tcp_Keepalive_Intvl1=$(grep -v ^# $sysctlconf|grep 'net.ipv4.tcp_keepalive_intvl' | awk -F "=" '{print $2}')

       if [ ${#Tcp_Keepalive_Intvl1} -eq 0 ];then
	  echo -e \""Tcp_Keepalive_Intvl\":\"75"\",
       else
          echo -e \""Tcp_Keepalive_Intvl\":\"$Tcp_Keepalive_Intvl1"\",
       fi
       #keepalive探测包的发送间隔
       echo -e \""Tcp_Tw_Recycle\":\"$Tcp_Tw_Recycle"\",
       echo -e \""Disk_Usages\":\n\"`df -h`"\",
    fi
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

#was主函数
function websphere_info(){
  #format
  #{
  #"yjt": "boy",
  #"age": 20
  #}  
  #echo \""ip\":\"$ipinfo"\",
  #echo -e \""ip\":\"$ipinfo"\",
	echo "{"
	#ps -ef | grep java |grep Dwas.install.root

        collect_sys_info 
    
	PIDCOUNT=`ps -eo ruser,pid,args | grep "java" | grep Dwas.install.root | grep -v grep |grep -v nodeagent| awk ' { print $2 }'|wc -l `

	PID=`ps -eo ruser,pid,args | grep "java" | grep Dwas.install.root | grep -v grep |grep -v nodeagent | awk ' { print $2 }' |sort -r `
	init=0
	#"waspid": [
	#echo \"ip\": [
	echo \"waspid\": [
	for OPID in $PID; 
	do
	    echo "{"
	    echo \""ip\":\"$ipinfo"\",	    
	    #去除行首空格
	    profile_dir=`pwdx $OPID|awk -F ":" '{print $NF}'  | sed "s/ //g"`
    	echo \""profile_dir\":\"$profile_dir"\",
		

		websphere_dir=`ps -feww|grep $OPID |grep -v grep|grep -io "Dosgi.install.area=.*"|awk '{FS=" "; print $1}'|cut -d "=" -f2`
    	echo \""websphere_dir\":\"$websphere_dir"\",

      start_user=`ps -ef |grep $OPID|grep -v grep| awk '{print $1}'`
    	echo \""start_user\":\"$start_user"\",

	    profile_name=${profile_dir##*/}
    	echo \""profile_name\":\"$profile_name"\",

		server_name=`ps -feww|grep $OPID |grep -v grep |awk -F' ' '{print $NF}'`
    	echo \""server_name\":\"$server_name"\",

		server_port=`netstat -tnlo | grep $OPID  | grep tcp  | awk '{print $4}' |awk -F ':' '{print $NF}'`
	    #server_port=`netstat -natp|grep $OPID`
	    #echo "server port is  $server_port"
    	echo \""server_port\":\"$server_port"\",

	    server_jvm_Xms=`ps -feww|grep $OPID |grep -v grep| grep -io "\-Xms.*" | awk '{print $1}'`
	    server_jvm_Xmx=`ps -feww|grep $OPID |grep -v grep| grep -io "\-Xmx.*" | awk '{print $1}'`
      server_jvm="$server_jvm_Xms $server_jvm_Xmx"
    	echo \""server_jvm\":\"$server_jvm"\",

	    java_bin=`ps -feww|grep $OPID |grep -v grep|awk '{print $8}'`
	    java_version=`$java_bin -version 2>&1 |grep J9VM |awk -F ' ' '{print $NF}'`
    	echo \""java_version\":\"$java_version"\",

		
		  was_version=`$websphere_dir/bin/versionInfo.sh|grep Version |grep -v VersionInfo |grep -v 'Version Directory' |grep -v 'Java SE Version' |awk '{print $2}'`
    	echo \""was_version\":\"$was_version"\",



      
	    openfiles=`cat /proc/$OPID/limits  |grep 'open files' |awk '{print $4}'`
    	echo \""openfiles\":\"$openfiles"\",		
    	
    	
	    openfiles_current=`ls /proc/$OPID/fd |wc -l`
    	echo \""openfiles_current\":\"$openfiles_current"\",	
    	
    	    	
	    processes=`cat /proc/$OPID/limits  |grep 'processes' |awk '{print $4}'`
    	echo \""processes\":\"$processes"\",		    	

	    processes_current=`ps hH p $OPID |wc -l`
    	echo \""processes_current\":\"$processes_current"\",		    	


	    processe_cpu=`top -bc -n 1 |grep $OPID |head -1 |awk {'print $9'} `
    	echo \""processe_cpu\":\"$processe_cpu"\",		  


	    processe_mem=`top -bc -n 1 |grep $OPID |head -1 |awk {'print $10'} `
    	echo \""processe_mem\":\"$processe_mem"\",		
    	
    	

    cell=`ps -ef |grep $OPID |grep -v grep|awk '{print $(NF-2)}'`
    node=`ps -ef |grep $OPID |grep -v grep|awk '{print $(NF-1)}'`

	    #cat /home/websphere/IBM/AppServer/profiles/Dmgr01/config/cells/centos152Cell01/security.xml| head -2  |grep enabled=\"true\" |wc -l
	    #cat /home/websphere/IBM/AppServer/profiles/AppSrv01/config/cells/centos152Cell01/security.xml| head -2  |grep enabled=\"true\" |wc -l
      security_enabled=`cat $profile_dir/config/cells/$cell/security.xml| head -2  |grep enabled=\"true\" |wc -l`
      if [ $security_enabled == 1 ];then  
          echo \""security_enabled\":\"true"\",
      else    
          echo \""security_enabled\":\"false"\",
      fi      
    
      
      #if [ "$server_name" != "dmgr" ];then  
      #   #redirect to tmp
      #   /home/websphere/IBM/AppServer/bin/wsadmin.sh -lang jython  -conntype SOAP -host 192.168.40.152 -port 8879 -username was -password was -f getPerformanceV32_nosleep.py $node $server_name >tmp
      #   #three line
      #   cat tmp |tail -n +3
      #fi
      $websphere_dir/bin/wsadmin.sh -lang jython  -conntype SOAP -host $ipinfo -port $soapport -username $was_usr -password $was_psw -f getPerformanceV32_nosleep.py $node $server_name >tmp
         cat tmp |tail -n +3      
	    mkdir -p /tmp/tmpcheck/${profile_name}_${server_name}_${OPID}
	    cp $profile_dir/config/cells/$cell/nodes/$node/servers/$server_name/server.xml /tmp/tmpcheck/${profile_name}_${server_name}_${OPID}
	    #jdbc
      cp $profile_dir/config/cells/$cell/nodes/$node/servers/$server_name/resources.xml  /tmp/tmpcheck/${profile_name}_${server_name}_${OPID}
      #: replace =
      #errlog=`cat $profile_dir/logs/${server_name}/SystemErr.log |grep -i error|tr ":" "="|tr "\"" "&"` 
      
      
      
      cat /dev/null > cccc.log
      #errlog=`awk '/Error:|Exception:|Too many open files/,/Error:|Exception:|Too many open files/'    /home/websphere/IBM/AppServer/profiles/Dmgr01/logs/dmgr/SystemErr.log > cc.log  &&  tac cc.log >ccc.log  &&    awk '!a[$NF]++' ccc.log >cccc.log`      
      errlog=`awk '/Error:|Exception:|Too many open files/,/Error:|Exception:|Too many open files/'    $profile_dir/logs/${server_name}/SystemErr.log > cc.log  &&  tac cc.log >ccc.log  &&    awk '!a[$NF]++' ccc.log >cccc.log`
      cat /dev/null > ccccc.log
      IFS_old=$IFS
      IFS=$'\n'
      #去除行首的[
      awk '{print substr($0,2)}'  cccc.log   >   cccc1.log
      for line in `cat cccc1.log`
      do

      	 #echo '----------'$line'-----------'  >>ccccc.log
         echo '======================================================================================================================'  >>ccccc.log
         #echo grep $line -C 10 /home/websphere/IBM/AppServer/profiles/AppSrv01/logs/server1/SystemErr.log 
         #grep $line -C 10 /home/websphere/IBM/AppServer/profiles/AppSrv01/logs/server1/SystemErr.log | tail -n 21 |tr ":" "="|tr "\"" "&">>ccccc.log
         #echo grep "'\/$line'" -C 10 /home/websphere/IBM/AppServer/profiles/AppSrv01/logs/server1/SystemErr.log  
         #echo grep "'\\$line'" -C 10 /home/websphere/IBM/AppServer/profiles/AppSrv01/logs/server1/SystemErr.log
         #grep "$line" -C 10 /home/websphere/IBM/AppServer/profiles/Dmgr01/logs/dmgr/SystemErr.log | tail -n 21 |tr ":" "="|tr "\"" "&" >>ccccc.log
         #echo '-----'$profile_dir'----' >>ccccc.log
         grep "$line" -C 10 $profile_dir/logs/${server_name}/SystemErr.log | tail -n 21 |tr ":" "="|tr "\"" "&" >>ccccc.log
         
      done
      IFS=$IFS_old
      errlog=`cat ccccc.log`
            
      echo \""errlog\":\"$errlog"\",
      
      
      #outlog=`cat $profile_dir/logs/${server_name}/SystemOut.log |grep -i error|tr ":" "="|tr "\"" "&"` 
      #outlog=`awk '/Error:|Exception:|Failed to create/,/Error:|Exception:|Failed to create/'    /home/websphere/IBM/AppServer/profiles/Dmgr01/logs/dmgr/SystemOut.log > cc.log  &&  tac cc.log >ccc.log  &&    awk '!a[$NF]++' ccc.log >cccc.log`
      echo \""SystemOut.log\":\"$profile_dir/logs/${server_name}/SystemOut.log"\",
      outlog=`awk '/Error:|Exception:|Failed to create/,/Error:|Exception:|Failed to create/'    $profile_dir/logs/${server_name}/SystemOut.log > cc.log  &&  tac cc.log >ccc.log  &&    awk '!a[$NF]++' ccc.log >cccc.log` 
      cat /dev/null > ccccc.log
      IFS_old=$IFS
      IFS=$'\n'
      #去除行首的[
      awk '{print substr($0,2)}'  cccc.log   >   cccc1.log
      for line in `cat cccc1.log`      
      do
      	 #echo '----------'$line'-----------------'    >>ccccc.log   	
         echo '======================================================================================================================\n'  >>ccccc.log
         grep "\$line" -C 10 $profile_dir/logs/${server_name}/SystemOut.log | tail -n 21 |tr ":" "="|tr "\"" "&" >>ccccc.log
      done
      IFS=$IFS_old
      outlog=`cat ccccc.log`

      echo \""outlog\":\"$outlog"\"
      
      #nativeerrlog=`cat $profile_dir/logs/${server_name}/native_stderr.log |grep -i error |tr ":" "=" |tr "\"" "&"` 
      #echo \""nativeerrlog\":\"$nativeerrlog"\"                  
      cp $profile_dir/logs/${server_name}/SystemOut.log  /tmp/tmpcheck/${profile_name}_${server_name}_${OPID}
      cp $profile_dir/logs/${server_name}/SystemErr.log  /tmp/tmpcheck/${profile_name}_${server_name}_${OPID}
      #cp $profile_dir/logs/${server_name}/native_stderr.log  /tmp/tmpcheck/${profile_name}_${server_name}_${OPID}
      init=`expr $init + 1`;
      #lt <
      echo "}"
	    [ $init -lt $PIDCOUNT ] && echo ","

	done
  echo "]"
  echo "}"

}

#was主函数
function get_websphere_main() {

  #get soap port 在dmgr机器执行此脚本   
  dmgrPID=`ps -eo ruser,pid,args | grep "java" | grep dmgr |grep -v nodeagent|grep "Node*"|  grep -v grep | awk ' { print $2 }'`
  if [ $dmgrPID ];then
     dmgr_profile_dir=`pwdx $dmgrPID|awk -F ":" '{print $NF}'`
     dmgrcell=`ps -ef |grep $dmgrPID |grep -v grep|awk '{print $(NF-2)}'`
     dmgrnode=`ps -ef |grep $dmgrPID |grep -v nodeagent |grep -v grep|awk '{print $(NF-1)}'`
     line_=`cat -n  $dmgr_profile_dir/config/cells/$dmgrcell/nodes/$dmgrnode/serverindex.xml |grep SOAP_CONNECTOR_ADDRESS |awk {'print $1'}`
     line_=`expr $line_ + 1`
     soapport=`sed -n $line_"p" $dmgr_profile_dir/config/cells/$dmgrcell/nodes/$dmgrnode/serverindex.xml |awk {'print $NF'} |awk -F '"' {'print $2'} |awk -F '"' {'print $1'}`
#  fi

     echo -e "Please input your was " $ipinfo " dmgr console username: \c"
     while : ;do
         char=` 
            stty cbreak -echo
            dd if=/dev/tty bs=1 count=1 2>/dev/null
            stty -cbreak echo
    `       #aaaaaaa
         if [ "$char" = "" ];then
            echo 
            break
         fi
         #USER 保留字
         USER1="$USER1$char"
         echo -n "*"
     done
     was_usr=$USER1

     echo -e "Please input your was " $ipinfo " dmgr console Passwd: \c"
     while : ;do
        char=` 
           stty cbreak -echo
           dd if=/dev/tty bs=1 count=1 2>/dev/null
           stty -cbreak echo
    `      #aaaaaaa
        if [ "$char" = "" ];then
           echo 
           break
        fi
        PASS1="$PASS1$char"
        echo -n "*"
     done  
     was_psw=$PASS1

   else
     was_usr=$USER1
     was_psw=$PASS1
   fi

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

####get websphere info
filename2=$HOSTNAME"_"$name"_"$type"_"$ipinfo"_"$qctime".json"
qctime=$(date +'%Y%m%d%H%M%S')
websphere_info >> "$filepath""$filename2"
tar -czvf /tmp/tmpcheck/"$HOSTNAME"_"$name"_"$type"_"$ipinfo"_"$qctime".tar.gz /tmp/tmpcheck 2> /dev/null

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


echo "当前服务器IP地址为\(供参考\)："$ipinfo
echo "当前服务器Listener端口为\(供参考\):" 
netstat -anpt|grep LISTEN|grep  :::*
echo "当前服务器进程\（供参考\）："
ps -aux
echo "###########################################"
get_websphere_main
