#!/usr/bin/env bash
# -------------------------------------------------------------------
#  MSYS2 Mirror + Proxy + SSL Disable Script
# -------------------------------------------------------------------
#  Features:
#   - Restores default mirrors for all MSYS2 repos
#   - Switches to HTTP (no SSL)
#   - Adds your proxy for curl, wget, git, and pacman
#   - Ranks the 5 fastest mirrors
# -------------------------------------------------------------------

set -e

MIRROR_DIR="/etc/pacman.d"
BACKUP_DIR="${MIRROR_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
PROXY="http://192.168.0.10:8080"   # 🔧 CHANGE YOUR PROXY HERE
TIMEOUT_CONNECT=5
TIMEOUT_TOTAL=300
RANK_COUNT=5

echo "[*] Backing up mirrorlists to $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"
cp -v ${MIRROR_DIR}/mirrorlist.* "$BACKUP_DIR/" || true

echo "[*] Restoring default official mirrors..."
cat > "${MIRROR_DIR}/mirrorlist.msys" <<'EOF'
Server = https://mirror.sjtu.edu.cn/msys2/msys/$arch/
Server = https://download.nus.edu.sg/mirror/msys2/msys/$arch/
Server = https://ftp.acc.umu.se/mirror/msys2.org/msys/$arch/
Server = https://mirror.msys2.org/msys/$arch/
Server = https://mirror.selfnet.de/msys2/msys/$arch/
Server = https://mirror.yandex.ru/mirrors/msys2/msys/$arch/
Server = https://mirrors.dotsrc.org/msys2/msys/$arch/
Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/msys/$arch/
Server = https://mirrors.ustc.edu.cn/msys2/msys/$arch/
Server = https://repo.msys2.org/msys/$arch/
EOF

cat > "${MIRROR_DIR}/mirrorlist.mingw64" <<'EOF'
Server = https://mirror.sjtu.edu.cn/msys2/mingw/mingw64/
Server = https://download.nus.edu.sg/mirror/msys2/mingw/mingw64/
Server = https://ftp.acc.umu.se/mirror/msys2.org/mingw/mingw64/
Server = https://mirror.msys2.org/mingw/mingw64/
Server = https://mirror.selfnet.de/msys2/mingw/mingw64/
Server = https://mirror.yandex.ru/mirrors/msys2/mingw/mingw64/
Server = https://mirrors.dotsrc.org/msys2/mingw/mingw64/
Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/mingw64/
Server = https://mirrors.ustc.edu.cn/msys2/mingw/mingw64/
Server = https://repo.msys2.org/mingw/mingw64/
EOF

cat > "${MIRROR_DIR}/mirrorlist.mingw32" <<'EOF'
Server = https://mirror.sjtu.edu.cn/msys2/mingw/mingw32/
Server = https://download.nus.edu.sg/mirror/msys2/mingw/mingw32/
Server = https://ftp.acc.umu.se/mirror/msys2.org/mingw/mingw32/
Server = https://mirror.msys2.org/mingw/mingw32/
Server = https://mirror.selfnet.de/msys2/mingw/mingw32/
Server = https://mirror.yandex.ru/mirrors/msys2/mingw/mingw32/
Server = https://mirrors.dotsrc.org/msys2/mingw/mingw32/
Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/mingw32/
Server = https://mirrors.ustc.edu.cn/msys2/mingw/mingw32/
Server = https://repo.msys2.org/mingw/mingw32/
EOF

cat > "${MIRROR_DIR}/mirrorlist.ucrt64" <<'EOF'
Server = https://mirror.sjtu.edu.cn/msys2/mingw/ucrt64/
Server = https://download.nus.edu.sg/mirror/msys2/mingw/ucrt64/
Server = https://ftp.acc.umu.se/mirror/msys2.org/mingw/ucrt64/
Server = https://mirror.msys2.org/mingw/ucrt64/
Server = https://mirror.selfnet.de/msys2/mingw/ucrt64/
Server = https://mirror.yandex.ru/mirrors/msys2/mingw/ucrt64/
Server = https://mirrors.dotsrc.org/msys2/mingw/ucrt64/
Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/ucrt64/
Server = https://mirrors.ustc.edu.cn/msys2/mingw/ucrt64/
Server = https://repo.msys2.org/mingw/ucrt64/
EOF

cat > "${MIRROR_DIR}/mirrorlist.clang64" <<'EOF'
Server = https://mirror.sjtu.edu.cn/msys2/mingw/clang64/
Server = https://download.nus.edu.sg/mirror/msys2/mingw/clang64/
Server = https://ftp.acc.umu.se/mirror/msys2.org/mingw/clang64/
Server = https://mirror.msys2.org/mingw/clang64/
Server = https://mirror.selfnet.de/msys2/mingw/clang64/
Server = https://mirror.yandex.ru/mirrors/msys2/mingw/clang64/
Server = https://mirrors.dotsrc.org/msys2/mingw/clang64/
Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/clang64/
Server = https://mirrors.ustc.edu.cn/msys2/mingw/clang64/
Server = https://repo.msys2.org/mingw/clang64/
EOF

echo "[*] Forcing HTTP (disabling SSL)..."
sed -i 's|https://|http://|g' ${MIRROR_DIR}/mirrorlist.*

echo "[*] Installing pacman-contrib if needed..."
pacman -Sy --needed --noconfirm pacman-contrib || true

echo "[*] Ranking mirrors..."
for f in ${MIRROR_DIR}/mirrorlist.*; do
  echo "→ Ranking $f"
  rankmirrors -n $RANK_COUNT "$f" > "${f}.tmp" 2>/dev/null || cp "$f" "${f}.tmp"
  mv "${f}.tmp" "$f"
done

echo "[*] Configuring proxy + SSL disable for all tools..."

# --- Pacman: use curl with proxy + SSL ignore
PACCONF="/etc/pacman.conf"
if ! grep -q "UseXferCommand" "$PACCONF"; then
  echo "[options]" >> "$PACCONF"
  echo "UseXferCommand" >> "$PACCONF"
fi
grep -v "XferCommand" "$PACCONF" > "${PACCONF}.tmp" || true
cat >> "${PACCONF}.tmp" <<EOF
UseXferCommand
XferCommand = /usr/bin/curl -s -S -L -C - -f -k -x ${PROXY} --connect-timeout ${TIMEOUT_CONNECT} --max-time ${TIMEOUT_TOTAL} -o %o %u
EOF
mv "${PACCONF}.tmp" "$PACCONF"

# --- Environment proxy for shell
echo "[*] Setting persistent proxy environment..."
cat > /etc/profile.d/proxy.sh <<EOF
export http_proxy="${PROXY}"
export https_proxy="${PROXY}"
export no_proxy="localhost,127.0.0.1,::1"
EOF

# --- Curl: disable SSL + proxy
cat > ~/.curlrc <<EOF
proxy = "${PROXY}"
insecure
EOF

# --- Wget: disable SSL + proxy
cat > ~/.wgetrc <<EOF
use_proxy = on
check_certificate = off
http_proxy = ${PROXY}
https_proxy = ${PROXY}
EOF

# --- Git: proxy + SSL off
git config --global http.proxy "${PROXY}"
git config --global https.proxy "${PROXY}"
git config --global http.sslVerify false

echo "[*] All services configured:"
echo "    - Mirrors updated and ranked"
echo "    - SSL disabled (HTTP mode)"
echo "    - Proxy: ${PROXY}"
echo "    - curl/wget/git/pacman ready"

echo "[*] You can now run:"
echo "    pacman -Syyu"
