ExUnit.start()

# Configure Mox for testing
Application.ensure_all_started(:mox)

# Define mocks for gRPC services
Mox.defmock(Cosmos.GRPC.Mock, for: [])
