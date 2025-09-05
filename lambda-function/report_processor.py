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

##-- Report Type Handlers --##

#- ECR Report Handler -#
def process_ecr_vulnerabilities(event,
                               account_id,
                               region,
                               source_repository,
                               source_branch,
                               source_commitid,
                               build_id,
                               report_url,
                               report_type,
                               generator_id,
                               finding_type,
                               created_at_timestamp):
    """
        Processes ECR vulnerability scan reports
    """
    finding_title = config.get_finding_title(report_type)
    current_vul_level = "LOW"
    
    vuln_ct = event['report']['imageScanFindings']['findings']
    vuln_count = len(vuln_ct)
    count = 1
    logger.info(f"Processing {vuln_count} ECR vulnerabilities")
    
    for i in range(vuln_count):
        severity = event['report']['imageScanFindings']['findings'][i]['severity']
        name = event['report']['imageScanFindings']['findings'][i]['name']
        url = event['report']['imageScanFindings']['findings'][i]['uri']
        
        if not config.should_exclude_severity(severity):
            normalized_severity = config.get_severity_mapping(severity)
            if normalized_severity > 20:
                current_vul_level = "NOTLOW"
            finding_description = f"{count}---Name:{name}---Severity:{severity}---URL:{url}"
            finding_id = f"{count}-{report_type.lower()}-{build_id}"
            count += 1
            import_security_finding(
                count, account_id, region, created_at_timestamp, source_repository,
                source_branch, source_commitid, build_id, report_url, finding_id,
                generator_id, normalized_severity, severity, finding_type, finding_title,
                finding_description, config.get_remediation_url('cloudformation')
            )
    
    return current_vul_level

#- SNYK Report Handler -#
def process_snyk_vulnerabilities(event,
                                account_id,
                                region,
                                source_repository,
                                source_branch,
                                source_commitid,
                                build_id,
                                report_url,
                                report_type,
                                generator_id,
                                finding_type,
                                created_at_timestamp):
    """Processes SNYK dependency scan reports"""
    finding_title = config.get_finding_title(report_type)
    current_vul_level = "LOW"
    
    vuln_ct = event['report']['vulnerabilities']
    vuln_count = len(vuln_ct)
    logger.info(f"Processing {vuln_count} SNYK vulnerabilities")
    count = 1
    title_list = []
    
    for i in range(vuln_count):
        title = event['report']['vulnerabilities'][i]['title']
        if title not in title_list:
            title_list.append(title)
            severity = event['report']['vulnerabilities'][i]['severity']
            packageName = event['report']['vulnerabilities'][i]['packageName']
            cvssScore = event['report']['vulnerabilities'][i]['cvssScore']
            
            if not config.should_exclude_severity(severity):
                normalized_severity = config.get_severity_mapping(severity)
                if normalized_severity > 20:
                    current_vul_level = "NOTLOW"
                finding_description = f"{count}---Title:{title}---Package:{packageName}---Severity:{severity}---CVSSv3_Score:{cvssScore}"
                finding_id = f"{count}-{report_type.lower()}-{build_id}"
                count += 1
                import_security_finding(
                    count, account_id, region, created_at_timestamp, source_repository,
                    source_branch, source_commitid, build_id, report_url, finding_id,
                    generator_id, normalized_severity, severity, finding_type, finding_title,
                    finding_description, config.get_remediation_url('snyk')
                )
    
    return current_vul_level

#- OWASP-Zap Report Handler -#
def process_owasp_zap_alerts(event,
                            account_id,
                            region,
                            source_repository,
                            source_branch,
                            source_commitid,
                            build_id,
                            report_url,
                            report_type,
                            generator_id,
                            finding_type,
                            created_at_timestamp):
    """Processes OWASP ZAP dynamic security scan reports"""
    finding_title = config.get_finding_title(report_type)
    current_vul_level = "LOW"
    
    alert_ct = event['report']['site'][0]['alerts']
    alert_count = len(alert_ct)
    logger.info(f"Processing {alert_count} OWASP-Zap alerts")
    
    for alertno in range(alert_count):
        risk_desc = event['report']['site'][0]['alerts'][alertno]['riskdesc']
        severity = risk_desc[0:3]
        normalized_severity = config.get_severity_mapping(severity)
        if normalized_severity > 20:
            current_vul_level = "NOTLOW"
        instances = len(event['report']['site'][0]['alerts'][alertno]['instances'])
        finding_description = f"{alertno}-Vulnerability:{event['report']['site'][0]['alerts'][alertno]['alert']}-Total occurances of this issue:{instances}"
        finding_id = f"{alertno}-{report_type.lower()}-{build_id}"
        import_security_finding(
            alertno, account_id, region, created_at_timestamp, source_repository,
            source_branch, source_commitid, build_id, report_url, finding_id,
            generator_id, normalized_severity, severity, finding_type, finding_title,
            finding_description, config.get_remediation_url('owasp')
        )
    
    return current_vul_level

##-- Message Processing --##
def process_security_scan_message(event):
    """Processes incoming security scan report messages and dispatches to appropriate handlers."""
    logger.debug('Processing complete event details')
    logger.debug(json.dumps(event, default=str))
    
    if event['messageType'] == 'CodeScanReport':
        try:
            account_id = boto3.client('sts').get_caller_identity().get('Account')
            region = os.environ['AWS_REGION']
            created_at = event['createdAt']
            source_repository = event['source_repository']
            source_branch = event['source_branch']
            source_commitid = event['source_commitid']
            build_id = event['build_id']
            report_type = event['reportType']
            finding_type = config.get_finding_type(report_type)
            generator_id = f"{report_type.lower()}-{source_repository}-{source_branch}"
            created_at_timestamp = datetime.now(timezone.utc).isoformat()

            #- Upload report to S3 artifact store -#
            try:
                s3 = boto3.client('s3')
                s3bucket = config.get_s3_artifact_bucket_name()
                key = f"reports/{event['reportType']}/{build_id}-{created_at}.json"
                s3.put_object(Bucket=s3bucket, Body=json.dumps(event), Key=key, ServerSideEncryption='aws:kms')
                report_url = f"https://s3.console.aws.amazon.com/s3/object/{s3bucket}/{key}?region={region}"
                logger.info(f"Successfully uploaded report to S3: {key}")
            except Exception as s3_error:
                logger.error(f"Failed to upload report to S3: {str(s3_error)}")
                report_url = config.get_default_report_url()

            #- Report type dispatch table -#
            report_handlers = {
                'ECR': process_ecr_vulnerabilities,
                'SNYK': process_snyk_vulnerabilities,
                'OWASP-Zap': process_owasp_zap_alerts
            }

            #- Process report using appropriate handler -#
            if report_type in report_handlers:
                current_vul_level = report_handlers[report_type](
                    event, account_id, region, source_repository, 
                    source_branch, source_commitid, build_id, report_url, 
                    report_type, generator_id, finding_type, created_at_timestamp
                )
            else:
                logger.error(f"Invalid report type was provided: {event.get('reportType', 'Unknown')}")
                raise ValueError(f"Unsupported report type: {report_type}")
            
            logger.info(f"Report processing completed with vulnerability level: {current_vul_level}")
            return current_vul_level
            
        except Exception as processing_error:
            logger.error(f"Error processing message: {str(processing_error)}")
            raise
            
    else:
        logger.error(f"Report message type not supported: {event.get('messageType', 'Unknown')}")
        raise ValueError(f"Unsupported message type: {event.get('messageType')}")