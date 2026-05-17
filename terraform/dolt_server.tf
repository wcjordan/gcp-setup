# Dolt SQL server for beads agent task coordination
resource "helm_release" "dolt_server" {
  name  = "dolt-server"
  chart = "./charts/dolt-server"

  depends_on = [google_container_node_pool.primary_nodes]

  set {
    name  = "rootPassword"
    value = var.dolt_root_password
  }
}
