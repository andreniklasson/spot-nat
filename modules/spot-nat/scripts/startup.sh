#!/bin/bash
yes | sudo yum update
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
INSTANCE_ID=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id`
REGION=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/placement/region`
aws ec2 modify-instance-attribute --instance-id $INSTANCE_ID --source-dest-check "{\"Value\": false}" --region $REGION
sudo yum install iptables-services -y
sudo systemctl enable iptables
sudo systemctl start iptables
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -F FORWARD
sudo iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
sudo service iptables save