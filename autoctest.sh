#!/usr/bin/env bash

RED="\e[31m"
LRED="\e[91m"
LBLUE="\e[94m"
GREEN="\e[32m"
MAGNETA="\e[35m"
LGREEN="\e[92m"
LCYAN="\e[96m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

TEST_START_STRING="___TESTVAL___"
OUTPUT_START_STRING="___TESTANS___"
TEST_END_STRING="___TESTEND___"
FINDING_FLAG_STATUS=0
READING_INPUT_STATUS=1
READING_OUTPUT_STATUS=2

function run_test() {
  input=$(sed 's/\\n/\n/g' <<< $1)
  output=$(sed 's/\\n/\n/g' <<< $2)
  executable_name=$3
  ./$executable_name <<< "${input}" > test_out
  result=$(cat test_out)
  printf "${LCYAN}TEST ${test_number}${ENDCOLOR}: "

  clean_result=$(sed 's/\n//g' <<< $result)
  clean_output=$(sed 's/\n//g' <<< $output)

  if [[ "$clean_result" == "$clean_output" ]]; then
    printf "${GREEN}SUCCESS${ENDCOLOR}\n"
  else
    printf "${RED}FAILED${ENDCOLOR}\n"
    printf "${MAGNETA}Test input${ENDCOLOR}:\n${input}\n"
    printf "${MAGNETA}Expected output${ENDCOLOR}:\n${output}\n"
    printf "${MAGNETA}Program result${ENDCOLOR}:\n${result}\n"
  fi

  leaks -atExit -- ./$executable_name 100 <<< "$input" > leaks_out
  
  if grep -q LEAK: "leaks_out"; then
    printf "${RED}Leaks${ENDCOLOR}:\n"
    cat leaks_out | grep LEAK
  fi
  
}

function run_all_tests_from_file() {
  executable_name=$1
  test_file_path=$2
  status="$FINDING_FLAG_STATUS"
  input=""
  output=""
  result=""
  test_number=0

  while IFS= read -r w
  do
    if [[ "$status" == "$FINDING_FLAG_STATUS" && "$w" == "$TEST_START_STRING" ]]; then
      status="$READING_INPUT_STATUS"
      input=""
    elif [[ "$status" == "$READING_INPUT_STATUS" && "$w" == "$OUTPUT_START_STRING" ]]; then
      status="$READING_OUTPUT_STATUS"
      output=""
    elif [[ "$status" == "$READING_OUTPUT_STATUS" && "$w" == "$TEST_END_STRING" ]]; then
      ((test_number=test_number+1))
      run_test "$input" "$output" "$executable_name"
      status="$FINDING_FLAG_STATUS"
    elif [ "$status" = "$READING_OUTPUT_STATUS" ]; then
      output+="$w\n"
    elif [ "$status" = "$READING_INPUT_STATUS" ]; then
      input+="$w\n"
    fi 
  done < "$test_file_path"
}

program_name="$1"
file_name=$(awk -F '\\.c' '{print $1}' <<< "$program_name")
if [[ ! -f "$2" ]]; then
  test_file_path="${file_name}.test"
else
  test_file_path="$2"
fi
executable_name="$file_name.out"

printf "Testing ${LCYAN}$program_name${ENDCOLOR}:\n"
printf "${LBLUE}Compiling${ENDCOLOR}...\n"
if gcc -Wall -Wextra -Werror -o "$executable_name" "$program_name"; then
  printf "${GREEN}Successfully compiled with flags -Wall -Wextra -Werror!${ENDCOLOR}\n"
else
  printf "${RED}Failed to compiled with flags -Wall -Wextra -Werror!${ENDCOLOR}\n"
  printf "${LBLUE}Compiling without flags${ENDCOLOR}...\n" 
  if gcc -o "$executable_name" "$program_name"; then
    printf "${YELLOW}Successfully compiled without additional flags !${ENDCOLOR}\n"
  else
    printf "${RED}Failed to compile.${ENDCOLOR}"
    exit 1
  fi
fi

printf "Checking using ${LBLUE}cppcheck${ENDCOLOR}...\n"
cppcheck --enable=all --suppress=missingIncludeSystem $program_name

printf "${LBLUE}Copying${ENDCOLOR} ${LBLUE}cpplint${ENDCOLOR}...\n"
cp ../materials/linters/* .

printf "${LBLUE}Linting${ENDCOLOR} ${GREEN}${program_name}${ENDCOLOR}...\n"
python cpplint.py $program_name



printf "\n\n\n"
touch leaks_out
touch test_out

run_all_tests_from_file "$executable_name" "$test_file_path"

if [[ -f "$executable_name" ]]; then
  printf "Removing executable file...\n"
  rm $executable_name
fi

if [[ -f "leaks_out" ]]; then
  printf "Removing leaks file...\n"
  rm leaks_out
fi

if [[ -f "test_out" ]]; then
  printf "Removing test_out file..."
  rm test_out
fi
