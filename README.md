## Overview
We provide an lean implementation of a job scheduling functionality where the jobs can be easily defined with docker labels.It is possible to set up single jobs which just run on the container where the labels are defined or central jobs which run against all containers.

Docker-cron is based on Alpine and it includes a docker client and the most important backup tools (tar rsync  rdiff-backup borgbackup)

 
## execute 
Just start the scheduler with

-  docker run --name docker-cron -v /var/run/docker.sock:/var/run/docker.sock  pschatzmann/docker-cron

and we will pick up all scheduling information which is defined in any of your containers.
 
##  docker-compose.yml
    version: '2'
      services:
        docker-cron:
        image: pschatzmann/docker-cron
        container_name: docker-cron
        volumes:
            - /var/run/docker.sock:/var/run/docker.sock
        restart: always



##  Labels

The job information is defined in the labels of the containers. Only the schedule and the command information is mandatory. If the job should only consist of one step, the step information can be skipped.

    job.<jobname>.condition = <condition>  (e.g true)
    job.<jobname>.schedule = <cron expression> (e.g.", "* * * * *")
    job.<jobname>.command.<stepName> = <command template> (e.g. echo test)
    job.<jobname>.condition.<stepName>.condition = <condition>  (e.g. false)
    job.<jobname>.scenario = "system | container | volume | containerLabelsWithSystem | containerVolumesWithTempSystem"
    job.<jobname>.scriptengine = <scripting engine>  (e.g javascript)


#  Example

The following example is printing the name of the container and the volumes every minute to the console
            - job.echo.schedule=* * * * *
            - job.echo.command=echo name={name} id={id}

# Schedule (Cron Expression) 
A UNIX crontab-like pattern is a string split in five space separated parts. Each part is intended as:

- Minutes sub-pattern. During which minutes of the hour should the task been launched? The values range is from 0 to 59.
- Hours sub-pattern. During which hours of the day should the task been launched? The values range is from 0 to 23.
- Days of month sub-pattern. During which days of the month should the task been launched? The values range is from 1 to 31. The special value "L" can be used to recognise the last day of month.
- Months sub-pattern. During which months of the year should the task been launched? The values range is from 1 (January) to 12 (December), otherwise this sub-pattern allows the aliases "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov" and "dec".
Days of week sub-pattern. During which days of the week should the task been launched? The values range is from 0 (Sunday) to 6 (Saturday), otherwise this sub-pattern allows the aliases "sun", "mon", "tue", "wed", "thu", "fri" and "sat".

The star wildcard character is also admitted, indicating "every minute of the hour", "every hour of the day", "every day of the month", "every month of the year" and "every day of the week", according to the sub-pattern in which it is used.

Once the scheduler is started, a task will be launched when the five parts in its scheduling pattern will be true at the same time.

# Commands
The indicated <command template> is used to build the command which needs to be executed. The standard template engine is simply replacing the expressions in curly braces {fieldname} with the corresponding label values. 

It is possible to use the scripting engine instead of this default templating engine with the label  "job.<jobname>.isScriptingAsTemplate=true". In this case you need to provide the command as a valid expression in the scripting language. E.g 'echo name='+name+' volume='+volume

# Variables
All container labels are available as variables. In addition we support the following additional variables
 -  name: container name
 - id: container id
 - host: host of the current container
 - docker-cron-host: host of the container which is running docker-cron
 - image: the image id
 - volume: internal volume name

# Conditions
This is an expression formulated in a scripting language which resolved to true or false. The default scripting engine is using javascript. e.g.  name == 'test' is evaluating true only if the container name is 'test'

 # Scenarios
This is mainly relevant for jobs which are defined in the 'docker-cron' container. 
- for 'system' the job is executed only once. 
- for 'container' we execute one job for each container which exists in Docker. 
- for 'volume' we start the job for each volume of the container and the volume information can be accessed with {volume} in the templating engine or with the volume variable in the scripting engine. 
- for 'containerLabelsWithSystem' we execute the job in the 'docker-cron' container using the variable informations of the current container
- for 'containerVolumesWithTempSystem' we create a new temporary docker-cron container which inherits the volume information of the local container. 


## Scripting Engines
We are supporting any scripting engine which implements JSR223. As default we use the standard implementation which comes with java. If you want to extend the scripting functionality you just need to copy the implementation jars to the mapped volume /usr/local/bin/docker-cron/lib/. 

Then you can select in your job the scripting language with the label corresponding label:  e.g. job.echo.scriptengine = javascript 

## Example Scenarios 

# Backup Docker Container

All containers are exported as tar files to the /backup directory every hour

    version: '2'
      services:
        docker-cron:
          image: pschatzmann/docker-cron
          container_name: docker-cron
          labels:
            - job.level=container
            - job.container-backup.schedule=0 * * * *
            - job.container-backup.command=docker export -o /backups/{name}.tar {id}
          volumes:
            - /var/run/docker.sock:/var/run/docker.sock
            - /backup:/backup
          restart: always

# Backup Volumes
All volumes of all containers are saved as tar files to the /backup directory on the host every hour

    version: '2'
    services:
      docker-cron:
        image: pschatzmann/docker-cron
        container_name: docker-cron
        labels:
            - job.volume-backup.level=volume
            - job.volume-backup.centralExecutor=true
            - job.volume-backup.schedule=0 * * * *
            - job.volume-backup.command.tar=tar -czvf /backup/{name}-volume.tar.gz {volume}
        volumes:
            - /var/run/docker.sock:/var/run/docker.sock
            - /backup:/backup
        restart: always

# Backup Postgres
Every day at midnight, we dumb all postgres containers and copy the dump into the /backup directory of the host. Then we user the docker cp to copy the file out of the container to the host

    version: '2'
      services:
        docker-cron:
          image: pschatzmann/docker-cron
          container_name: docker-cron

          labels:
            - job.level=container
            - job.condition=container.matches("postgres.*")
            - job.postgres-backup.command.1=docker exec -t {name} pg_dumpall -c -U postgres -f /var/lib/postgresql/data/dump-{name}.sql
            - job.postgres-backup.command.2=docker cp {name}:/var/lib/postgresql/data/dump-{name}.sql /backup 
          volumes:
            - /var/run/docker.sock:/var/run/docker.sock
          restart: always


# Combined Example
And here is a combined example that backs up the containers,  all volumes of all containers and the database containers

    version: '2'
    services:
     docker-cron:
      image: pschatzmann/docker-cron
      container_name: docker-cron
      volumes:
       - /var/run/docker.sock:/var/run/docker.sock
       - /backup:/backup
      labels:
        - job.schedule=0 * * * *
        - job.container-backup.scenario=containerLabelsWithSystem
        - job.container-backup.command=docker export -o /backup/{name}.tar {id}
        - job.volume-backup.condition= name != 'nginx'
        - job.volume-backup.scenario=containerVolumesWithTempSystem
        - job.volume-backup.command.tar=tar -czvf /backup/{name}-volume.tar.gz {volume}
        - job.postgres-backup.scenario=container
        - job.postgres-backup.condition=image.startsWith('postgres')
        - job.postgres-backup.command.1=docker exec -t {name} pg_dumpall -c -U postgres -f /var/lib/postgresql/data/dump-{name}.sql
        - job.postgres-backup.command.2=docker cp {name}:/var/lib/postgresql/data/dump-{name}.sql /backup 

      restart: always


