#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script collects configuration and log files.

if [[ -z "$(command -v zip)" ]]
then
    echo "zip program is missing"
    exit 1
fi

# If available, add a prefix to the log names. The names will
# be bison-config.log.zip, bison-test-suite.log.zip, etc.
if [[ -n "$1" ]]; then
    pkg_prefix="$1-"
elif [[ -n "${PKG_NAME}" ]]; then
    pkg_prefix="$PKG_NAME-"
else
    pkg_prefix=
fi

config_log_zip="${pkg_prefix}config.log.zip"
test_suite_log_zip="${pkg_prefix}test-suite.log.zip"

echo ""
echo "**********************"
echo "Saving log files"
echo "**********************"

rm -f "config.log.zip" "../config.log.zip" "../../config.log.zip"
rm -f "test-suite.log.zip" "../test-suite.log.zip" "../../test-suite.log.zip"
rm -f "${config_log_zip}" "../${config_log_zip}" "../../${config_log_zip}"
rm -f "${test_suite_log_zip}" "../${test_suite_log_zip}" "../../${test_suite_log_zip}"

# Collect all config.log files
IFS= find . -name 'config.log' -print | while read -r file
do
    zip -9 "${config_log_zip}" "$file"
done

# Collect all test-suite.log files
IFS= find . -name 'test*.log' -print | while read -r file
do
    zip -9 "${test_suite_log_zip}" "$file"
done

# And Emacs test logs
IFS= find . -name '*-tests.log' -print | while read -r file
do
    zip -9 "${test_suite_log_zip}" "$file"
done

# And GnuPG test logs
if [[ -e libgcrypt.log ]]; then
    zip -9 "${test_suite_log_zip}" libgcrypt.log
fi
if [[ -e gnupg.log ]]; then
    zip -9 "${test_suite_log_zip}" gnupg.log
fi

# Copy the zips to the build script directory
if [[ -e "${config_log_zip}" ]]; then
    cp "${config_log_zip}" ../
fi

if [[ -e "${test_suite_log_zip}" ]]; then
    cp "${test_suite_log_zip}" ../
fi

exit 0
