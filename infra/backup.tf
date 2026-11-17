# Política mínima de backup (geração "filho" do GFS): snapshot diário do disco
# do banco, retenção curta. Os snapshots herdam a criptografia do disco (gp3 encrypted = true).

data "aws_iam_policy_document" "dlm_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dlm" {
  name               = "${var.projeto}-dlm-backup"
  description        = "Papel usado pelo Data Lifecycle Manager para criar e expirar snapshots"
  assume_role_policy = data.aws_iam_policy_document.dlm_assume.json
}

resource "aws_iam_role_policy_attachment" "dlm" {
  role       = aws_iam_role.dlm.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "banco" {
  description        = "Snapshot diario do disco do banco com retencao curta"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      Backup = "diario"
    }

    schedule {
      name      = "diario-filho"
      copy_tags = true

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = [var.backup_hora_utc]
      }

      retain_rule {
        count = var.backup_retencao
      }

      tags_to_add = {
        TipoBackup = "dlm-diario"
      }
    }
  }

  depends_on = [aws_iam_role_policy_attachment.dlm]
}
