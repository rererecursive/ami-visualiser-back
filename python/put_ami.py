"""
PUT/LOAD:

Extract the necessary information from the files in S3:
    - manifest.json
    - ohai.json
    - output.log
    - source-ami.json
    - produced-ami.json
and load it into DynamoDB.

Loading will be done via an S3 event which triggers Lambda.

Loading should convert the parent AMI ID to the key ID in Dynamo. This ensures that the data is in a 'purely readable state', requiring no modifications when read.
"""

"""
GET (API):

Request the data from Dynamo.
"""
import json
import time
import os
import boto3

def handler(event, context):
  region  = os.environ['REGION']
  record  = event['Records'][0]
  bucket  = record['s3']['bucket']['name']
  key     = record['s3']['object']['key']
  folder  = ''.join(key.rpartition('/')[:-1])
  ami     = AMI()

  print("Fetching files from:")
  print(f"  S3 bucket: {bucket}")
  print(f"  S3 folder: {folder}")

  # print("Waiting 5 seconds for other files to be uploaded...")
  # time.sleep(5)
  s3_client = boto3.client('s3', region_name=region)

  # Process each file in the S3 folder.
  for file in ami.get_files():
    print(f"Fetching file: {file} ...")
    path = folder + file
    obj = s3_client.get_object(Bucket=bucket, Key=path)
    data = obj['Body'].read().decode('utf-8')
    ami.process_file(file, data)

  # Convert and send the item to DynamoDB.
  table = 'amis'
  item = ami.to_dynamodb_schema()
  dynamo_client = boto3.client('dynamodb', region_name=region)
  print(f"Adding the following item to table '{table}' ...")
  print(json.dumps(item, indent=2))
  dynamo_client.put_item(
    TableName=table,
    Item=item,
    ConditionExpression="attribute_not_exists(id)" # Existing images are immutable
  )

"""
Each Dynamo record is a document describing the AMI.
It links to other data via a "parent".
A parent is an AMI ID that must be resolved to an integer by querying Dynamo.
This is the only transformation required before storing the document into Dynamo.
"""
class AMI:
  def __init__(self):
    self.schema = {
      'id':         '',
      'download':   {},
      'languages':  {},
      'packages':   {},
      'summary':    {}
      # 'tags':       [],
    }
    self.processors = {
      # 'manifest.json':      [],
      # 'ohai.json':          [self.add_packages, self.add_languages],
      # 'output.log':         [],
      'produced-ami.json':  [self.add_produced_ami_details]
      # 'source-ami.json':    [self.add_source_ami_details],
      # 'packer.json':        [self.add_bake_details]
    }

  def get_files(self):
    return list(self.processors.keys())

  def process_file(self, filename, contents):
    funcs = self.processors[filename]

    for fn in funcs:
      if filename.endswith('.json'):
        contents = json.loads(contents)

      fn(contents)

  def add_source_ami_details(self, details):
    """Lookup the AMI ID from DynamoDB. If it does not exist, we'll
    need to create it using this same object.
    """
    pass

  def add_produced_ami_details(self, details):
    keys_to_keep = ['CreationDate', 'OwnerId', 'Description', 'Name']
    items = {k:v for k,v in details.items() if k in keys_to_keep}

    self.schema['summary'].update(items)
    self.schema['id'] = details['ImageId']

  def add_bake_details(self, details):
    """Add to the summary the Git details, Packer version, Chef recipe
    that came from the bake.
    """
    pass

  def add_packages(self, packages):
    """Add package information (Chef, Docker).
    """
    pass

  def add_languages(self, languages):
    """Add language information (Ruby, Python, etc).
    """
    pass

  def lookup_source_ami_id(self):
    """Query DynamoDB for the AMI's ID.
    """
    pass

  def to_dynamodb_schema(self, input=None):
    output = {}
    if input is None:
      input = self.schema

    for key, value in input.items():
      if type(value) == str:
        output[key] = {'S': value}

      elif type(value) == dict:
        items = self.to_dynamodb_schema(value)
        output[key] = {'M': items}

    return output

def get_event():
  return {
      "Records": [
          {
              "eventVersion": "2.1",
              "eventSource": "aws:s3",
              "awsRegion": "ap-southeast-2",
              "eventTime": "2020-03-24T02:14:27.695Z",
              "eventName": "ObjectCreated:Put",
              "userIdentity": {
                  "principalId": "AWS:AIDAUCEIG37ALE44XRKK6"
              },
              "requestParameters": {
                  "sourceIPAddress": "49.176.18.172"
              },
              "responseElements": {
                  "x-amz-request-id": "B2023E0029D3F448",
                  "x-amz-id-2": "FQgKG41gLONrH4trFtAGlbppYugUhiM2ovrPRsrLEoLVbUf2G81yjO8Wwxns/hK31fx/O1aYFUL29YdIayMso0XzsreElCj3o0l2XrM9EJs="
              },
              "s3": {
                  "s3SchemaVersion": "1.0",
                  "configurationId": "zac",
                  "bucket": {
                      "name": "ztlewis-builds",
                      "ownerIdentity": {
                          "principalId": "A3A8XHM6GKL9A4"
                      },
                      "arn": "arn:aws:s3:::ztlewis-builds"
                  },
                  "object": {
                      "key": "packer-builds/web-master-2020-03-23T21-23-01/source-ami.log",
                      "size": 0,
                      "eTag": "d41d8cd98f00b204e9800998ecf8427e",
                      "sequencer": "005E796D04CFE221F5"
                  }
              }
          }
      ]
  }

handler(get_event(), {})
