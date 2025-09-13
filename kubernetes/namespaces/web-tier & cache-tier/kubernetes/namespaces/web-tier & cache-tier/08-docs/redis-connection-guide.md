# Redis EKS 연결 가이드

## 개요

이 문서는 기존 `redisService.js`와 EKS Redis 클러스터 간의 호환성을 보장하기 위한 연결 설정 가이드입니다.

## 서비스 엔드포인트

### 1. 통합 서비스 (기존 코드 호환)
```javascript
// 기존 환경변수 설정 (변경 불필요)
REDIS_HOST=redis-service.cache-tier.svc.cluster.local
REDIS_PORT=6379
REDIS_PASSWORD=redis-secure-password-2024
```

### 2. 읽기/쓰기 분리 (성능 최적화)
```javascript
// 쓰기 전용 (Master)
REDIS_WRITE_HOST=redis-master-0.redis-master.cache-tier.svc.cluster.local
REDIS_WRITE_PORT=6379

// 읽기 전용 (Slave 로드밸런싱)
REDIS_READ_HOST=redis-readonly.cache-tier.svc.cluster.local
REDIS_READ_PORT=6379
```

## 기존 코드 호환성

### redisService.js 수정 사항

기존 `redisService.js`는 수정 없이 그대로 사용 가능합니다. 다음 환경변수만 업데이트하면 됩니다:

```bash
# Kubernetes ConfigMap 또는 Secret에 설정
REDIS_HOST=redis-service.cache-tier.svc.cluster.local
REDIS_PORT=6379
REDIS_PASSWORD=redis-secure-password-2024
REDIS_DB=0
```

### 성능 최적화를 위한 선택적 수정

읽기 성능 향상을 위해 읽기/쓰기 분리를 원하는 경우:

```javascript
// redisService.js에 추가할 수 있는 최적화 코드
class RedisService {
  constructor() {
    // 기존 클라이언트 (쓰기용)
    this.writeClient = null;
    // 읽기 전용 클라이언트 (선택사항)
    this.readClient = null;
  }

  async initialize() {
    // 기존 초기화 로직 유지
    const writeConfig = {
      host: process.env.REDIS_HOST || 'redis-service.cache-tier.svc.cluster.local',
      port: parseInt(process.env.REDIS_PORT) || 6379,
      password: process.env.REDIS_PASSWORD,
      // ... 기존 설정
    };
    
    this.writeClient = new Redis(writeConfig);
    this.client = this.writeClient; // 기존 호환성 유지

    // 읽기 전용 클라이언트 (선택사항)
    if (process.env.REDIS_READ_HOST) {
      const readConfig = {
        ...writeConfig,
        host: process.env.REDIS_READ_HOST,
      };
      this.readClient = new Redis(readConfig);
    }
  }

  // 읽기 작업 최적화 (선택사항)
  async get(key) {
    const client = this.readClient || this.client;
    // 기존 로직 사용
    return super.get.call({ client, isReady: () => client.status === 'ready' }, key);
  }
}
```

## 배포 순서

1. **ConfigMap 및 Secret 배포**
   ```bash
   kubectl apply -f k8s-manifests/redis-configmap.yaml
   kubectl apply -f k8s-manifests/redis-secret.yaml
   ```

2. **Redis Master 배포**
   ```bash
   kubectl apply -f k8s-manifests/redis-master-statefulset.yaml
   ```

3. **Redis Slave 배포**
   ```bash
   kubectl apply -f k8s-manifests/redis-slave-statefulset.yaml
   ```

4. **Services 배포**
   ```bash
   kubectl apply -f k8s-manifests/redis-services.yaml
   ```

5. **모니터링 설정**
   ```bash
   kubectl apply -f k8s-manifests/redis-monitoring.yaml
   ```

## 검증 방법

### 1. Pod 상태 확인
```bash
kubectl get pods -n cache-tier -l app=redis
```

### 2. 서비스 연결 테스트
```bash
# Master 연결 테스트
kubectl exec -it -n cache-tier redis-master-0 -- redis-cli -a redis-secure-password-2024 ping

# Slave 연결 테스트
kubectl exec -it -n cache-tier redis-slave-0 -- redis-cli -a redis-secure-password-2024 ping
```

### 3. 복제 상태 확인
```bash
kubectl exec -it -n cache-tier redis-master-0 -- redis-cli -a redis-secure-password-2024 info replication
```

### 4. 백엔드 연결 테스트
```bash
# 백엔드 Pod에서 Redis 연결 테스트
kubectl exec -it -n web-tier <backend-pod-name> -- node -e "
const Redis = require('ioredis');
const client = new Redis({
  host: 'redis-service.cache-tier.svc.cluster.local',
  port: 6379,
  password: 'redis-secure-password-2024'
});
client.ping().then(console.log).catch(console.error);
"
```

## 트러블슈팅

### 1. 연결 실패
- DNS 해상도 확인: `nslookup redis-service.cache-tier.svc.cluster.local`
- 네트워크 정책 확인: `kubectl get networkpolicy -n cache-tier`
- 비밀번호 확인: `kubectl get secret redis-secret -n cache-tier -o yaml`

### 2. 복제 실패
- Master 로그 확인: `kubectl logs -n cache-tier redis-master-0`
- Slave 로그 확인: `kubectl logs -n cache-tier redis-slave-0`
- 네트워크 연결 확인: `kubectl exec -it -n cache-tier redis-slave-0 -- ping redis-master-0.redis-master.cache-tier.svc.cluster.local`

### 3. 성능 문제
- 메모리 사용량 확인: `kubectl top pods -n cache-tier`
- Redis 메트릭 확인: Prometheus에서 redis_* 메트릭 조회
- 슬로우 쿼리 확인: `kubectl exec -it -n cache-tier redis-master-0 -- redis-cli -a redis-secure-password-2024 slowlog get 10`

## 백업 및 복구

### 자동 백업
- 매일 새벽 2시 자동 백업 실행
- 백업 파일은 `/backup` 디렉토리에 저장
- 7일 이상 된 백업 파일 자동 삭제

### 수동 백업
```bash
kubectl create job --from=cronjob/redis-backup redis-backup-manual -n cache-tier
```

### 복구
```bash
# 백업 파일 확인
kubectl exec -it -n cache-tier redis-master-0 -- ls -la /backup

# 복구 실행 (예시)
kubectl exec -it -n cache-tier redis-master-0 -- redis-cli -a redis-secure-password-2024 --rdb /backup/dump_20241201_020000.rdb
```

## 모니터링 대시보드

Prometheus + Grafana 환경에서 다음 메트릭을 모니터링할 수 있습니다:

- `redis_connected_clients`: 연결된 클라이언트 수
- `redis_used_memory_bytes`: 메모리 사용량
- `redis_commands_processed_total`: 처리된 명령어 수
- `redis_keyspace_hits_total`: 캐시 히트 수
- `redis_keyspace_misses_total`: 캐시 미스 수
- `redis_master_repl_offset`: 복제 오프셋

## 보안 고려사항

1. **네트워크 분리**: cache-tier 네임스페이스는 web-tier에서만 접근 가능
2. **비밀번호 보호**: Kubernetes Secret을 통한 비밀번호 관리
3. **내부 통신**: 클러스터 내부 통신만 허용, 외부 접근 차단
4. **모니터링**: 비정상적인 접근 패턴 감지 및 알림