resource "aws_ecr_repository" "backend_repo" {
  name = "${var.project_name}-service"
}

resource "aws_ecr_lifecycle_policy" "backend_policy" {
  repository = aws_ecr_repository.backend_repo.name
  policy     = <<eof
    {
      "rules":[
        {
          "rulePriority":1,
          "description":"Keep only 1 untagged image",
          "selection":{
            "tagStatus":"untagged",
            "countType":"imageCountMoreThan",
            "countNumber":1
          },
          "action":{
            "type":"expire"
          }
        }
      ]
    }
    eof
}
