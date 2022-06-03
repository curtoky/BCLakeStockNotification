import boto3
import requests
from bs4 import BeautifulSoup
from datetime import datetime, timedelta
import json

access_key = ${{ secrets.AWS_ACCESS_KEY }}
secret_key = ${{ secrets.AWS_SECRET_KEY }}

## Create an SNS client
def sendtext(fulllist,FisherNumber):
  print(FisherNumber)
  client = boto3.client(
      "sns",
      aws_access_key_id=access_key,
      aws_secret_access_key=secret_key,
      region_name="us-east-1"
  )
  
  # Send your sms message.
  client.publish(
      PhoneNumber=FisherNumber,
      Message=fulllist
  )
  

def getusers():
  client = boto3.client(
      "dynamodb",
      aws_access_key_id=access_key,
      aws_secret_access_key=secret_key,
      region_name="us-east-1"
  )
  
  data = client.scan(
    TableName='FisherInfoTable'
  )

  return data


def getreport(FilterType,FilterValue):
  d = datetime.today() - timedelta(hours=7, minutes=0)
  today = d
  FilterValue = FilterValue.replace(" ", "%20")
  URL = f"https://www.gofishbc.com/Stocked-Fish/Detailed-Report.aspx?{FilterType}={FilterValue}&start={today}&end={today}"
  print(URL)
  return URL


def lambda_handler(event, context):
 
  dynamodb_users = getusers()
  dictcount = 0

  for x in dynamodb_users["Items"]:
    FisherName = dynamodb_users["Items"][dictcount]["Name"]["S"]
    FisherNumber = dynamodb_users["Items"][dictcount]["PhoneNumber"]["S"]
    FilterType = dynamodb_users["Items"][dictcount]["FilterType"]["S"]
    FilterValue =  dynamodb_users["Items"][dictcount]["FilterValue"]["S"]
    print(FisherName + FisherNumber + FilterType + FilterValue)
    dictcount += 1

    URL = getreport(FilterType,FilterValue)
    page = requests.get(URL)
    soup = BeautifulSoup(page.content, 'html.parser')

    try:
      html = soup.find(id="report_table").get_text().split("\n\n")
    except:
      print("whatevs")
    else:
      splitcount = len(html)
      mylist = list(html[1].split("\n"))
      mylist.pop(0)
      count = (len(html)-3)
  
      for i in range(2, splitcount-1):
        fulllist = "BC Stocked Lake Update\n===================\n"
        body = html[i].split("\n")
      
        for x in range(0,len(mylist)):
            fulllist += mylist[x] + ": " + body[x] + "\n"
            sendtext(fulllist,FisherNumber)
  
