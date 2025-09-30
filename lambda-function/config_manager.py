################################################################################
#  File: lambda-function/config_manager.py
#  Description: Configuration management for the DevSecOps Lambda function
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 28/09/2025
#
#  Purpose: This file handles loading and managing configuration settings
#           from CloudFormation environment variables, JSON config files, and AWS
#           SSM Parameter Store.
################################################################################

##-- Imports & Logging Setup --##
import os
import json
import boto3
from logger_config import create_component_logger

logger = create_component_logger("config-manager")

class ConfigManager:
    def __init__(self):
        with open("config.json") as f:
            self._config = json.load(f)
        self._validate_env()

        logger.info("ConfigManager initialized successfully")
        logger.debug(f"Using S3 bucket: {self.get_s3_artifact_bucket_name()}")
        logger.debug(f"Using AWS region: {self.get_aws_region()}")
        logger.debug(f"Using AWS partition: {self.get_aws_partition()}")
    
    def _validate_env(self):
        required = [
            'S3_ARTIFACT_BUCKET_NAME'
        ]
        
        missing = [var for var in required if not os.environ.get(var)]
        if missing:
            error_msg = f"Missing required environment variables: {missing}. These should be set by CloudFormation."
            logger.error(error_msg)
            raise ValueError(error_msg)
        
        os.environ.setdefault('AWS_PARTITION', 'aws')
        logger.info("Environment validation completed successfully")
    
    def get_s3_artifact_bucket_name(self):
        return os.environ['S3_ARTIFACT_BUCKET_NAME']

    def get_aws_region(self):
        return os.environ['AWS_REGION']
    
    def get_aws_partition(self):
        return os.environ.get('AWS_PARTITION', 'aws')
    
    def get_severity_mapping(self, severity):
        #- Normalize input severity to match config scale -#
        severity_upper = severity.upper().strip()
        
        #- Handle abbreviated forms first -#
        abbreviation_map = {
            'CRI': 'CRITICAL',
            'BLO': 'BLOCKER', 
            'HIG': 'HIGH',
            'MAJ': 'MAJOR',
            'MED': 'MEDIUM',
            'LOW': 'LOW',
            'INF': 'INFORMATIONAL',
            'NEG': 'NEGLIGIBLE',
            'UNK': 'UNKNOWN'
        }
        
        #- Check if it's an abbreviation (3 chars) -#
        if len(severity_upper) == 3 and severity_upper in abbreviation_map:
            normalized_severity = abbreviation_map[severity_upper]
        else:
            #- Direct mapping for full names -#
            normalized_severity = severity_upper
        
        return self._config['severity_mappings']['custom_scale'].get(normalized_severity, 1)
    
    def get_finding_type(self, report_type):
        return self._config['finding_types'].get(report_type, f"{report_type} code scan")
    
    def get_finding_title(self, report_type):
        return self._config['finding_titles'].get(report_type, f"{report_type} Analysis")
    
    def get_remediation_url(self, url_type):
        return self._config['remediation_urls'].get(url_type, self._config['default_report_url'])
    
    def should_exclude_severity(self, severity):
        return severity in self._config['excluded_severities']
    
    def get_product_arn(self, region, account_id):
        return f"arn:{os.environ['AWS_PARTITION']}:securityhub:{region}:{account_id}:product/{account_id}/default"
    