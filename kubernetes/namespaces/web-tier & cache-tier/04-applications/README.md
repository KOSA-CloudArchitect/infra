# 04-Applications (애플리케이션)

이 폴더에는 실제 애플리케이션 배포 관련 리소스들이 포함되어 있습니다.

## 파일 목록

- `04-frontend-deployment.yaml` - 프론트엔드 애플리케이션
- `05-backend-deployment.yaml` - 백엔드 애플리케이션
- `06-websocket-deployment.yaml` - WebSocket 서버
- `frontend-config-updated.yaml` - 프론트엔드 설정
- `deployment.spec.template.spec.yaml` - 배포 템플릿

## 배포 순서

1. 백엔드 애플리케이션 배포
2. WebSocket 서버 배포
3. 프론트엔드 애플리케이션 배포
4. 설정 업데이트 적용
