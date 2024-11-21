
# Download AWS Resilience Hub Assessment reports using CLI

## About

This is a project to download Resilience Hub Assessment reports using CLI. This repository is created mainly for the script used in the blog post but can upgrade it to be standalone project to access resilience hub reports with additional details. This project can be used by team/customers without Console access.

## Description

`aws-rh-download-assessment` shell script will take Region and S3 bucket as an input. This script will look for all the assessment reports for each application in a specific region , describe the assessment, components, fetch reports, create summary report (html) and upload the artifacts to S3 bucket specified

## Important

- As an AWS best practice, grant this code least privilege, or only the permissions required to perform a task. For more information, see
  [Grant least privilege](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#grant-least-privilege) in the *AWS Identity and Access Management User Guide*.


## Project 

**Requirements:**
* Python 2 version 2.6.5+ or Python 3 version 3.3+
* macOS, Linux, or Unix

### Install Prerequisites

**AWS CLI**
If you already have pip and a supported version of Python, you can install the AWS CLI with the following command:

`$ pip install awscli --upgrade --user`

[Configuring the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)

For general use, the aws configure command is the fastest way to set up your AWS CLI installation.

`$ aws configure`

The AWS CLI will prompt you for four pieces of information. AWS Access Key ID and AWS Secret Access Key are your account credentials.

[Named Profiles](https://docs.aws.amazon.com/cli/latest/userguide/cli-multiple-profiles.html)

The AWS CLI supports named profiles stored in the config and credentials files. You can configure additional profiles by using `aws configure` with the `--profile option` or by adding entries to the config and credentials files.

`$ aws configure --profile example`

**jq**

jq is a lightweight and flexible command-line JSON processor.

[Installing jq](https://stedolan.github.io/jq/download/)

OS X: Use [Homebrew](https://brew.sh/) to install jq:

`$ brew install jq`

Linux: jq is in the official [Amazon Linux AMI](https://aws.amazon.com/amazon-linux-ami/2017.03-packages/#j), [Debian](https://packages.debian.org/jq) and [Ubuntu](http://packages.ubuntu.com/jq) repositories.

Amazon Linux AMI, RHEL, CentOS:

`$ sudo yum install jq`

Debian/Ubuntu:

`$ sudo apt-get install jq`

### Usage:

Make sure you are in project home directory

```
$ cd scripts
$ ./aws-rh-download-assessment.sh <profile>
```

*NOTE:- If you are using a default profile then no need to mention the profile.
```
$ ./aws-rh-download-assessment.sh

```

### Output:

This script will generate assessment reports for all the applications for a specific region chosen and upload it to the S3 bucket provided. 
Individual reports are generated in JSON format and a summary report is generated in HTML format.

Sample HTMl report is attached below:

![Screenshot 2023-03-21 at 8 11 48 PM](https://user-images.githubusercontent.com/12705995/229577799-49714c87-aa10-4f10-a7d2-7089a4ae4e6d.png)

