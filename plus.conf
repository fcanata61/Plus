#!/usr/bin/env bash
# plus - Gerenciador de pacotes Linux avançado
# Parte 1: Estrutura, configuração, logging e utilitários

set -euo pipefail
IFS=$'\n\t'

# ===== Diretórios principais =====
PLUS_ROOT="${PLUS_ROOT:-/opt/plus}"
WORKDIR="${WORKDIR:-$PLUS_ROOT/workdir}"
SYNC_DIR="${SYNC_DIR:-$PLUS_ROOT/sync}"
LOG_DIR="${LOG_DIR:-$PLUS_ROOT/logs}"
CONF_FILE="${PLUS_ROOT}/plus.conf"

# Criar diretórios se não existirem
mkdir -p "$WORKDIR/src" "$WORKDIR/build" "$WORKDIR/sha256" "$SYNC_DIR" "$LOG_DIR"

# ===== Carregar configuração =====
if [[ -f "$CONF_FILE" ]]; then
    source "$CONF_FILE"
fi

# ===== Logging =====
log() {
    local level="$1"
    local msg="$2"
    echo "[$(date +'%F %T')] $level $msg" | tee -a "$LOG_DIR/plus.log"
}

# ===== Utilitários =====
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log INFO "Created directory: $dir"
    fi
}

confirm() {
    local msg="$1"
    read -rp "$msg [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

die() {
    local msg="$1"
    log ERROR "$msg"
    exit 1
}

# ===== Função para help =====
show_help() {
    cat <<EOF
plus - Gerenciador de pacotes Linux avançado

Comandos:
  install <pkg>       Instalar pacote
  remove <pkg>        Remover pacote
  upgrade <pkg/all>   Atualizar pacote ou sistema inteiro
  build <pkg>         Build isolado do pacote
  sync <pkg/all>      Sincronizar pacotes/repositórios
  clean               Limpar diretórios de trabalho
  help                Mostrar esta ajuda

Flags:
  --force, --dry-run, --no-install, --cflags, --ldflags, --destdir
EOF
}

# ===== Função principal CLI =====
main() {
    local cmd="${1:-help}"
    shift || true
    case "$cmd" in
        install) install_package "$@" ;;
        remove) remove_package "$@" ;;
        upgrade) upgrade_package "$@" ;;
        build) build_package "$@" ;;
        sync) sync_package "$@" ;;
        clean) clean_workdir ;;
        help|*) show_help ;;
    esac
}
# ===== Dependências =====
# Estrutura de arquivos de dependência esperada:
# src/<pkg>/<pkg>.dep       -> obrigatórias
# src/<pkg>/<pkg>.optdep    -> opcionais
# src/<pkg>/<pkg>.recom     -> recomendadas

declare -A DEPS_RESOLVED
declare -A DEP_STACK

resolve_deps() {
    local pkg="$1"
    local parent="${2:-}"

    # Evitar ciclos
    if [[ ${DEP_STACK[$pkg]:-0} -eq 1 ]]; then
        die "Dependency cycle detected: $pkg <- $parent"
    fi
    DEP_STACK[$pkg]=1

    # Ignorar se já resolvido
    if [[ ${DEPS_RESOLVED[$pkg]:-0} -eq 1 ]]; then
        return
    fi

    log INFO "DEPS Resolving dependencies for $pkg"

    local dep_file="$WORKDIR/src/$pkg/$pkg.dep"
    local opt_file="$WORKDIR/src/$pkg/$pkg.optdep"
    local recom_file="$WORKDIR/src/$pkg/$pkg.recom"

    # Dependências obrigatórias
    if [[ -f "$dep_file" ]]; then
        while read -r dep; do
            [[ -z "$dep" || "$dep" =~ ^# ]] && continue
            resolve_deps "$dep" "$pkg"
        done < "$dep_file"
    fi

    # Dependências opcionais
    if [[ -f "$opt_file" ]]; then
        while read -r dep; do
            [[ -z "$dep" || "$dep" =~ ^# ]] && continue
            log INFO "DEPS Optional: $dep for $pkg (skipped by default)"
        done < "$opt_file"
    fi

    # Dependências recomendadas
    if [[ -f "$recom_file" ]]; then
        while read -r dep; do
            [[ -z "$dep" || "$dep" =~ ^# ]] && continue
            log INFO "DEPS Recommended: $dep for $pkg (can be skipped with --no-recommended)"
        done < "$recom_file"
    fi

    DEPS_RESOLVED[$pkg]=1
    DEP_STACK[$pkg]=0
  }
# ===== Funções de download e sync =====

# Download de fonte Git ou HTTP
download_source() {
    local pkg="$1"
    local url="$2"
    local dest="$SYNC_DIR/$pkg"
    local branch="${3:-$SYNC_DEFAULT_BRANCH}"

    ensure_dir "$dest"

    if [[ "$url" =~ ^git ]]; then
        if [[ -d "$dest/.git" ]]; then
            log INFO "SYNC $pkg: git fetch"
            git -C "$dest" fetch --all
            git -C "$dest" checkout "$branch"
            git -C "$dest" pull origin "$branch"
        else
            log INFO "SYNC $pkg: git clone $url branch $branch"
            git clone -b "$branch" "$url" "$dest"
        fi
    else
        # Download HTTP/HTTPS
        local file="$dest/$(basename "$url")"
        log INFO "SYNC $pkg: downloading $url to $file"
        curl -L -o "$file" "$url"
    fi
}

# Sync de pacote individual ou todos
sync_package() {
    local pkg="$1"
    local url="$2"
    local branch="${3:-$SYNC_DEFAULT_BRANCH}"

    log INFO "SYNC Starting sync for $pkg"

    # Hook pre-sync
    if [[ -x "$PLUS_ROOT/hooks/pre-sync.sh" ]]; then
        log INFO "SYNC Running pre-sync hook for $pkg"
        "$PLUS_ROOT/hooks/pre-sync.sh" "$pkg"
    fi

    download_source "$pkg" "$url" "$branch"

    # Hook post-sync
    if [[ -x "$PLUS_ROOT/hooks/post-sync.sh" ]]; then
        log INFO "SYNC Running post-sync hook for $pkg"
        "$PLUS_ROOT/hooks/post-sync.sh" "$pkg"
    fi

    log INFO "SYNC Completed for $pkg"
}

# Sync de todos os pacotes
sync_all() {
    # Ler lista de pacotes e URLs de algum arquivo ou diretório
    # Exemplo: $PLUS_ROOT/packages.list com linhas "pkg url [branch]"
    if [[ ! -f "$PLUS_ROOT/packages.list" ]]; then
        die "SYNC packages.list não encontrado"
    fi

    while read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        local pkg url branch
        pkg=$(echo "$line" | awk '{print $1}')
        url=$(echo "$line" | awk '{print $2}')
        branch=$(echo "$line" | awk '{print $3}')
        branch="${branch:-$SYNC_DEFAULT_BRANCH}"
        sync_package "$pkg" "$url" "$branch"
    done < "$PLUS_ROOT/packages.list"
  }
# ===== Funções de build =====

# Detecta e descompacta automaticamente arquivos de origem
extract_source() {
    local src_file="$1"
    local dest_dir="$2"

    ensure_dir "$dest_dir"

    case "$src_file" in
        *.tar.gz|*.tgz) tar -xzf "$src_file" -C "$dest_dir" ;;
        *.tar.bz2|*.tbz2) tar -xjf "$src_file" -C "$dest_dir" ;;
        *.tar.xz|*.txz) tar -xJf "$src_file" -C "$dest_dir" ;;
        *.zip) unzip -q "$src_file" -d "$dest_dir" ;;
        *) die "Unsupported archive format: $src_file" ;;
    esac

    log INFO "EXTRACT Extracted $src_file to $dest_dir"
}

# Aplica patches automaticamente
apply_patches() {
    local src_dir="$1"
    local patch_dir="$2"

    if [[ ! -d "$patch_dir" ]]; then
        log INFO "PATCH No patches to apply in $patch_dir"
        return
    fi

    for patch in "$patch_dir"/*.patch; do
        [[ -f "$patch" ]] || continue
        log INFO "PATCH Applying $(basename "$patch")"
        patch -d "$src_dir" -p1 < "$patch"
    done
}

# Build isolado de pacote
build_package() {
    local pkg="$1"
    local destdir="${2:-/}"
    local no_install="${3:-0}"
    local cflags="${4:-$CFLAGS}"
    local ldflags="${5:-$LDFLAGS}"

    log INFO "BUILD Starting build for $pkg"

    # Resolver dependências obrigatórias
    resolve_deps "$pkg"

    local src="$WORKDIR/src/$pkg"
    local build="$WORKDIR/build/$pkg"

    ensure_dir "$src"
    ensure_dir "$build"

    # Detectar arquivo de origem
    local archive
    archive=$(find "$SYNC_DIR/$pkg" -type f -name "*.tar*" -o -name "*.zip" | head -n 1)
    [[ -f "$archive" ]] || die "BUILD Source archive not found for $pkg"

    # Descompactar
    extract_source "$archive" "$src"

    # Aplicar patches
    apply_patches "$src" "$WORKDIR/patches/$pkg"

    # Hooks pre-build
    if [[ -x "$PLUS_ROOT/hooks/pre-build.sh" ]]; then
        "$PLUS_ROOT/hooks/pre-build.sh" "$pkg"
    fi

    # Compilação
    log INFO "BUILD Compiling $pkg with CFLAGS='$cflags' LDFLAGS='$ldflags'"
    (cd "$src" && make CFLAGS="$cflags" LDFLAGS="$ldflags")

    # Hooks post-build
    if [[ -x "$PLUS_ROOT/hooks/post-build.sh" ]]; then
        "$PLUS_ROOT/hooks/post-build.sh" "$pkg"
    fi

    # Instalação opcional
    if [[ "$no_install" -eq 0 ]]; then
        log INFO "INSTALL Installing $pkg to $destdir"
        (cd "$src" && fakeroot make install DESTDIR="$destdir")
    fi

    log INFO "BUILD Completed for $pkg"
}
# ===== Funções de instalação =====
install_package() {
    local pkg="$1"
    local no_install="${2:-0}"
    local cflags="${3:-$CFLAGS}"
    local ldflags="${4:-$LDFLAGS}"

    log INFO "INSTALL Installing $pkg"
    build_package "$pkg" "/" "$no_install" "$cflags" "$ldflags"

    # Atualizar registro de pacotes
    ensure_dir "$PLUS_ROOT/var/db"
    echo "$(date +%F_%T) $pkg" >> "$PLUS_ROOT/var/db/installed.packages"
}

# ===== Funções de remoção =====
remove_package() {
    local pkg="$1"
    local force="${2:-0}"
    local undo="${3:-0}"

    log INFO "REMOVE Removing $pkg"

    # Verificar dependências
    local dependents
    dependents=$(grep -R "$pkg" "$PLUS_ROOT/var/db/installed.packages" || true)
    if [[ -n "$dependents" && "$force" -ne 1 ]]; then
        log INFO "REMOVE Package $pkg is required by other packages. Use --force to override."
        return
    fi

    # Remover arquivos instalados
    local install_dir="$WORKDIR/build/$pkg"
    if [[ -d "$install_dir" ]]; then
        if [[ "$undo" -eq 1 ]]; then
            log INFO "REMOVE Undoing installation of $pkg"
            (cd "$install_dir" && make uninstall || true)
        else
            log INFO "REMOVE Removing files of $pkg"
            rm -rf "$install_dir"
        fi
    fi

    # Remover registro de pacotes
    if [[ -f "$PLUS_ROOT/var/db/installed.packages" ]]; then
        grep -v "^.* $pkg\$" "$PLUS_ROOT/var/db/installed.packages" > "$PLUS_ROOT/var/db/tmp.packages"
        mv "$PLUS_ROOT/var/db/tmp.packages" "$PLUS_ROOT/var/db/installed.packages"
    fi

    log INFO "REMOVE Completed for $pkg"

    # Detectar órfãos
    detect_orphans
}

# ===== Detectar pacotes órfãos =====
detect_orphans() {
    log INFO "ORPHANS Checking for orphan packages"
    local installed orphan
    installed=$(awk '{print $2}' "$PLUS_ROOT/var/db/installed.packages" || true)
    for pkg in $installed; do
        local used
        used=$(grep -R "$pkg" "$PLUS_ROOT/var/db/installed.packages" || true)
        if [[ -z "$used" ]]; then
            log INFO "ORPHAN Found orphan package: $pkg"
        fi
    done
}

# ===== Funções de upgrade =====
upgrade_package() {
    local pkg="$1"
    local force="${2:-0}"
    local no_install="${3:-0}"
    local cflags="${4:-$CFLAGS}"
    local ldflags="${5:-$LDFLAGS}"

    log INFO "UPGRADE Upgrading $pkg"

    # Determinar versão instalada
    local installed_ver
    installed_ver=$(grep " $pkg\$" "$PLUS_ROOT/var/db/installed.packages" | tail -n1 | awk '{print $1}' || true)

    # Aqui você pode adicionar lógica para verificar versão remota
    # Para simplificação, sempre faz build
    build_package "$pkg" "/" "$no_install" "$cflags" "$ldflags"

    # Atualizar registro
    ensure_dir "$PLUS_ROOT/var/db"
    echo "$(date +%F_%T) $pkg" >> "$PLUS_ROOT/var/db/installed.packages"

    log INFO "UPGRADE Completed for $pkg"
}

# Upgrade de todos pacotes
upgrade_all() {
    log INFO "UPGRADE Starting system upgrade"
    local installed
    installed=$(awk '{print $2}' "$PLUS_ROOT/var/db/installed.packages" | sort -u)
    for pkg in $installed; do
        upgrade_package "$pkg"
    done
    log INFO "UPGRADE System upgrade completed"
  }
# ===== Funções SHA256 =====
sha256_check() {
    local file="$1"
    local sum_file="$WORKDIR/sha256/$(basename "$file").sha256"

    if [[ ! -f "$file" ]]; then
        die "SHA256 Check failed: $file does not exist"
    fi

    if [[ -f "$sum_file" ]]; then
        local expected actual
        expected=$(cut -d ' ' -f1 "$sum_file")
        actual=$(sha256sum "$file" | awk '{print $1}')
        if [[ "$expected" != "$actual" ]]; then
            die "SHA256 mismatch for $file"
        else
            log INFO "SHA256 Verified for $file"
        fi
    else
        # Criar SHA256
        sha256sum "$file" > "$sum_file"
        log INFO "SHA256 Generated for $file"
    fi
}

# ===== Hooks =====
run_hook() {
    local hook_type="$1"
    local action="$2"  # pkg
    local hook_file="$PLUS_ROOT/hooks/${hook_type}.sh"
    if [[ -x "$hook_file" ]]; then
        log INFO "HOOK Running $hook_type for $action"
        "$hook_file" "$action"
    fi
}

# ===== Limpeza =====
clean_workdir() {
    log INFO "CLEAN Cleaning workdir $WORKDIR"
    rm -rf "$WORKDIR/src" "$WORKDIR/build" "$WORKDIR/sha256"
    mkdir -p "$WORKDIR/src" "$WORKDIR/build" "$WORKDIR/sha256"
}

clean_sync() {
    log INFO "CLEAN Cleaning sync directory $SYNC_DIR"
    rm -rf "$SYNC_DIR"/*
    ensure_dir "$SYNC_DIR"
}

clean_logs() {
    log INFO "CLEAN Cleaning logs directory $LOG_DIR"
    rm -rf "$LOG_DIR"/*
    ensure_dir "$LOG_DIR"
}

# Limpeza total
clean_all() {
    clean_workdir
    clean_sync
    clean_logs
    log INFO "CLEAN All directories cleaned"
}

# ===== Atualização da CLI principal =====
main() {
    local cmd="${1:-help}"
    shift || true
    case "$cmd" in
        install) install_package "$@" ;;
        remove) remove_package "$@" ;;
        upgrade)
            if [[ "${1:-}" == "all" ]]; then
                upgrade_all
            else
                upgrade_package "$@"
            fi
            ;;
        build) build_package "$@" ;;
        sync)
            if [[ "${1:-}" == "all" ]]; then
                sync_all
            else
                sync_package "$@"  # espera pkg url [branch]
            fi
            ;;
        clean) clean_all ;;
        help|*) show_help ;;
    esac
}

# ===== Executar CLI =====
main "$@"
      
