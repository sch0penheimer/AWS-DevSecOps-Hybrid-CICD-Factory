################################################################################
#  File: lambda-function/report_processor.py
#  Description: Processes code scan reports, uploads to the artifact store, and sends findings to Security Hub.
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 04/09/2025
#
#  Purpose: This file contains functions to process incoming code scan reports,
#           upload them to the S3 artifact bucket, and exports findings into AWS Security Hub.
################################################################################

##-- Imports & Logging Setup --##
import os
import json
import boto3
from datetime import datetime, timezone
from logger_config import create_component_logger
from securityhub_client import import_security_finding
from config_manager import config

logger = create_component_logger("report-processor")

def extract_findings(event, report_type):
    findings = []
    
    if report_type == 'ECR':
        for i, vuln in enumerate(event['report']['imageScanFindings']['findings']):
            findings.append({
                'id': f"{i}-{vuln['name']}",
                'severity': vuln['severity'],
                'description': f"Name:{vuln['name']} URL:{vuln['uri']}"
            })
    
    elif report_type == 'SNYK':
        seen_titles = set()
        for i, vuln in enumerate(event['report']['vulnerabilities']):
            if vuln['title'] not in seen_titles:
                seen_titles.add(vuln['title'])
                findings.append({
                    'id': f"{i}-{vuln['title']}",
                    'severity': vuln['severity'],
                    'description': f"Title:{vuln['title']} Package:{vuln['packageName']} CVSSv3:{vuln['cvssScore']}"
                })
    
    elif report_type == 'OWASP-Zap':
        for i, alert in enumerate(event['report']['site'][0]['alerts']):
            severity = alert['riskdesc'][:3]
            findings.append({
                'id': f"{i}-{alert['alert']}",
                'severity': severity,
                'description': f"Vulnerability:{alert['alert']} Instances:{len(alert['instances'])}"
            })
    
    return findings

def upload_to_s3(event, build_id, created_at):
    try:
        s3 = boto3.client('s3')
        bucket = config.get_s3_artifact_bucket_name()
        key = f"reports/{event['reportType']}/{build_id}-{created_at}.json"
        s3.put_object(Bucket=bucket, Body=json.dumps(event), Key=key, ServerSideEncryption='aws:kms')
        return f"https://s3.console.aws.amazon.com/s3/object/{bucket}/{key}?region={os.environ['AWS_REGION']}"
    except Exception as e:
        logger.error(f"S3 upload failed: {e}")
        return config.get_remediation_url('default')

def process_security_scan_message(event):
    if event['messageType'] != 'CodeScanReport':
        raise ValueError(f"Unsupported message type: {event.get('messageType')}")
    
    #- Extract event data -#
    account_id = boto3.client('sts').get_caller_identity()['Account']
    region = os.environ['AWS_REGION']
    report_type = event['reportType']
    build_id = event['build_id']
    created_at = datetime.now(timezone.utc).isoformat()
    
    #- Upload report to S3 -#
    report_url = upload_to_s3(event, build_id, event['createdAt'])
    
    #- Extract and process findings -#
    findings = extract_findings(event, report_type)
    vulnerability_level = "LOW"
    
    remediation_map = {'ECR': 'cloudformation', 'SNYK': 'snyk', 'OWASP-Zap': 'owasp'}
    
    for finding in findings:
        if not config.should_exclude_severity(finding['severity']):
            normalized_severity = config.get_severity_mapping(finding['severity'])
            if normalized_severity > 20:
                vulnerability_level = "NOTLOW"
            
            finding_data = {
                'id': f"{finding['id']}-{build_id}",
                'account_id': account_id,
                'region': region,
                'created_at': created_at,
                'generator_id': f"{report_type.lower()}-{event['source_repository']}-{event['source_branch']}",
                'normalized_severity': normalized_severity,
                'type': config.get_finding_type(report_type),
                'title': config.get_finding_title(report_type),
                'description': finding['description'],
                'remediation_url': config.get_remediation_url(remediation_map.get(report_type, 'default')),
                'report_url': report_url,
                'build_id': build_id
            }
            
            import_security_finding(finding_data)
    
    logger.info(f"Processed {len(findings)} findings, vulnerability level: {vulnerability_level}")
    return vulnerability_level