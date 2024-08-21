#!/usr/bin/env bash

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
@test "__solve_dynamic_variables_1" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
C={{B}}
B={{A}}
A=10
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'C={{B}}
B={{A}}
A=10'
	
}


@test "__solve_dynamic_variables_2" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
A=10
A=20
A=30
B={{A}}
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'A=10
A=20
A=30
B=30'

}



@test "__solve_dynamic_variables_3" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
N=10
The number is {{N}}
# FOO={{N}}
A=1
B={{A}}
C={{B}}
X={{Y}}
Y=4
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'N=10
The number is 10
# FOO=10
A=1
B=1
C=1
X={{Y}}
Y=4'

}


@test "__solve_dynamic_variables_4" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
A=1
C={{B}}
B={{A}}
X={{Y}}
Y=4
X={{Y}}
F={{J}}
J=8
F={{J}}
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'A=1
C={{B}}
B=1
X={{Y}}
Y=4
X=4
F={{J}}
J=8
F=8'

}


@test "__solve_dynamic_variables_5" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
A=1
B={{A}}
E={{D}}
F={{H}}
H={{K}}
K={{I}}
I=30
D={{B}}
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'A=1
B=1
E={{D}}
F={{H}}
H={{K}}
K={{I}}
I=30
D=1'

}




@test "__solve_dynamic_variables_6" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
A=1
B={{A}}
E={{D}}
F={{H}}
H={{K}}
K={{I}}
S={{B}}
I=30
D={{B}}
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	
	assert_output 'A=1
B=1
E={{D}}
F={{H}}
H={{K}}
K={{I}}
S=1
I=30
D=1'

}




@test __solve_dynamic_variables_7 {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
A=20
D={{B}}
B={{VAL}}
C={{B}}
#A=10
VAL={{A}}
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	
	assert_output 'A=20
D={{B}}
B={{VAL}}
C={{VAL}}
#A=10
VAL=20'
}




@test __solve_dynamic_variables_8 {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
D={{A}}
A=10
C={{A}}
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	
	assert_output 'D={{A}}
A=10
C=10'
}


@test __solve_dynamic_variables_9 {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER MODULE
X=40
# --- LAYER CONTEXT
D={{X}}
A=10
B={{A}}
C={{B}}
A=20
# --- LAYER USER
A=50
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER MODULE
X=40
# --- LAYER CONTEXT
D=40
A=10
B=10
C=10
A=20
# --- LAYER USER
A=50'

}


@test "__solve_dynamic_variables_10" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER INIT
N=10
# --- LAYER DEFAULT
The number is {{N}}
# FOO={{N}}
A=1
B={{A}}
C={{B}}
X={{Y}}
Y=4
X={{Y}}
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER INIT
N=10
# --- LAYER DEFAULT
The number is 10
# FOO=10
A=1
B=1
C=1
X={{Y}}
Y=4
X=4'

}



@test "__solve_dynamic_variables_10B" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER INIT
N=10
# --- LAYER DEFAULT
The number is {{N}}
# FOO={{N}}
A=1
B={{A}}
C={{B}}
X={{Y}}
Y=4
X={{Y}}
# --- LAYER USER
Y=20
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER INIT
N=10
# --- LAYER DEFAULT
The number is 10
# FOO=10
A=1
B=1
C=1
X=20
Y=4
X=4
# --- LAYER USER
Y=20'

}


@test "__solve_dynamic_variables_11" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER MODULE
X=40
# --- LAYER CONTEXT
D={{X}}
B={{A}}
A=10
C={{W}}
# --- LAYER USER
W=50
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER MODULE
X=40
# --- LAYER CONTEXT
D=40
B={{A}}
A=10
C=50
# --- LAYER USER
W=50'

}




@test "__solve_dynamic_variables_12" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
E={{X}}
A={{E}}
B={{A}}
D={{B}}
X=1
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'E={{X}}
A={{X}}
B={{X}}
D={{X}}
X=1'

}

@test "__solve_dynamic_variables_13" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
A=10
B={{A}}
C={{B}}
A=20
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'A=10
B=10
C=10
A=20'

}

@test "__solve_dynamic_variables_13B" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
D={{X}}
A=10
B={{A}}
C={{B}}
A=20
J={{K}}
K=10
# --- LAYER CONTEXT
X=100
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
D=100
A=10
B=10
C=10
A=20
J={{K}}
K=10
# --- LAYER CONTEXT
X=100'

}




@test "__solve_dynamic_variables_14" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
A=20
D={{B}}
B={{VAL}}
C={{B}}
#A=10
VAL={{A}}
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'A=20
D={{B}}
B={{VAL}}
C={{VAL}}
#A=10
VAL=20'

}


#VAL=20 {{D}} {{B}} {{B}} {{E}}
@test "__solve_dynamic_variables_15" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
A=20
B=5
D={{B}}
E={{A}} {{D}}
C={{VAL}}
#A=10
VAL={{E}}
Y={{VAL}}
Z={{E}}
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'A=20
B=5
D=5
E=20 5
C={{VAL}}
#A=10
VAL=20 5
Y=20 5
Z=20 5'
}



@test "__solve_dynamic_variables_16" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
A=20
B=5
D={{B}}
E={{A}} {{D}}
C={{VAL}}
#A=10
VAL=20 {{D}} {{B}} {{B}} {{E}}
VAL={{E}}
Y={{VAL}}
Z={{E}}
EOL
)> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'A=20
B=5
D=5
E=20 5
C={{VAL}}
#A=10
VAL=20 5 5 5 20 5
VAL=20 5
Y=20 5
Z=20 5'

}






@test "__solve_dynamic_variables_20" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
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
)>> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'A=1
B= 2
B= 2 4
C=
C=4
C=4
D=10
X=10'


}




@test "__solve_dynamic_variables_21" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
A=1
A!=2
B={{A}}
C=
C!=2
D={{C}}
EOL
)>> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'A=1
A=2
B=2
C=
C=
D='

}


@test "__solve_dynamic_variables_22" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
A=1
A!=2
B={{A}}
B!=0
C!=2
D={{B}} {{C}}
EOL
)>> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'A=1
A=2
B=2
B=0
C=
D=0 '

}




@test "__solve_dynamic_variables_23" {

export B=100
export C="1000"
export D=200

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
A=1
B+= 2
B+=4
C?=4
C?=5
D=
X={{D}}
EOL
)>> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'A=1
B=100  2
B=100  2 4
C=1000
C=1000
D=
X='

}




@test "__solve_dynamic_variables_24" {

export A=10
export C=100
export E=ON

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
A=1
A!=2
B={{A}}
C!=2
D={{C}}
E!={{C}}
F!={{C}}
EOL
)>> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'A=1
A=2
B=2
C=2
D=2
E=2
F='
}




@test "__solve_dynamic_variables_25" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
A=1
B+= 2
B+=4
C=
C?=4
C?=5
D?=10
X={{D}}
EOL
)>> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
A=1
B= 2
B= 2 4
C=
C=4
C=4
D=10
X=10'

}


@test "__solve_dynamic_variables_26" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
D={{X}}
A=10
B={{A}}
C={{B}}
A=20
X=100
EOL
)>> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
D={{X}}
A=10
B=10
C=10
A=20
X=100'

}



@test "__solve_dynamic_variables_27" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
D={{X}}
A=10
B={{A}}
C={{B}}
A=20
J={{K}}
K=10
# --- LAYER CONTEXT
X=100
EOL
)>> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
D=100
A=10
B=10
C=10
A=20
J={{K}}
K=10
# --- LAYER CONTEXT
X=100'
}

@test "__solve_dynamic_variables_28" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
D={{X}}
A=10
B={{A}}
C={{B}}
A=20
J={{K}}
K=10
# --- LAYER CONTEXT
X=100
K=20
EOL
)>> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
D=100
A=10
B=10
C=10
A=20
J=20
K=10
# --- LAYER CONTEXT
X=100
K=20'

}

@test "__solve_dynamic_variables_29" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
A=20
D={{B}}
B={{VAL}}
C={{B}}
#A=10
VAL?={{A}}
EOL
)>> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'A=20
D={{B}}
B={{VAL}}
C={{VAL}}
#A=10
VAL=20'

}



@test "__solve_dynamic_variables_30" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
B={{A}}
E={{D}}
F={{H}}
A=20
H={{K}}
K={{I}}
I=30
C=10
D={{B}}
W={{Y}}
EOL
)>> "${ENV_FILE}"

	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'B={{A}}
E={{D}}
F={{H}}
A=20
H={{K}}
K={{I}}
I=30
C=10
D={{A}}
W={{Y}}'

}



@test "__solve_dynamic_variables_31" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
B={{A}}
E={{D}} {{D}}
# --- LAYER CONTEXT
F={{H}}
A=20
J={{K}}
K=30
# --- LAYER DEFAULT
D={{B}}
W={{Y}}
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
B=20
E=20 20
# --- LAYER CONTEXT
F={{H}}
A=20
J={{K}}
K=30
# --- LAYER DEFAULT
D=20
W={{Y}}'

}




@test "__solve_dynamic_variables_32" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
B={{A}}
E={{D}}
J=32
# --- LAYER CONTEXT
D=10
E=3
# --- LAYER DEFAULT
C={{J}} {{D}}
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
B={{A}}
E=10
J=32
# --- LAYER CONTEXT
D=10
E=3
# --- LAYER DEFAULT
C=32 10'

}



@test "__solve_dynamic_variables_33" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
A=50
# --- LAYER CONTEXT
D={{X}}
A=10
B={{A}}
C={{B}}
A=20
# --- LAYER MODULE
X=40
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
A=50
# --- LAYER CONTEXT
D=40
A=10
B=10
C=10
A=20
# --- LAYER MODULE
X=40'

}



@test "__solve_dynamic_variables_34" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
A=20
# --- LAYER CONTEXT
B={{VAL}}
# --- LAYER MODULE
A=10
VAL?={{A}}
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
A=20
# --- LAYER CONTEXT
B=10
# --- LAYER MODULE
A=10
VAL=10'

}

@test "__solve_dynamic_variables_35" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
A=20
# --- LAYER CONTEXT
B={{A}}
# --- LAYER MODULE
A?=10
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
A=20
# --- LAYER CONTEXT
B=20
# --- LAYER MODULE
A=20'

}


@test "__solve_dynamic_variables_36" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
B={{A}}
A=20
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
B={{A}}
A=20'

}


@test "__solve_dynamic_variables_37" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
C=30
# --- LAYER CONTEXT
B={{A}}
A+=20 {{C}}
# --- LAYER MODULE
A+=10
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
C=30
# --- LAYER CONTEXT
B=20 30 10
A=20 30
# --- LAYER MODULE
A=20 30 10'

}



@test "__solve_dynamic_variables_38" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER CONTEXT
VAL?=value1
L+={{SWITCH}}
A=ON
VAL=value2
# --- LAYER MODULE
SWITCH={{A}}
SWITCH!={{VAL}}
L+=10
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER CONTEXT
VAL=value1
L=value2
A=ON
VAL=value2
# --- LAYER MODULE
SWITCH=ON
SWITCH=value2
L=value2 10'

}


@test "__solve_dynamic_variables_39" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
A=ON
B=1
# --- LAYER CONTEXT
B?=1
# --- LAYER MODULE
C={{A}}
C!={{B}}
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
A=ON
B=1
# --- LAYER CONTEXT
B=1
# --- LAYER MODULE
C=ON
C=1'

}


@test "__solve_dynamic_variables_40" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
D={{X}}
# --- LAYER MODULE
D={{X}}
A=10
B={{A}}
C={{B}}
A=20
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'D={{X}}
# --- LAYER MODULE
D={{X}}
A=10
B=10
C=10
A=20'

}


@test "__solve_dynamic_variables_41" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
A=20
# --- LAYER CONTEXT
D={{B}}
B={{VAL}}
C={{B}}
# --- LAYER MODULE
A=10
VAL?={{A}}
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
A=20
# --- LAYER CONTEXT
D={{B}}
B=10
C=10
# --- LAYER MODULE
A=10
VAL=10'

}


@test "__solve_dynamic_variables_42" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
B={{A}}
# --- LAYER CONTEXT
E={{D}}
F={{H}}
A=20
# --- LAYER MODULE
H={{C}}
C=10
D={{B}}
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
B=20
# --- LAYER CONTEXT
E=20
F=10
A=20
# --- LAYER MODULE
H={{C}}
C=10
D=20'

}


@test "__solve_dynamic_variables_43" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
C=100
# --- LAYER CONTEXT
H={{C}}
C=10
# --- LAYER MODULE
C=1000
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'C=100
# --- LAYER CONTEXT
H=1000
C=10
# --- LAYER MODULE
C=1000'

}



@test "__solve_dynamic_variables_44" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER USER
C=100
C=200
J=12
K={{J}}
W={{X}}
L={{W}}
X=10
# --- LAYER CONTEXT
H={{C}}
C=10
C=20
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER USER
C=100
C=200
J=12
K=12
W={{X}}
L={{X}}
X=10
# --- LAYER CONTEXT
H=200
C=10
C=20'

}

@test "__solve_dynamic_variables_45" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
B={{A}}
C=100
J={{K}}
# --- LAYER CONTEXT
E={{D}}
F={{H}}
A=20
# --- LAYER MODULE
H={{C}}
C=10
D={{B}}
K=20
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output 'B=20
C=100
J=20
# --- LAYER CONTEXT
E=20
F=10
A=20
# --- LAYER MODULE
H=100
C=10
D=20
K=20'

}




@test "__solve_dynamic_variables_46" {

export H=30
	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
# --- LAYER CONTEXT
B={{A}}
B?=100
D={{C}}
D?=200
F={{E}}
F?=300
H?=400
J?=
Y?=500
P=1000
N?=10
# --- LAYER MODULE
P?=100
L?=100
A=20
C=
K=50
J={{K}}
Y=600
N?=20
# --- LAYER USER
P=10
L=10
N?=30
EOL
)>> "${ENV_FILE}"
	
	run __solve_dynamic_variables "${ENV_FILE}"
	assert_output '# --- LAYER CONTEXT
B=20
B=20
D=
D=
F={{E}}
F?=300
H=30
J=
Y=
P=1000
N=10
# --- LAYER MODULE
P=1000
L=1000
A=20
C=
K=50
J=50
Y=600
N=10
# --- LAYER USER
P=10
L=10
N=10'

}







@test "__prepare_env_file_1" {

	# env file
	ENV_FILE="${TEST_TEMP_DIR}/env.env"
	touch "${TEST_TEMP_DIR}/env.env"
	(cat <<'EOL'
A1=10
A2=20
A3={{A4}}
A4=40

L1+=100
L2+={{A3}}
SWITCH={{ON}}
SWITCH!={{B1}}
L3+=300
A4?=41
L1+={{SWITCH}}
A5?=50 {{SWITCH}}

ON=ON
B1={{A1}}
B2=2000
EOL
)> "${ENV_FILE}"

	run __prepare_env_file "${ENV_FILE}"
	run cat "${ENV_FILE}" >/dev/null
	assert_output 'A=10
A=20
A=30
B=30'

}


