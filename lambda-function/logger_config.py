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

def create_component_logger(component_name):
    logger = logging.getLogger(component_name)
    
    if not logger.handlers:
        logger.setLevel(logging.INFO)
        handler = logging.StreamHandler()
        handler.setFormatter(logging.Formatter(
            f'[{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}] [{component_name}] [%(levelname)s] - %(message)s'
        ))
        logger.addHandler(handler)
        logger.propagate = False
        
    return logger