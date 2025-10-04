"""
Lambda function for auto-remediation of GuardDuty findings
This function automatically stops EC2 instances when high-severity threats are detected
"""

import json
import boto3
import os
import logging
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
ec2_client = boto3.client('ec2')
cloudwatch_client = boto3.client('cloudwatch')

def handler(event, context):
    """
    Main Lambda handler function
    Processes GuardDuty findings and takes remediation actions
    """
    
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Extract GuardDuty finding details
        detail = event.get('detail', {})
        finding_type = detail.get('type', '')
        severity = detail.get('severity', 0)
        finding_id = detail.get('id', '')
        service = detail.get('service', {})
        resource = detail.get('resource', {})
        
        logger.info(f"Processing finding: {finding_id}, Type: {finding_type}, Severity: {severity}")
        
        # Get instance ID from environment variable
        instance_id = os.environ.get('INSTANCE_ID')
        
        if not instance_id:
            logger.error("INSTANCE_ID environment variable not set")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'INSTANCE_ID not configured'})
            }
        
        # Define high-severity threshold and suspicious finding types
        high_severity_threshold = 7.0
        suspicious_types = [
            'Recon:EC2/PortProbeUnprotectedPort',
            'Recon:EC2/Portscan',
            'UnauthorizedAPICall:EC2/SSHBruteForce',
            'UnauthorizedAPICall:EC2/RDPBruteForce',
            'CryptoCurrency:EC2/BitcoinTool.B!DNS',
            'Trojan:EC2/BlackholeTraffic!DNS',
            'Trojan:EC2/DGADomainRequest.B',
            'Trojan:EC2/DNSDataExfiltration',
            'Backdoor:EC2/Spambot',
            'Backdoor:EC2/XORDDoS'
        ]
        
        # Check if this is a high-severity finding or suspicious type
        should_remediate = (
            severity >= high_severity_threshold or 
            finding_type in suspicious_types
        )
        
        if should_remediate:
            logger.warning(f"High-severity finding detected: {finding_type} (severity: {severity})")
            
            # Get instance details
            instance_details = get_instance_details(instance_id)
            
            if not instance_details:
                logger.error(f"Instance {instance_id} not found or not accessible")
                return {
                    'statusCode': 404,
                    'body': json.dumps({'error': f'Instance {instance_id} not found'})
                }
            
            # Check if instance is running
            if instance_details['State']['Name'] == 'running':
                # Stop the instance
                logger.warning(f"Stopping instance {instance_id} due to security threat")
                stop_instance(instance_id)
                
                # Send custom metric to CloudWatch
                send_cloudwatch_metric(finding_type, severity, instance_id)
                
                # Create a summary response
                response = {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': 'Auto-remediation executed successfully',
                        'action': 'instance_stopped',
                        'instance_id': instance_id,
                        'finding_id': finding_id,
                        'finding_type': finding_type,
                        'severity': severity,
                        'timestamp': datetime.utcnow().isoformat()
                    })
                }
            else:
                logger.info(f"Instance {instance_id} is already {instance_details['State']['Name']}")
                response = {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': 'Instance already stopped or stopping',
                        'instance_id': instance_id,
                        'current_state': instance_details['State']['Name']
                    })
                }
        else:
            logger.info(f"Finding severity {severity} below threshold {high_severity_threshold}, no action taken")
            response = {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Finding severity below remediation threshold',
                    'finding_id': finding_id,
                    'severity': severity,
                    'threshold': high_severity_threshold
                })
            }
        
        logger.info(f"Lambda execution completed: {response}")
        return response
        
    except Exception as e:
        logger.error(f"Error processing GuardDuty finding: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def get_instance_details(instance_id):
    """
    Get details about the EC2 instance
    """
    try:
        response = ec2_client.describe_instances(InstanceIds=[instance_id])
        if response['Reservations']:
            return response['Reservations'][0]['Instances'][0]
        return None
    except Exception as e:
        logger.error(f"Error getting instance details: {str(e)}")
        return None

def stop_instance(instance_id):
    """
    Stop the EC2 instance
    """
    try:
        response = ec2_client.stop_instances(InstanceIds=[instance_id])
        logger.info(f"Stop instances response: {response}")
        return response
    except Exception as e:
        logger.error(f"Error stopping instance: {str(e)}")
        raise e

def send_cloudwatch_metric(finding_type, severity, instance_id):
    """
    Send custom metric to CloudWatch for monitoring
    """
    try:
        cloudwatch_client.put_metric_data(
            Namespace='ThreatDetection/AutoRemediation',
            MetricData=[
                {
                    'MetricName': 'InstancesStopped',
                    'Dimensions': [
                        {
                            'Name': 'FindingType',
                            'Value': finding_type
                        },
                        {
                            'Name': 'InstanceId',
                            'Value': instance_id
                        }
                    ],
                    'Value': 1,
                    'Unit': 'Count',
                    'Timestamp': datetime.utcnow()
                },
                {
                    'MetricName': 'FindingSeverity',
                    'Dimensions': [
                        {
                            'Name': 'FindingType',
                            'Value': finding_type
                        }
                    ],
                    'Value': severity,
                    'Unit': 'None',
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
        logger.info("Custom metrics sent to CloudWatch")
    except Exception as e:
        logger.error(f"Error sending CloudWatch metrics: {str(e)}")
        # Don't raise exception for metric failures
