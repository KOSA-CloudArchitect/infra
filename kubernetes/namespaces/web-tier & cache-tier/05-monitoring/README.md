# 05-Monitoring (모니터링)

이 폴더에는 모니터링 관련 리소스들이 포함되어 있습니다.

## 파일 목록

- `09-monitoring-prometheus.yaml` - Prometheus 서버
- `10-monitoring-redis-exporter.yaml` - Redis 메트릭 수집기
- `11-monitoring-grafana.yaml` - Grafana 대시보드
- `13-monitoring-alertmanager.yaml` - AlertManager
- `redis-monitoring.yaml` - Redis 모니터링 설정

## 배포 순서

1. Prometheus 서버 배포
2. Redis Exporter 배포
3. Grafana 대시보드 배포
4. AlertManager 배포
5. 모니터링 설정 적용
