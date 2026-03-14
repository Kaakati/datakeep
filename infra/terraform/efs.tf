resource "aws_efs_file_system" "main" {
  encrypted        = true
  performance_mode = "generalPurpose"

  tags = { Name = "${local.name_prefix}-efs" }
}

resource "aws_efs_mount_target" "main" {
  count           = 2
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

# Access point for /rails/storage (Active Storage, uploads)
resource "aws_efs_access_point" "storage" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/storage"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }

  tags = { Name = "${local.name_prefix}-storage-ap" }
}

# Access point for /rails/backups (database backup files)
resource "aws_efs_access_point" "backups" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/backups"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }

  tags = { Name = "${local.name_prefix}-backups-ap" }
}
