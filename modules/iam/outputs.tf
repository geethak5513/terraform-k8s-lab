output "eso_role_arn" {
  value = aws_iam_role.eso_role.arn
}

output "argocd_role_arn" {
  value = aws_iam_role.argocd_role.arn
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller_role.arn
}