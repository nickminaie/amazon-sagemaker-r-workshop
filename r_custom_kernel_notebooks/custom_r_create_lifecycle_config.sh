## On-Create: Bringing custom environment from S3 to SageMaker instance
## NOTE: Your SageMaker IAM role should have access to this bucket

## Script: Nick Minaie
## Github: https://github.com/nickminaie/AWS-SageMaker-R-Workshop
## Date: May 5, 2020

#!/bin/bash
sudo -u ec2-user -i <<'EOF'
aws s3 cp s3://[YOUR BUCKET]/custom_r.zip ~/SageMaker/
unzip ~/SageMaker/custom_r.zip -d ~/SageMaker/
mv ~/SageMaker/home/ec2-user/SageMaker/envs/ ~/SageMaker/envs
rm -rf ~/SageMaker/home/
rm ~/SageMaker/custom_r.zip

EOF
