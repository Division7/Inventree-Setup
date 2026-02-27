resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

}

resource "aws_subnet" "default_deploy" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2"
}