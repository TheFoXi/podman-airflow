## Standalone Airflow in Podman

Automated installation script for Standalone Airflow with DAG modules that monitor memory consumption by processes.  
Designed for `Podman`, but can also run easily on `Docker` (e.g., `OrbStack`).

### 0. Project Configuration

Before running the Terraform script, you need to configure Ansible variables.  
For this example, the mail provider `mailtrap.io` was used. Edit `./ansible/playbook.yml` accordingly:

```yml
    memory_monitor_smtp_server: sandbox.smtp.mailtrap.io # Specify your SMTP server
    memory_monitor_smtp_port: 2525 # Define the port
    memory_monitor_smtp_user: <Username>
    memory_monitor_smtp_password: <Password>
    memory_monitor_email_from: monitor@example.ee # Email address from which notifications will be sent
    memory_monitor_threshold_mb: 1300 # Memory usage threshold in MB for all Airflow processes
    memory_monitor_interval: 2 # Monitoring interval in minutes
    memory_monitor_email: admin@example.ee # Recipient email for notifications
    single_process_memory_threshold_mb: 100 # Memory usage threshold in MB for a single Airflow process
    single_process_memory_interval: 2 # Monitoring interval in minutes
```

### 1. Run the Terraform Script

```shell
cd terraform
terraform init
terraform validate
terraform apply
```

### 2. Retrieve the Airflow Admin Password

```shell
podman exec -it airflow-container cat /opt/airflow/standalone_admin_password.txt
```

### 3. Open Local Standalone Airflow

Access the Airflow web UI at: [http://0.0.0.0:8080](http://0.0.0.0:8080) or [http://localhost:8080](http://localhost:8080)

---


### To change the `docker/podman` context, update the Terraform provider host in the configuration file.  
Default:

```h
provider "docker" {
  host = "npipe:////.//pipe//podman-machine-default"
}
```

#### OrbStak Example.  
Dont forget to change - unix:///Users/`NAME`/.orbstack/run/docker.sock


```h
provider "docker" {
  host = "unix:///Users/denis/.orbstack/run/docker.sock"
}
```

