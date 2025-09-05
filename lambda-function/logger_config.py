################################################################################
#  File: lambda-function/logger_config.py
#  Description: Centralized logging configuration for the AWS DevSecOps Hybrid CI/CD Platform.
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 04/09/2025
#
#  Purpose: Provide a consistent logging setup across all Lambda function's utils.
################################################################################

import logging
from datetime import datetime

class CustomFormatter(logging.Formatter):
    def format(self, record):
        timestamp = datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]
        record.timestamp = timestamp
        record.project = "AWS-DevSecOps-Hybrid-CICD-Platform"
        return super().format(record)

def create_component_logger(component_name):
    """
        Creates and returns a logger with customized format for the specified component
    """
    logger = logging.getLogger(component_name)
    
    if logger.handlers:
        return logger
        
    logger.setLevel(logging.DEBUG)
    
    handler = logging.StreamHandler()
    formatter = CustomFormatter(
        f'[%(timestamp)s] [%(project)s] [{component_name}] [%(levelname)s] - %(message)s'
    )
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.propagate = False
    
    return logger