variable "access_key" {
  type      = string
  sensitive = true
}

variable "secret_key" {
  type      = string
  sensitive = true
}

variable "region" {
  type = string
}

resource "aws_lb" "load_balancer"{
  load_balancer_type = "network"
  subnets = [aws_subnet.public]
}

resource "aws_lb_target_group" "traffic_forwarder"{
  port = 443
  protocol = "TCP"
  vpc_id = aws_vpc.vpc.id
  target_type = "ip"
}

resource "aws_lb_listener" "traffic_listener"{
  load_balancer_arn = aws_lb.load_balancer.arn
  port = 443
  protocol = "TCP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.traffic_forwarder.arn
  }

}

resource "aws_ecs_cluster" "cluster" {
  name = "inventree_cluster"
}

resource "aws_ecs_cluster_capacity_providers" "cluster" {
  cluster_name       = aws_ecs_cluster.cluster.name
  capacity_providers = ["FARGATE"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 100
  }
}

resource "aws_ecs_service" "inventree" {
  name            = "inventree-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.ecs_task.arn
  network_configuration {
    subnets = [aws_subnet.default_deploy]
    assign_public_ip = false
    security_groups = []
  }

  load_balancer {
    container_name = "caddy_server"
    container_port = 443
  }
}

resource "aws_efs_file_system" "inventree_files" {
  availability_zone_name = var.region
  creation_token         = "inventree_files"
}


resource "aws_ecs_task_definition" "ecs_task" {
  family                   = "service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE", "EC2"]
  cpu                      = 512
  memory                   = 2048
  volume {
    name = "inventree_postgres"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.inventree_files.id
      root_directory = "/postgres"
    }
  }
  volume {
    name = "inventree_server"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.inventree_files.id
      root_directory = "/server"
    }
  }

  volume{
    name = "inventree_caddy_log"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.inventree_files.id
      root_directory = "/caddy/log"
    }
  }

  volume{
    name = "inventree_caddy_media"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.inventree_files.id
      root_directory = "/caddy/media"
    }
  }

  volume{
    name = "inventree_caddy_config"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.inventree_files.id
      root_directory = "/caddy/config"
    }
  }

  volume{
    name = "inventree_caddy_data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.inventree_files.id
      root_directory = "/caddy/data"
    }
  }

  # language=JSON
  container_definitions = <<DEFINITION
  [
    {
      "name"                 : "inventree-db",
      "image"                : "postgres:17",
      "cpu"                  : 512,
      "memory"               : 2048,
      "essential"            : true,
      "mountPoints": [
        {
          "sourceVolume": "inventree_postgres",
          "containerPath": "/var/lib/postgresql/data/",
          "readOnly": false
        }
      ]
    },
    {
     "name"                 : "inventree-server",
      "image"                : "inventree/inventree:STABLE",
      "cpu"                  : 512,
      "memory"               : 2048,
      "essential"            : true,
      "portMappings" : [
        {
          "containerPort"    : 8000,
          "hostPort"         : 8000
        }
      ],
      "mountPoints": [
        {
          "sourceVolume": "inventree_server",
          "containerPath": "/home/inventree/data",
          "readOnly": false
        }
      ]
    },
    {
     "name"                 : "inventree_background_worker",
      "image"                : "inventree/inventree:STABLE",
      "cpu"                  : 512,
      "memory"               : 2048,
      "essential"            : true,
      "mountPoints": [
        {
          "sourceVolume": "inventree_server",
          "containerPath": "/home/inventree/data",
          "readOnly": false
        }
      ],
      "command": ["inventree", "worker"]
    },
    {
     "name"                 : "caddy_server",
      "image"                : "inventree/inventree:STABLE",
      "cpu"                  : 512,
      "memory"               : 2048,
      "essential"            : true,
      "portMappings" : [
        {
          "containerPort"    : 80,
          "hostPort"         : 80
        },
        {
          "containerPort"    : 443,
          "hostPort"         : 443
        }
      ],
      "mountPoints": [
        {
          "sourceVolume": "inventree_caddy_media",
          "containerPath": "/var/www",
          "readOnly": false
        },
        {
          "sourceVolume": "inventree_caddy_log",
          "containerPath": "/var/log",
          "readOnly": false
        },
        {
          "sourceVolume": "inventree_caddy_data",
          "containerPath": "/data",
          "readOnly": false
        },
        {
          "sourceVolume": "inventree_caddy_config",
          "containerPath": "/config",
          "readOnly": false
        }
      ]
    }
  ]
  DEFINITION
}