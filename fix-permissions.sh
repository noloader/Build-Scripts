#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script fixes owner and permissions on files and directories.
# Some packages use SUDO_USER and SUDO_GROUP during install for
# system directories. I _think_ using SUDO_USER:SUDO_GROUP is
# correct Unix behavior, but we want to use more traditional file
# permissions in system directories.
#
# There are two use case. First use case, $root_dir is in $HOME.
# In this case we use the user's info as owner:group. The second
# use case is, an arbitrary filesystem location. In this case we
# use the filesystem's info as owner:group. The filesystem
# typically uses root:root, admin:staff, etc.

echo ""
echo "**********************"
echo "Fixing ownership"
echo "**********************"

root_dir="$1"
if [[ -z "${root_dir}" ]]; then
    echo "Please specify a directory as first arg"
    exit 1
fi

# Fold slashes
root_dir=$(echo "${root_dir}" | tr -s '\\' | tr -s '/' )

# Validate
if [[ ! -d "${root_dir}" ]]; then
    echo "Directory does not exist"
    exit 1
elif [[ "${root_dir}" == "\\" || "${root_dir}" == "/" ]]; then
    echo "Will not modify" "'""${1}""'"
    exit 1
fi

# Remove trailing slash
root_dir=$(echo "${root_dir}" | sed 's/\/$//g')

# Don't operate on root directories, like /bin or /usr
# The tr removes all characters except the forward slash.
count=$(echo "${root_dir}" | tr -cd '/' | wc -c)
if [[ "${count}" -le 1 ]]; then
    echo "Will not modify" "'""${1}""'"
    exit 1
fi

# See if this is case 1, $root_dir is in $HOME.
# Also include an install into /tmp in this case.
if [[ "${root_dir}" == "$HOME"* || "${root_dir}" == "/tmp"* ]]; then
    private_subdir=1
else
    private_subdir=0
fi

# Find the most reasonable owner:group of the directory
if [[ "${private_subdir}" -eq 1 ]];
then
    # Find the owner:group of $HOME
    dir_usr=$(ls -ld "$HOME" 2>/dev/null | head -n 1 | awk 'NR==1 {print $3}')
    dir_grp=$(ls -ld "$HOME" 2>/dev/null | head -n 1 | awk 'NR==1 {print $4}')
elif [[ -d /usr ]]
then
    # Non-home directory. Assume a system directory
    dir_usr=$(ls -ld "/usr" 2>/dev/null | head -n 1 | awk 'NR==1 {print $3}')
    dir_grp=$(ls -ld "/usr" 2>/dev/null | head -n 1 | awk 'NR==1 {print $4}')
    dir_bin=$(ls -ld "/usr/bin" 2>/dev/null | head -n 1 | awk 'NR==1 {print $4}')
else
    # Find the parent directory
    parent_dir="$(dirname "${root_dir}")"
    if [[ -z "${parent_dir}" ]]; then
        echo "Failed to find parent directory"
        exit 1
    fi

    # Find the owner:group of $root_dir/..
    dir_usr=$(ls -ld "${parent_dir}" 2>/dev/null | head -n 1 | awk 'NR==1 {print $3}')
    dir_grp=$(ls -ld "${parent_dir}" 2>/dev/null | head -n 1 | awk 'NR==1 {print $4}')
    dir_bin=$(ls -ld "${parent_dir}/bin" 2>/dev/null | head -n 1 | awk 'NR==1 {print $4}')
fi

# Sanity check on user and group
if [[ -z "${dir_usr}" || -z "${dir_grp}" ]]; then
    echo "Failed to determine owner and group"
    exit 1
fi

# User and group are mostly standard. Solaris can be different.
echo "user: ${dir_usr}"
echo "group: ${dir_grp}"

if [[ -n "${dir_bin}" && "${dir_grp}" != "${dir_bin}" ]]; then
    echo "bin: ${dir_bin}"
fi

# Set the owner:group on the root directory and below
if ! chown -hR "${dir_usr}:${dir_grp}" "${root_dir}"; then
    echo "Failed to change owner and group on root directory"
    exit 1
fi

#  Solaris uses group 'bin' on bin/, lib/ and friends
if [[ -n "${dir_bin}" && "${dir_grp}" != "${dir_bin}" ]];
then
    for exec_dir in "${root_dir}/bin" "${root_dir}/sbin" \
                    "${root_dir}/lib" "${root_dir}/libexec" \
                    "${root_dir}/lib32" "${root_dir}/lib64" \
                    "${root_dir}/32" "${root_dir}/64";
    do
        if [[ -d "${exec_dir}" ]]; then
            chown -hR "${dir_usr}:${dir_bin}" "${exec_dir}"
        fi
    done
fi

# Make directories viewable
find "${root_dir}" -type d -exec chmod a+x {} \;

# Fix permissions on shared objects
IS_DARWIN="$(uname -s | grep -i -c darwin)"
IFS= find "${root_dir}" -type d -name 'lib*' -print | while read -r sharedobj_dir
do
    if [[ "${IS_DARWIN}" -ne 0 ]]; then
        find "${sharedobj_dir}" -type f -name '*\.dylib*' -exec chmod a+x {} \;
    else
        find "${sharedobj_dir}" -type f -name '*\.so*' -exec chmod a+x {} \;
    fi
done

# Fix permissions on archives and libtool archives
IFS= find "${root_dir}" -type d -name 'lib*' -print | while read -r sharedobj_dir
do
    find "${sharedobj_dir}" -name '*\.a$' -exec chmod a-x {} \;
    find "${sharedobj_dir}" -name '*\.la$' -exec chmod a-x {} \;
done

echo "**********************"

exit 0
