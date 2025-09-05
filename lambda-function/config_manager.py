################################################################################
#  File: lambda-function/config_manager.py
#  Description: Configuration management for the DevSecOps Lambda function
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 04/09/2025
#
#  Purpose: This file handles loading and managing configuration settings
#           from environment variables, JSON config files, and AWS SSM Parameter Store.
################################################################################

import os
import json
import boto3
from logger_config import create_component_logger

logger = create_component_logger("config-manager")

class ConfigManager:
    def __init__(self, config_file_path="config.json", env_file_path=".env"):
        self.config_file_path = config_file_path
        self.env_file_path = env_file_path
        self._config = None
        self.ssm = boto3.client('ssm')
        self._load_env_file()
        self._load_config()
        self._validate_required_env_vars()
    
    def _load_env_file(self):
        """
            Loads environment variables from .env file if exists
        """
        try:
            if os.path.exists(self.env_file_path):
                with open(self.env_file_path, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith('#') and '=' in line:
                            key, value = line.split('=', 1)
                            #- Only set if not already in environment -#
                            if not os.environ.get(key.strip()):
                                os.environ[key.strip()] = value.strip()
                logger.info(f"Loaded environment variables from {self.env_file_path}")
        except Exception as e:
            logger.warning(f"Could not load .env file: {e}")
    
    def _load_config(self):
        """
            Loads configuration from JSON config file
        """
        try:
            with open(self.config_file_path, 'r') as f:
                self._config = json.load(f)
            logger.info("Configuration loaded successfully")
        except FileNotFoundError:
            logger.error(f"Configuration file not found: {self.config_file_path}")
            raise
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in configuration file: {e}")
            raise
    
    def _validate_required_env_vars(self):
        """
            Validates required environment variables are present
        """
        required_vars = ['AWS_REGION', 'S3_ARTIFACT_BUCKET_NAME']
        optional_vars = {
            'AWS_PARTITION': 'aws'
        }
        
        missing_vars = [var for var in required_vars if not os.environ.get(var)]
        if missing_vars:
            raise ValueError(f"Missing required environment variables: {missing_vars}")
        
        #- Set defaults for optional variables -#
        for var, default in optional_vars.items():
            if not os.environ.get(var):
                os.environ[var] = default
                logger.info(f"Using default value for {var}: {default}")
    
    def get_parameter(self, parameter_name, default_value=None):
        """
            Gets the parameter from SSM Parameter Store
        """
        try:
            response = self.ssm.get_parameter(Name=parameter_name, WithDecryption=True)
            return response['Parameter']['Value']
        except self.ssm.exceptions.ParameterNotFound:
            logger.warning(f"Parameter {parameter_name} not found, using default: {default_value}")
            return default_value
        except Exception as e:
            logger.error(f"Error getting parameter {parameter_name}: {e}")
            return default_value

    def get_s3_artifact_bucket_name(self, account_id=None):
        """
            Gets the S3 artifact bucket name from environment variable
        """
        bucket_name = os.environ.get('S3_ARTIFACT_BUCKET_NAME')
        if not bucket_name:
            raise ValueError("S3_ARTIFACT_BUCKET_NAME environment variable is required")
        return bucket_name
    
    def get_severity_mapping(self, severity):
        """
            Gets the normalized severity based on configured scale
        """
        severity_upper = severity.upper()
        
        severity_variations = {
            'MED': 'MEDIUM',
            'HIG': 'HIGH',
            'INF': 'INFORMATIONAL'
        }
        
        normalized_severity = severity_variations.get(severity_upper, severity_upper)
        
        try:
            return self._config['severity_mappings']['custom_scale'].get(normalized_severity, 1)
        except KeyError:
            logger.warning(f"Severity mapping not found for '{normalized_severity}', using default")
            return 1
    
    def get_finding_type(self, report_type):
        """
           Gets the finding type for report type
        """
        return self._config['finding_types'].get(report_type, f"{report_type} code scan")
    
    def get_finding_title(self, report_type):
        """
            Gets the finding title for report type
        """
        return self._config['finding_titles'].get(report_type, f"{report_type} Analysis")
    
    def get_remediation_url(self, url_type):
        """
            Gets the remediation URL by type
        """
        return self._config['remediation_urls'].get(url_type, self._config.get('default_report_url', 'https://aws.amazon.com'))
    
    def should_exclude_severity(self, severity):
        """
            Checks if severity should be excluded from processing
        """
        return severity in self._config.get('excluded_severities', [])
    
    def get_product_arn(self, region, account_id):
        """
            Gets the Security Hub Product ARN based on AWS partition
        """
        partition = os.environ.get('AWS_PARTITION', 'aws')
        return f"arn:{partition}:securityhub:{region}:{account_id}:product/{account_id}/default"

#- Global config instance -#
config = ConfigManager()
