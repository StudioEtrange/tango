
bats_load_library 'bats-assert'
bats_load_library 'bats-support'
bats_load_library 'bats-file'


setup() {
	load 'tango_bats_helper.bash'

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
	run cat "${TEST_FILE_1}"
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
	run cat "${TEST_FILE_1}"
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
	run cat "${TEST_FILE_2}"
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





@test "__parse_env_file_1" {

	TEST_FILE_3="${TEST_TEMP_DIR}/test_3"
	(cat <<'EOL'
A=1

B+= 2
B+=4

C=
C?=4
C?=5

D?=10
X={{D}}
EOL
)>> "${TEST_FILE_3}"

	__parse_env_file "${TEST_FILE_3}"
	run cat "${TEST_FILE_3}"
	assert_output 'A=1

B= 2
B= 2 4

C=
C=4
C=4

D=10
X=10'

}




@test "__parse_env_file_2" {

	TEST_FILE_4="${TEST_TEMP_DIR}/test_4"
	(cat <<'EOL'
A=1
A!=2

B={{A}}

C=
C!=2
D={{C}}

EOL
)>> "${TEST_FILE_4}"

	__parse_env_file "${TEST_FILE_4}"
	run cat "${TEST_FILE_4}"
	assert_output 'A=1
A=2

B=2

C=
C=
D='

}




@test "__parse_env_file_3" {

export B=100
export C="1000"
export D=200

	TEST_FILE_5="${TEST_TEMP_DIR}/test_5"
	(cat <<'EOL'
A=1

B+= 2
B+=4

C?=4
C?=5

D=
X={{D}}
EOL
)>> "${TEST_FILE_5}"

	__parse_env_file "${TEST_FILE_5}"
	run cat "${TEST_FILE_5}"
	assert_output 'A=1

B=100  2
B=100  2 4

C=1000
C=1000

D=
X='

}




@test "__parse_env_file_4" {

export A=10
export C=100
export E=ON

	TEST_FILE_6="${TEST_TEMP_DIR}/test_6"
	(cat <<'EOL'
A=1
A!=2

B={{A}}

C!=2
D={{C}}

E!={{C}}
F!={{C}}
EOL
)>> "${TEST_FILE_6}"

	__parse_env_file "${TEST_FILE_6}"
	run cat "${TEST_FILE_6}"
	assert_output 'A=1
A=2

B=2

C=2
D=2

E=2
F='
}