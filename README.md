# Detailed instructions on how to setup managed k8s aws-eks cluster with autoscaling manually with UI & CLI to learn the hard way :p

In this chapter we provision and use an AWS EKS cluster via the AWS Management Console and the eksctl CLI tool to learn the manual process before later automating it with Terraform.

<b><u>The course examples are:</u></b>
1. Provision an EKS cluster with IAM Roles, VPC for worker nodes with IGW & NAT Gateway & private & public subnets with associated route tables
2. Create an EC2 NodeGroup with associated IAM rules, a deployed autoscaler and test scale up & scale down
3. Create Serverless Fargate Managed Pods with IAM Role and pod selector criteria
4. Provision the EKS cluster with NodeGroup (from step 1&2) with a single eksctl CLI tool command
5. Integrate EKS cluster into a Jenkins CI/CD pipeline via custom Docker Image with aws & k8s dependencies installed

<b><u>The exercise projects are:</u></b>
1. wip

## Setup

### 1. Pull SCM

Pull the repository locally by running
```bash
git clone https://github.com/hangrybear666/12-devops-bootcamp__aws_eks.git
```

### 2. Install kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### 3. Install helm

See https://helm.sh/docs/intro/install/
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 4. Install helmfile and run helmfile init to install plugins

Find the binary link for your OS at https://github.com/helmfile/helmfile/releases
```bash
curl -LO https://github.com/helmfile/helmfile/releases/download/v1.0.0-rc.4/helmfile_1.0.0-rc.4_linux_386.tar.gz
tar -xzf helmfile_1.0.0-rc.4_linux_386.tar.gz --wildcards '*helmfile'
sudo chmod +x helmfile
sudo mv helmfile /usr/bin/helmfile
helmfile init
# install plugins by agreeing with "y"
```

## Usage (course examples)

<details closed>
<summary><b>1. Provision an EKS cluster with IAM Roles, VPC for worker nodes with IGW & NAT Gateway & private & public subnets with associated route tables</b></summary>

#### a. Create IAM Role for EKS Cluster
IAM -> Roles -> Create role -> AWS Service -> EKS -> EKS Cluster (Use Case) -> Name "aws-console-eks-cluster-role" -> Next x3

#### b. Create VPC, Subnet, IGW, NAT Gateway, Security Group, Route Tables, Routes and Attachments with CloudFormation Template
CloudFormation -> Create Stack -> Choose an existing template -> Amazon S3 URL -> https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/amazon-eks-vpc-private-subnets.yaml
-> Stack name "aws-console-eks-vpc-stack" -> Next -> Next -> Submit

*NOTE:* The Documentation for setting up the VPC via CloudFormation can be found here: https://docs.aws.amazon.com/eks/latest/userguide/creating-a-vpc.html

- The VPC is designed to contain Kubernetes worker nodes, with both private and public subnets across two availability zones (AZs)
- It contains 2 private and 2 public subnets in two AZs.
- The 2 public subnets have **one** route tables associated with it that directs traffic to the IGW for internet connectivity.
- The public subnets also include a NAT gateway each, so instances in the private subnets can route egress to NAT gateway via route tables.
- The NAT gateway forwards the request to the IGW for outbound internet access, while keeping instances in the private subnet closed off for ingress.
- There are two private route tables because each private subnet routes internet-bound traffic through a different NAT Gateway. This allows for high availability and redundancy across multiple Availability Zones (AZs).
- A security group is created for controlling communication between the EKS control plane and worker nodes.

#### VPC and Networking
- **VPC**
- **Public Subnet 01**
- **Public Subnet 02**
- **Private Subnet 01**
- **Private Subnet 02**

#### Route Tables and Associations
- **Public Route Table**
- **Private Route Table 01**
- **Private Route Table 02**
- **Public Route**
- **Private Route 01**
- **Private Route 02**
- **Public Subnet 01 Route Table Association**
- **Public Subnet 02 Route Table Association**
- **Private Subnet 01 Route Table Association**
- **Private Subnet 02 Route Table Association**

#### Gateways and Attachments
- **Internet Gateway**
- **VPC Gateway Attachment**
- **NAT Gateway 01**
- **NAT Gateway 02**
- **NAT Gateway EIP 1**
- **NAT Gateway EIP 2**

### Security
- **Control Plane Security Group**

#### c. Save Outputs for EKS creation
Navigate to *Cloudformation -> "aws-console-eks-vpc-stack" -> Outputs* and note down the `VpcId` and `SecurityGroup` e.g. `vpc-04949f5326907d10f` & `sg-0fbe7eccb24716e60`

#### d. Create EKS cluster from management console
EKS -> Clusters -> Create EKS cluster -> Name: "aws-console-eks-cluster" -> Upgrade policy = Standard -> Secrets encryption (NO) -> Next -> VPC ID from step c) -> Select all subnets -> Security Group from step c) -> Cluster endpoint access = Public and Private -> Control plane logging (NONE) -> Prometheus Metrics (NONE) -> EKS Addons (kube-proxy, Amazon VPC CNI, CoreDNS) -> Next -> Create

#### e. Wait until cluster is ready and check health status
Wait (~10mins) until EKS control plane has been initialized and check for correct setup

```bash
aws eks update-kubeconfig --name aws-console-eks-cluster
cat ~/.kube/config
kubectl cluster-info
```

</details>

-----
<details closed>
<summary><b>2. Create an EC2 NodeGroup with associated IAM rules, a deployed autoscaler and test scale up & scale down</b></summary>

#### a. Create IAM Roles and Permissions for NodeGroups
IAM -> Roles -> Create Role -> Aws Service -> User Case (EC2) -> Add permission -> AmazonEKSWorkerNodePolicy & AmazonEC2ContainerRegistryReadOnly & AmazonEKS_CNI_Policy -> Role Name "aws-console-eks-ec2-nodegroup-policy" -> Create Role

*Note* See https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html for additional documentation

#### b. Create Security Group for SSH Access to Worker Nodes from restricted IPs
Security Groups -> Name "aws-console-eks-nodegroup-ssh-access" -> Select EKS VPC -> Inbound Rule (SSH) Port 22 with only my IP e.g. 3.79.46.109/32 -> Outbound Rule (Delete)

#### c. Create Node Group with preinstalled container runtime and kubernetes dependencies
EKS -> Clusters -> aws-console-eks-cluster -> Compute -> Add Node Group -> Name "aws-console-eks-ec2-node-group" -> Attach IAM role from step f) -> Amazon Linux 2 -> On-Demand -> t2.small -> 10GiB Disk size -> Desired size 3 / Minimum size 2 / Maximum size 3 / Maximum unavailable 1 -> Configure Remote Access (Yes) -> Allow remote access from selected Security Group from step g)

#### d. Configure Autoscaling by setting up a custom IAM policy
IAM -> Policies -> Create policy -> JSON -> Name "aws-console-eks-nodegroupAutoscalerPolicy" -> Create Policy -> Attach Policy -> aws-console-eks-ec2-nodegroup-policy
Apply the code from `autoscalingPermissions.json` but be sure to check the following documentation in case the Policies have changed:
 https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md#full-cluster-autoscaler-features-policy-recommended

#### e. Deploy Autoscaler in EKS clusters kube-system namespace

- Check for newest yaml file here and overwrite the local `cluster-autoscaler-autodiscover.yaml` file: https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
- Then replace the version tag of the autoscaler image with the corresponding version of your kubernetes cluster. You can find your cluster version by checking in AWS Console at EKS -> Clusters -> aws-console-eks-cluster
- Then navigate to https://github.com/kubernetes/autoscaler/tags and select the corresponding tag to replace `registry.k8s.io/autoscaling/cluster-autoscaler:v1.30.2` in `cluster-autoscaler-autodiscover.yaml` with the appropriate version.
- You might have to change the ssl-certs mount Path to support the Amazon Linux Version running on your worker nodes with e.g. `mountPath: /etc/ssl/certs/ca-bundle.crt`

**IMPORTANT** if you have given the eks cluster another name, then you have to replace this in `cluster-autoscaler-autodiscover.yaml` at the end of the line `- --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/aws-console-eks-cluster`

```bash
kubectl apply -f cluster-autoscaler-autodiscover.yaml
kubectl get all -n kube-system
kubectl get nodes
```

#### f. Scale Down NodeGroup by decreasing the desired size to 1

Change the desired size to e.g. 1 and check the autoscaler logs for changes.

EKS -> Clusters -> aws-console-eks-cluster -> Node groups -> aws-console-eks-ec2-node-group -> Edit node group
```bash
# replace with your pod id
kubectl logs deployment.apps/cluster-autoscaler -n kube-system
kubectl get nodes -w # watch continuously
```

#### g. Create nginx deployment with LoadBalancer to check public availability of Pod Service

The following deployment automatically creates a publicly available Load Balancer under EC2 -> Load balancers which is situated in both public subnets (where individual nodes reside in either one)
```bash
kubectl apply -f nginx-deployment.yaml
```

Navigate to your Load Balancer public DNS name and check ingress capability.

 #### h. Create 30 replicas of nginx to check scale up, then delete pods to watch scale down

Then change replica count to 30 in `nginx-deployment.yaml` and run the apply command again. The autoscaler should now provision up to the maximum number of nodes (3) in order to start all pods.
```bash
# change replicas to 30
kubectl apply -f nginx-deployment.yaml
kubectl logs deployment.apps/cluster-autoscaler -n kube-system
kubectl get pods -w # watch continuously
kubectl get nodes
# clean up and watch scale down
kubectl delete -f nginx-deployment.yaml
kubectl logs deployment.apps/cluster-autoscaler -n kube-system
kubectl get nodes
```


</details>

-----

<details closed>
<summary><b>3. Create Serverless Fargate Managed Pods with IAM Role and pod selector criteria</b></summary>

#### a. Create IAM Role for EKS Fargate
IAM -> Roles -> Create role -> AWS Service -> EKS -> EKS - Fargate Pod (Use Case) -> Name "aws-console-eks-fargate-pod-role" -> Next x3

#### b. Create Fargate Profile in EKS Cluster
EKS -> Clusters -> aws-console-eks-cluster -> Compute -> Add Fargate Profile -> Name "aws-console-eks-fargate-profile" -> Select Private Subnets -> Namespace "dev-fargate" -> Match Labels key:value = profile:fargate
*NOTE:* Even though Fargate managed service runs in its own AWS VPC, our pods will have an internal IP address within our cluster, pulling from the private subnet CIDR range

#### c. Deploy nginx with fargate namespace and label selectors

*NOTE:* all pods are deployed in their own fargate node running in a separate VM
```bash
kubectl create ns dev-fargate
kubectl apply -f nginx-deployment-fargate.yaml
kubectl get pods -n dev-fargate -w
kubectl get nodes
# delete
kubectl delete -f nginx-deployment-fargate.yaml
kubectl delete ns dev-fargate
```

</details>

-----

<details closed>
<summary><b>4. Provision the EKS cluster with NodeGroup (from step 1&2) with a single eksctl CLI tool command</b></summary>

#### a. Delete all resources created in prior steps

#### b. Install eksctl
```bash
mkdir ~/eksinstall/ && cd ~/eksinstall/
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo mv /tmp/eksctl /usr/local/bin
cd - && sudo rm -rf ~/eksinstall/
```

#### c. Create Cluster via CLI

```bash
eksctl create cluster \
  --name aws-eksctl-cluster \
  --version 1.30 \
  --region eu-central-1 \
  --nodegroup-name aws-eksctl-nodeGroup \
  --node-type t2.small \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \

```

</details>

-----

<details closed>
<summary><b>5. Integrate EKS cluster into a Jenkins CI/CD pipeline via custom Docker Image with aws & k8s dependencies installed</b></summary>

#### a. Build and Push a Docker container to ECR that includes aws-iam-authenticator and kubectl for jenkins to use as an agent
```bash
docker build -f Dockerfile -t aws-iam-auth-k8s:0.1 .
docker tag aws-iam-auth-k8s:0.1 010928217051.dkr.ecr.eu-central-1.amazonaws.com/k8s-imgs:aws-iam-auth-k8s-0.1
docker push 010928217051.dkr.ecr.eu-central-1.amazonaws.com/k8s-imgs:aws-iam-auth-k8s-0.1
```

#### b. Retrieve information about your cluster and add it to the aws-iam-auth config file
- Change the endpoint url in `aws-iam-authenticator-config.yaml` at `clusters.cluster.server` to your own after retrieving it in the aws cli
- Change the cluster name at the bottom under args in case you named your cluster something else other than in step 4c)
- Retrieve `certificate-authority-data` from your kube/config that has been set up by eksctl after cluster creation and add it to `clusters.cluster.certificate-authority-data`

```bash
# retrieve endpoint url
aws eks describe-cluster --name aws-eksctl-cluster --query 'cluster.endpoint'
# retrieve certificate data for the cluster matching your endpoint url
cat ~/.kube/config
```

#### c. Configure Credentials on Jenkins for AWS, Git, Docker Hub, and Kubernetes

- Create Username:Password with the id `docker-hub-repo` containing your user and API Token as password
- Create Username:Password with the id `git-creds` with either your username or jenkins and an API Token as password
- Create Secret Text with the id `aws_access_key_id` with your AWS IAM Account's Access Key ID (or better a dedicated Jenkins IAM Account)
- Create Secret Text with the id `aws_secret_access_key` with your AWS IAM Account's Secret Access Key (or better a dedicated Jenkins IAM Account)
- Create Secret File with the id `aws-iam-authenticator-config` with your updated `aws-iam-authenticator-config.yaml` from step b)

```bash
```

#### d.

```bash

```


</details>
-----