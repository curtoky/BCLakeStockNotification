# OVERVIEW
A fun side-project to track when BC lakes are being stocked with fish. The application is a fully deployable serverless application utilizing:
* A Flask web application for sign up and unsubscribing hosted in ECS Fargate
    * User registers with name, phone number, and region of interest (IE. Lower Mainalnd)
* A lambda function scheduled by EventBridge that
    * Scrapes for any newly updated lakes
    * Checks DynamoDB for all users and confirms if those lakes are in their region of interest, if so, send a personalized text messaging informing them that the lakes have been restocked.
<img src="https://user-images.githubusercontent.com/23089491/171757822-b2080a8d-1963-41bc-8a27-cfe09bc49417.jpg" width="557" height="696">
<br/><br/>

# AWS ARCHITECTURE
![LakeStockNotification](https://user-images.githubusercontent.com/23089491/171752983-6e0181c4-5641-464e-a4c4-036f8a0b0fab.png)

<br/><br/><br/><br/><br/>

# PRE-REQS
#### This guide assumes the following tools are already installed on your computer, if not please download and install from here:
##### AWS CLI - https://aws.amazon.com/cli/
##### DOCKER - https://www.docker.com/products/docker-desktop/
##### TERRAFORM - https://www.terraform.io/downloads

<br/><br/>

# AWS CLI

#### Create an ECR repository to upload the Docker App to.
```
cd LakeStockNotification/WebApp/

aws ecr create-repository \
    --repository-name flask-repo \
    --image-scanning-configuration scanOnPush=true \
    --region us-east-1
```


#### If successful you should see something following. Take note of the "accountID" in the results as it's used for the Docker and Terraform piece.
```json
{
    "repository": {
        "repositoryUri": "<accountID>.dkr.ecr.us-east-1.amazonaws.com/flask-repo", 
        "imageScanningConfiguration": {
            "scanOnPush": true
        }, 
        "encryptionConfiguration": {
            "encryptionType": "AES256"
        }, 
        "registryId": "<accountID>", 
        "imageTagMutability": "MUTABLE", 
        "repositoryArn": "arn:aws:ecr:us-east-1:<accountID>:repository/flask-repo", 
        "repositoryName": "flask-repo","createdAt": 1652233192.0
    }
}
```


# DOCKER

#### Here is where push the docker app to ECR.
```
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <accountID>.dkr.ecr.us-east-1.amazonaws.com
docker build -t flask-repo .
docker tag flask-repo:latest <accountID>.dkr.ecr.us-east-1.amazonaws.com/flask-repo:latest
docker push <accountID>.dkr.ecr.us-east-1.amazonaws.com/flask-repo:latest

```


# TERRAFORM

#### Now we run the Terraform code to build the infrastructure and run the code.
```
cd ../TFCode/

terraform init
terraform plan
terraform apply
```
#### You will be prompted to add the ECR image URL, it will be the below URL + account ID.
```
  Please enter your ECR image URL:

  Enter a value: 
```
#### Add it here.
```  
<accountID>.dkr.ecr.us-east-1.amazonaws.com/flask-repo:latest
```
