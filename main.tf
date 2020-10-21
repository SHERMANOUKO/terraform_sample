# https://blog.gruntwork.io/a-comprehensive-guide-to-managing-secrets-in-your-terraform-code-1d586955ace1

# resource "aws_iam_user" "example" {
#   count = 3
#   name  = "neo.${count.index}"
# }

variable "user_names" {
  description = "Create IAM users with these names"
  type        = list(string)
  default     = ["neo", "trinity", "morpheus"]
}

resource "aws_iam_user" "example" {
  count = length(var.user_names)
  name  = var.user_names[count.index]
}

# you have to specify which IAM user you’re interested in by specifying 
# its index in the list using the same array lookup syntax
output "neo_arn" {
  value       = aws_iam_user.example[0].arn
  description = "The ARN for user Neo"
}

# ARNs of all the IAM users -- splat expression, "*":
output "all_arns" {
  value       = aws_iam_user.example[*].arn
  description = "The ARNs for all users"
}

# create the same three IAM users using for_each
resource "aws_iam_user" "example" {
  for_each = toset(var.user_names)
  name     = each.value
}

output "all_users" {
  value = aws_iam_user.example
}

# If you wanted to bring back the all_arns output variable, 
# you’d have to do a little extra work to extract those ARNs 
# using the values built-in function (which returns just the values from a map) 
# and a splat expression:
output "all_arns" {
  value = values(aws_iam_user.example)[*].arn
}

variable "custom_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

# dynamically generate tag blocks using for_each in the aws_autoscaling_group resource
resource "aws_autoscaling_group" "example" {
  # (...)
  
  dynamic "tag" {
    for_each = var.custom_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Terraform code to convert the list of names in var.names to upper case
variable "names" {
  description = "A list of names"
  type        = list(string)
  default     = ["neo", "trinity", "morpheus"]
}

output "upper_names" {
  value = [for name in var.names : upper(name)]
}

#  filter the resulting list by specifying a condition
output "short_upper_names" {
  value = [for name in var.names : upper(name) if length(name) < 5]
}

variable "hero_thousand_faces" {
  description = "map"
  type        = map(string)
  default     = {
    neo      = "hero"
    trinity  = "love interest"
    morpheus = "mentor"
  }
}

output "bios" {
  value = [for name, role in var.hero_thousand_faces : "${name} is the ${role}"]
}

# for expressions to output a map rather than list

# For looping over lists
# {for <ITEM> in <LIST> : <OUTPUT_KEY> => <OUTPUT_VALUE>}

# For looping over maps
# {for <KEY>, <VALUE> in <MAP> : <OUTPUT_KEY> => <OUTPUT_VALUE>}

variable "hero_thousand_faces" {
  description = "map"
  type        = map(string)
  default     = {
    neo      = "hero"
    trinity  = "love interest"
    morpheus = "mentor"
  }
}

output "upper_roles" {
  value = {for name, role in var.hero_thousand_faces : upper(name) => upper(role)}
}

# output becomes
upper_roles = {
  "MORPHEUS" = "MENTOR"
  "NEO" = "HERO"
  "TRINITY" = "LOVE INTEREST"
}

# IAM policy that allows read-only access to CloudWatch using the aws_iam_policy resource and the aws_iam_policy_document data source
resource "aws_iam_policy" "cloudwatch_read_only" {
  name   = "cloudwatch-read-only"
  policy = data.aws_iam_policy_document.cloudwatch_read_only.json
}

data "aws_iam_policy_document" "cloudwatch_read_only" {
  statement {
    effect    = "Allow"
    actions   = [
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*"
    ]
    resources = ["*"]
  }
}

# IAM policy that allows full (read and write) access to CloudWatch
resource "aws_iam_policy" "cloudwatch_full_access" {
  name   = "cloudwatch-full-access"
  policy = data.aws_iam_policy_document.cloudwatch_full_access.json
}

data "aws_iam_policy_document" "cloudwatch_full_access" {
  statement {
    effect    = "Allow"
    actions   = ["cloudwatch:*"]
    resources = ["*"]
  }
}

variable "give_neo_cloudwatch_full_access" {
  description = "If true, neo gets full access to CloudWatch"
  type        = bool
}

resource "aws_iam_user_policy_attachment" "neo_cloudwatch_full" {
  count = var.give_neo_cloudwatch_full_access ? 1 : 0
  user       = aws_iam_user.example[0].name
  policy_arn = aws_iam_policy.cloudwatch_full_access.arn
}

resource "aws_iam_user_policy_attachment" "neo_cloudwatch_read" {
  count = var.give_neo_cloudwatch_full_access ? 0 : 1
  user       = aws_iam_user.example[0].name
  policy_arn = aws_iam_policy.cloudwatch_read_only.arn
}

# Conditionals with for_each and for expressions
dynamic "tag" {
  for_each = {
    for key, value in var.custom_tags:
    key => upper(value)
    if key != "Name"
  }
  content {
    key                 = tag.key
    value               = tag.value
    propagate_at_launch = true
  }
}

data "aws_availability_zones" "all" {}

resource "aws_instance" "example_2" {
  count             = length(data.aws_availability_zones.all.names)
  availability_zone =  data.aws_availability_zones.all.names[count.index]
  ami               = "ami-0c55b159cbfafe1f0"
  instance_type     = "t2.micro"
}

# how to handle secrets, such as passwords, API keys, and other sensitive data,

#1: Environment Variables

# declare variables for the secrets you wish to pass in:

variable "username" {
  description = "The username for the DB master user"
  type        = string
}

variable "password" {
  description = "The password for the DB master user"
  type        = string
}

# pass the variables to the Terraform resources that need those secrets
resource "aws_db_instance" "example" {
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "example"
  # Set the secrets from variables
  username             = var.username
  password             = var.password
}

# Set secrets via environment variables as below
# export TF_VAR_username=(the username)
# export TF_VAR_password=(the password)

# When you run Terraform, it'll pick up the secrets automatically
# terraform apply

#2: Encrypted Files (e.g., AWS KMS, GCP KMS, AZURE Key Vault)
# An example using AWS KMS


# create a file called db-creds.yml with your secrets -- do NOT check this file into version control!
# username: admin
# password: password

# encrypt this file by using the aws kms encrypt command 
# and writing the resulting cipher text to db-creds.yml.encrypted

# aws kms encrypt \
#   --key-id <YOUR KMS KEY> \
#   --region <AWS REGION> \
#   --plaintext fileb://db-creds.yml \
#   --output text \
#   --query CiphertextBlob \
#   > db-creds.yml.encrypted

# You can now safely check db-creds.yml.encrypted into version control.

#  To decrypt the secrets from this file in your Terraform code, 
# you can use the aws_kms_secrets data source 
# (for GCP KMS or Azure Key Vault, you’d instead use 
# the google_kms_secret or azurerm_key_vault_secret data sources, respectively):

data "aws_kms_secrets" "creds" {
  secret {
    name    = "db"
    payload = file("${path.module}/db-creds.yml.encrypted")
  }
}

# You can parse the YAML as follows
locals {
  db_creds = yamldecode(data.aws_kms_secrets.creds.plaintext["db"])
}

# read the username and password from that YAML and pass them to the aws_db_instance resource
resource "aws_db_instance" "example" {
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "example"
  # Set the secrets from the encrypted file
  username = local.db_creds.username
  password = local.db_creds.password
}

# An example using AWS KMS with sops and Terragrunt
#  https://github.com/mozilla/sops
# https://terragrunt.gruntwork.io/ and https://terragrunt.gruntwork.io/docs/getting-started/quick-start/

# you used sops to create an encrypted YAML file called db-creds.yml
locals {
  db_creds = yamldecode(sops_decrypt_file(("db-creds.yml")))
}

# you can pass username and password as inputs to your Terraform code:
inputs = {
  username = local.db_creds.username
  password = local.db_creds.password
}

# Terraform code, in turn, can read these inputs via variables
variable "username" {
  description = "The username for the DB master user"
  type        = string
}

variable "password" {
  description = "The password for the DB master user"
  type        = string
}

# pass those variables through to aws_db_instance
resource "aws_db_instance" "example" {
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "example"
  # Set the secrets from variables
  username = var.username
  password = var.password
}





