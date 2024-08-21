
bats_load_library 'bats-assert'
bats_load_library 'bats-support'
bats_load_library 'bats-file'


setup() {
	load '../tango_bats_helper.bash'

	TEST_TEMP_DIR="$(temp_make)"


	touch "${TEST_TEMP_DIR}/mod.yml"
	touch "${TEST_TEMP_DIR}/mod.scalable"
	TEST_FILE_1="${TEST_TEMP_DIR}/mod.env"
	(cat <<'EOL'
MOD_IMAGE_FIXED_VAR=bash
MOD_VERSION_FIXED_VAR?=latest
EOL
)> "${TEST_FILE_1}"
	TEST_FILE_2="${TEST_TEMP_DIR}/mod.deps"
	(cat <<'EOL'
foo
bar
EOL
)> "${TEST_FILE_2}"


	
	touch "${TEST_TEMP_DIR}/foo.yml"
	touch "${TEST_TEMP_DIR}/foo.scalable"
	TEST_FILE_3="${TEST_TEMP_DIR}/foo.env"
	(cat <<'EOL'
FOO_IMAGE_FIXED_VAR=bash
FOO_VERSION_FIXED_VAR?=latest
EOL
)> "${TEST_FILE_3}"
	TEST_FILE_4="${TEST_TEMP_DIR}/foo.deps"
	(cat <<'EOL'
bar
EOL
)> "${TEST_FILE_4}"
	
	
	touch "${TEST_TEMP_DIR}/bar.yml"
	touch "${TEST_TEMP_DIR}/bar.scalable"
	TEST_FILE_5="${TEST_TEMP_DIR}/bar.env"
	(cat <<'EOL'
BAR_IMAGE_FIXED_VAR=bash
BAR_VERSION_FIXED_VAR?=latest
EOL
)> "${TEST_FILE_5}"
	TEST_FILE_6="${TEST_TEMP_DIR}/bar.deps"
	(cat <<'EOL'
zebra
EOL
)> "${TEST_FILE_6}"


	touch "${TEST_TEMP_DIR}/zebra.yml"
	touch "${TEST_TEMP_DIR}/zebra.scalable"
	TEST_FILE_7="${TEST_TEMP_DIR}/zebra.env"
	(cat <<'EOL'
ZEBRA_IMAGE_FIXED_VAR=bash
ZEBRA_VERSION_FIXED_VAR?=latest
EOL
)> "${TEST_FILE_7}"

	touch "${TEST_TEMP_DIR}/alpha.yml"
	touch "${TEST_TEMP_DIR}/alpha.scalable"
	TEST_FILE_8="${TEST_TEMP_DIR}/alpha.env"
	(cat <<'EOL'
ALPHA_IMAGE_FIXED_VAR=bash
ALPHA_VERSION_FIXED_VAR?=latest
EOL
)> "${TEST_FILE_8}"
}

teardown() {
	true

	temp_del "$TEST_TEMP_DIR"
}




#  -------------------------------------------------------------------
@test "__get_scaled_item_instances_list_1" {
	ZEBRA_INSTANCES_NAMES="z1 z2"

	run __get_scaled_item_instances_list "zebra" "5"
	assert_output 'zebra_z1 zebra_z2 zebra_instance_3 zebra_instance_4 zebra_instance_5'
	
	ALPHA_INSTANCES_NAMES="a1"
	run __get_scaled_item_instances_list "alpha" "1"
	assert_output 'alpha_a1'

	ALPHA_INSTANCES_NAMES=""
	run __get_scaled_item_instances_list "alpha" "1"
	assert_output 'alpha'

	ALPHA_INSTANCES_NAMES=""
	run __get_scaled_item_instances_list "alpha" "2"
	assert_output 'alpha_instance_1 alpha_instance_2'
}

@test "__load_modules_dependencies_1" {
	
	TANGO_MODULES_ROOT="${TEST_TEMP_DIR}"

	
	__load_modules_dependencies

	assert_equal "$MOD_MODULE_DEPENDENCIES" "foo bar"
	assert_equal "$FOO_MODULE_DEPENDENCIES" "bar"
	assert_equal "$BAR_MODULE_DEPENDENCIES" "zebra"
	assert_equal "$ZEBRA_MODULE_DEPENDENCIES" ""

}

@test "__load_modules_dependencies_2" {
	
	TANGO_MODULES_ROOT="${TEST_TEMP_DIR}"

	# shell environment variable test
	export ZEBRA_MODULE_DEPENDENCIES="toto"
	__load_modules_dependencies
	

	assert_equal "$MOD_MODULE_DEPENDENCIES" "foo bar"
	assert_equal "$FOO_MODULE_DEPENDENCIES" "bar"
	assert_equal "$BAR_MODULE_DEPENDENCIES" "zebra"
	assert_equal "$ZEBRA_MODULE_DEPENDENCIES" "toto"
}


@test "__parse_and_scale_modules_declaration_1" {

	TANGO_MODULES_ROOT="${TEST_TEMP_DIR}"
	TANGO_SERVICES_MODULES="bar%alpha"
	
	__load_modules_dependencies
	__parse_and_scale_modules_declaration


	assert_equal "$BAR_MODULE_DEPENDENCIES" "alpha zebra"
	assert_equal "$BAR_INSTANCES_LIST" "bar"
	assert_equal "$BAR_INSTANCES_LIST_FULL" "bar%alpha"
	assert_equal "$BAR_INSTANCES_NB" "1"
	assert_equal "$BAR_MODULE_EXTENDED_DEF" "%alpha"
	assert_equal "$BAR_MODULE_EXTENDED_DEF_WITHOUT_SCALE" "%alpha"
	assert_equal "$BAR_MODULE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""
	assert_equal "$BAR_INSTANCE_EXTENDED_DEF" "%alpha"
	assert_equal "$BAR_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "%alpha"
	assert_equal "$BAR_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""

	assert_equal "$TANGO_SERVICES_MODULES" "bar"
	assert_equal "$TANGO_SERVICES_MODULES_FULL" "bar%alpha"
	assert_equal "$TANGO_SERVICES_MODULES_SCALED" ""
	assert_equal "$TANGO_SERVICES_MODULES_SCALED_FULL" ""
}


@test "__parse_and_scale_modules_declaration_2" {

	TANGO_MODULES_ROOT="${TEST_TEMP_DIR}"
	TANGO_SERVICES_MODULES="bar^2%alpha foo^3%zebra"
	
	__load_modules_dependencies
	__parse_and_scale_modules_declaration


	assert_equal "$BAR_MODULE_DEPENDENCIES" "alpha zebra"
	assert_equal "$BAR_INSTANCES_LIST" "bar_instance_1 bar_instance_2"
	assert_equal "$BAR_INSTANCES_LIST_FULL" "bar_instance_1%alpha bar_instance_2%alpha"
	assert_equal "$BAR_INSTANCES_NB" "2"

	assert_equal "$BAR_MODULE_EXTENDED_DEF" "^2%alpha"
	assert_equal "$BAR_MODULE_EXTENDED_DEF_WITHOUT_SCALE" "%alpha"
	assert_equal "$BAR_MODULE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""
	assert_equal "$BAR_INSTANCE_1_INSTANCE_EXTENDED_DEF" "^2%alpha"
	assert_equal "$BAR_INSTANCE_1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "%alpha"
	assert_equal "$BAR_INSTANCE_1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""
	assert_equal "$BAR_INSTANCE_2_INSTANCE_EXTENDED_DEF" "^2%alpha"
	assert_equal "$BAR_INSTANCE_2_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "%alpha"
	assert_equal "$BAR_INSTANCE_2_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""

	assert_equal "$FOO_MODULE_DEPENDENCIES" "zebra bar"
	assert_equal "$FOO_INSTANCES_LIST" "foo_instance_1 foo_instance_2 foo_instance_3"
	assert_equal "$FOO_INSTANCES_LIST_FULL" "foo_instance_1%zebra foo_instance_2%zebra foo_instance_3%zebra"
	assert_equal "$FOO_INSTANCES_NB" "3"
	assert_equal "$FOO_MODULE_EXTENDED_DEF" "^3%zebra"
	assert_equal "$FOO_MODULE_EXTENDED_DEF_WITHOUT_SCALE" "%zebra"
	assert_equal "$FOO_MODULE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""
	assert_equal "$FOO_INSTANCE_1_INSTANCE_EXTENDED_DEF" "^3%zebra"
	assert_equal "$FOO_INSTANCE_1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "%zebra"
	assert_equal "$FOO_INSTANCE_1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""

	assert_equal "$TANGO_SERVICES_MODULES" "bar_instance_1 bar_instance_2 foo_instance_1 foo_instance_2 foo_instance_3"
	assert_equal "$TANGO_SERVICES_MODULES_FULL" "bar^2%alpha foo^3%zebra"
	assert_equal "$TANGO_SERVICES_MODULES_SCALED" "bar foo"

}


@test "__recursive_modules_dependencies_1" {
	
	TANGO_MODULES_ROOT="${TEST_TEMP_DIR}"
	TANGO_SERVICES_MODULES="bar^2%alpha foo^3%zebra"
	
	__load_modules_dependencies
	__parse_and_scale_modules_declaration

	assert_equal "$BAR_MODULE_DEPENDENCIES" "alpha zebra"
	assert_equal "$ALPHA_MODULE_DEPENDENCIES" ""
	assert_equal "$ZEBRA_MODULE_DEPENDENCIES" ""
	assert_equal "$FOO_MODULE_DEPENDENCIES" "zebra bar"

	assert_equal "$BAR_INSTANCES_NB" "2"
	assert_equal "$FOO_INSTANCES_NB" "3"
	assert_equal "$ZEBRA_INSTANCES_NB" ""
	assert_equal "$ALPHA_INSTANCES_NB" ""

	assert_equal "$TANGO_SERVICES_MODULES_FULL" "bar^2%alpha foo^3%zebra"


	__recursive_modules_dependencies "bar foo"

	assert_equal "$TANGO_SERVICES_MODULES_LINKED" "alpha zebra bar"

	assert_equal "$BAR_INSTANCES_ADDED" "$(( 0 + 3 ))"
	assert_equal "$ZEBRA_INSTANCES_ADDED" "$(( 0 + 2 + 3 + 3 ))"
	assert_equal "$ALPHA_INSTANCES_ADDED" "$(( 0 + 2 + 3 ))"
	assert_equal "$FOO_INSTANCES_ADDED" ""

	# according to deps file :
	# bar dependency is zebra
	# foo dependency is bar
	assert_equal "$BAR_MODULE_LINKED" "foo"
	assert_equal "$ALPHA_MODULE_LINKED" "bar"
	assert_equal "$ZEBRA_MODULE_LINKED" "bar foo"
	assert_equal "$FOO_MODULE_LINKED" ""


}

@test "__recursive_modules_dependencies_2" {
	
	TANGO_MODULES_ROOT="${TEST_TEMP_DIR}"
	TANGO_SERVICES_MODULES="bar^2%alpha foo^3%zebra mod^2%bar"
	
	__load_modules_dependencies
	__parse_and_scale_modules_declaration

	assert_equal "$BAR_MODULE_DEPENDENCIES" "alpha zebra"
	assert_equal "$ALPHA_MODULE_DEPENDENCIES" ""
	assert_equal "$ZEBRA_MODULE_DEPENDENCIES" ""
	assert_equal "$FOO_MODULE_DEPENDENCIES" "zebra bar"
	assert_equal "$MOD_MODULE_DEPENDENCIES" "bar foo"


	assert_equal "$BAR_INSTANCES_NB" "2"
	assert_equal "$FOO_INSTANCES_NB" "3"
	assert_equal "$MOD_INSTANCES_NB" "2"
	assert_equal "$ZEBRA_INSTANCES_NB" ""
	assert_equal "$ALPHA_INSTANCES_NB" ""

	assert_equal "$TANGO_SERVICES_MODULES_FULL" "bar^2%alpha foo^3%zebra mod^2%bar"


	__recursive_modules_dependencies "bar foo mod"

	assert_equal "$TANGO_SERVICES_MODULES_LINKED" "alpha zebra bar foo"

	assert_equal "$BAR_INSTANCES_ADDED" "$(( 0 + 3 + 2 + 2 ))"
	assert_equal "$ZEBRA_INSTANCES_ADDED" "$(( 0 + 2 + 3 + 3 + 2 + 2 + 2 ))"
	assert_equal "$ALPHA_INSTANCES_ADDED" "$(( 0 + 2 + 3 + 2 + 2))"
	assert_equal "$FOO_INSTANCES_ADDED" "$(( 0 + 2 ))"
	assert_equal "$MOD_INSTANCES_ADDED" ""

	assert_equal "$BAR_MODULE_LINKED" "foo mod"
	assert_equal "$ZEBRA_MODULE_LINKED" "bar foo"
	assert_equal "$ALPHA_MODULE_LINKED" "bar"
	assert_equal "$FOO_MODULE_LINKED" "mod"
	assert_equal "$MOD_MODULE_LINKED" ""


}



@test "__process_modules_dependencies_1" {
	
	TANGO_MODULES_ROOT="${TEST_TEMP_DIR}"
	TANGO_SERVICES_MODULES="bar^2%alpha foo^3%zebra mod^2%bar"
	
	__load_modules_dependencies
	__parse_and_scale_modules_declaration

	# children modules of a module
	assert_equal "$BAR_MODULE_DEPENDENCIES" "alpha zebra"
	assert_equal "$ALPHA_MODULE_DEPENDENCIES" ""
	assert_equal "$ZEBRA_MODULE_DEPENDENCIES" ""
	assert_equal "$FOO_MODULE_DEPENDENCIES" "zebra bar"
	assert_equal "$MOD_MODULE_DEPENDENCIES" "bar foo"

	assert_equal "$BAR_INSTANCES_NB" "2"
	assert_equal "$FOO_INSTANCES_NB" "3"
	assert_equal "$ZEBRA_INSTANCES_NB" ""
	assert_equal "$ALPHA_INSTANCES_NB" ""
	assert_equal "$MOD_INSTANCES_NB" "2"

	assert_equal "$TANGO_SERVICES_MODULES" "bar_instance_1 bar_instance_2 foo_instance_1 foo_instance_2 foo_instance_3 mod_instance_1 mod_instance_2"
	assert_equal "$TANGO_SERVICES_MODULES_FULL" "bar^2%alpha foo^3%zebra mod^2%bar"
	assert_equal "$TANGO_SERVICES_MODULES_SCALED" "bar foo mod"

	__process_modules_dependencies

	assert_equal "$TANGO_SERVICES_MODULES" "bar_instance_1 bar_instance_2 foo_instance_1 foo_instance_2 foo_instance_3 mod_instance_1 mod_instance_2 alpha_instance_1 alpha_instance_2 alpha_instance_3 alpha_instance_4 alpha_instance_5 alpha_instance_6 alpha_instance_7 alpha_instance_8 alpha_instance_9 zebra_instance_1 zebra_instance_2 zebra_instance_3 zebra_instance_4 zebra_instance_5 zebra_instance_6 zebra_instance_7 zebra_instance_8 zebra_instance_9 zebra_instance_10 zebra_instance_11 zebra_instance_12 zebra_instance_13 zebra_instance_14 bar_instance_3 bar_instance_4 bar_instance_5 bar_instance_6 bar_instance_7 bar_instance_8 bar_instance_9 foo_instance_4 foo_instance_5"
	assert_equal "$TANGO_SERVICES_MODULES_FULL" "bar^9%alpha foo^5%zebra mod^2%bar"
	assert_equal "$TANGO_SERVICES_MODULES_SCALED" "bar foo mod alpha zebra"
	assert_equal "$TANGO_SERVICES_MODULES_LINKED" "alpha zebra bar foo"


	assert_equal "$BAR_INSTANCES_ADDED" "$(( 0 + 3 + 2 + 2 ))" # 7
	assert_equal "$ZEBRA_INSTANCES_ADDED" "$(( 0 + 2 + 3 + 3 + 2 + 2 + 2 ))" # 14
	assert_equal "$ALPHA_INSTANCES_ADDED" "$(( 0 + 2 + 3 + 2 + 2))" # 9
	assert_equal "$FOO_INSTANCES_ADDED" "$(( 0 + 2 ))" # 2
	assert_equal "$MOD_INSTANCES_ADDED" ""

	assert_equal "$BAR_INSTANCES_NB" "$(( 2 + 7 ))"
	assert_equal "$FOO_INSTANCES_NB" "$(( 3 + 2 ))"
	assert_equal "$ZEBRA_INSTANCES_NB" "$(( 0 + 14 ))"
	assert_equal "$ALPHA_INSTANCES_NB" "$(( 0 + 9 ))"
	assert_equal "$MOD_INSTANCES_NB" "$(( 2 + 0 ))"

	# parent modules of a module
	assert_equal "$BAR_MODULE_LINKED" "foo mod"
	assert_equal "$ZEBRA_MODULE_LINKED" "bar foo"
	assert_equal "$ALPHA_MODULE_LINKED" "bar"
	assert_equal "$FOO_MODULE_LINKED" "mod"
	assert_equal "$MOD_MODULE_LINKED" ""

	# parent instance of instance
	assert_equal "$BAR_INSTANCE_3_INSTANCE_LINKED" "foo_instance_1"
	assert_equal "$BAR_INSTANCE_8_INSTANCE_LINKED" "mod_instance_1"
	assert_equal "$ZEBRA_INSTANCE_10_INSTANCE_LINKED" "foo_instance_1"
	
	# children instances of instance
	assert_equal "$BAR_INSTANCE_1_INSTANCE_DEPENDENCIES" "alpha_instance_1 zebra_instance_1"
	assert_equal "$FOO_INSTANCE_1_INSTANCE_DEPENDENCIES" "zebra_instance_10 bar_instance_3"
	assert_equal "$MOD_INSTANCE_1_INSTANCE_DEPENDENCIES" "bar_instance_8 foo_instance_4"


}

@test "__process_modules_dependencies_2" {
	
	TANGO_MODULES_ROOT="${TEST_TEMP_DIR}"
	TANGO_SERVICES_MODULES="bar^2%alpha foo^3%zebra zebra~vpn_1"
	
	ZEBRA_INSTANCES_NAMES="z1"

	__load_modules_dependencies
	__parse_and_scale_modules_declaration


	assert_equal "$BAR_MODULE_DEPENDENCIES" "alpha zebra"
	assert_equal "$ALPHA_MODULE_DEPENDENCIES" ""
	assert_equal "$ZEBRA_MODULE_DEPENDENCIES" ""
	assert_equal "$FOO_MODULE_DEPENDENCIES" "zebra bar"

	assert_equal "$BAR_INSTANCES_NB" "2"
	assert_equal "$FOO_INSTANCES_NB" "3"
	assert_equal "$ZEBRA_INSTANCES_NB" "1"
	assert_equal "$ALPHA_INSTANCES_NB" ""

	assert_equal "$BAR_INSTANCES_LIST" "bar_instance_1 bar_instance_2"
	assert_equal "$BAR_INSTANCES_LIST_FULL" "bar_instance_1%alpha bar_instance_2%alpha"

	assert_equal "$ZEBRA_INSTANCES_LIST" "zebra_z1"
	assert_equal "$ZEBRA_INSTANCES_LIST_FULL" "zebra_z1~vpn_1"

	assert_equal "$TANGO_SERVICES_MODULES" "bar_instance_1 bar_instance_2 foo_instance_1 foo_instance_2 foo_instance_3 zebra_z1"
	assert_equal "$TANGO_SERVICES_MODULES_FULL" "bar^2%alpha foo^3%zebra zebra~vpn_1"
	assert_equal "$TANGO_SERVICES_MODULES_SCALED" "bar foo"

	__process_modules_dependencies
	
	assert_equal "$TANGO_SERVICES_MODULES" "bar_instance_1 bar_instance_2 foo_instance_1 foo_instance_2 foo_instance_3 zebra_z1 alpha_instance_1 alpha_instance_2 alpha_instance_3 alpha_instance_4 alpha_instance_5 zebra_instance_2 zebra_instance_3 zebra_instance_4 zebra_instance_5 zebra_instance_6 zebra_instance_7 zebra_instance_8 zebra_instance_9 bar_instance_3 bar_instance_4 bar_instance_5"
	assert_equal "$TANGO_SERVICES_MODULES_FULL" "bar^5%alpha foo^3%zebra zebra^9~vpn_1"
	assert_equal "$TANGO_SERVICES_MODULES_SCALED" "bar foo alpha zebra"
	assert_equal "$TANGO_SERVICES_MODULES_LINKED" "alpha zebra bar"

	assert_equal "$BAR_INSTANCES_LIST" "bar_instance_1 bar_instance_2 bar_instance_3 bar_instance_4 bar_instance_5"
	assert_equal "$BAR_INSTANCES_LIST_FULL" "bar_instance_1%alpha bar_instance_2%alpha bar_instance_3%alpha bar_instance_4%alpha bar_instance_5%alpha"

	assert_equal "$ZEBRA_INSTANCES_LIST" "zebra_z1 zebra_instance_2 zebra_instance_3 zebra_instance_4 zebra_instance_5 zebra_instance_6 zebra_instance_7 zebra_instance_8 zebra_instance_9"
	assert_equal "$ZEBRA_INSTANCES_LIST_FULL" "zebra_z1~vpn_1 zebra_instance_2~vpn_1 zebra_instance_3~vpn_1 zebra_instance_4~vpn_1 zebra_instance_5~vpn_1 zebra_instance_6~vpn_1 zebra_instance_7~vpn_1 zebra_instance_8~vpn_1 zebra_instance_9~vpn_1"
	
	assert_equal "$ALPHA_INSTANCES_LIST" "alpha_instance_1 alpha_instance_2 alpha_instance_3 alpha_instance_4 alpha_instance_5"
	assert_equal "$ALPHA_INSTANCES_LIST_FULL" "alpha_instance_1 alpha_instance_2 alpha_instance_3 alpha_instance_4 alpha_instance_5"

	assert_equal "$BAR_INSTANCES_ADDED" "$(( 0 + 3 ))" # 3
	assert_equal "$ZEBRA_INSTANCES_ADDED" "$(( 0 + 2 + 3 + 3 ))" # 8
	assert_equal "$ALPHA_INSTANCES_ADDED" "$(( 0 + 2 + 3 ))" # 5
	assert_equal "$FOO_INSTANCES_ADDED" ""

	assert_equal "$BAR_INSTANCES_NB" "$(( 2 + 3 ))"
	assert_equal "$FOO_INSTANCES_NB" "$(( 3 + 0 ))"
	assert_equal "$ZEBRA_INSTANCES_NB" "$(( 1 + 8 ))"
	assert_equal "$ALPHA_INSTANCES_NB" "$(( 0 + 5 ))"

	assert_equal "$BAR_MODULE_LINKED" "foo"
	assert_equal "$ZEBRA_MODULE_LINKED" "bar foo"
	assert_equal "$ALPHA_MODULE_LINKED" "bar"
	assert_equal "$FOO_MODULE_LINKED" ""

	assert_equal "$FOO_MODULE_EXTENDED_DEF" "^3%zebra"
	assert_equal "$FOO_MODULE_EXTENDED_DEF_WITHOUT_SCALE" "%zebra"
	assert_equal "$FOO_MODULE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""
	assert_equal "$FOO_INSTANCE_1_INSTANCE_EXTENDED_DEF" "^3%zebra"
	assert_equal "$FOO_INSTANCE_1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "%zebra"
	assert_equal "$FOO_INSTANCE_1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""

	assert_equal "$ALPHA_MODULE_EXTENDED_DEF" ""
	assert_equal "$ALPHA_MODULE_EXTENDED_DEF_WITHOUT_SCALE" ""
	assert_equal "$ALPHA_MODULE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""
	assert_equal "$ALPHA_INSTANCE_1_INSTANCE_EXTENDED_DEF" ""
	assert_equal "$ALPHA_INSTANCE_1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" ""
	assert_equal "$ALPHA_INSTANCE_1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""
	assert_equal "$ALPHA_INSTANCE_5_INSTANCE_EXTENDED_DEF" ""
	assert_equal "$ALPHA_INSTANCE_5_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" ""
	assert_equal "$ALPHA_INSTANCE_5_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""

	assert_equal "$BAR_MODULE_EXTENDED_DEF" "^2%alpha"
	assert_equal "$BAR_MODULE_EXTENDED_DEF_WITHOUT_SCALE" "%alpha"
	assert_equal "$BAR_MODULE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""
	assert_equal "$BAR_INSTANCE_1_INSTANCE_EXTENDED_DEF" "^2%alpha"
	assert_equal "$BAR_INSTANCE_1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "%alpha"
	assert_equal "$BAR_INSTANCE_1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""
	assert_equal "$BAR_INSTANCE_2_INSTANCE_EXTENDED_DEF" "^2%alpha"
	assert_equal "$BAR_INSTANCE_2_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "%alpha"
	assert_equal "$BAR_INSTANCE_2_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""
	assert_equal "$BAR_INSTANCE_5_INSTANCE_EXTENDED_DEF" "^2%alpha"
	assert_equal "$BAR_INSTANCE_5_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "%alpha"
	assert_equal "$BAR_INSTANCE_5_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""


	assert_equal "$ZEBRA_MODULE_EXTENDED_DEF" "~vpn_1"
	assert_equal "$ZEBRA_MODULE_EXTENDED_DEF_WITHOUT_SCALE" "~vpn_1"
	assert_equal "$ZEBRA_MODULE_EXTENDED_DEF_WITHOUT_SCALE_DEP" "~vpn_1"
	assert_equal "$ZEBRA_Z1_INSTANCE_EXTENDED_DEF" "~vpn_1"
	assert_equal "$ZEBRA_Z1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "~vpn_1"
	assert_equal "$ZEBRA_Z1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" "~vpn_1"
	assert_equal "$ZEBRA_INSTANCE_2_INSTANCE_EXTENDED_DEF" "~vpn_1"
	assert_equal "$ZEBRA_INSTANCE_2_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "~vpn_1"
	assert_equal "$ZEBRA_INSTANCE_2_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" "~vpn_1"
	assert_equal "$ZEBRA_INSTANCE_7_INSTANCE_EXTENDED_DEF" "~vpn_1"
	assert_equal "$ZEBRA_INSTANCE_7_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "~vpn_1"
	assert_equal "$ZEBRA_INSTANCE_7_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" "~vpn_1"
	assert_equal "$ZEBRA_INSTANCE_9_INSTANCE_EXTENDED_DEF" "~vpn_1"
	assert_equal "$ZEBRA_INSTANCE_9_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "~vpn_1"
	assert_equal "$ZEBRA_INSTANCE_9_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" "~vpn_1"

	# parent instance of instance
	assert_equal "$FOO_INSTANCE_1_INSTANCE_LINKED" ""
	assert_equal "$FOO_INSTANCE_3_INSTANCE_LINKED" ""

	assert_equal "$BAR_INSTANCE_1_INSTANCE_LINKED" ""
	assert_equal "$BAR_INSTANCE_2_INSTANCE_LINKED" ""
	assert_equal "$BAR_INSTANCE_3_INSTANCE_LINKED" "foo_instance_1"
	assert_equal "$BAR_INSTANCE_4_INSTANCE_LINKED" "foo_instance_2"
	assert_equal "$BAR_INSTANCE_5_INSTANCE_LINKED" "foo_instance_3"

	assert_equal "$ZEBRA_Z1_INSTANCE_LINKED" ""
	assert_equal "$ZEBRA_INSTANCE_2_INSTANCE_LINKED" "bar_instance_1"
	assert_equal "$ZEBRA_INSTANCE_3_INSTANCE_LINKED" "bar_instance_2"
	assert_equal "$ZEBRA_INSTANCE_4_INSTANCE_LINKED" "bar_instance_3"
	assert_equal "$ZEBRA_INSTANCE_5_INSTANCE_LINKED" "bar_instance_4"
	assert_equal "$ZEBRA_INSTANCE_6_INSTANCE_LINKED" "bar_instance_5"
	assert_equal "$ZEBRA_INSTANCE_7_INSTANCE_LINKED" "foo_instance_1"
	assert_equal "$ZEBRA_INSTANCE_8_INSTANCE_LINKED" "foo_instance_2"
	assert_equal "$ZEBRA_INSTANCE_9_INSTANCE_LINKED" "foo_instance_3"
}


@test "__process_modules_dependencies_3" {
	
	TANGO_MODULES_ROOT="${TEST_TEMP_DIR}"
	TANGO_SERVICES_MODULES="bar^2%alpha foo~vpn_1^3%zebra"
	
	ZEBRA_INSTANCES_NAMES="z1"

	__load_modules_dependencies
	__parse_and_scale_modules_declaration


	assert_equal "$BAR_MODULE_DEPENDENCIES" "alpha zebra"
	assert_equal "$ALPHA_MODULE_DEPENDENCIES" ""
	assert_equal "$ZEBRA_MODULE_DEPENDENCIES" ""
	assert_equal "$FOO_MODULE_DEPENDENCIES" "zebra bar"

	assert_equal "$BAR_INSTANCES_NB" "2"
	assert_equal "$FOO_INSTANCES_NB" "3"
	assert_equal "$ZEBRA_INSTANCES_NB" ""
	assert_equal "$ALPHA_INSTANCES_NB" ""

	assert_equal "$BAR_INSTANCES_LIST" "bar_instance_1 bar_instance_2"
	assert_equal "$BAR_INSTANCES_LIST_FULL" "bar_instance_1%alpha bar_instance_2%alpha"

	assert_equal "$ZEBRA_INSTANCES_LIST" ""
	assert_equal "$ZEBRA_INSTANCES_LIST_FULL" ""

	assert_equal "$TANGO_SERVICES_MODULES" "bar_instance_1 bar_instance_2 foo_instance_1 foo_instance_2 foo_instance_3"
	assert_equal "$TANGO_SERVICES_MODULES_FULL" "bar^2%alpha foo~vpn_1^3%zebra"
	assert_equal "$TANGO_SERVICES_MODULES_SCALED" "bar foo"

	__process_modules_dependencies
	
	assert_equal "$TANGO_SERVICES_MODULES" "bar_instance_1 bar_instance_2 foo_instance_1 foo_instance_2 foo_instance_3 alpha_instance_1 alpha_instance_2 alpha_instance_3 alpha_instance_4 alpha_instance_5 zebra_z1 zebra_instance_2 zebra_instance_3 zebra_instance_4 zebra_instance_5 zebra_instance_6 zebra_instance_7 zebra_instance_8 bar_instance_3 bar_instance_4 bar_instance_5"
	assert_equal "$TANGO_SERVICES_MODULES_FULL" "bar^5%alpha foo^3~vpn_1%zebra"
	assert_equal "$TANGO_SERVICES_MODULES_SCALED" "bar foo alpha zebra"
	assert_equal "$TANGO_SERVICES_MODULES_LINKED" "alpha zebra bar"

	assert_equal "$BAR_INSTANCES_LIST" "bar_instance_1 bar_instance_2 bar_instance_3 bar_instance_4 bar_instance_5"
	assert_equal "$BAR_INSTANCES_LIST_FULL" "bar_instance_1%alpha bar_instance_2%alpha bar_instance_3%alpha bar_instance_4%alpha bar_instance_5%alpha"

	assert_equal "$ZEBRA_INSTANCES_LIST" "zebra_z1 zebra_instance_2 zebra_instance_3 zebra_instance_4 zebra_instance_5 zebra_instance_6 zebra_instance_7 zebra_instance_8"
	assert_equal "$ZEBRA_INSTANCES_LIST_FULL" "zebra_z1 zebra_instance_2 zebra_instance_3 zebra_instance_4 zebra_instance_5 zebra_instance_6~vpn_1 zebra_instance_7~vpn_1 zebra_instance_8~vpn_1"
	
	assert_equal "$ALPHA_INSTANCES_LIST" "alpha_instance_1 alpha_instance_2 alpha_instance_3 alpha_instance_4 alpha_instance_5"
	assert_equal "$ALPHA_INSTANCES_LIST_FULL" "alpha_instance_1 alpha_instance_2 alpha_instance_3 alpha_instance_4 alpha_instance_5"

	assert_equal "$BAR_INSTANCES_ADDED" "$(( 0 + 3 ))" # 3
	assert_equal "$ZEBRA_INSTANCES_ADDED" "$(( 0 + 2 + 3 + 3 ))" # 8
	assert_equal "$ALPHA_INSTANCES_ADDED" "$(( 0 + 2 + 3 ))" # 5
	assert_equal "$FOO_INSTANCES_ADDED" ""

	assert_equal "$BAR_INSTANCES_NB" "$(( 2 + 3 ))"
	assert_equal "$FOO_INSTANCES_NB" "$(( 3 + 0 ))"

	assert_equal "$BAR_MODULE_LINKED" "foo"
	assert_equal "$FOO_MODULE_LINKED" ""

	assert_equal "$FOO_MODULE_EXTENDED_DEF" "~vpn_1^3%zebra"
	assert_equal "$FOO_MODULE_EXTENDED_DEF_WITHOUT_SCALE" "~vpn_1%zebra"
	assert_equal "$FOO_MODULE_EXTENDED_DEF_WITHOUT_SCALE_DEP" "~vpn_1"
	assert_equal "$FOO_INSTANCE_1_INSTANCE_EXTENDED_DEF" "~vpn_1^3%zebra"
	assert_equal "$FOO_INSTANCE_1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "~vpn_1%zebra"
	assert_equal "$FOO_INSTANCE_1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" "~vpn_1"

	assert_equal "$BAR_MODULE_EXTENDED_DEF" "^2%alpha"
	assert_equal "$BAR_MODULE_EXTENDED_DEF_WITHOUT_SCALE" "%alpha"
	assert_equal "$BAR_MODULE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""
	assert_equal "$BAR_INSTANCE_1_INSTANCE_EXTENDED_DEF" "^2%alpha"
	assert_equal "$BAR_INSTANCE_1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "%alpha"
	assert_equal "$BAR_INSTANCE_1_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""
	assert_equal "$BAR_INSTANCE_2_INSTANCE_EXTENDED_DEF" "^2%alpha"
	assert_equal "$BAR_INSTANCE_2_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "%alpha"
	assert_equal "$BAR_INSTANCE_2_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""
	assert_equal "$BAR_INSTANCE_5_INSTANCE_EXTENDED_DEF" "^2%alpha"
	assert_equal "$BAR_INSTANCE_5_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE" "%alpha"
	assert_equal "$BAR_INSTANCE_5_INSTANCE_EXTENDED_DEF_WITHOUT_SCALE_DEP" ""


	# parent instance of instance
	assert_equal "$FOO_INSTANCE_1_INSTANCE_LINKED" ""
	assert_equal "$FOO_INSTANCE_3_INSTANCE_LINKED" ""

	assert_equal "$BAR_INSTANCE_1_INSTANCE_LINKED" ""
	assert_equal "$BAR_INSTANCE_2_INSTANCE_LINKED" ""
	assert_equal "$BAR_INSTANCE_3_INSTANCE_LINKED" "foo_instance_1"
	assert_equal "$BAR_INSTANCE_4_INSTANCE_LINKED" "foo_instance_2"
	assert_equal "$BAR_INSTANCE_5_INSTANCE_LINKED" "foo_instance_3"

	assert_equal "$ZEBRA_Z1_INSTANCE_LINKED" "bar_instance_1"
	assert_equal "$ZEBRA_INSTANCE_2_INSTANCE_LINKED" "bar_instance_2"
	assert_equal "$ZEBRA_INSTANCE_3_INSTANCE_LINKED" "bar_instance_3"
	assert_equal "$ZEBRA_INSTANCE_4_INSTANCE_LINKED" "bar_instance_4"
	assert_equal "$ZEBRA_INSTANCE_5_INSTANCE_LINKED" "bar_instance_5"
	assert_equal "$ZEBRA_INSTANCE_6_INSTANCE_LINKED" "foo_instance_1"
	assert_equal "$ZEBRA_INSTANCE_7_INSTANCE_LINKED" "foo_instance_2"
	assert_equal "$ZEBRA_INSTANCE_8_INSTANCE_LINKED" "foo_instance_3"

}



@test "__process_modules_dependencies_4" {
	
	TANGO_MODULES_ROOT="${TEST_TEMP_DIR}"

	touch "${TEST_TEMP_DIR}/A.yml"
	touch "${TEST_TEMP_DIR}/B.yml"
	touch "${TEST_TEMP_DIR}/C.yml"
	touch "${TEST_TEMP_DIR}/C.scalable"
	touch "${TEST_TEMP_DIR}/D.yml"
	touch "${TEST_TEMP_DIR}/E.yml"
	touch "${TEST_TEMP_DIR}/E.scalable"
	touch "${TEST_TEMP_DIR}/K.yml"
	touch "${TEST_TEMP_DIR}/K.scalable"
	touch "${TEST_TEMP_DIR}/P.yml"

	# default dependencies definition 
	# P -> D
	#   -> B
	#   -> E
	#   -> A
	# D -> K
	# C -> K
	P_MODULE_DEPENDENCIES="D A B E"
	D_MODULE_DEPENDENCIES="K"
	C_MODULE_DEPENDENCIES="K"

	# dependencies declaration in command line
	# P -> D
	#   -> B
	#   -> E
	# E -> C
	TANGO_SERVICES_MODULES="P%D%B%E E^2~vpn_1%C"



	__load_modules_dependencies
	__parse_and_scale_modules_declaration

	__process_modules_dependencies
	
	assert_equal "$TANGO_SERVICES_MODULES" "P E_instance_1 E_instance_2 D B E_instance_3 A K_instance_1 K_instance_2 K_instance_3 K_instance_4 C_instance_1 C_instance_2 C_instance_3"
	assert_equal "$TANGO_SERVICES_MODULES_FULL" "P%D%B%E E^3~vpn_1%C"
	assert_equal "$TANGO_SERVICES_MODULES_SCALED" "E K C"
	assert_equal "$TANGO_SERVICES_MODULES_LINKED" "D B E A K C"

	assert_equal "$A_INSTANCES_NB" "1"
	assert_equal "$B_INSTANCES_NB" "1"
	assert_equal "$C_INSTANCES_NB" "3"
	assert_equal "$D_INSTANCES_NB" "1"
	assert_equal "$E_INSTANCES_NB" "3"
	assert_equal "$K_INSTANCES_NB" "4"
	assert_equal "$P_INSTANCES_NB" "1"

	assert_equal "$A_INSTANCES_ADDED" "1"
	assert_equal "$B_INSTANCES_ADDED" "1"
	assert_equal "$C_INSTANCES_ADDED" "3"
	assert_equal "$D_INSTANCES_ADDED" "1"
	assert_equal "$E_INSTANCES_ADDED" "1"
	assert_equal "$K_INSTANCES_ADDED" "4"
	assert_equal "$P_INSTANCES_ADDED" ""

	assert_equal "$A_INSTANCES_LIST" "A"
	assert_equal "$A_INSTANCES_LIST_FULL" "A"
	assert_equal "$B_INSTANCES_LIST" "B"
	assert_equal "$B_INSTANCES_LIST_FULL" "B"
	assert_equal "$C_INSTANCES_LIST" "C_instance_1 C_instance_2 C_instance_3"
	assert_equal "$C_INSTANCES_LIST_FULL" "C_instance_1~vpn_1 C_instance_2~vpn_1 C_instance_3~vpn_1"
	assert_equal "$D_INSTANCES_LIST" "D"
	assert_equal "$D_INSTANCES_LIST_FULL" "D"
	assert_equal "$E_INSTANCES_LIST" "E_instance_1 E_instance_2 E_instance_3"
	assert_equal "$E_INSTANCES_LIST_FULL" "E_instance_1~vpn_1%C E_instance_2~vpn_1%C E_instance_3~vpn_1%C"
	assert_equal "$K_INSTANCES_LIST" "K_instance_1 K_instance_2 K_instance_3 K_instance_4"
	assert_equal "$K_INSTANCES_LIST_FULL" "K_instance_1 K_instance_2 K_instance_3 K_instance_4"
	assert_equal "$P_INSTANCES_LIST" "P"
	assert_equal "$P_INSTANCES_LIST_FULL" "P%D%B%E"

}


