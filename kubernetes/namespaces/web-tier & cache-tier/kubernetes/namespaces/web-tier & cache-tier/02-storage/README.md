# 02-Storage (스토리지)

이 폴더에는 데이터 저장소 관련 리소스들이 포함되어 있습니다.

## 파일 목록

- `redis-*.yaml` - Redis 클러스터 구성 (Master, Slave, Config, Secret, Services)
- `rds-table-setup-*.yaml` - RDS 테이블 설정
- `db-setup-job.yaml` - 데이터베이스 초기화 Job
- `setup-backend-database.sql` - 데이터베이스 스키마

## 배포 순서

1. Redis Secret 생성
2. Redis ConfigMap 생성
3. Redis Master StatefulSet 배포
4. Redis Slave StatefulSet 배포
5. Redis Services 생성
6. RDS 테이블 설정 Job 실행
