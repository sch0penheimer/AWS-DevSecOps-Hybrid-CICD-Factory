################################################################################
#  File: lambda-function/lambda_handler.py
#  Description: Main Lambda function Entrypoint.
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 04/09/2025
#
#  Purpose: This file contains the main entry point for the AWS Lambda function.
#           It initializes logging, processes incoming events, and handles errors.
################################################################################

##-- Imports & Logging Setup --##
import json
from logger_config import create_component_logger
from report_processor import process_security_scan_message

logger = create_component_logger("lambda-handler")

##-- Lambda Entrypoint --##
def lambda_handler(event, context):
    request_id = context.aws_request_id if context else "unknown"
    
    try:
        logger.info(f"Processing request: {request_id}")
        result = process_security_scan_message(event)
        logger.info(f"Request completed: {request_id}")
        return result
    except Exception as error:
        logger.error(f"Request failed: {request_id} - {error}")
        raise