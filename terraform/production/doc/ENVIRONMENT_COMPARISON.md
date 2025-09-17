# 📊 Test vs Production 환경 비교

## 🔍 환경별 주요 차이점

### **1. 노드 그룹 설정**

| 노드 그룹 | Test 환경 | Production 환경 | 차이점 |
|-----------|-----------|-----------------|--------|
| **core-on** | min: 1, max: 5, desired: 1 | min: 2, max: 10, desired: 2 | Production: 고가용성 |
| **airflow-core-on** | min: 1, max: 5, desired: 1 | min: 2, max: 10, desired: 2 | Production: 고가용성 |
| **spark-driver-on** | min: 1, max: 5, desired: 1 | min: 2, max: 10, desired: 2 | Production: 고가용성 |
| **kafka-storage-on** | min: 1, max: 5, desired: 1 | min: 3, max: 10, desired: 3 | Production: AZ별 1개씩 |
| **airflow-worker-spot** | min: 0, max: 20, desired: 0 | min: 0, max: 50, desired: 0 | Production: 더 큰 스케일 |
| **spark-exec-spot** | min: 0, max: 50, desired: 0 | min: 0, max: 100, desired: 0 | Production: 더 큰 스케일 |
| **gpu-spot** | min: 0, max: 10, desired: 0 | min: 0, max: 20, desired: 0 | Production: 더 큰 스케일 |

### **2. RDS 설정**

| 설정 | Test 환경 | Production 환경 | 차이점 |
|------|-----------|-----------------|--------|
| **인스턴스 클래스** | db.t4g.medium | db.r6g.large | Production: 더 큰 인스턴스 |
| **스토리지** | 20GB | 100GB | Production: 더 큰 스토리지 |
| **최대 스토리지** | 100GB | 1000GB | Production: 자동 확장 |
| **백업 보존** | 3일 | 7일 | Production: 더 긴 백업 |
| **Multi-AZ** | false | true | Production: 고가용성 |
| **백업 윈도우** | 03:00-04:00 | 03:00-04:00 | 동일 |
| **유지보수 윈도우** | sun:04:00-sun:05:00 | sun:04:00-sun:05:00 | 동일 |

### **3. 보안 설정**

| 설정 | Test 환경 | Production 환경 | 차이점 |
|------|-----------|-----------------|--------|
| **EKS 퍼블릭 액세스** | 현재 IP만 | 현재 IP만 | 동일 (보안) |
| **S3 퍼블릭 액세스** | 차단 | 차단 | 동일 (보안) |
| **RDS 퍼블릭 액세스** | 비활성화 | 비활성화 | 동일 (보안) |
| **VPC 피어링** | 활성화 | 활성화 | 동일 |

### **4. 비용 예상**

| 컴포넌트 | Test 환경 (월) | Production 환경 (월) | 차이점 |
|----------|----------------|---------------------|--------|
| **EKS 클러스터** | $73 | $73 | 동일 |
| **노드 그룹 (On-Demand)** | $50-100 | $200-400 | Production: 4배 |
| **노드 그룹 (Spot)** | $20-50 | $50-150 | Production: 3배 |
| **RDS** | $30-60 | $150-300 | Production: 5배 |
| **S3** | $5-20 | $10-50 | Production: 2배 |
| **총 예상 비용** | **$178-303** | **$483-973** | Production: 3배 |

## 🚀 배포 전략

### **Test 환경 배포**
```bash
# 빠른 배포 (개발/테스트용)
cd terraform/test
terraform apply -auto-approve
```

### **Production 환경 배포**
```bash
# 단계별 안전한 배포
cd terraform/production
./deploy.sh
```

## ⚠️ 주의사항

### **Test 환경**
- ✅ 빠른 배포 가능
- ✅ 낮은 비용
- ❌ 단일 AZ (고가용성 없음)
- ❌ 작은 인스턴스 크기

### **Production 환경**
- ✅ 고가용성 (Multi-AZ)
- ✅ 자동 스케일링
- ✅ 백업 및 복구
- ❌ 높은 비용
- ❌ 긴 배포 시간

## 🔄 마이그레이션 전략

### **Test → Production 마이그레이션**
1. **데이터베이스**: RDS 스냅샷 생성 → Production 복원
2. **S3 데이터**: 버킷 간 복사
3. **Kubernetes 리소스**: YAML 파일로 마이그레이션
4. **설정**: 환경변수 및 시크릿 재설정

### **롤백 전략**
1. **Production → Test**: 데이터 다운그레이드
2. **전체 삭제**: `terraform destroy`
3. **부분 삭제**: 특정 리소스만 삭제

## 📋 체크리스트

### **배포 전 체크리스트**
- [ ] AWS CLI 설정 확인
- [ ] kubectl 설치 및 설정
- [ ] Helm 설치
- [ ] Terraform 상태 확인
- [ ] 비용 예산 확인
- [ ] 백업 전략 수립

### **배포 후 체크리스트**
- [ ] 모든 노드가 Ready 상태
- [ ] 모든 Pod가 Running 상태
- [ ] 네임스페이스 생성 확인
- [ ] 서비스 어카운트 IRSA 연결 확인
- [ ] RDS 연결 테스트
- [ ] S3 버킷 접근 테스트
- [ ] Jenkins 서버 접근 테스트

---
**작성일**: 2024년 12월
**작성자**: tjpark

