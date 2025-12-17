#!/bin/bash
set -e

echo "[Hook] start"

# 1) nginx 설치
if ! command -v nginx >/dev/null 2>&1; then
  echo "[Hook] nginx not found -> install"
  if command -v yum >/dev/null 2>&1; then
    yum install -y nginx
  else
    apt-get update -y
    apt-get install -y nginx
  fi
fi

systemctl enable nginx

APP_DIR="/opt/codedeploy-app"

# 2) dist 실제 경로 자동 탐색 (Angular 설정 차이 대응)
DIST_DIR="$(find "$APP_DIR/dist" -maxdepth 4 -type d -name "browser" 2>/dev/null | head -n 1)"
if [ -z "$DIST_DIR" ]; then
  DIST_DIR="$(find "$APP_DIR/dist" -maxdepth 2 -mindepth 1 -type d 2>/dev/null | head -n 1)"
fi

if [ -z "$DIST_DIR" ]; then
  echo "ERROR: dist not found under $APP_DIR/dist"
  ls -al "$APP_DIR" || true
  ls -al "$APP_DIR/dist" || true
  exit 1
fi

echo "[Hook] Using DIST_DIR=$DIST_DIR"

# 3) nginx 루트에 복사
rm -rf /usr/share/nginx/html/*
cp -r "$DIST_DIR"/* /usr/share/nginx/html/

# 4) SPA 라우팅 설정 (Angular 필수)
cat >/etc/nginx/conf.d/angular-spa.conf <<'EOF'
server {
  listen 80;
  server_name _;
  root /usr/share/nginx/html;
  index index.html;

  location / {
    try_files $uri $uri/ /index.html;
  }
}
EOF

# 5) nginx 재시작
nginx -t
systemctl restart nginx

echo "[Hook] done"
