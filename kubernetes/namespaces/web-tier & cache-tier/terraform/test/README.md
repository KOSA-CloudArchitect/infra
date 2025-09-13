# Test Environment Infrastructure

이 폴더는 테스트 환경을 위한 Terraform 인프라 코드입니다.

## 🏗️ 주요 구성 요소

### 1. **VPC 구성**
- **VPC-APP**: 애플리케이션용 (Public/Private Subnets)
- **VPC-DB**: 데이터베이스용 (Private Subnets만)
- **VPC Peering**: App과 DB VPC 간 통신

### 2. **RDS PostgreSQL**
- **인스턴스 타입**: `db.t3.micro` (최소 사양)
- **스토리지**: 20GB (자동 확장 최대 100GB)
- **엔진**: PostgreSQL 15.4
- **보안**: VPC-APP에서만 접근 가능

### 3. **단방향 통신 설정**
- **PUBLIC → ONPREM**: 허용 (AWS에서 On-premises로 통신 가능)
- **ONPREM → PUBLIC**: 차단 (On-premises에서 AWS로 통신 불가)
- **VPN 서버**: 불필요 (AWS 기본 보안 정책으로 자동 적용)

## 🚀 배포 방법

### 1. **사전 준비**
```bash
# AWS CLI 설정
aws configure

# Terraform 초기화
terraform init
```

### 2. **환경 변수 설정**
```bash
# 예시 파일을 복사
cp terraform.tfvars.example terraform.tfvars

# 실제 값으로 수정
# - db_password: 안전한 비밀번호 설정
# - key_pair_name: EC2 접속용 키페어 이름
```

### 3. **배포 실행**
```bash
# 계획 확인
terraform plan

# 배포 실행
terraform apply
```

### 4. **배포 확인**
```bash
# 출력 정보 확인
terraform output

# 리소스 상태 확인
terraform show
```

## 🔒 보안 설정

### **RDS PostgreSQL**
- VPC-APP의 private subnet에서만 접근 가능
- SSL 암호화 활성화
- 백업 보존 기간: 7일

### **단방향 통신**
- PUBLIC → ONPREM 통신 허용
- ONPREM → PUBLIC 통신 자동 차단
- 별도의 VPN 서버 불필요

## 💰 비용 최적화

### **RDS PostgreSQL**
- `db.t3.micro` 인스턴스 (최소 사양)
- 성능 인사이트 비활성화
- 상세 모니터링 비활성화
- 자동 스토리지 확장 (20GB → 100GB)

### **통신 비용**
- VPN 서버 비용 절약 (인스턴스 불필요)
- AWS 기본 보안 정책 활용

## 🌐 네트워크 구성

### **CIDR 대역**
- **VPC-APP**: 172.20.128.0/17
- **VPC-DB**: 172.20.0.0/17
- **On-premises**: 10.128.0.0/19

### **Subnet 구성**
- **Public Subnets**: AZ-a, AZ-b, AZ-c
- **Private Subnets**: AZ-a, AZ-b, AZ-c
- **DB Subnets**: AZ-a, AZ-b (Multi-AZ 구성)

## 📊 모니터링 및 로깅

### **RDS PostgreSQL**
- 연결/해제 로그 활성화
- 백업 로그 활성화
- CloudWatch 메트릭 기본 제공

### **통신 모니터링**
- VPC Flow Logs로 통신 패턴 모니터링
- CloudWatch 기본 메트릭

## 🧹 정리 방법

### **전체 인프라 삭제**
```bash
terraform destroy
```

### **특정 리소스만 삭제**
```bash
# RDS만 삭제
terraform destroy -target=aws_db_instance.postgresql

# 특정 리소스만 삭제
terraform destroy -target=aws_db_instance.postgresql
```

## ⚠️ 주의사항

1. **데이터베이스 비밀번호**: 반드시 안전한 비밀번호로 설정
2. **키페어**: VPN Server 접속을 위한 키페어 필요
3. **비용**: 테스트 완료 후 반드시 리소스 정리
4. **보안**: 프로덕션 환경에는 적합하지 않음

## 🔧 문제 해결

### **일반적인 문제들**
1. **VPC Peering 연결 실패**: 라우팅 테이블 확인
2. **RDS 연결 실패**: 보안 그룹 설정 확인
3. **통신 문제**: VPC Flow Logs와 보안 그룹 설정 확인

### **로그 확인**
```bash
# RDS 로그 확인
aws rds describe-db-log-files --db-instance-identifier [INSTANCE-ID]

# VPC Flow Logs 확인
aws logs describe-log-groups --log-group-name-prefix "/aws/vpc/flowlogs"
```

## 📞 지원

문제가 발생하면 다음을 확인하세요:
1. Terraform 상태 파일
2. AWS CloudTrail 로그
3. CloudWatch 메트릭
4. 보안 그룹 설정
