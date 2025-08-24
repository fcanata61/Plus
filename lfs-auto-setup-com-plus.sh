#!/usr/bin/env bash
# ====================================================
# LFS Auto Setup com PLUS
# ====================================================

set -euo pipefail

PLUS_ROOT="/opt/plus"
WORKDIR="$PLUS_ROOT/workdir"
SYNC_DIR="$PLUS_ROOT/sync"
LOG_DIR="$PLUS_ROOT/logs"
DB_DIR="$PLUS_ROOT/var/db"
LFS_TOOLCHAIN_DIR="$PLUS_ROOT/lfs-toolchain"

# ----------------------------------------------------
# 1. Criar diretórios
# ----------------------------------------------------
mkdir -p "$PLUS_ROOT"
mkdir -p "$WORKDIR/src" "$WORKDIR/build" "$WORKDIR/sha256"
mkdir -p "$SYNC_DIR/source_cache"
mkdir -p "$LOG_DIR"
mkdir -p "$DB_DIR"
mkdir -p "$LFS_TOOLCHAIN_DIR"
mkdir -p "$PLUS_ROOT/hooks"
mkdir -p "$PLUS_ROOT/patches"

echo "[INFO] Diretórios criados."

# ----------------------------------------------------
# 2. Copiar PLUS scripts e configuração
# ----------------------------------------------------
cp plus.sh "$PLUS_ROOT/plus.sh"
cp plus.conf "$PLUS_ROOT/plus.conf"
cp packages.list "$PLUS_ROOT/packages.list"
cp -r hooks patches "$PLUS_ROOT/"

chmod +x "$PLUS_ROOT/plus.sh"
echo "[INFO] PLUS scripts e config copiados."

# ----------------------------------------------------
# 3. Exportar variáveis de ambiente
# ----------------------------------------------------
export PLUS_ROOT WORKDIR SYNC_DIR LOG_DIR DB_DIR
export LFS_TOOLCHAIN_DIR
export PATH="$LFS_TOOLCHAIN_DIR/bin:$PATH"

# ----------------------------------------------------
# 4. Sincronizar todos os pacotes
# ----------------------------------------------------
cd "$PLUS_ROOT"
./plus.sh sync all

# ----------------------------------------------------
# 5. Instalar dependências do Toolchain
# ----------------------------------------------------
for pkg in gmp mpfr mpc isl binutils gcc make bash coreutils; do
    ./plus.sh install "$pkg" --destdir="$LFS_TOOLCHAIN_DIR"
done

echo "[INFO] Dependências do Toolchain instaladas."

# ----------------------------------------------------
# 6. Build inicial do Toolchain
# ----------------------------------------------------
./plus.sh build gcc --destdir="$LFS_TOOLCHAIN_DIR"
echo "[INFO] Toolchain GCC construído."

# ----------------------------------------------------
# 7. Criar diretórios do sistema LFS
# ----------------------------------------------------
export LFS="$LFS_TOOLCHAIN_DIR"
mkdir -p $LFS/{bin,boot,etc,home,lib,lib64,opt,sbin,srv,tmp,var,usr,var/tmp}
echo "[INFO] Diretórios base do LFS criados."

# ----------------------------------------------------
# 8. Build e instalação de pacotes básicos
# ----------------------------------------------------
BASIC_PACKAGES=(make bash coreutils findutils grep sed m4 ncurses bison flex tar)
for pkg in "${BASIC_PACKAGES[@]}"; do
    ./plus.sh install "$pkg" --destdir="$LFS"
done

echo "[INFO] Pacotes básicos instalados no LFS."

# ----------------------------------------------------
# 9. Build de kernel (exemplo)
# ----------------------------------------------------
./plus.sh sync linux https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git main
./plus.sh build linux --destdir="$LFS"
echo "[INFO] Kernel Linux construído e instalado."

# ----------------------------------------------------
# 10. Limpeza final
# ----------------------------------------------------
./plus.sh clean
echo "[INFO] Workdir, sync e logs limpos."

# ----------------------------------------------------
# 11. Teste do LFS
# ----------------------------------------------------
echo "[INFO] Você pode entrar no chroot do LFS com:"
echo "sudo chroot $LFS /bin/bash"

echo "[INFO] Setup do LFS com PLUS concluído."
