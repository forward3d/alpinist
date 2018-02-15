# Alpinist

Automatic Alpine Linux Package (apk) Repository Generation using AWS Lambda, S3 & SSM Parameter Store

## Summary

This project provides you with an python [AWS Lambda](https://aws.amazon.com/lambda/) function that is capable of automatically creating a signed Alpine Repository whenever a new Alpine Package is uploaded into an S3 bucket.

## Table of Contents

<!-- toc -->

- [Installation](#installation)
  * [Prerequisites](#prerequisites)
  * [Steps](#steps)
    + [1. Uploading the Lambda function code](#1-uploading-the-lambda-function-code)
    + [2. Running CloudFormation](#2-running-cloudformation)
- [Alpine Repository](#alpine-repository)
  * [Layout](#layout)
    + [`.index` files](#index-files)
  * [Adding a Package](#adding-a-package)
  * [Using the Repository within Alpine](#using-the-repository-within-alpine)
    + [Adding your Public Key](#adding-your-public-key)
    + [Adding the Repository](#adding-the-repository)
  * [Index Signing](#index-signing)
    + [Keys](#keys)
      - [Pair Generation](#pair-generation)
      - [Public Key](#public-key)
      - [Storing in AWS SSM Parameter Store](#storing-in-aws-ssm-parameter-store)
- [Included Binary blobs (`abuild-tar` & `apk`)](#included-binary-blobs-abuild-tar--apk)
  * [Re-building the binaries from source](#re-building-the-binaries-from-source)
- [Authors](#authors)
- [Code of Conduct](#code-of-conduct)
- [License](#license)
- [Acknowledgments](#acknowledgments)

<!-- tocstop -->

## Installation

This project uses [AWS SAM](https://docs.aws.amazon.com/lambda/latest/dg/serverless_app.html) for storing all the CloudFormation infrastructure, which is basically an optimized version of CloudFormation. You can see what objects will be created in the `template.yaml` file.

### Prerequisites

* An existing S3 bucket to use for storing the lambda code
* [AWS CLI](https://aws.amazon.com/cli/) installed and configured with credentials
* Public/Private keypair used for signing packages and the repository (See [Keys](#keys))
  * Private key must exist within AWS SSM Parameter Store (See [Index Signing](#index-signing))

### Steps

#### 1. Uploading the Lambda function code

Once you have created the S3 bucket that you will store the lambda code within, you will need to run this command to deploy it. Remember to put in the name of your bucket.

    aws cloudformation package \
      --template-file template.yaml \
      --output-template-file serverless-output.yaml \
      --s3-bucket BUCKETNAME

#### 2. Running CloudFormation

You need to decide on the name of the bucket you want to use as your repository, don't create this S3 bucket, as the template will do that for you. You also need to pick a name for the CloudFormation stack.

So now we have our generated template from the previous command, you now need to deploy it...

    aws cloudformation deploy \
      --parameter-overrides BucketName=BUCKETNAMEFORTHEREPO \
      --template-file serverless-output.yaml \
      --stack-name NAMEOFTHECLOUDFORMATIONSTACK \
      --capabilities CAPABILITY_IAM

If that completes successfully, then you all all deployed.

## Alpine Repository

### Layout

In S3 you __must__ use this specific directory layout...

    /<alpine_version>/<repository_name>/<architecture>

Example...

    /3.7/main/x86_64/aspell-ar-1.2-r0.apk

You can have as many combinations of Alpine version, repository name and architecture as you like.

#### `.index` files

Whenever a package is processed by the Lambda function it will create an index file at the same path. These files contain some metadata about individual packages, and are used to to generate the overall `APKINDEX` for each repository.

It will be named exactly the same as the package, but instead of an `.apk` file extension it will be `.index`. These files are replaced whenever the individual package file is changed or touched.

### Adding a Package

Simply upload your `apk` file to the correct location within S3. When you upload an Alpine package the Lambda function will generate the `APKINDEX.tar.gz` automatically.


### Using the Repository within Alpine

When you have uploaded a package and it has successfully created the `APKINDEX.tar.gz` you will of course want to use the repository within Alpine. You must add the public key, and then configure the repositories you want.


#### Adding your Public Key

Install the public key into Alpine by simply downloading it to the correct directory from S3...

    cd /etc/apk/keys
    wget https://s3-REGION.amazonaws.com/BUCKETNAME/KEYNAME.rsa.pub

Example...

    cd /etc/apk/keys
    wget https://s3-eu-west-1.amazonaws.com/apks/developers@forward3d.com-5a7dfa17.rsa.pub

#### Adding the Repository

Once you have the public key, you must also add the repositories you want to enable. You do this by simply adding a line to the `/etc/apk/repositories` file.

    echo "https://s3-REGION.amazonaws.com/BUCKETNAME/ALPINEVERSION/REPOSITORYNAME" >> /etc/apk/repositories

For example...

    echo "https://s3-eu-west-1.amazonaws.com/apks/3.7/main" >> /etc/apk/repositories

After that, simply update...

    apk update

### Index Signing

You must provide a RSA private key for signing the repository, you must use the same key that generated the package, otherwise you will end up with `bad signatures` or `untrusted key`. This has to be stored in [AWS SSM Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-paramstore.html) as a `Secure String`.

#### Keys

##### Pair Generation

If you need to generate some keys to use, have a look at the instructions on this Github repo...

https://github.com/andyshinn/docker-alpine-abuild#keys

##### Public Key

Make sure you make your public key available, as you will need to install it on any machine you want to use the repository from. We suggest putting it at the root of the S3 bucket.

##### Storing in AWS SSM Parameter Store

You need to store the private half of your keypair in [AWS SSM Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-paramstore.html) in the region you want to deploy the Lambda function. Since you can't create `SecureString` parameters through CloudFormation you must go do this manually through the interface or using the AWS CLI.

    aws ssm put-parameter --region 'eu-west-1' --name '/apk/rsa' --type 'SecureString' --value "`cat developers@forward3d.com-5a7dfa17.rsa`"
    aws ssm put-parameter --region 'eu-west-1' --name '/apk/key' --type 'String' --value 'developers@forward3d.com-5a7dfa17.rsa.pub'

Note: `/apk/key` does not contain the public key, it contains literally the __name__ of the public key.

## Included Binary blobs (`abuild-tar` & `apk`)

These binaries are required to generate the index itself. These could be re-written in Python if someone is up for the challenge, however currently it was easier to compile them to run inside Amazon Linux.

### Re-building the binaries from source

If you don't trust this repository and want to re-build these binaries yourself, you can do so easily with the `Dockerfile` in the `docker/apk-tools` directory. Simply build the image, and then copy out the files while the container is still running...

    docker build -t apk-tools .
    docker run -it --rm apk-tools

    docker cp `docker ps | grep apk-tools | awk '{print $1}'`:/apk-tools/src/apk .
    docker cp `docker ps | grep apk-tools | awk '{print $1}'`:/abuild/abuild-tar .

## Authors

See the list of [contributors](https://github.com/forward3d/alpinist/contributors) who participated in this project.

## Code of Conduct

This project is has a code of conduct - please see the [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) file for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

* [Andy Shinn](https://github.com/andyshinn) for his various Alpine packaging repos
