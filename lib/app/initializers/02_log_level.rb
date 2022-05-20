logger = AppConfig.connectors_logger
logger.level = ConnectorsApp::Config['log_level'] || 'info'

ConnectorsShared::Logger.setup!(logger)
