#!/bin/bash

# =============================================================================
# TANGO VARIABLE SYSTEM IMPLEMENTATION
# =============================================================================
# Implémentation complète du système de variables déclaratives de Tango
# avec ordre de priorité, syntaxes spéciales et gestion des chemins
# =============================================================================

# Variables globales pour le système
declare -A TANGO_VARS=()           # Stockage des variables
declare -A TANGO_VAR_SOURCES=()    # Source de chaque variable
declare -a TANGO_ENV_FILES=()      # Liste des fichiers d'environnement
declare -a TANGO_PATH_VARS=()      # Variables de type PATH

# Niveaux de priorité (plus le nombre est bas, plus la priorité est haute)
export PRIORITY_SHELL_ENV=1
export PRIORITY_COMMAND_LINE=2
export PRIORITY_USER_ENV=3
export PRIORITY_MODULE_ENV=4
export PRIORITY_CONTEXT_ENV=5
export PRIORITY_DEFAULT_ENV=6
export PRIORITY_RUNTIME_ENV=7

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

# Fonction de logging
tango_log() {
    local level="$1"
    local message="$2"
    echo "[TANGO-VAR-$level] $message" >&2
}

# Vérifier si une variable existe
var_exists() {
    local var_name="$1"
    [[ -n "${TANGO_VARS[$var_name]:-}" ]]
}

# Obtenir la priorité d'une variable
get_var_priority() {
    local var_name="$1"
    local source="${TANGO_VAR_SOURCES[$var_name]:-}"
    
    case "$source" in
        "shell_env") echo $PRIORITY_SHELL_ENV ;;
        "command_line") echo $PRIORITY_COMMAND_LINE ;;
        "user_env") echo $PRIORITY_USER_ENV ;;
        "module_env") echo $PRIORITY_MODULE_ENV ;;
        "context_env") echo $PRIORITY_CONTEXT_ENV ;;
        "default_env") echo $PRIORITY_DEFAULT_ENV ;;
        "runtime_env") echo $PRIORITY_RUNTIME_ENV ;;
        *) echo 999 ;;
    esac
}

# =============================================================================
# GESTION DES VARIABLES D'ENVIRONNEMENT SHELL
# =============================================================================

# Capturer les variables d'environnement shell existantes
capture_shell_env() {
    tango_log "INFO" "Capturing shell environment variables..."
    
    # Capturer toutes les variables exportées
    while IFS='=' read -r var_name var_value; do
        if [[ -n "$var_name" && "$var_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
            TANGO_VARS["$var_name"]="$var_value"
            TANGO_VAR_SOURCES["$var_name"]="shell_env"
        fi
    done < <(env)
}

# =============================================================================
# PARSEUR DE FICHIERS D'ENVIRONNEMENT
# =============================================================================

# Résoudre les références de variables {{var}} et {{$var}}
resolve_variable_references() {
    local value="$1"
    local temp_value="$value"
    
    # Résoudre les références internes {{var}}
    while [[ "$temp_value" =~ \{\{([^}$]+)\}\} ]]; do
        local ref_var="${BASH_REMATCH[1]}"
        local ref_value="${TANGO_VARS[$ref_var]:-}"
        temp_value="${temp_value/\{\{$ref_var\}\}/$ref_value}"
    done
    
    # Résoudre les références d'environnement {{$var}}
    while [[ "$temp_value" =~ \{\{\$([^}]+)\}\} ]]; do
        local env_var="${BASH_REMATCH[1]}"
        local env_value="${!env_var:-}"
        temp_value="${temp_value/\{\{\$$env_var\}\}/$env_value}"
    done
    
    echo "$temp_value"
}

# Parser une ligne d'environnement
parse_env_line() {
    local line="$1"
    local source="$2"
    local priority="$3"
    
    # Ignorer les commentaires et lignes vides
    [[ "$line" =~ ^[[:space:]]*# ]] && return 0
    [[ "$line" =~ ^[[:space:]]*$ ]] && return 0
    
    # Détecter le type d'assignation
    local var_name var_value operator
    
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)([\+\?\!]?)=(.*)$ ]]; then
        var_name="${BASH_REMATCH[1]}"
        operator="${BASH_REMATCH[2]}"
        var_value="${BASH_REMATCH[3]}"
        
        # Résoudre les références de variables
        var_value=$(resolve_variable_references "$var_value")
        
        # Traiter selon l'opérateur
        case "$operator" in
            "+")  # Assignation cumulative +=
                handle_cumulative_assignment "$var_name" "$var_value" "$source" "$priority"
                ;;
            "?")  # Assignation par défaut ?=
                handle_default_assignment "$var_name" "$var_value" "$source" "$priority"
                ;;
            "!")  # Assignation de remplacement !=
                handle_replacement_assignment "$var_name" "$var_value" "$source" "$priority"
                ;;
            "")   # Assignation normale =
                handle_normal_assignment "$var_name" "$var_value" "$source" "$priority"
                ;;
        esac
    fi
}

# Assignation normale
handle_normal_assignment() {
    local var_name="$1"
    local var_value="$2"
    local source="$3"
    local priority="$4"
    
    local current_priority=$(get_var_priority "$var_name")
    
    # Assigner seulement si la priorité est plus haute ou égale
    if [[ $priority -le $current_priority ]]; then
        TANGO_VARS["$var_name"]="$var_value"
        TANGO_VAR_SOURCES["$var_name"]="$source"
        tango_log "DEBUG" "Set $var_name=$var_value (source: $source)"
    fi
}

# Assignation cumulative +=
handle_cumulative_assignment() {
    local var_name="$1"
    local var_value="$2"
    local source="$3"
    local priority="$4"
    
    local current_value="${TANGO_VARS[$var_name]:-}"
    local new_value
    
    if [[ -n "$current_value" ]]; then
        new_value="$current_value $var_value"
    else
        new_value="$var_value"
    fi
    
    TANGO_VARS["$var_name"]="$new_value"
    TANGO_VAR_SOURCES["$var_name"]="$source"
    tango_log "DEBUG" "Cumulative $var_name+=$var_value -> $new_value (source: $source)"
}

# Assignation par défaut ?=
handle_default_assignment() {
    local var_name="$1"
    local var_value="$2"
    local source="$3"
    local priority="$4"
    
    # Assigner seulement si la variable n'existe pas
    if ! var_exists "$var_name"; then
        TANGO_VARS["$var_name"]="$var_value"
        TANGO_VAR_SOURCES["$var_name"]="$source"
        tango_log "DEBUG" "Default $var_name?=$var_value (source: $source)"
    fi
}

# Assignation de remplacement !=
handle_replacement_assignment() {
    local var_name="$1"
    local var_value="$2"
    local source="$3"
    local priority="$4"
    
    local current_value="${TANGO_VARS[$var_name]:-}"
    
    # Remplacer seulement si la valeur actuelle n'est pas vide
    if [[ -n "$current_value" ]]; then
        TANGO_VARS["$var_name"]="$var_value"
        TANGO_VAR_SOURCES["$var_name"]="$source"
        tango_log "DEBUG" "Replace $var_name!=$var_value (source: $source)"
    fi
}

# =============================================================================
# CHARGEMENT DES FICHIERS D'ENVIRONNEMENT
# =============================================================================

# Charger un fichier d'environnement
load_env_file() {
    local file_path="$1"
    local source="$2"
    local priority="$3"
    
    if [[ ! -f "$file_path" ]]; then
        tango_log "WARN" "Environment file not found: $file_path"
        return 1
    fi
    
    tango_log "INFO" "Loading environment file: $file_path (source: $source)"
    
    while IFS= read -r line; do
        parse_env_line "$line" "$source" "$priority"
    done < "$file_path"
}

# =============================================================================
# GESTION DES VARIABLES DE LIGNE DE COMMANDE
# =============================================================================

# Parser les arguments de ligne de commande
parse_command_line() {
    local args=("$@")
    
    for ((i=0; i<${#args[@]}; i++)); do
        local arg="${args[i]}"
        
        case "$arg" in
            --domain=*)
                local domain="${arg#--domain=}"
                handle_normal_assignment "TANGO_DOMAIN" "$domain" "command_line" "$PRIORITY_COMMAND_LINE"
                ;;
            --domain)
                ((i++))
                local domain="${args[i]:-}"
                handle_normal_assignment "TANGO_DOMAIN" "$domain" "command_line" "$PRIORITY_COMMAND_LINE"
                ;;
            --module=*)
                local module="${arg#--module=}"
                handle_cumulative_assignment "TANGO_SERVICES_MODULES" "$module" "command_line" "$PRIORITY_COMMAND_LINE"
                ;;
            --module)
                ((i++))
                local module="${args[i]:-}"
                handle_cumulative_assignment "TANGO_SERVICES_MODULES" "$module" "command_line" "$PRIORITY_COMMAND_LINE"
                ;;
            --plugin=*)
                local plugin="${arg#--plugin=}"
                handle_cumulative_assignment "TANGO_PLUGINS" "$plugin" "command_line" "$PRIORITY_COMMAND_LINE"
                ;;
            --plugin)
                ((i++))
                local plugin="${args[i]:-}"
                handle_cumulative_assignment "TANGO_PLUGINS" "$plugin" "command_line" "$PRIORITY_COMMAND_LINE"
                ;;
            --port=*)
                local port="${arg#--port=}"
                handle_cumulative_assignment "TANGO_PORTS" "$port" "command_line" "$PRIORITY_COMMAND_LINE"
                ;;
            --port)
                ((i++))
                local port="${args[i]:-}"
                handle_cumulative_assignment "TANGO_PORTS" "$port" "command_line" "$PRIORITY_COMMAND_LINE"
                ;;
            --freeport)
                handle_normal_assignment "TANGO_FREEPORT" "true" "command_line" "$PRIORITY_COMMAND_LINE"
                ;;
            --env=*)
                local env_file="${arg#--env=}"
                TANGO_ENV_FILES+=("$env_file")
                ;;
            --env)
                ((i++))
                local env_file="${args[i]:-}"
                TANGO_ENV_FILES+=("$env_file")
                ;;
        esac
    done
}

# =============================================================================
# GESTION DES CHEMINS
# =============================================================================

# Identifier les variables de type PATH
identify_path_variables() {
    for var_name in "${!TANGO_VARS[@]}"; do
        if [[ "$var_name" =~ _PATH$ ]]; then
            TANGO_PATH_VARS+=("$var_name")
        fi
    done
}

# Résoudre un chemin selon les règles Tango
resolve_path() {
    local var_name="$1"
    local var_value="${TANGO_VARS[$var_name]:-}"
    local parent_path=""
    
    # Déterminer le chemin parent
    local parent_var="${var_name%_PATH}_PARENT_PATH"
    if var_exists "$parent_var"; then
        parent_path="${TANGO_VARS[$parent_var]}"
    else
        parent_path="${TANGO_VARS[TANGO_CTX_WORK_ROOT]:-$(pwd)/workspace/tango}"
    fi
    
    local resolved_path
    
    if [[ -z "$var_value" ]]; then
        # Valeur vide : utiliser le nom de la variable en minuscules
        local default_name=$(echo "${var_name,,}" | sed 's/_path$//')
        resolved_path="$parent_path/$default_name"
    elif [[ "$var_value" =~ ^/ ]]; then
        # Chemin absolu
        resolved_path="$var_value"
        # Vérifier que le chemin existe
        if [[ ! -d "$resolved_path" ]]; then
            tango_log "ERROR" "Absolute path does not exist: $resolved_path"
            return 1
        fi
    else
        # Chemin relatif
        resolved_path="$parent_path/$var_value"
        # Créer le répertoire s'il n'existe pas
        if [[ ! -d "$resolved_path" ]]; then
            mkdir -p "$resolved_path"
            tango_log "INFO" "Created directory: $resolved_path"
        fi
    fi
    
    # Normaliser le chemin
    resolved_path=$(readlink -m "$resolved_path")
    TANGO_VARS["$var_name"]="$resolved_path"
    
    tango_log "DEBUG" "Resolved path $var_name: $resolved_path"
}

# Traiter toutes les variables de type PATH
process_path_variables() {
    tango_log "INFO" "Processing PATH variables..."
    
    identify_path_variables
    
    for var_name in "${TANGO_PATH_VARS[@]}"; do
        resolve_path "$var_name"
    done
}

# =============================================================================
# GÉNÉRATION DES FICHIERS D'ENVIRONNEMENT
# =============================================================================

# Générer le fichier d'environnement pour docker-compose
generate_compose_env() {
    local output_file="$1"
    
    tango_log "INFO" "Generating docker-compose environment file: $output_file"
    
    {
        echo "# Generated docker-compose environment file"
        echo "# Generated on $(date)"
        echo ""
        
        for var_name in $(printf '%s\n' "${!TANGO_VARS[@]}" | sort); do
            local var_value="${TANGO_VARS[$var_name]}"
            echo "$var_name=$var_value"
        done
    } > "$output_file"
}

# Générer le fichier d'environnement pour bash
generate_bash_env() {
    local output_file="$1"
    
    tango_log "INFO" "Generating bash environment file: $output_file"
    
    {
        echo "#!/bin/bash"
        echo "# Generated bash environment file"
        echo "# Generated on $(date)"
        echo ""
        
        for var_name in $(printf '%s\n' "${!TANGO_VARS[@]}" | sort); do
            local var_value="${TANGO_VARS[$var_name]}"
            # Échapper les caractères spéciaux pour bash
            var_value=$(printf '%q' "$var_value")
            echo "export $var_name=$var_value"
        done
    } > "$output_file"
    
    chmod +x "$output_file"
}

# =============================================================================
# FONCTIONS PRINCIPALES
# =============================================================================

# Initialiser le système de variables
init_variable_system() {
    tango_log "INFO" "Initializing Tango variable system..."
    
    # Définir les variables par défaut
    TANGO_VARS["TANGO_CTX_NAME"]="${TANGO_CTX_NAME:-tango}"
    TANGO_VARS["TANGO_CTX_WORK_ROOT"]="${TANGO_CTX_WORK_ROOT:-$(pwd)/workspace/tango}"
    TANGO_VARS["CTX_DATA_PATH"]="${CTX_DATA_PATH:-data}"
    TANGO_VARS["WORKING_DIR"]="$(pwd)"
    TANGO_VARS["TANGO_DOMAIN"]="${TANGO_DOMAIN:-.*}"
    
    # Marquer comme variables par défaut
    for var_name in TANGO_CTX_NAME TANGO_CTX_WORK_ROOT CTX_DATA_PATH WORKING_DIR TANGO_DOMAIN; do
        TANGO_VAR_SOURCES["$var_name"]="default_env"
    done
}

# Charger toutes les variables selon l'ordre de priorité
load_all_variables() {
    local args=("$@")
    
    tango_log "INFO" "Loading variables with priority order..."
    
    # 1. Capturer les variables d'environnement shell (priorité la plus haute)
    capture_shell_env
    
    # 2. Parser les arguments de ligne de commande
    parse_command_line "${args[@]}"
    
    # 3. Charger les fichiers d'environnement dans l'ordre de priorité
    # Fichiers d'environnement utilisateur
    for env_file in "${TANGO_ENV_FILES[@]}"; do
        load_env_file "$env_file" "user_env" "$PRIORITY_USER_ENV"
    done
    

    # 4. Traiter les variables de type PATH
    process_path_variables
}

# Afficher le résumé des variables
show_variables_summary() {
    echo ""
    echo "=== TANGO VARIABLES SUMMARY ==="
    echo ""
    
    for var_name in $(printf '%s\n' "${!TANGO_VARS[@]}" | sort); do
        local var_value="${TANGO_VARS[$var_name]}"
        local var_source="${TANGO_VAR_SOURCES[$var_name]}"
        printf "%-30s = %-50s [%s]\n" "$var_name" "$var_value" "$var_source"
    done
    
    echo ""
    echo "=== PATH VARIABLES ==="
    echo ""
    
    for var_name in "${TANGO_PATH_VARS[@]}"; do
        local var_value="${TANGO_VARS[$var_name]}"
        printf "%-30s = %s\n" "$var_name" "$var_value"
    done
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

# Fonction principale pour traiter toutes les variables
process_tango_variables() {
    local args=("$@")
    local context_name="${TANGO_CTX_NAME:-tango}"
    
    # Initialiser le système
    init_variable_system
    
    # Charger toutes les variables
    load_all_variables "${args[@]}"
    
    # Générer les fichiers d'environnement
    generate_compose_env "generated.${context_name}.compose.env"
    generate_bash_env "generated.${context_name}.bash.env"
    
    # Afficher le résumé si demandé
    if [[ "${TANGO_VARS[TANGO_VERBOSE]:-}" == "true" ]]; then
        show_variables_summary
    fi
    
    tango_log "INFO" "Variable processing completed successfully"
}
