output "eso_role_arn" {
  value = aws_iam_role.eso_role.arn
}

output "argocd_role_arn" {
  value = aws_iam_role.argocd_role.arn
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller_role.arn
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN used by the EBS CSI driver"
  value       = aws_iam_role.ebs_csi_role.arn
}
