#!/usr/bin/env bash
# Đưa service web MU lên VPS Docker Swarm. Chạy từ máy dev (Git Bash / WSL / Linux).
#   bash deploy.sh setup            # lần đầu: thư mục, swarm init, nhãn node, mật khẩu DB (trên VPS)
#   bash deploy.sh images [TAG]     # build + push image mu-web, mu-gateway (cần dist/web từ build_content.py --web)
#   bash deploy.sh content          # đẩy gói nội dung mới + manifest.json (+ APK nếu có) lên VPS — không cần build image
#   bash deploy.sh up [TAG]         # docker stack deploy
#   bash deploy.sh all [TAG]        # images + content + up
#   bash deploy.sh status | logs <mu-web|mu-gateway|openmu|mu-db>
set -euo pipefail
cd "$(dirname "$0")"
[ -f deploy.env ] || { echo "Thiếu deploy.env (sao chép deploy.env.example)"; exit 1; }
# shellcheck disable=SC1091
set -a; . ./deploy.env; set +a
: "${HUB:?}" "${VPS:?}"; MU_DIR="${MU_DIR:-/opt/mu}"; HTTP_PORT="${HTTP_PORT:-8090}"; VPS_PORT="${VPS_PORT:-22}"
SSH=(ssh -p "$VPS_PORT" -o ServerAliveInterval=30 "$VPS")
SCP=(scp -P "$VPS_PORT")
STACK=mu

cmd_setup() {
  "${SSH[@]}" "MU_DIR='$MU_DIR' bash -s" <<'EOS'
set -e
mkdir -p "$MU_DIR/content/packs" "$MU_DIR/download"
docker info 2>/dev/null | grep -q 'Swarm: active' || docker swarm init >/dev/null
NODE=$(docker node ls --filter role=manager -q | head -1)
docker node update --label-add mu.main=true "$NODE" >/dev/null
if [ ! -f "$MU_DIR/stack.env" ]; then
  umask 077
  echo "DB_PASSWORD=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)" > "$MU_DIR/stack.env"
  echo "Đã tạo $MU_DIR/stack.env (mật khẩu DB ngẫu nhiên). Thêm OPENMU_ADMIN_USER / OPENMU_ADMIN_PASSWORD nếu muốn."
fi
echo "OK: $MU_DIR sẵn sàng, node $NODE có nhãn mu.main=true"
EOS
}

cmd_images() {
  local tag="${1:-$(date +%Y%m%d%H%M)}"
  [ -f dist/web/index.html ] || { echo "Chưa có dist/web — chạy: python tools/build_content.py --godot <Godot> --web"; exit 1; }
  docker build -f web/Dockerfile     -t "$HUB/mu-web:$tag"     .
  docker build -f gateway/Dockerfile -t "$HUB/mu-gateway:$tag" .
  docker push "$HUB/mu-web:$tag"
  docker push "$HUB/mu-gateway:$tag"
  echo "$tag" > .last_tag
  echo "Image tag: $tag"
}

# Build image NGAY TRÊN VPS (không cần Docker local / Docker Hub; đủ cho Swarm 1 node).
cmd_images_remote() {
  local tag="${1:-$(date +%Y%m%d%H%M)}"
  [ -f dist/web/index.html ] || { echo "Chưa có dist/web"; exit 1; }
  "${SSH[@]}" "rm -rf '$MU_DIR/build' && mkdir -p '$MU_DIR/build'"
  tar -cf - web gateway dist/web | "${SSH[@]}" "tar -xf - -C '$MU_DIR/build'"
  "${SSH[@]}" "cd '$MU_DIR/build' && docker build -f web/Dockerfile -t '$HUB/mu-web:$tag' . && docker build -f gateway/Dockerfile -t '$HUB/mu-gateway:$tag' . && rm -rf '$MU_DIR/build'"
  echo "$tag" > .last_tag
  echo "Image tag (trên VPS): $tag"
}

cmd_content() {
  [ -f dist/content/manifest.json ] || { echo "Chưa có dist/content — chạy build_content.py trước"; exit 1; }
  # Gói tên theo mã băm => chỉ gửi gói VPS chưa có. manifest.json gửi CUỐI để người chơi không thấy bản dở dang.
  local have; have=$("${SSH[@]}" "ls '$MU_DIR/content/packs' 2>/dev/null || true")
  local sent=0
  for f in dist/content/packs/*.pck; do
    local n; n=$(basename "$f")
    if ! grep -qxF "$n" <<<"$have"; then
      echo "  -> $n ($(du -h "$f" | cut -f1))"
      "${SCP[@]}" "$f" "$VPS:$MU_DIR/content/packs/$n.part"
      "${SSH[@]}" "mv '$MU_DIR/content/packs/$n.part' '$MU_DIR/content/packs/$n'"
      sent=$((sent+1))
    fi
  done
  "${SCP[@]}" dist/content/manifest.json "$VPS:$MU_DIR/content/manifest.json.new"
  "${SSH[@]}" "mv '$MU_DIR/content/manifest.json.new' '$MU_DIR/content/manifest.json'"
  if [ -f dist/apk/mu-launcher.apk ]; then
    "${SCP[@]}" dist/apk/mu-launcher.apk "$VPS:$MU_DIR/download/mu-launcher.apk"
    echo "  APK đã đẩy: https://${DOMAIN:-<domain>}/download/mu-launcher.apk"
  fi
  # Dọn gói không còn trong manifest.
  ls dist/content/packs | "${SSH[@]}" "cd '$MU_DIR/content/packs' && cat > /tmp/mu_keep && for f in *.pck; do grep -qxF \"\$f\" /tmp/mu_keep || rm -f \"\$f\"; done; rm -f /tmp/mu_keep"
  echo "Nội dung: gửi $sent gói mới."
}

# Build image trang thông tin (MuGodot/website) ngay trên VPS. Dữ liệu tài khoản nằm ở $MU_DIR/site-data (không mất khi cập nhật).
cmd_site() {
  local tag; tag="$(date +%Y%m%d%H%M)"
  "${SSH[@]}" "mkdir -p '$MU_DIR/site-data' && chown 10001 '$MU_DIR/site-data' && rm -rf '$MU_DIR/build-site' && mkdir -p '$MU_DIR/build-site'"
  tar -cf - --exclude='website/data' -C .. website | "${SSH[@]}" "tar -xf - -C '$MU_DIR/build-site'"
  "${SCP[@]}" site/Dockerfile "$VPS:$MU_DIR/build-site/Dockerfile"
  "${SSH[@]}" "cd '$MU_DIR/build-site' && docker build -t '$HUB/mu-site:$tag' . && rm -rf '$MU_DIR/build-site'"
  echo "$tag" > .site_tag
  echo "Image mu-site: $tag"
}

cmd_up() {
  local tag="${1:-$(cat .last_tag 2>/dev/null || true)}"
  [ -n "$tag" ] || { echo "Cần TAG (deploy.sh up <tag>) hoặc chạy images trước"; exit 1; }
  "${SCP[@]}" stack.yml "$VPS:$MU_DIR/stack.yml"
  "${SSH[@]}" "set -e; cd '$MU_DIR'; set -a; . ./stack.env; set +a; \
    export HUB='$HUB' TAG='$tag' MU_DIR='$MU_DIR' HTTP_PORT='$HTTP_PORT' SITE_PORT='${SITE_PORT:-8091}' SITE_TAG='$(cat .site_tag 2>/dev/null || echo none)'; \
    docker stack deploy --with-registry-auth --resolve-image never --prune -c stack.yml $STACK"
  echo "Đã deploy tag $tag. Kiểm tra: bash deploy.sh status"
}

case "${1:-}" in
  setup)   cmd_setup ;;
  images)  shift; cmd_images "$@" ;;
  images-remote) shift; cmd_images_remote "$@" ;;
  content) cmd_content ;;
  site)    cmd_site ;;
  up)      shift; cmd_up "$@" ;;
  all)     shift; cmd_images "$@"; cmd_content; cmd_up "${1:-}" ;;
  status)  "${SSH[@]}" "docker stack services $STACK; echo; curl -s -o /dev/null -w 'web /healthz -> %{http_code}\n' http://127.0.0.1:$HTTP_PORT/healthz" ;;
  logs)    "${SSH[@]}" "docker service logs --tail 100 -f ${STACK}_${2:?tên service}" ;;
  *) sed -n 2,10p "$0"; exit 1 ;;
esac
