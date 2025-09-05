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
    """
        Main Lambda function handler
    """
    request_id = context.aws_request_id if context else "unknown"
    
    try:
        logger.info(f"Lambda execution started - RequestID: {request_id}")
        logger.debug(f"Received event: {json.dumps(event, default=str)}")
        
        result = process_security_scan_message(event)
        
        logger.info(f"Lambda execution completed successfully - RequestID: {request_id}")
        logger.debug(f"Processing result: {json.dumps(result, default=str)}")
        
        return result
        
    except Exception as error:
        logger.error(f"Lambda execution failed - RequestID: {request_id} - Error: {str(error)}")
        logger.exception("Full error traceback:")
        raise