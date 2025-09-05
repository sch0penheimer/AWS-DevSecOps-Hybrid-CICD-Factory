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
from config_manager import config

logger = create_component_logger("securityhub-client")

##-- Security Hub Client Initialization --##
securityhub = boto3.client('securityhub')

##-- Finding Import Function --##
def import_security_finding(count,
                           account_id, 
                           region, 
                           created_at, 
                           source_repository,
                           source_branch,
                           source_commitid,
                           build_id, 
                           report_url, 
                           finding_id, 
                           generator_id,
                           normalized_severity, 
                           severity,
                           finding_type, 
                           finding_title, 
                           finding_description, 
                           remediation_url):
    """
        Imports a finding to the AWS Security Hub.
    """
    logger.debug(f"Importing finding {finding_id} to Security Hub")
    
    new_findings = []
    new_findings.append({
        "SchemaVersion": "2018-10-08",
        "Id": finding_id,
        "ProductArn": config.get_product_arn(region, account_id),
        "GeneratorId": generator_id,
        "AwsAccountId": account_id,
        "Types": [
            f"Software and Configuration Checks/AWS Security Best Practices/{finding_type}"
        ],
        "CreatedAt": created_at,
        "UpdatedAt": created_at,
        "Severity": {
            "Normalized": normalized_severity,
        },
        "Title":  f"{count}-{finding_title}",
        "Description": f"{finding_description}",
        'Remediation': {
            'Recommendation': {
                'Text': 'For directions on how to fix this issue, see the documentation and best practices',
                'Url': remediation_url
            }
        },
        'SourceUrl': report_url,
        'Resources': [
            {
                'Id': build_id,
                'Type': "CodeBuild",
                'Partition': "aws",
                'Region': region
            }
        ],
    })
    
    response = securityhub.batch_import_findings(Findings=new_findings)
    if response['FailedCount'] > 0:
        logger.error(f"Failed to import finding {finding_id}: {response}")
        raise Exception(f"Failed to import finding: {response['FailedCount']}")
    else:
        logger.info(f"Successfully imported finding {finding_id} to the Security Hub")
