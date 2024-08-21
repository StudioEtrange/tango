
bats_load_library 'bats-assert'
bats_load_library 'bats-support'
bats_load_library 'bats-file'


setup() {
	load '../tango_bats_helper.bash'

	TEST_TEMP_DIR="$(temp_make)"


	TEST_FILE_1="${TEST_TEMP_DIR}/test_1"
	(cat <<'EOL'
A=1
B=$HOME
C={{$HOME}}
D={{$UNKNOWN}}
E={{$ti ti}}
G= {{$HOME}} {{$HOME}} {{$HOME}}
H={{$OTHER}}

NOT A VALID VARNAME=10
NOT A VALID VARNAME={{$HOME}}
EOL
)> "${TEST_FILE_1}"




	TEST_FILE_2="${TEST_TEMP_DIR}/test_2"
	cat <(echo -n) ${TEST_FILE_1} <(cat <<'EOL'

F={{A}}
G={{B}}
H={{C}}
I={{D}}
J={{E}}
K={{J}}

L={{W}}
W=10
L={{W}}

M= {{$HOME}} {{$HOME}} {{$HOME}}
N={{M}}

Y={{UNKNOWN}}
NOT CATCHED X=0
U={{X}}
#COMMENT2={{A}}
#COMMENT3={{COMMENT2}}
EOL
)>> "${TEST_FILE_2}"

}

teardown() {
	true
    temp_del "$TEST_TEMP_DIR"
}




# GENERIC -------------------------------------------------------------------
@test "__substitute_env_var_in_file_1" {

	__substitute_env_var_in_file "${TEST_FILE_1}"
	run cat "${TEST_FILE_1}" >/dev/null
	assert_output 'A=1
B=$HOME
C='$HOME'
D={{MISSING_UNKNOWN}}
E={{$ti ti}}
G= '$HOME' '$HOME' '$HOME'
H={{MISSING_OTHER}}

NOT A VALID VARNAME=10
NOT A VALID VARNAME='$HOME
}


@test "__substitute_env_var_in_file_2" {

	export OTHER="test"
	__substitute_env_var_in_file "${TEST_FILE_1}"
	run cat "${TEST_FILE_1}" >/dev/null
	assert_output 'A=1
B=$HOME
C='$HOME'
D={{MISSING_UNKNOWN}}
E={{$ti ti}}
G= '$HOME' '$HOME' '$HOME'
H='$OTHER'

NOT A VALID VARNAME=10
NOT A VALID VARNAME='$HOME
}




@test "__substitute_key_in_file_1" {

	__substitute_env_var_in_file "${TEST_FILE_2}"
	__substitute_key_in_file "${TEST_FILE_2}"
	run cat "${TEST_FILE_2}" >/dev/null
	assert_output 'A=1
B=$HOME
C='$HOME'
D={{MISSING_UNKNOWN}}
E={{$ti ti}}
G= '$HOME' '$HOME' '$HOME'
H={{MISSING_OTHER}}

NOT A VALID VARNAME=10
NOT A VALID VARNAME='$HOME'

F=1
G=$HOME
H='$HOME'
I={{MISSING_UNKNOWN}}
J={{$ti ti}}
K={{$ti ti}}

L={{W}}
W=10
L=10

M= '$HOME' '$HOME' '$HOME'
N= '$HOME' '$HOME' '$HOME'

Y={{UNKNOWN}}
NOT CATCHED X=0
U={{X}}
#COMMENT2=1
#COMMENT3={{COMMENT2}}'

}




@test "__init_env_file_1" {

	GENERATED_ENV_FILE_FOR_BASH="${TEST_TEMP_DIR}/generated.bash.env"
	GENERATED_ENV_FILE_FOR_COMPOSE="${TEST_TEMP_DIR}/generated.compose.env"

	
	# user env file
	TANGO_USER_ENV_FILE="${TEST_TEMP_DIR}/user.env"
	touch "${TANGO_USER_ENV_FILE}"
	(cat <<'EOL'
A=20
F=60
EOL
)> "${TANGO_USER_ENV_FILE}"

	# ctx env file
	TANGO_CTX_ENV_FILE="${TEST_TEMP_DIR}/ctx.env"
	touch "${TANGO_CTX_ENV_FILE}"
	(cat <<'EOL'
B={{A}}
C+=20
D+=10
EOL
)> "${TANGO_CTX_ENV_FILE}"


	# module env file
	TANGO_CTX_MODULES_ROOT="${TEST_TEMP_DIR}"
	TEST_FILE_MOD="${TEST_TEMP_DIR}/mod.env"
	touch "${TEST_FILE_MOD}"
	(cat <<'EOL'
A?=10
F=40
EOL
)> "${TEST_FILE_MOD}"


	# default tango env file
	TANGO_ENV_FILE="${TEST_TEMP_DIR}/tango.env"
	touch "${TANGO_ENV_FILE}"
	(cat <<'EOL'
FOO=BAR
A=30
F=70
F=80
EOL
)> "${TANGO_ENV_FILE}"


	TANGO_SERVICES_MODULES="mod"
	run __init_env_file "${GENERATED_ENV_FILE_FOR_BASH}" "user ctx modules default"
	run cat "${GENERATED_ENV_FILE_FOR_BASH}" >/dev/null

	assert_output '# --- LAYER INIT
C=
D=
# --- LAYER USER
A=20
F=60
# --- LAYER CONTEXT
B={{A}}
C+=20
D+=10
# --- LAYER MODULE_MOD
A?=10
F=40
# --- LAYER DEFAULT
FOO=BAR
#A=30
#F=70
#F=80'

}



@test "__init_env_file_2" {

	GENERATED_ENV_FILE_FOR_BASH="${TEST_TEMP_DIR}/generated.bash.env"
	GENERATED_ENV_FILE_FOR_COMPOSE="${TEST_TEMP_DIR}/generated.compose.env"

	
	# user env file
	TANGO_USER_ENV_FILE="${TEST_TEMP_DIR}/user.env"
	touch "${TANGO_USER_ENV_FILE}"
	(cat <<'EOL'
C=30
EOL
)> "${TANGO_USER_ENV_FILE}"

	# ctx env file
	TANGO_CTX_ENV_FILE="${TEST_TEMP_DIR}/ctx.env"
	touch "${TANGO_CTX_ENV_FILE}"
	(cat <<'EOL'
B={{A}}
A=+20 {{C}}
EOL
)> "${TANGO_CTX_ENV_FILE}"


	# module env file
	TANGO_CTX_MODULES_ROOT="${TEST_TEMP_DIR}"
	TEST_FILE_MOD="${TEST_TEMP_DIR}/mod.env"
	touch "${TEST_FILE_MOD}"
	(cat <<'EOL'
A+=10
EOL
)> "${TEST_FILE_MOD}"


	# default tango env file
	TANGO_ENV_FILE="${TEST_TEMP_DIR}/tango.env"
	touch "${TANGO_ENV_FILE}"
	(cat <<'EOL'
EOL
)> "${TANGO_ENV_FILE}"


	TANGO_SERVICES_MODULES="mod"
	run __init_env_file "${GENERATED_ENV_FILE_FOR_BASH}" "user ctx modules default"
	run cat "${GENERATED_ENV_FILE_FOR_BASH}" >/dev/null

	assert_output '# --- LAYER INIT
# --- LAYER USER
A=20
# --- LAYER CONTEXT
B={{A}}
# --- LAYER MODULE_MOD
A?=10

# --- LAYER DEFAULT
FOO=BAR
#A=30
#F=70
#F=80'

}
















@test "__create_and_load_env_file_1" {

	# TEST explanation

# variables stacked in files to be interpreted
# layer tango
#	FOO=BAR
# layer module
#	A?=10
# layer context
# 	B={{A}}
# layer user
#	A=20

# layer tango
#	FOO=BAR
# layer module
#	A?=10
# layer context
# 	B={{A}}
# layer user
#	A=20


# resulting variables shoud be
#	A=20
#	B=20

	GENERATED_ENV_FILE_FOR_BASH="${TEST_TEMP_DIR}/generated.bash.env"
	GENERATED_ENV_FILE_FOR_COMPOSE="${TEST_TEMP_DIR}/generated.compose.env"

	# default tango env file
	TANGO_ENV_FILE="${TEST_TEMP_DIR}/tango.env"
	touch "${TEST_TEMP_DIR}/tango.env"
	(cat <<'EOL'
FOO=BAR
EOL
)> "${TANGO_ENV_FILE}"

	# ctx env file
	TANGO_CTX_ENV_FILE="${TEST_TEMP_DIR}/ctx.env"
	touch "${TEST_TEMP_DIR}/ctx.env"
	(cat <<'EOL'
B={{A}}
EOL
)> "${TANGO_CTX_ENV_FILE}"

	# user env file
	TANGO_USER_ENV_FILE="${TEST_TEMP_DIR}/user.env"
	touch "${TEST_TEMP_DIR}/user.env"
	(cat <<'EOL'
A=20
EOL
)> "${TANGO_USER_ENV_FILE}"

	# module env file
	TANGO_CTX_MODULES_ROOT="${TEST_TEMP_DIR}"
	TEST_FILE_MOD="${TEST_TEMP_DIR}/mod.env"
	(cat <<'EOL'
A?=10
EOL
)> "${TEST_FILE_MOD}"



	TANGO_SERVICES_MODULES="mod"
	run __create_env_files "bash" "default modules ctx user" "silent"
	

 	run cat "${GENERATED_ENV_FILE_FOR_BASH}" >/dev/null
	assert_output '# ------ STACK 1

FOO="BAR"

A="10"

B="10"

A="20"
# ------ STACK 2

FOO="BAR"

A="20"

B="20"

A="20"'

	__load_env_vars
	

	assert_equal "$FOO" "BAR"
	assert_equal "$A" "20"
	assert_equal "$B" "20"

}


@test "__create_and_load_env_file_2" {


	# TEST explanation
# variables stacked in files to be interpreted
# layer context
# 	B=10
# layer user
# 	C={{B}}
# Layer shell
#	B=20

# layer context
# 	B=10
# layer user
# 	C={{B}}
# Layer shell
#	B=20


# resulting variables shoud be
#	B=20

	GENERATED_ENV_FILE_FOR_BASH="${TEST_TEMP_DIR}/generated.bash.env"
	GENERATED_ENV_FILE_FOR_COMPOSE="${TEST_TEMP_DIR}/generated.compose.env"

	# default tango env file
	TANGO_ENV_FILE="${TEST_TEMP_DIR}/tango.env"
	touch "${TEST_TEMP_DIR}/tango.env"

	# ctx env file
	TANGO_CTX_ENV_FILE="${TEST_TEMP_DIR}/ctx.env"
	touch "${TEST_TEMP_DIR}/ctx.env"
	(cat <<'EOL'
B=10
EOL
)> "${TANGO_CTX_ENV_FILE}"

	# user env file
	TANGO_USER_ENV_FILE="${TEST_TEMP_DIR}/user.env"
	touch "${TEST_TEMP_DIR}/user.env"
		(cat <<'EOL'
C={{B}}
EOL
)> "${TANGO_USER_ENV_FILE}"

	# module env file
	TANGO_CTX_MODULES_ROOT="${TEST_TEMP_DIR}"

	# shell var
	UNKNOW_VAR=50
	B=20
	


	run __create_env_files "bash" "default modules ctx user" "silent"
	
	
	run cat "${GENERATED_ENV_FILE_FOR_BASH}" >/dev/null
	assert_output '# ------ STACK 1

B="10"

C="10"
# ------ STACK 2

B="10"

C="10"'

	__extract_declared_variable_names "$GENERATED_ENV_FILE_FOR_BASH"
	assert_equal "${VARIABLES_LIST}" "B C"

	__update_env_files "" "silent"
	run cat "${GENERATED_ENV_FILE_FOR_BASH}" >/dev/null
	assert_output '# ------ STACK 1

B="10"

C="10"
# ------ STACK 2

B="10"

C="10"
# ------ UPDATE
export B="20"'

	__load_env_vars
	
	assert_equal "$B" "20"
	assert_equal "$C" "20"
	assert_equal "$UNKNOW_VAR" "50"

}




