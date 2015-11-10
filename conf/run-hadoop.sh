#!/bin/bash

# Re-start the mysql service
service mysql restart

# Init and start zookeeper
service zookeeper-server init
service zookeeper-server start

service hadoop-hdfs-namenode start
service hadoop-hdfs-datanode start

sudo -u hdfs hadoop fs -mkdir -p /tmp/hadoop-yarn/staging/history/done_intermediate
sudo -u hdfs hadoop fs -chown -R mapred:mapred /tmp/hadoop-yarn/staging
sudo -u hdfs hadoop fs -chmod -R 1777 /tmp
sudo -u hdfs hadoop fs -mkdir -p /var/log/hadoop-yarn
sudo -u hdfs hadoop fs -chown yarn:mapred /var/log/hadoop-yarn

service hadoop-yarn-resourcemanager start
service hadoop-yarn-nodemanager start
service hadoop-mapreduce-historyserver start

sudo -u hdfs hadoop fs -mkdir -p /user/hdfs
sudo -u hdfs hadoop fs -chown hdfs /user/hdfs

#init hive
sudo -u hdfs hadoop fs -mkdir -p /user/hive/warehouse
sudo -u hdfs hadoop fs -chown hdfs /user/hive/warehouse

sudo -u hdfs hadoop fs -chmod -R 1777 /user/hive/warehouse


# # init Hive metastore schema . NB : we also set a MySQL user account [ user : hive , pwd : hive ]  
# for Hive to access the metastore
# TODO PRIORITY 1 : use a bind variable to specify the hive version
# because there is a path to Hive metastore init script linked to Hive's version
working_dir=`pwd`
# We move to this directory (/usr/lib/hive/scripts/metastore/upgrade/mysql/) because in /usr/lib/hive/scripts/metastore/upgrade/mysql/hive-schema-1.1.0.mysql.sql , 
# there is a source call to another sql file : 
# SOURCE hive-txn-schema-0.13.0.mysql.sql;
# which is located in /usr/lib/hive/scripts/metastore/upgrade/mysql/
cd /usr/lib/hive/scripts/metastore/upgrade/mysql/
mysql -u root -padmin mysql < /etc/hive/conf/my_hive_metastore_init.sql

# We go back to the previous working dir
cd $working_dir

service hive-metastore start
service hive-server2 start
service hive-webhcat-server start

#create user directories
sudo -u hdfs hadoop fs -mkdir -p /user/root
sudo -u hdfs hadoop fs -chown root:root /user/root

#init oozie
sudo -u hdfs hadoop fs -mkdir /user/oozie
sudo -u hdfs hadoop fs -chown oozie:oozie /user/oozie
sudo oozie-setup sharelib create -fs hdfs://localhost:8020 -locallib /usr/lib/oozie/oozie-sharelib-yarn

service oozie start
export OOZIE_URL=http://localhost:11000/oozie

#init spark history server
sudo -u hdfs hadoop fs -mkdir /user/spark
sudo -u hdfs hadoop fs -mkdir /user/spark/applicationHistory
sudo -u hdfs hadoop fs -chown -R spark:spark /user/spark
sudo -u hdfs hadoop fs -chmod 1777 /user/spark/applicationHistory

#init spark shared libraries
#client than can use SPARK_JAR=hdfs://<nn>:<port>/user/spark/share/lib/spark-assembly.jar
sudo -u spark hadoop fs -mkdir -p /user/spark/share/lib 
sudo -u spark hadoop fs -put /usr/lib/spark/lib/spark-assembly.jar /user/spark/share/lib/spark-assembly.jar 

service spark-history-server start

service hue start

sleep 1

# tail log directory
tail -n 1000 -f /var/log/hadoop-*/*.out
