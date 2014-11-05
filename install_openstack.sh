涉及两个节点：控制节点（Controller）和计算节点（Compute）。

##基本架构和网络配置

Controller节点，控制节点运行的服务包括认证服务、镜像服务以及计算服务的管理部分。当然，还包括database服务、message broker以及NTP等；

Compute节点，主要服务是计算服务的hypervisor部分（因为计算服务的另外一部分在控制节点上进行）。By default, Compute uses KVM as the hypervisor；
Compute节点还提供Nova Networking服务。

###网络配置

Controller节点有一个网卡，负责和外网以及Compute节点通讯；
Compute节点有两个网卡，其中一个网卡负责和Controller节点通讯，另一个网卡用于虚拟机桥接；

Controller节点的网络配置

执行：
cat > /etc/hosts << EOF
# controller
172.16.71.194 controller
# compute
172.16.71.195 compute1
EOF

# 修改Controller节点主机名为controller，即设置/etc/hostname的文本内容为controller
cat > /etc/hostname << EOF
controller
EOF


Compute节点的网络配置

执行：
cat > /etc/hosts << EOF
# controller
172.16.71.194 controller
# compute
172.16.71.195 compute1
EOF

# 修改Controller节点主机名为controller，即设置/etc/hostname的文本内容为controller
cat > /etc/hostname << EOF
compute1
EOF

P.S：说明，compute1节点的eth1的配置稍后再说吧！

###网络连接测试

确保controller节点能够ping通compute1节点和外网，可分别用“ping -c 5 comptue1”和“ping -c 5 baidu.com”命令测试；
确保compute1节点能够ping通controller节点，可用“ping -c 5 controller”命令测试；

###安装配置NTP

NTP（Network Time Protocol）服务用于同步时间。

controller安装配置NTP

# By default, the controller node synchronizes the time via a pool of public servers.
# 当然也可以指定服务器来同步时间，譬如参考自己公司内部的某个服务器，具体做法是编辑/etc/ntp.conf文件，
# 考虑到目前没必要，所以此处略过，更多内容参考文档
# 所以，对于controller节点的ntp配置，完全是默认，不作修改
# 具体命令行执行如下：
apt-get install ntp -y

install-ntp-in-the-controller.sh

其他节点安装配置NTP

# apt-get install ntp -y
# 和controller节点不同，其他节点的时间需要和controller节点完全保持一致，所以修改/etc/ntp.conf文件
# 将“server ntp.ubuntu.com”之类的代码行给注释掉，然后添加一行“server controller iburst”
# In addition, remove the /var/lib/ntp/ntp.conf.dhcp file if it exists.
# 最后，还得重启ntp服务
# 具体命令行执行如下：
apt-get install ntp -y
sed -i 's/^server/# &/g' /etc/ntp.conf
cat >> /etc/ntp.conf << EOF
# 
# 设置ntp server为controller节点
server controller iburst
EOF
# 删除/var/lib/ntp/ntp.conf.dhcp
rm -f /var/lib/ntp/ntp.conf.dhcp
# 重启
service ntp restart

install-ntp-in-others-node.sh

###验证ntp服务

a. 在controller节点执行“ntpq -c peers”
输出结果中remote列中至少列出一个服务器名，如下：
     remote           refid      st t when poll reach   delay   offset  jitter
==============================================================================
+dns1.synet.edu. 202.118.1.46     2 u   92   64  372   68.416  170.158 164.060
 gus.buptnet.edu .STEP.          16 u    - 1024    0    0.000    0.000   0.000
*dns2.synet.edu. 202.118.1.46     2 u   34   64  377   66.886   36.388  58.152
+juniperberry.ca 193.79.237.14    2 u    4   64  373  324.820   93.437  41.092

b. 在controller节点执行“ntpq -c assoc”
输出结果中condition列中至少有一个sys.peer值，如下：
ind assid status  conf reach auth condition  last_event cnt
===========================================================
  1 24431  941a   yes   yes  none candidate    sys_peer  1
  2 24432  8011   yes    no  none    reject    mobilize  1
  3 24433  961a   yes   yes  none  sys.peer    sys_peer  1
  4 24434  941a   yes   yes  none candidate    sys_peer  1


c. 在其他节点执行“ntpq -c peers”
输出结果中remote列应该列出controller服务器名“controller”，如下：
     remote           refid      st t when poll reach   delay   offset  jitter
==============================================================================
*controller      202.112.31.197   3 u   18   64   37    0.356   53.981  26.278

d. 在其他节点执行“ntpq -c assoc”
输出结果中condition列中的值应该是“sys.peer”，如下：
ind assid status  conf reach auth condition  last_event cnt
===========================================================
  1 59579  963a   yes   yes  none  sys.peer    sys_peer  3

###更新和安装OpenStack packages
操作如下：
# Install the python-software-properties package to ease repository management
apt-get install python-software-properties -y
# Upgrade the packages on your system
apt-get update && apt-get dist-upgrade -y

# 重启系统，然后继续

# To enable the OpenStack repository
add-apt-repository cloud-archive:juno -y

P.S：每个节点都应该这行以上步骤哦。

###在Controller节点安装配置MySQL数据库
操作如下：

# 安装mariadb-server和python-mysqldb，设置root密码为123456
apt-get install mariadb-server python-mysqldb -y

# 在[mysqld]段设置（修改）bind-address的参数值为MySQL所在主机IP（原值为127.0.0.1）
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf

# 在[mysqld]段设置（添加）如下文本：
# [mysqld]
# ...
# default-storage-engine = innodb
# innodb_file_per_table
# collation-server = utf8_general_ci
# init-connect = 'SET NAMES utf8'
# character-set-server = utf8
# 说明：以上似乎是设置编码相关
sed -i 's/skip-external-locking/skip-external-locking\ndefault-storage-engine = innodb\ninnodb_file_per_table\ncollation-server = utf8_general_ci\ninit-connect = "SET NAMES utf8"\ncharacter-set-server = utf8/g' /etc/mysql/my.cnf
# 这一句sed语句不是太好，最好换成别的

# 然后重启mysql服务
service mysql restart

# mysql数据库进行安全相关的配置，执行如下命令
# 此命令执行过程中会有一些选项，都是很简单的英文，自己看着办，只是对于“Remove anonymous users? [Y/n]”选择Y。
mysql_secure_installation

###在Controller节点安装配置MySQL数据库

# 安装Messaging server RabbitMQ
# 设置RabbitMQ密码为123456
export RABBIT_PASS=123456
apt-get install rabbitmq-server -y
rabbitmqctl change_password guest $RABBIT_PASS

创建数据库，为后续的keystone、nova等服务创建MySQL数据库。

mysql -u root -p
# 输入密码

create database keystone;
grant all privileges on keystone.* to 'keystone'@'localhost' \
identified by '123456';
grant all privileges on keystone.* to 'keystone'@'%' \
identified by '123456';
create database glance;
grant all privileges on glance.* to 'glance'@'localhost' \
identified by '123456';
grant all privileges on glance.* to 'glance'@'%' \
identified by '123456';
create database nova;
grant all privileges on nova.* to 'nova'@'localhost' \
identified by '123456';
grant all privileges on nova.* to 'nova'@'%' \
identified by '123456';

##安装和配置Keystone服务

##########在controller安装keystone和python-keystoneclient开始##########
apt-get install -y keystone python-keystoneclient
# 应该将apt-get install操作和其他命令分开
##########在controller安装keystone和python-keystoneclient结束##########

##########################配置keystone开始############################
# 为keystone配置数据库（keystone@controller 123456）
# 该设置使得keystone使用keystone（用户名）/123456（密码）访问mysql中的keystone数据库；
sed -i '/connection = .*/{s|sqlite:///.*|mysql://'"keystone"':'"123456"'@'"controller"'/keystone|g}' /etc/keystone/keystone.conf
# 默认情况下，Ubuntu的keystone安装包为keystone创建一个SQLite数据库，此时这个数据库没有存在的意义了，删除它
rm /var/lib/keystone/keystone.db

# In the [token] section, configure the UUID token provider and SQL driver:
# provider=keystone.token.providers.uuid.Provider
# driver=keystone.token.persistence.backends.sql.Token
# pdf文档driver的配置说明有错误，应该配置为
# driver=keystone.token.backends.sql.Token
sed -i 's/^#provider=<None>/provider=keystone.token.providers.uuid.Provider/g' /etc/keystone/keystone.conf
sed -i 's/#driver=keystone.token.backends.sql.Token/driver=keystone.token.backends.sql.Token/g' /etc/keystone/keystone.conf

# (Optional) To assist with troubleshooting, enable verbose logging in the [DEFAULT] section
sed -i 's/^#verbose=false/verbose=true/g' /etc/keystone/keystone.conf
# 配置keystone的日志文件
sed -i -e "s|#log_dir=<None>|log_dir=/var/log/keystone|g" /etc/keystone/keystone.conf

# Populate the Identity service database
su -s /bin/sh -c "keystone-manage db_sync" keystone

# 为keystone创建token
# 因为keystone是为其他services提供认证服务的，而其他服务若想要使用keystone提供的服务则需要
# keystone授权的token作为钥匙，因此keystone需要创建一个token，为简单起见，这里设置token为
# 1234567890，编辑/etc/keystone/keystone.conf设置[DEFAULT]段中admin_token值：
# [DEFAULT]
# admin_token=1234567890
sed -i -e "s/#admin_token=ADMIN/admin_token=1234567890/g" /etc/keystone/keystone.conf

# By default, the Identity service stores expired tokens in the database indefinitely.
# The accumulation of expired tokens considerably increases the database size and might
# degrade service performance, particularly in environments with limited resources.
# We recommend that you use cron to configure a periodic task that purges expired tokens hourly:
(crontab -l -u keystone 2>&1 | grep -q token_flush) || echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' >> /var/spool/cron/crontabs/keystone
##########################配置keystone开始############################

##########################验证keystone开始############################
# 验证keystone安装配置成功，执行“keystone user-list”命令验证keystone服务是否安装成功
# 在执行这条命令“keystone user-list”之前需要引入这两个值，执行下面两条命令即可：
export OS_SERVICE_TOKEN=1234567890
export OS_SERVICE_ENDPOINT=http://controller:35357/v2.0
keystone user-list
# 如果没有报错神马的，就说明没有问题
##########################验证keystone结束############################

###########################创建管理员admin开始###########################
# 默认情况下（针对icehouse版本的OpenStack），keystone创建了一个_member_ role
# Dashboard Service默认情况下会为该role下的用户授权访问权限，若想让用户admin具有该访问
# dashboard访问权限，那么需要将admin与_member_ role绑定；
# 说明：关于role，每个OpenStack都有一个相关role的说明文档：policy.json，该文档对各种role
# 的权限有规定，所有创建的role必须要符合policy.json，通常情况下，这些services都将管理员权限分配给role admin。

# a. 创建一个admin user（简单起见，设置其密码为123456）
keystone user-create --name=admin --pass=123456 --email=admin@example.com

# b. 创建admin role
keystone role-create --name=admin

# c. 创建admin tenant
keystone tenant-create --name=admin --description="Admin Tenant"

# d. 为admin user、admin role、admin teant建立关系
keystone user-role-add --user=admin --tenant=admin --role=admin

# e. 将admin user绑定到_member_ role上
keystone user-role-add --user=admin --tenant=admin --role=_member_
###########################创建管理员admin结束###########################

###########################创建普通用户demo开始###########################
# a. 创建一个demo user（简单起见，设置其密码为123456）
keystone user-create --name=demo --pass=123456 --email=demo@example.com

# b. 创建demo tenant
keystone tenant-create --name=demo --description="Demo Tenant"

# c. 将demo user绑定到_member_ role上
keystone user-role-add --user=demo --tenant=demo --role=_member_
###########################创建普通用户demo结束###########################

#########################创建service tenant开始#########################
keystone tenant-create --name=service --description="Service Tenant"
#########################创建service tenant结束#########################

# 说明：可以使用“keystone user-list”“keystone role-list”“keystone tenant-list”等命令
# 查看上述“keystone xx-create”命令的执行结果。
# 说明：上述命令的处理结果也会同步到mysql keystone数据库中，所以也可以前往mysql数据库查看操作结果。

################创建keystone service和其API endpoint开始################
# a. 注册keystone service
keystone service-create --name=keystone --type=identity --description="OpenStack Identity"

# b. 指定keystone service api endpoint
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ identity / {print $2}') \
--publicurl=http://controller:5000/v2.0 \
--internalurl=http://controller:5000/v2.0 \
--adminurl=http://controller:35357/v2.0
################创建keystone service和其API endpoint结束################

########################确认keystone安装成功开始########################
unset OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT
keystone --os-tenant-name admin --os-username admin --os-password 123456 --os-auth-url http://controller:35357/v2.0 tenant-list
########################确认keystone安装成功结束########################

###########Create OpenStack client environment scripts开始###########
# 为方便用户权限切换，为用户admin创建~/admin_openrc.sh文件，如下：
cat > ~/admin_openrc.sh << EOF
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=123456
export OS_AUTH_URL=http://controller:35357/v2.0
EOF

# 同样，也创建一个~/demo_penrc.sh文件，如下：
cat > ~/demo_penrc.sh << EOF
export OS_TENANT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=123456
export OS_AUTH_URL=http://controller:5000/v2.0
EOF
###########Create OpenStack client environment scripts结束###########

##安装和配置Glance服务

##########在controller节点安装glance和python-glanceclient开始##########
apt-get install -y glance python-glanceclient
##########在controller节点安装glance和python-glanceclient结束##########

############################配置glance开始###########################
# 配置数据库
# 编辑/etc/glance/glance-api.conf和/etc/glance/glance-registry.conf，
# 设置（修改）[database]段中的数据库连接字符串（前面已经设置访问密码为123456）：
#[database]
# connection = mysql://glance:123456@controller/glance
sed -i -e 's|#connection = <None>|connection = mysql://glance:123456@controller/glance|g' /etc/glance/glance-api.conf
sed -i -e 's|#connection = <None>|connection = mysql://glance:123456@controller/glance|g' /etc/glance/glance-registry.conf
sed -i -e 's|sqlite_db = /var/lib/glance/glance.sqlite|#&|g' /etc/glance/glance-api.conf
sed -i -e 's|sqlite_db = /var/lib/glance/glance.sqlite|#&|g' /etc/glance/glance-registry.conf

# 配置image service和message broker
# 编辑/etc/glance/glance-api.conf的[default]段，如下：
# [DEFAULT]
# ...
# rpc_backend = rabbit
# rabbit_host = controller # 文件中已有该字段，默认值为localhost
# rabbit_password = 123456 # 文件中已有该字段，默认值为guest
sed -i -e 's|rabbit_host = localhost|rpc_backend = rabbit\nrabbit_host = controller|g' /etc/glance/glance-api.conf
sed -i -e 's|rabbit_password = guest|rabbit_password = 123456|g' /etc/glance/glance-api.conf

# 配置glance的认证服务
# 编辑/etc/glance/glance-api.conf和/etc/glance/glance-registry.conf
# a. 在[keystone_authtoken]下设置如下：
# [keystone_authtoken]
#auth_uri = http://controller:5000 # 新增
#auth_host = controller # 修改
#auth_port = 35357
#auth_protocol = http
#admin_tenant_name = service # 修改
#admin_user = glance # 修改
#admin_password = 123456 # 修改
sed -i -e 's|auth_host = 127.0.0.1|auth_uri = http://controller:5000\nauth_host = controller|g' /etc/glance/glance-api.conf;
sed -i -e 's|admin_tenant_name = %SERVICE_TENANT_NAME%|admin_tenant_name = service|g' /etc/glance/glance-api.conf;
sed -i -e 's|admin_user = %SERVICE_USER%|admin_user= glance|g' /etc/glance/glance-api.conf;
sed -i -e 's|admin_password = %SERVICE_PASSWORD%|admin_password = 123456|g' /etc/glance/glance-api.conf;

sed -i -e 's|auth_host = 127.0.0.1|auth_uri = http://controller:5000\nauth_host = controller|g' /etc/glance/glance-registry.conf;
sed -i -e 's|admin_tenant_name = %SERVICE_TENANT_NAME%|admin_tenant_name = service|g' /etc/glance/glance-registry.conf;
sed -i -e 's|admin_user = %SERVICE_USER%|admin_user= glance|g' /etc/glance/glance-registry.conf;
sed -i -e 's|admin_password = %SERVICE_PASSWORD%|admin_password = 123456|g' /etc/glance/glance-registry.conf;

# 在[paste_deploy]段下设置如下：
# [paste_deploy]
# ...
# flavor = keystone
sed -i -e 's|#flavor=|flavor = keystone|g' /etc/glance/glance-api.conf;
sed -i -e 's|#flavor=|flavor = keystone|g' /etc/glance/glance-registry.conf;

# 设置日志详细程度
sed -i 's/^#verbose = False/verbose = True/g' /etc/glance/glance-api.conf;
sed -i 's/^#verbose= False/verbose = True/g' /etc/glance/glance-registry.conf;

#删除package为glance默认创建的SQLite数据库
rm /var/lib/glance/glance.sqlite

#同步glance数据（创建数据表等）
su -s /bin/sh -c "glance-manage db_sync" glance

#为glance创建用户
keystone user-create --name=glance --pass=123456 --email=glance@example.com
keystone user-role-add --user=glance --tenant=service --role=admin

# 向Keystone注册glance服务并配置其endpoint
source ~/admin_openrc.sh
keystone service-create --name=glance --type=image --description="OpenStack Image Service"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ image / {print $2}') \
--publicurl=http://controller:9292 \
--internalurl=http://controller:9292 \
--adminurl=http://controller:9292
############################配置glance-api结束###########################

############################重启glance服务开始###########################
service glance-registry restart
service glance-api restart
############################重启glance服务结束###########################

#######################测试glance上传image服务开始#######################
# 使用wget工具下载CirrOS
mkdir ~/images
cd~/images/
wget http://cdn.download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img
source ~/admin_openrc.sh

#上传image到glance服务
glance image-create --name "cirros-0.3.3-x86_64" --disk-format qcow2 \
--container-format bare --is-public True --progress < cirros-0.3.3-x86_64-disk.img

# 如果一切安好，说明glance配置没问题了
#######################测试glance上传image服务结束#######################

##在controller节点安装和配置Nova服务

#################在controller节点安装nova服务部分组件开始#################
# 在controller节点上安装compute服务部分组件（蛮多的）
apt-get install -y nova-api nova-cert nova-conductor nova-consoleauth nova-novncproxy nova-scheduler python-novaclient
#################在controller节点安装nova服务部分组件结束#################

####################在controller节点配置nova服务开始####################
# 配置nova数据库
# 编辑/etc/nova/nova.conf的[database]段，添加：
# connection = mysql://nova:123456@controller/nova
cat >> /etc/nova/nova.conf << EOF
connection = mysql://nova:123456@controller/nova
EOF

# 配置nova的message broker和vnc
#编辑/etc/nova/nova.conf的[DEFAULT]段，添加：
#rpc_backend = rabbit
#rabbit_host = controller
#rabbit_password = 123456
# 
#my_ip = 172.16.71.159
#vncserver_listen = 172.16.71.159
#vncserver_proxyclient_address = 172.16.71.159
export LOCALHOSTIP=$(ifconfig eth0 | grep "inet addr" | awk '{print $2}' | sed 's/addr://g')
cat >> /etc/nova/nova.conf << EOF

rpc_backend = rabbit
rabbit_host = controller
rabbit_password = 123456

my_ip = $LOCALHOSTIP
vncserver_listen = $LOCALHOSTIP
vncserver_proxyclient_address = $LOCALHOSTIP
EOF

#移除默认的SQLite数据库
rm /var/lib/nova/nova.sqlite

# 同步nova数据
su -s /bin/sh -c "nova-manage db sync" nova

# 配置compute节点的认证服务
# a. 编辑/etc/nova/nova.conf的[DEFAULT]段，添加：
# auth_strategy = keystone
cat >> /etc/nova/nova.conf << EOF
auth_strategy = keystone
EOF

# 编辑/etc/nova/nova.conf，添加[keystone_authtoken]段文本：
#[keystone_authtoken]
#auth_uri = http://controller:5000
#auth_host = controller
#auth_port = 35357
#auth_protocol = http
#admin_tenant_name = service
#admin_user = nova
#admin_password = 123456
cat >> /etc/nova/nova.conf << EOF
[keystone_authtoken]
auth_uri = http://controller:5000
auth_host = controller
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = nova
admin_password = 123456
EOF

# 配置image存储的地方，这里是controller
# In the [glance] section, configure the location of the Image Service:
#/etc/nova/nova.conf中增加如下内容：
# [glance]
# ...
# host = controller
cat >> /etc/nova/nova.conf << EOF
[glance]
host = controller
EOF

# 注册nova服务
cd ~
source admin_openrc.sh
keystone service-create --name=nova --type=compute \
--description="OpenStack Compute"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ compute / {print $2}') \
--publicurl=http://controller:8774/v2/%\(tenant_id\)s \
--internalurl=http://controller:8774/v2/%\(tenant_id\)s \
--adminurl=http://controller:8774/v2/%\(tenant_id\)s

# 为nova创建用户
keystone user-create --name=nova --pass=123456 --email=nova@example.com
keystone user-role-add --user=nova --tenant=service --role=admin

####################在controller节点配置nova服务开始####################

###########################验证nova服务开始###########################
# 重启nova服务
# service nova-api restart
#service nova-cert restart
#service nova-consoleauth restart
#service nova-scheduler restart
#service nova-conductor restart
#service nova-novncproxy restart
# 重启nova服务略显麻烦，后续可能有多次这样需要在controller node重启nova服务，为简单起见，
# 将以上重启nova服务指令写入restartNova.sh中，以后执行source restartNova.sh即可
cd ~
cat >> restartNova.sh << EOF
service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart
EOF
source restartNova.sh

# 执行“nova image-list”验证nova服务
nova image-list
# 如果没有异常，说明nova安装成功（其实只能说明nova-api安装成功，不过nova-api安装成功了，其他一般也就没啥问题）
###########################验证nova服务结束###########################

##在compute节点安装和配置Nova服务
##################在compute节点安装nova计算部分组件开始##################
apt-get install -y nova-compute sysfsutils
##################在compute节点安装nova计算部分组件结束##################

########################在compute配置nova开始########################
# 配置RabbitMQ
cat >> /etc/nova/nova.conf << EOF
rpc_backend = rabbit
rabbit_host = controller
rabbit_password = 123456
EOF

# 配置认证服务
cat >> /etc/nova/nova.conf << EOF
keystone_authtoken = keystone
EOF

# 配置my_ip
export LOCALHOSTIP=$(ifconfig eth0 | grep "inet addr" | awk '{print $2}' | sed 's/addr://g')
cat >> /etc/nova/nova.conf << EOF
my_ip = $LOCALHOSTIP # 这里的my_ip配置管理网卡的ip，即与controller通讯的网卡的ip
EOF

# enable and configure remote console access
cat >> /etc/nova/nova.conf << EOF
vnc_enabled = True vncserver_listen = 0.0.0.0 vncserver_proxyclient_address = $LOCALHOSTIP
novncproxy_base_url = http://controller:6080/vnc_auto.htmlEOF
EOF

# 继续配置认证服务
cat >> /etc/nova/nova.conf << EOF

[keystone_authtoken]
auth_uri = http://controller:5000/v2.0
identity_uri = http://controller:35357
admin_tenant_name = service
admin_user = nova admin_password = 123456
EOF

# In the [glance] section, configure the location of the Image Service
cat >> /etc/nova/nova.conf << EOF

[glance] host = controller
EOF

# 重启nova服务
service nova-compute restart

# By default, the Ubuntu packages create an SQLite database. # Because this configuration uses a SQL database server,
# you can remove the SQLite database file:
rm -f /var/lib/nova/nova.sqlite
########################在compute配置nova结束########################

##############################验证开始##############################
# 验证，在controller执行“nova service-list”命令
cd ~
source admin_openrc.sh
nova service-list
# 结果信息中应该包括nova-cert、nova-compute等信息，其中nova-compute的Host应该是“compute1”
##############################验证结束##############################

sed -i "s/OPENSTACK_HOST = '127.0.0.1'/OPENSTACK_HOST = controller/" /etc/openstack-dashboard/local_settings.py
sed -i "s/#ALLOWED_HOSTS = ['horizon.example.com', ]/ALLOWED_HOSTS = ['*']/" /etc/openstack-dashboard/local_settings.py
sed -i 's/TIME_ZONE = "UTC"/TIME_ZONE = "CN"/' /etc/openstack-dashboard/local_settings.py

# 重启apache服务，即执行“service apache2 restart”和“service memcached restart”
# 在Ubuntu中执行“service apache2 restart”有些问题，报错AH00558
# 解决方法：
# 在/etc/apache2/apache2.conf文件中添加：
# ServerName controller
# 或者
# ServerName 127.0.0.1
执行
cat >> /etc/apache2/apache2.conf << EOF
ServerName 127.0.0.1
EOF
service apache2 restart
service memcached restart