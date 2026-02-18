[webservers]
wordpress-web ansible_host=${web_server_ip} ansible_user=ansible

[webservers:vars]
wordpress_url=${wordpress_url}
database_host=${db_host}
s3_bucket_name=${s3_bucket_name}

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_private_key_file=~/.ssh/app1-web-key
