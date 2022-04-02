#!/bin/bash

docker-compose up -d

user_password='123456'
repl_password='321456'

echo "Start MYSQL : Waiting for initialize mysql..."

until docker exec mysql_master sh -c 'export MYSQL_PWD=321456; mysql -u root -e ";"'
do
    echo "Waiting for mysql_master database connection..."
    sleep 5
done

create_sa_stmt='CREATE USER "user"@"%" IDENTIFIED WITH mysql_native_password BY "'$user_password'";'
grant_sa_stmt='GRANT ALL ON *.* TO "user"@"%";'

create_repl_stmt='CREATE USER "repl"@"%" IDENTIFIED WITH mysql_native_password BY "'$repl_password'";'
grant_repl_stmt='GRANT REPLICATION SLAVE ON *.* TO "repl"@"%";'

docker exec mysql_master sh -c "export MYSQL_PWD=321456; mysql -u root -e '$create_sa_stmt'"
docker exec mysql_master sh -c "export MYSQL_PWD=321456; mysql -u root -e '$grant_sa_stmt'"

docker exec mysql_master sh -c "export MYSQL_PWD=321456; mysql -u root -e '$create_repl_stmt'"
docker exec mysql_master sh -c "export MYSQL_PWD=321456; mysql -u root -e '$grant_repl_stmt'"


until docker exec mysql_slave sh -c 'export MYSQL_PWD=321456; mysql -u root -e ";"'
do
    echo "Waiting for mysql_slave database connection..."
    sleep 5
done

docker exec mysql_slave sh -c "export MYSQL_PWD=321456; mysql -u root -e '$create_sa_stmt'"
docker exec mysql_slave sh -c "export MYSQL_PWD=321456; mysql -u root -e '$grant_sa_stmt'"

docker exec mysql_slave sh -c "export MYSQL_PWD=321456; mysql -u root -e '$create_repl_stmt'"
docker exec mysql_slave sh -c "export MYSQL_PWD=321456; mysql -u root -e '$grant_repl_stmt'"


docker-ip() {
    docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$@"
}

MS_STATUS=`docker exec mysql_master sh -c 'export MYSQL_PWD=321456; mysql -u root -e "SHOW MASTER STATUS"'`

CURRENT_LOG=`echo $MS_STATUS | awk '{print $6}'`
CURRENT_POS=`echo $MS_STATUS | awk '{print $7}'`

echo 'CURRENT_LOG : '$CURRENT_LOG
echo 'CURRENT_POS : '$CURRENT_POS

echo $(docker-ip mysql_master)

docker exec mysql_slave sh -c "export MYSQL_PWD=321456; mysql -u root -e 'stop slave;'"

start_slave_stmt="CHANGE MASTER TO MASTER_HOST='$(docker-ip mysql_master)',MASTER_USER='repl',MASTER_PASSWORD='$repl_password',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS;"
start_slave_cmd='export MYSQL_PWD=321456; mysql -u root -e "'
start_slave_cmd+="$start_slave_stmt"
start_slave_cmd+='"'
docker exec mysql_slave sh -c "$start_slave_cmd"

docker exec mysql_slave sh -c "export MYSQL_PWD=321456; mysql -u root -e 'start slave;'"

docker exec mysql_slave sh -c "export MYSQL_PWD=321456; mysql -u root -e 'SHOW SLAVE STATUS \G;'"


