FROM nimmis/java:oracle-8-jdk
MAINTAINER Eric Djatsa <eric.djatsa@outlook.com>

#Base image doesn't start in root
WORKDIR /

#Add the CDH 5 repository
COPY conf/cloudera.list /etc/apt/sources.list.d/cloudera.list
#Set preference for cloudera packages
COPY conf/cloudera.pref /etc/apt/preferences.d/cloudera.pref
#Add repository for python installation
COPY conf/python.list /etc/apt/sources.list.d/python.list

#Add a Repository Key
RUN wget http://archive.cloudera.com/cdh5/ubuntu/trusty/amd64/cdh/archive.key -O archive.key && sudo apt-key add archive.key && \
    sudo apt-get update
    
    
# Prepare installation of mysql-server
## NB : VERY IMPORTANT : we set the password for [ root ] user to 'admin'
# you should therefore use this password whenever you perform any operation with root user
# on the mysql db . Example : when initializing hive metastore DB and Oozie DB
 
RUN echo mysql-server mysql-server/root_password select admin | debconf-set-selections
RUN echo mysql-server mysql-server/root_password_again select admin | debconf-set-selections
RUN echo mysql-server mysql-server/root_password seen true | debconf-set-selections
RUN echo mysql-server mysql-server/root_password_again seen true | debconf-set-selections

#Install CDH package and dependencies
# NB : Refering to the docker recommendations on writing Dockerfile : https://docs.docker.com/v1.8/articles/dockerfile_best-practices/
# I list the packages to install in alphabetical order. This will simplify adding new packages and will simplify reading
RUN DEBIAN_FRONTEND=noninteractive sudo apt-get update && sudo apt-get install -y \
    hadoop-conf-pseudo  \
    hive-hcatalog  \
    hive-metastore  \
    hive-server2  \
    hive-webhcat  \
    hive-webhcat-server \
    hue \
    hue-plugins  \
    libmysql-java  \
    mysql-server  \
    oozie  \
    python2.7  \
    spark-core \
    spark-history-server \
    spark-python  \
    zookeeper-server 

# NB : there is an error in the cdh5 installation official documentation. The file [ /usr/share/java/libmysql-java.jar ]  does not exists for 
# ubuntu systems
RUN ln -s /usr/share/java/mysql-connector-java.jar /usr/lib/hive/lib/mysql-connector-java.jar

#Copy updated config files
COPY conf/core-site.xml /etc/hadoop/conf/core-site.xml
COPY conf/hdfs-site.xml /etc/hadoop/conf/hdfs-site.xml
COPY conf/mapred-site.xml /etc/hadoop/conf/mapred-site.xml
COPY conf/hadoop-env.sh /etc/hadoop/conf/hadoop-env.sh
COPY conf/yarn-site.xml /etc/hadoop/conf/yarn-site.xml

COPY conf/hive-site.xml /etc/hive/conf/hive-site.xml
COPY conf/my_hive_metastore_init.sql /etc/hive/conf/my_hive_metastore_init.sql
# Hcatalog env settings file
COPY conf/webhcat-env.sh /etc/hive-webhcat/conf/webhcat-env.sh

COPY conf/fair-scheduler.xml /etc/hadoop/conf/fair-scheduler.xml
COPY conf/oozie-site.xml /etc/oozie/conf/oozie-site.xml
COPY conf/spark-defaults.conf /etc/spark/conf/spark-defaults.conf
COPY conf/hue.ini /etc/hue/conf/hue.ini

#Format HDFS
RUN sudo -u hdfs hdfs namenode -format

COPY conf/run-hadoop.sh /usr/bin/run-hadoop.sh
RUN chmod +x /usr/bin/run-hadoop.sh

RUN sudo -u oozie /usr/lib/oozie/bin/ooziedb.sh create -run && \
    wget http://archive.cloudera.com/gplextras/misc/ext-2.2.zip -O ext.zip && \
    unzip ext.zip -d /var/lib/oozie

# uninstall not necessary HUE apps
RUN /usr/lib/hue/tools/app_reg/app_reg.py --remove hbase && \
    /usr/lib/hue/tools/app_reg/app_reg.py --remove impala && \
    /usr/lib/hue/tools/app_reg/app_reg.py --remove search && \
    /usr/lib/hue/tools/app_reg/app_reg.py --remove sqoop && \
    /usr/lib/hue/tools/app_reg/app_reg.py --remove rdbms && \
    /usr/lib/hue/tools/app_reg/app_reg.py --remove zookeeper && \
    /usr/lib/hue/tools/app_reg/app_reg.py --remove security

# NameNode (HDFS)
EXPOSE 8020 50070

# DataNode (HDFS)
EXPOSE 50010 50020 50075

# ResourceManager (YARN)
EXPOSE 8030 8031 8032 8033 8088

# NodeManager (YARN)
EXPOSE 8040 8042

# JobHistoryServer
EXPOSE 10020 19888

# Hue
EXPOSE 8888

# Spark history server
EXPOSE 18080

# Technical port which can be used for your custom purpose.
EXPOSE 9999

CMD ["/usr/bin/run-hadoop.sh"]
