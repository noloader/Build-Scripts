# Solaris

The Build-Scripts should work out-of-the-box for modern Solaris, like Solaris 10 or Solaris 11. Once you run the setup recipes you should be able to build most programs with the scripts.

Solaris ships with a modified version of OpenSSH 1.2.12, so updating OpenSSH is an important operation. A new OpenSSH will allow you to use Ecdsa and Ed25519 keys. After building a new OpenSSH you have to update the existing Solaris configuration so the operating system uses the new OpenSSH.

Modern OpenSSH no longer supports DSA keys by default. Default DSA support was disabled at OpenSSH 7.9. You should ensure you have an Ecdsa or Ed25519 key (or enable DSA keys in `sshd_config`). Also see [OpenSSH Release Notes](https://www.openssh.com/releasenotes.html).

After installing OpenSSH you should also tune `sshd_config` to suit your taste. You can disable password logins, enable public key logins, etc.

## Setup

Once you clone the repo you should perform a one-time setup. The setup installs updated CA certificates and builds a modern Wget. `setup-cacerts.sh` installs a local copy of 11 CA certificates in `$HOME/.build-scripts/cacerts`. They are used to download source code packages for programs and libraries. `setup-wget.sh` installs a local copy of `wget` in `$HOME/.build-scripts/wget`. It is a reduced-functionality version of Wget with only HTTPS, IPv4, IPv6 and large-file support. It is anemic but functional enough to download packages over HTTPS.

```
$ ./setup-cacerts.sh
...

$ ./setup-wget.sh
...
```

You can build the fully-functional version of Wget by running `./build-wget.sh`, but it is not needed for OpenSSH.

## OpenSSH

The following steps should be performed to update OpenSSH. The new OpenSSH is permanently installed at `/opt/ssh` (as opposed to a location like `/usr/local`). `/opt/ssh` will have a standard Linux filesystem below it.

```
$ INSTX_PREFIX=/opt/ssh ./build-openssh.sh
```

After building and installing OpenSSH you have to tell Solaris to use it. First, backup `/lib/svc/method/sshd`:

```
$ sudo su -
...

# cp -r /lib/svc/method/sshd /lib/svc/method/sshd.bu
```

Second, open `/lib/svc/method/sshd` in a text editor. Change the hard-coded `/etc/ssh` to `$SSHDIR`. There are several places the hard-coded value is used.

Third, modify the variable `SSHDIR` and set it to `/opt/ssh/etc`.

Fourth, modify the variable `KEYGEN` and set it to `/opt/ssh/bin/ssh-keygen -q`.

Fifth, locate references to `ssh_host_rsa_key`. At each location, add references to `ssh_host_ecdsa_key` and `ssh_host_ed25519_key`.

Sixth, in the `start` command, have the scripts call `/opt/ssh/sbin/sshd` instead of `/usr/lib/ssh/sshd`.

Finally, reboot the machine with the `reboot` command.

Note: if you see two Message of the Day messages with the new OpenSSH, then add `PrintMotd no` to `/opt/ssh/etc/sshd_config`.

## /lib/svc/method/sshd

After the changes your modified `/lib/svc/method/sshd` should look similar to below.

```
# cat /lib/svc/method/sshd
#!/usr/sbin/sh
#
# Copyright (c) 2001, 2013, Oracle and/or its affiliates.
#

. /lib/svc/share/smf_include.sh
. /lib/svc/share/ipf_include.sh

# SSHDIR=/etc/ssh
SSHDIR=/opt/ssh/etc

# KEYGEN="/usr/bin/ssh-keygen -q"
KEYGEN="/opt/ssh/bin/ssh-keygen -q"

PIDFILE=$SMF_SYSVOL_FS/sshd.pid

# Checks to see if RSA, and DSA host keys are available
# if any of these keys are not present, the respective keys are created.
create_key()
{
        keypath=$1
        keytype=$2

        if [ ! -f $keypath ]; then
                #
                # HostKey keywords in sshd_config may be preceded or
                # followed by a mix of any number of space or tabs,
                # and optionally have an = between keyword and
                # argument.  We use two grep invocations such that we
                # can match HostKey case insensitively but still have
                # the case of the path name be significant, keeping
                # the pattern somewhat more readable.
                #
                # The character classes below contain one literal
                # space and one literal tab.
                #
                grep -i "^[     ]*HostKey[      ]*=\{0,1\}[     ]*$keypath" \
                    $SSHDIR/sshd_config | grep "$keypath" > /dev/null 2>&1

                if [ $? -eq 0 ]; then
                        echo Creating new $keytype public/private host key pair
                        $KEYGEN -f $keypath -t $keytype -N ''
                        if [ $? -ne 0 ]; then
                                echo "Could not create $keytype key: $keypath"
                                exit $SMF_EXIT_ERR_CONFIG
                        fi
                fi
        fi
}

create_ipf_rules()
{
        FMRI=$1
        ipf_file=`fmri_to_file ${FMRI} $IPF_SUFFIX`
        policy=`get_policy ${FMRI}`

        #
        # Get port from sshd_config
        #
        tports=`grep "^Port" "$SSHDIR/sshd_config" 2>/dev/null | \
            awk '{print $2}'`

        echo "# $FMRI" >$ipf_file
        for port in $tports; do
                generate_rules $FMRI $policy "tcp" "any" $port $ipf_file
        done
}

remove_key()
{
        keypath=$1
        if [ -f $keypath ]; then
                grep -i "^[     ]*HostKey[      ]*=\{0,1\}[     ]*$keypath" \
                    $SSHDIR/sshd_config | grep "$keypath" > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                        rm -f ${keypath} ${keypath}.pub
                fi
        fi
}

#
# Makes sure, that sshd_config does not contain single line
# 'ListenAddress ::'.
#
# This used to be part of default SunSSH sshd_config and instructed SunSSH
# to listen on all interfaces. For OpenSSH, the same line means listen on all
# IPv6 interfaces.
#
fix_listenaddress()
{
        fbackup="$SSHDIR/sshd_config.pre_listenaddress_fix"
        reason4change="#\n\
# Historically default sshd_config was shipped with 'ListenAddress ::',\n\
# which means 'listen on all interfaces' in SunSSH.\n\
# In OpenSSH this setting means 'listen on all IPv6 interfaces'.\n\
# To avoid loss of service after transitioning to OpenSSH, the following\n\
# line was commented out by the network/ssh service method script on\n\
#     $(date).\n\
# Original file was backed up to $fbackup\n\
#\n\
# "
        expl4log="Historically default sshd_config was shipped with \
'ListenAddress ::', which means 'listen on all interfaces' in SunSSH. \
In OpenSSH this setting means 'listen on all IPv6 interfaces'. \
For both SunSSH and OpenSSH the default behavior when no ListenAddress \
is specified is to listen on all interfaces (both IPv4 and IPv6)."
        msg_not_removed="Custom ListenAddress setting detected in \
$SSHDIR/sshd_config, the file will not be modified. Please, check your \
ListenAddress settings. $expl4log"
        msg_removed="Removing 'ListenAddress ::'. $expl4log Original file has \
been backed up to $fbackup"

        # only modify sshd_config, if ssh implementation is OpenSSH
        if [[ "$(ssh -V 2>&1)" == Sun_SSH_* ]]; then
                return 0;
        fi

        # comment '# IPv4 & IPv6' indicates an old default sshd_config
        grep -q '^# IPv4 & IPv6$' $SSHDIR/sshd_config || return 0;

        # backup
        cp $SSHDIR/sshd_config $fbackup

        # if 'ListenAddress ::' is the only ListenAddress line, comment it out
        listen_address=$(grep -i '^[ \t]*ListenAddress' $SSHDIR/sshd_config)
        if [[ "$listen_address" == 'ListenAddress ::' ]]; then
                echo $msg_removed
                awk_prog="/^ListenAddress ::$/ {printf(\"$reason4change\")}\
                          !/^# IPv4 & IPv6$/   {print}"
        else
                # send warning message both to log and console
                echo $msg_not_removed | smf_console
                awk_prog="!/^# IPv4 & IPv6$/   {print}"
        fi;

        sshd_config=$(nawk "$awk_prog" $SSHDIR/sshd_config)
        if [[ $? -ne 0 ]]; then
                echo "Update error! Check your ListenAddress settings."
                return 1;
        else
                # write the fixed content to the file
                echo "$sshd_config" > $SSHDIR/sshd_config
                return 0;
        fi

}

# This script is being used for two purposes: as part of an SMF
# start/stop/refresh method, and as a sysidconfig(1M)/sys-unconfig(1M)
# application.
#
# Both, the SMF methods and sysidconfig/sys-unconfig use different
# arguments..

case $1 in
        # sysidconfig/sys-unconfig arguments (-c and -u)
'-c')
        create_key "$SSHDIR/ssh_host_rsa_key" rsa
        create_key "$SSHDIR/ssh_host_dsa_key" dsa
        create_key "$SSHDIR/ssh_host_ecdsa_key" ecdsa
        create_key "$SSHDIR/ssh_host_ed25519_key" ed25519
        ;;

'-u')
        # sysconfig unconfigure to remove the sshd host keys
        remove_key "$SSHDIR/ssh_host_rsa_key"
        remove_key "$SSHDIR/ssh_host_dsa_key"
        remove_key "$SSHDIR/ssh_host_ecdsa_key"
        remove_key "$SSHDIR/ssh_host_ed25519_key"
        ;;

        # SMF arguments (start and restart [really "refresh"])

'ipfilter')
        create_ipf_rules $2
        ;;

'start')
        #
        # If host keys don't exist when the service is started, create
        # them; sysidconfig is not run in every situation (such as on
        # the install media).
        #
        create_key "$SSHDIR/ssh_host_rsa_key" rsa
        create_key "$SSHDIR/ssh_host_dsa_key" dsa
        create_key "$SSHDIR/ssh_host_ecdsa_key" ecdsa
        create_key "$SSHDIR/ssh_host_ed25519_key" ed25519

        #
        # Make sure, that sshd_config does not contain single line
        # 'ListenAddress ::'.
        #
        fix_listenaddress

        # /usr/lib/ssh/sshd
        /opt/ssh/sbin/sshd

        ;;

'restart')
        if [ -f "$PIDFILE" ]; then
                /usr/bin/kill -HUP `/usr/bin/cat $PIDFILE`
        fi
        ;;

*)
        echo "Usage: $0 { start | restart }"
        exit 1
        ;;
esac

exit $?
```
