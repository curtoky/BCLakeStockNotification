from flask import Flask, render_template, request
import boto3
import os

app = Flask(__name__)
access_key = ${{ secrets.AWS_ACCESS_KEY }}
secret_key = ${{ secrets.AWS_SECRET_KEY }}

#client = boto3.client('dynamodb', region_name='us-east-1')
text_client = boto3.client('sns', region_name='us-east-1', aws_access_key_id=access_key,aws_secret_access_key=secret_key)
client = boto3.client('dynamodb', region_name='us-east-1', aws_access_key_id=access_key,aws_secret_access_key=secret_key)
dynamoTableName = 'FisherInfoTable'


@app.route('/')
def index():
    return render_template("index.html")
  
  
@app.route('/subscribe')
def subscribe():
    return render_template("subscribe.html")


@app.route('/form', methods=["POST"])
def form():
    name = request.form.get("name")
    phone_number = request.form.get("phone_number")
    region = request.form.get("region")
    
    if not name or not region or not phone_number:
        error_statement = "All form fields required"
        return render_template("subscribe.html", 
                                error_statement=error_statement, 
                                name=name, 
                                region=region,
                                phone_number=phone_number)      
    
    client.put_item(
        TableName=dynamoTableName,
        Item={
            'PhoneNumber': {'S': phone_number },
            'FilterType': {'S': "REGION" },
            'FilterValue': {'S': region },
            'Name': {'S': name }                        
        }
    )

    
    text_message = f"Hello {name}, you have been subscribed to Lake Stock Notifications for {region}. \n\nTo unsubscribe please go to http://fishing.curtiswindsor.com/unsubscribe and enter your phone number."
    text_client.publish(PhoneNumber=phone_number,Message=text_message)
    
    return render_template("form.html",name=name,region=region,phone_number=phone_number)



@app.route('/unsubscribe')
def unsubscribe():   
    return render_template("unsub.html")
    
@app.route('/code')
def code():   
    return render_template("code.html")
    

    
@app.route('/unsubform', methods=["POST"])
def unsubform():    
    unsubphone_number = request.form.get("unsubphone_number")

    client.delete_item(
    TableName=dynamoTableName,
    Key={
        'PhoneNumber': {'S': unsubphone_number }
    }
)

    text_message = f"You have been successfully unsubscribed from the Lake Stock Notifications"
    text_client.publish(PhoneNumber=unsubphone_number,Message=text_message)

    return render_template("unsubform.html")


if __name__ == "__main__":
    port = int(os.environ.get('PORT', 5000))
    app.run(debug=True, host='0.0.0.0', port=port)    
