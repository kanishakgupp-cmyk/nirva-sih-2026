cd /workspaces/nirva-sih-2026

cat > vercel-build.sh <<'EOF'
#!/bin/bash
set -e

git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /tmp/flutter
export PATH="/tmp/flutter/bin:$PATH"

flutter config --enable-web

cd mobile
flutter pub get

flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY" \
  --dart-define=API_BASE_URL="$API_BASE_URL"
EOF

chmod +x vercel-build.sh
