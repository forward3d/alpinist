from subprocess import check_output
from pathlib import Path

import json
import uuid
import boto3
import pprint
import tarfile
import datetime

s3 = boto3.resource('s3')
s3client = boto3.client('s3')
ssm = boto3.client('ssm')

def handler(event, context):
    bucket = ''
    repos = set()

    for record in event['Records']:
        # extract the bucket and key
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        repos.add(str(Path(key).parent))

        version = Path(key).parts[0]
        arch = Path(key).parts[2]

        # download the apk from s3 that triggered this
        path = downloadFromS3(bucket, key)

        # get the generated index for this apk and upload it to the bucket
        uploadToS3(bucket, getIndexPathForApk(key), getIndexForApk(path, arch))

    for repo in repos:
        # list all index files in this particular repo
        allIndexFiles = listAllIndexFiles(bucket, repo)

        # bring all the index files into the lambda
        allLocalIndexFiles = downloadAllIndexFiles(bucket, allIndexFiles)

        # concat all the index files together and then build the APKINDEX file
        apkIndexPath = concatIndexFiles(allLocalIndexFiles)
        unsignedApkIndexPath = compressApkIndex(apkIndexPath)

        # now sign the APKINDEX and upload it so S3
        signedApkIndexPath = signApkIndex(unsignedApkIndexPath)
        uploadToS3(bucket, f"{repo}/APKINDEX.tar.gz", signedApkIndexPath)

    return {}

def signApkIndex(unsignpath):
    signpath = '/tmp/{}-{}'.format(uuid.uuid4(), 'APKINDEX.tar.gz')
    keypath = '/tmp/{}-{}'.format(uuid.uuid4(), 'rsa')
    print(f"Signing {unsignpath} to {signpath}")

    name = ssm.get_parameter(Name='/apk/key', WithDecryption=False)
    keyname = name['Parameter']['Value']

    key = ssm.get_parameter(Name='/apk/rsa', WithDecryption=True)
    privateKey = open(keypath, 'w')
    privateKey.write(key['Parameter']['Value'])
    privateKey.close()

    check_output(["./apk-sign", unsignpath, signpath, keyname, keypath]).decode('utf-8')
    return signpath

def compressApkIndex(path):
    print(f"Compressing {path}")
    tarpath = '/tmp/{}-{}'.format(uuid.uuid4(), 'APKINDEX.unsigned.tar.gz')
    despath = '/tmp/{}-{}'.format(uuid.uuid4(), 'APKINDEX.unsigned.tar.gz')

    description = open(despath, 'w')
    description.write(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    description.close()

    tarpath = '/tmp/{}-{}'.format(uuid.uuid4(), 'APKINDEX.unsigned.tar.gz')
    tar = tarfile.open(tarpath, 'w:gz')
    tar.add(path, arcname='APKINDEX')
    tar.add(despath, arcname='DESCRIPTION')
    tar.close()
    return tarpath

def concatIndexFiles(indexes):
    path = '/tmp/{}-{}'.format(uuid.uuid4(), 'APKINDEX')
    with open(path, 'w') as outfile:
        for index in indexes:
            with open(index) as infile:
                outfile.write(infile.read())
    return path

def downloadAllIndexFiles(bucket, paths):
    localIndexFiles = []
    for key in paths:
        path = downloadFromS3(bucket, key)
        localIndexFiles.append(path)
    return localIndexFiles

def listAllIndexFiles(bucket, repoPath):
    file_names = []
    paginator = s3client.get_paginator('list_objects_v2')
    response_iterator = paginator.paginate(Bucket=bucket, Prefix=repoPath)
    for response in response_iterator:
        for object_data in response['Contents']:
            key = object_data['Key']
            if key.endswith('.index'):
                file_names.append(key)
    return file_names

def uploadToS3(bucket, key, path):
    print(f"S3 Upload: Bucket={bucket}, Key={key}")
    s3.meta.client.upload_file(path, bucket, key)

def getIndexPathForApk(key):
    return str(Path(key).with_suffix('.index'))

def getIndexForApk(file, arch):
    path = '/tmp/{}-{}'.format(uuid.uuid4(), Path(file).with_suffix('.index').name)
    localIndex = open(path, 'w')
    localIndex.write(check_output(["./apk-index", file, arch]).decode("utf-8"))
    localIndex.close()
    return path

def downloadFromS3(bucket, key):
    print(f"S3 Download: Bucket={bucket}, Key={key}")
    path = '/tmp/{}-{}'.format(uuid.uuid4(), Path(key).name)
    s3.Bucket(bucket).download_file(key, path)
    return path
