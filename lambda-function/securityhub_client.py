#############################################################################################
#  AWS Security Hub Client
#  File: securityhub_client.py
#  Description: Utility functions for importing findings to AWS Security Hub.
#
#  Sections:
#    - Imports & Logging Setup
#    - Security Hub Client Initialization
#    - Finding Import Function
#############################################################################################

##-- Imports & Logging Setup --##
import boto3
from logger_config import create_component_logger
from config_manager import ConfigManager

logger = create_component_logger("securityhub-client")

##-- Security Hub Client Initialization --##
securityhub = boto3.client('securityhub')

##-- Config Initialization --##
config = ConfigManager()

##-- Finding Import Function --##
def import_security_finding(finding_data):
    logger.debug(f"Importing finding {finding_data['id']} to Security Hub")
    
    finding = {
        "SchemaVersion": "2018-10-08",
        "Id": finding_data['id'],
        "ProductArn": config.get_product_arn(finding_data['region'], finding_data['account_id']),
        "GeneratorId": finding_data['generator_id'],
        "AwsAccountId": finding_data['account_id'],
        "Types": [f"Software and Configuration Checks/AWS Security Best Practices/{finding_data['type']}"],
        "CreatedAt": finding_data['created_at'],
        "UpdatedAt": finding_data['created_at'],
        "Severity": {"Normalized": finding_data['normalized_severity']},
        "Title": finding_data['title'],
        "Description": finding_data['description'],
        "Remediation": {
            "Recommendation": {
                "Text": "See documentation for remediation steps",
                "Url": finding_data['remediation_url']
            }
        },
        "SourceUrl": finding_data['report_url'],
        "Resources": [{
            "Id": finding_data['build_id'],
            "Type": "CodeBuild",
            "Partition": "aws",
            "Region": finding_data['region']
        }]
    }
    
    response = securityhub.batch_import_findings(Findings=[finding])
    logger.info(f"SecurityHub response: {response}")
    if response['FailedCount'] > 0:
        raise Exception(f"Failed to import finding: {response}")
    logger.info(f"Imported finding {finding_data['id']}")