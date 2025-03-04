# Terraform configuration specifying the required providers.
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker" # Docker provider from kreuzwerker
      version = "~> 3.0.1"           # Provider version constraint
    }
    tls = {
      source  = "hashicorp/tls" # TLS provider for generating cryptographic keys
      version = "4.0.6"         # Provider version
    }
  }
}

provider "docker" {
  host = "npipe:////.//pipe//podman-machine-default"
}

# Docker provider configuration using a Unix socket (Orbstack).
# provider "docker" {
#   host = "unix:///Users/denis/.orbstack/run/docker.sock"
# }

# Generate an SSH key for secure access to the containers.
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"  # Use the RSA algorithm.
  rsa_bits  = "4096" # Key size: 4096 bits.
}

# Create a Docker network for the Airflow and Ansible containers.
resource "docker_network" "airflow_network" {
  name = "airflow-net" # Name of the Docker network.
}

# Pull the Ubuntu 22.04 image for the Airflow container.
resource "docker_image" "airflow" {
  name         = "ubuntu:22.04" # Image name.
  keep_locally = true           # Retain the image locally.
}

# Define the Apache Airflow container.
resource "docker_container" "airflow" {
  name    = "airflow-container"           # Container name.
  image   = docker_image.airflow.image_id # Use the previously pulled image.
  restart = "always"                      # Always restart the container on failure.

  # Connect the container to the specified Docker network.
  networks_advanced {
    name = docker_network.airflow_network.name
  }

  # Map internal port 8080 to external port 8080.
  ports {
    internal = 8080
    external = 8080
  }

  # Command executed on container startup: install packages, configure SSH, and keep the container running.
  command = ["/bin/bash", "-c", <<EOT
    apt update && apt install -y openssh-server sudo
    mkdir -p /root/.ssh
    echo "${tls_private_key.ssh_key.public_key_openssh}" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "root ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/root
    chmod 0440 /etc/sudoers.d/root
    service ssh start
    tail -f /dev/null
  EOT
  ]
}

# Pull the latest Ubuntu image for the Ansible container.
resource "docker_image" "ansible" {
  name         = "ubuntu:latest" # Image name.
  keep_locally = true            # Retain the image locally.
}

# Define the Ansible container that installs Ansible and runs a playbook at startup.
resource "docker_container" "ansible" {
  name    = "ansible-container"           # Container name.
  image   = docker_image.ansible.image_id # Use the previously pulled image.
  restart = "always"                      # Always restart the container on failure.

  # Connect the container to the same Docker network as the Airflow container.
  networks_advanced {
    name = docker_network.airflow_network.name
  }

  # Mount the local Ansible configuration directory into the container.
  volumes {
    host_path      = abspath("${path.module}/../ansible") # Absolute path on the host.
    container_path = "/ansible"                           # Mount point in the container.
  }

  # Set environment variable to reference the Airflow container's name.
  env = [
    "AIRFLOW_HOST=${docker_container.airflow.name}",
  ]

  # Command to install dependencies, configure SSH, wait for Airflow's SSH to become available, then run the Ansible playbook.
  command = ["/bin/bash", "-c", <<EOT

    apt update && apt install -y ansible openssh-client netcat-traditional

    mkdir -p /root/.ssh
    echo "${tls_private_key.ssh_key.private_key_pem}" > /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
    echo "Host airflow\n    HostName airflow\n    User root\n    StrictHostKeyChecking no" > /root/.ssh/config

    # Wait for the SSH service in the Airflow container to become available.
    echo "Waiting for airflow-container readiness..."
    until nc -zv airflow-container 22; do
      echo "Expectation..."
      sleep 2
    done
    echo "Airflow is available, moving on"

    # Execute the Ansible playbook using the specified inventory file.
    ansible-playbook -i /ansible/inventory.ini /ansible/playbook.yml
    tail -f /dev/null
  EOT
  ]
  depends_on = [docker_container.airflow] # Ensure the Airflow container is running before starting this container.
}
