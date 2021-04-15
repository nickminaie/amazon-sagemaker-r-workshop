## On-Start: Once you set up the environment once
## then you can have this life-cycle config to link the custom env with kernel

## Script: Nick Minaie
## Github: https://github.com/nickminaie/AWS-SageMaker-R-Workshop
## Date: May 5, 2020

#!/bin/bash
sudo -u ec2-user -i <<'EOF'
ln -s /home/ec2-user/SageMaker/envs/custom-r /home/ec2-user/anaconda3/envs/custom-r

EOF
echo "Restarting the Jupyter server.."
restart jupyter-server
