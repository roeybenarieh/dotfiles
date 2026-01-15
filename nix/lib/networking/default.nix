{ ... }:

rec {
  broadcast_listen_on_port = port: "0.0.0.0:${toString port}";
  schemaless_local_endpoint_on_port = port: "localhost:${toString port}";
  http_local_endpoint_on_port = port: "http://${schemaless_local_endpoint_on_port port}";
  https_local_endpoint_on_port = port: "https://${schemaless_local_endpoint_on_port port}";
}
