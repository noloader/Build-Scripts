# Darwin

The Build-Scripts should work out-of-the-box for modern Darwin, like OS X 10.5. Once you run the setup recipes you should be able to build most programs with the scripts.

Modern OpenSSH no longer supports DSA keys by default. Default DSA support was disabled at OpenSSH 7.9. You should ensure you have an Ecdsa or Ed25519 key (or enable DSA keys in `sshd_config`). Also see [OpenSSH Release Notes](https://www.openssh.com/releasenotes.html).

After installing OpenSSH you should also tune `sshd_config` to suit your taste. You can disable password logins, enable public key logins, etc.

## System Integrity Protection

OS X 10.12 added System Integrity Protection (SIP). If SIP is in effect, then you have to disable SIP to modify the Launch Daemon and install `ssh-8.plist`. Also see [Disabling and Enabling System Integrity Protection](https://developer.apple.com/documentation/security/disabling_and_enabling_system_integrity_protection) and [About macOS Recovery on Intel-based Mac computers](https://support.apple.com/en-us/HT201314)..

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

The following steps should be performed to update OpenSSH. The new OpenSSH is permanently installed at `/opt/ssh` (as opposed to a location like `/usr/local`). `/opt/ssh` will have a standard filesystem below it.

```
$ INSTX_PREFIX=/opt/ssh ./build-openssh.sh
```

After building and installing OpenSSH you have to tell Darwin to use it. To do so you create a plist and tell the launch daemon about it.

First, generate new keys and/or copy existing keys to `$INSTX_PREFIX/etc`. You probably have new keys from `make install`, so copy existing keys as required.

Second, create or copy an existing `sshd_config` to `$INSTX_PREFIX/etc`.

Third, open `/System/Library/LaunchDaemons/ssh-8.plist` in a text editor. Add the following launch configuration.

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>Label</key>
        <string>com.openssh.sshd.8</string>
        <key>Program</key>
        <string>/opt/ssh/sbin/sshd</string>
        <key>ProgramArguments</key>
        <array>
                <string>/opt/ssh/sbin/sshd</string>
                <string>-i</string>
                <string>-e</string>
                <string>-f</string>
                <string>/opt/ssh/etc/sshd_config</string>
        </array>
        <key>SHAuthorizationRight</key>
        <string>system.preferences</string>
        <key>Sockets</key>
        <dict>
                <key>Listeners</key>
                <dict>
                        <key>SockServiceName</key>
                        <string>22</string>
                </dict>
        </dict>
        <key>StandardErrorPath</key>
        <string>/var/log/sshd.8.log</string>
        <key>inetdCompatibility</key>
        <dict>
                <key>Wait</key>
                <false/>
        </dict>
</dict>
</plist>
```

Be sure to use a name like `com.openssh.sshd.8` to avoid collisions with Apple's SSH service.

Finally, load the new configuration.

```
sudo launchctl load -w /System/Library/LaunchDaemons/ssh-8.plist
```

If needed, you can disable Apple's SSH daemon with the following.

```
sudo launchctl unload -w /System/Library/LaunchDaemons/ssh.plist
```
