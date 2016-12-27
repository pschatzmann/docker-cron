FROM       java:alpine
MAINTAINER Phil Schatzmann <pschatzmann@gmail.com>
RUN 		   apk add --update tar rsync libstdc++ docker rdiff-backup
COPY 	   *.jar /usr/local/bin/docker-cron/
COPY	   ./lib /usr/local/bin/docker-cron/lib/
CMD java -jar /usr/local/bin/docker-cron/docker-cron.jar 

