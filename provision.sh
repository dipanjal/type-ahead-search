#!/bin/sh
host_user=ubuntu
host_ip=13.233.237.20
pem_file_path=~/.ssh/java-2201-aws.pem
project_name=type-ahead-search
tar_file_name=$project_name.tar.gz

apt_install() {
    echo Login into $host_ip and installing apts
    ssh -i $pem_file_path $host_user@$host_ip "sudo apt update -y"
    ssh -i $pem_file_path $host_user@$host_ip "sudo apt install docker.io -y && sudo usermod -aG docker $host_user"
    ssh -i $pem_file_path $host_user@$host_ip "sudo apt install docker-compose -y"
    ssh -i $pem_file_path $host_user@$host_ip "sudo apt install make -y"

}

make_tar() {
    echo .
    echo cleanup previous tar.gz file
    [ -f "$tar_file_name" ] && rm -rf $tar_file_name

    echo .
    echo creating tar file
    tar -zcvf $tar_file_name .
}

upload_files() {
    make_tar

    echo .
    echo create new project directory or cleanup if already exists 
    ssh -i $pem_file_path $host_user@$host_ip "[ -d "~/$project_name" ] && rm -rf ~/$project_name/* || mkdir ~/$project_name"

    echo .
    echo uploading tar file to remote server
    scp -i $pem_file_path ./$tar_file_name $host_user@$host_ip:~/$project_name

    echo .
    echo extracting tar file
    ssh -i $pem_file_path $host_user@$host_ip "cd ~/$project_name && tar -xzf $tar_file_name && ls"
}

check_hdfs() {
    directory=/phrases 
    ssh -i $pem_file_path $host_user@$host_ip "docker exec -i assembler.hadoop.namenode hdfs dfs -ls $directory"
    ssh -i $pem_file_path $host_user@$host_ip "docker exec -i assembler.hadoop.namenode hdfs fsck $directory"
}

show_logs() {
    ssh -i $pem_file_path $host_user@$host_ip "cd ~/$project_name && make logs"
}

cleanup_docker() {
    if [[ "$2" == 'clean' ]]
    then
        if [[ "$3" == '--hard' ]]
        then 
            echo Hard cleaning docker system
            ssh -i $pem_file_path $host_user@$host_ip "cd ~/$project_name && make clear"
        fi
    else
        ssh -i $pem_file_path $host_user@$host_ip "cd ~/$project_name && make stop"
    fi
    
}

run_and_setup() {
    echo .
    echo run and setup
    ssh -i $pem_file_path $host_user@$host_ip "cd ~/$project_name && make run"
    sleep 10s
    ssh -i $pem_file_path $host_user@$host_ip "cd ~/$project_name && make setup"
    check_hdfs
}

deploy() {
    upload_files
    cleanup_docker
    run_and_setup
}


if [[ "$1" == 'logs' ]]
then
    show_logs
elif [[ "$1" == 'hdfs' ]]
then
    check_hdfs
elif [[ "$1" == 'deploy' ]]
then
    deploy
else
    apt_install
    deploy
fi